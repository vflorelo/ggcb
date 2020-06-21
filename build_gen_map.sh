#!/bin/bash
file_name="$1"
base_name=$(echo "$file_name" | perl -pe 's/\.gb.*//')
acc_no=$(grep -w ^ACCESSION "$file_name" | awk '{print $2}')
draw_mode="$2"
preload="$3"
if [ -f "$file_name" ]
then
  genome_length=$(seqret $file_name raw::stdout | perl -pe 's/\n//g' | wc -c | awk '{print $1*0.017}')
  gff_str=$(seqret -feature $file_name gff3::stdout | awk '{if($3=="CDS"){print $0}}')
else
  exit 0
fi
gene_height=10
genome_height=8
map_height=25
canvas_width=$genome_length
gene_style_str="style=\"fill:#888888;fill-opacity:1;stroke:#000000;stroke-width:1px;stroke-linecap:butt;stroke-linejoin:round;stroke-opacity:1\""
genome_style_str="style=\"fill:#cccccc;fill-opacity:1;stroke:none\""
genome_top=$(echo "$preload" | awk '{print $1+8.5}')
if [ "$draw_mode" = single ]
then
  out_file=$(echo "$base_name".svg)
  echo "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>
<svg xmlns=\"http://www.w3.org/2000/svg\" version=\"1.1\" width=\"$canvas_width""px\" height=\"$map_height""px\" viewBox=\"0 0 $canvas_width $map_height\" id=\"$acc_no\">
  <path d=\"m 0,$genome_top 0,$genome_height $genome_length,0 0,-$genome_height z\" id=\"$acc_no""_genome\" $genome_style_str><title>$base_name</title></path>" >> "$out_file"
elif [ "$draw_mode" = multi ]
then
  out_file="genomes.svg"
  echo "  <path d=\"m 0,$genome_top 0,$genome_height $genome_length,0 0,-$genome_height z\" id=\"$acc_no""_genome\" $genome_style_str><title>$base_name</title></path>" >> "$out_file"
fi
###########################################################################################
###			Help section. Global Variable Definition			###
###########################################################################################
#	d="M	    x,y		    x,y		   x,y	  	   x,y	 z"	<-Meaning
#	d="M	  a(x,y)	  b(x,y)	 c(x,y)		 d(x,y)	 z"	<-Points
#	d="M	start,top	start,butt	stop,butt	stop,top  "	<-Vars
#	head=5
#	    f
#	a _g|\
#	 |__  Xe
#	b  c|/
#	    d
#	g<--->e = 4
plus_a=$(echo $preload | awk '{print $1+4}')
minus_a=$(echo $preload | awk '{print $1+17}')
plus_datablock=$(echo "$gff_str" | awk 'BEGIN{FS="\t"}{if($7=="+"){print $4*0.017 FS $5*0.017 FS $9}}')
plus_count=$(echo "$plus_datablock" | wc -l)
minus_datablock=$(echo "$gff_str" | awk 'BEGIN{FS="\t"}{if($7=="-"){print $4*0.017 FS $5*0.017 FS $9}}')
minus_count=$(echo "$minus_datablock" | wc -l)
for line_num in $(seq 1 $plus_count)
do
  element_datablock=$(echo "$plus_datablock" | tail -n+$line_num | head -n1)
  locus_tag=$(echo $element_datablock | cut -f3 | perl -pe 's/\;/\n/g' | awk 'BEGIN{FS="="}{if($1=="locus_tag"){print $2}}')
  product=$(echo $element_datablock | cut -f3 | perl -pe 's/\;/\n/g' | awk 'BEGIN{FS="="}{if($1=="product"){print $2}}')
  if [ -z "$locus_tag" ]
  then
    locus_tag=$(echo "$acc_no""_""$line_num")
  fi
  if [ -z "$product" ]
  then
    product="Undefined_product_$line_num"
  fi
  gene_start=$(echo "$element_datablock" | cut -f1)
  gene_arrow_base=$(echo "$element_datablock" | awk 'BEGIN{FS="\t"}{if( (($2-$1)-3) > 0 ) print ($2-$1)-3; else print 0}')
  echo "  <path d=\"m $gene_start,$plus_a 0,4 $gene_arrow_base,0 0,3 3,-5 -3,-5 0,3 z\" id=\"$locus_tag\" $gene_style_str ><title>$locus_tag - $product</title></path>"
done >> "$out_file"
for line_num in $(seq 1 $minus_count)
do
  element_datablock=$(echo "$minus_datablock" | tail -n+$line_num | head -n1)
  locus_tag=$(echo $element_datablock | cut -f3 | perl -pe 's/\;/\n/g' | awk 'BEGIN{FS="="}{if($1=="locus_tag"){print $2}}')
  product=$(echo $element_datablock | cut -f3 | perl -pe 's/\;/\n/g' | awk 'BEGIN{FS="="}{if($1=="product"){print $2}}')
  if [ -z "$locus_tag" ]
  then
    locus_tag=$(echo "$acc_no""_""$line_num")
  fi
  if [ -z "$product" ]
  then
    product="Undefined product $line_num"
  fi
  gene_start=$(echo "$element_datablock" | cut -f2)
  gene_arrow_base=$(echo "$element_datablock" | awk 'BEGIN{FS="\t"}{if( (($2-$1)-3) > 0 ) print ($2-$1)-3; else print 0}')
  echo "  <path d=\"m $gene_start,$minus_a 0,4 -$gene_arrow_base,0 0,3 -3,-5 3,-5 0,3 z\" id=\"$locus_tag\" $gene_style_str ><title>$locus_tag - $product</title></path>"
done >> "$out_file"

if [ "$draw_mode" = single ]
then
  echo "</svg>" >> "$out_file"
  svg_integrity=$(xmllint --noout "$ou_file")
  if [ -z "$svg_integrity" ]
  then
    echo "success" | perl -pe 's/\n//g' 1>&2
  elif [ ! -z "$svg_integrity" ]
  then
    echo "fail" | perl -pe 's/\n//g' 1>&2
  fi
fi
exit 0

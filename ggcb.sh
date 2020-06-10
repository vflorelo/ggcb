#!/bin/bash
bin_dir="/usr/local/bioinformatics/local_scripts"
run_mode=$(echo "$1" | tr '[:upper:]' '[:lower:]')
eval_cutoff="$2"
aln_length_cutoff="$3"
genome_order_file="$4"
if [ -z $1 ]
then
  echo "Arg 1 run mode [ blastn, tblastx ]"
  echo "Arg 2 e-value cutoff [ floating, <1 -> 0.0 ]"
  echo "Arg 3 minimum alignment length [ integer > 20 ]"
  echo "Arg 4 genome order file [ optional ]"
  exit 0
fi
file_datablock=$(grep -v ^$ "$genome_order_file")
num_files=$(echo "$file_datablock" | wc -l)
num_comparisons=$(echo "$num_files" | awk '{print $1-1}')
for line_num in $(seq 1 $num_files)
do
  file_name=$(echo "$file_datablock" | tail -n+$line_num | head -n1)
  if [ ! -f "$file_name" ]
  then
    echo "Missing file(s)"
    exit 0
  else
    echo "****** Files in order ******"
  fi
done
if [ "$run_mode" = blastn ]
then
  comp_command="blastn -query sequence_2 -subject sequence_1 -out blast_comparison_file -outfmt \"6 qseqid sseqid qstart sstart qend send evalue score length\" -evalue $eval_cutoff"
elif [ "$run_mode" = tblastx ]
then
  comp_command="tblastx -query sequence_2 -subject sequence_1 -out blast_comparison_file -outfmt \"6 qseqid sseqid qstart sstart qend send evalue score length\" -evalue $eval_cutoff -best_hit_overhang 0.2"
fi
genome_lengths=""
for comp_num in $(seq 1 $num_comparisons)
do
  genome_preload=$(echo $comp_num | awk '{print ($1*43)}')
  block_preload=$(echo $comp_num  | awk '{print (($1-1)*43)+16.5}')
  echo -e "$genome_preload\n$block_preload"
  file_name_1=$(echo "$file_datablock" | tail -n+$comp_num | head -n1)
  file_name_2=$(echo "$file_datablock" | tail -n+$comp_num | head -n2 | tail -n1)
  seqret $file_name_1 fasta::sequence_1
  seqret $file_name_2 fasta::sequence_2
  seq_length_1=$(grep -v \> sequence_1 | perl -pe 's/\n//g' | wc -c)
  seq_length_2=$(grep -v \> sequence_2 | perl -pe 's/\n//g' | wc -c)
  genome_lengths=$(echo -e "$genome_lengths\n$seq_length_1\n$seq_length_2")
  eval "$comp_command"
  cat blast_comparison_file >> full_$run_mode\_comparison.tsv
  if [ "$comp_num" -eq "1" ]
  then
    ${bin_dir}/build_gen_map.sh $file_name_1 multi 0
  fi
  ${bin_dir}/build_gen_map.sh $file_name_2 multi $genome_preload
  blast_datablock=$(awk -v cutoff="$aln_length_cutoff" 'BEGIN{FS="\t"}{if($9 >= cutoff){print $AF }}' blast_comparison_file | sort -nk9 )
  num_blocks=$(echo "$blast_datablock" | wc -l)
  #	qseqid	sseqid	qstart	sstart	qend	send	evalue	score	length
  #	  $1	  $2	  $3	  $4	 $5	 $6	  $7	 $8	  $9
  #	unused	unused	  b	  a	  c	  d	color	color	filter
  for block_num in $(seq 1 $num_blocks)
  do
    block_id="block_$block_num"
    datablock=$(echo "$blast_datablock" | tail -n+$block_num | head -n1)
    sequence_1=$(echo "$datablock" | cut -f1)
    sequence_2=$(echo "$datablock" | cut -f2)
    block_upper_start=$(echo "$datablock" | awk 'BEGIN{FS="\t"}{print $4*0.017}')		#begin of subject
    block_upper_end=$(echo "$datablock"   | awk 'BEGIN{FS="\t"}{print ((($6-$4)+1)*0.017)}')	#end of subject minus start of subject
    block_lower_end=$(echo "$datablock"   | awk 'BEGIN{FS="\t"}{print ((($6-$5)+1)*0.017)}')	#end of subject minus end of query
    block_lower_start=$(echo "$datablock" | awk 'BEGIN{FS="\t"}{print ((($5-$3)+1)*0.017)}')	#end of query minus start of query
    info_str=$(echo "$datablock" | awk 'BEGIN{FS="\t"}{print "e-value="$7,"score="$8,"length="$9}')
    block_precolor=$(echo "$datablock"    | awk 'BEGIN{FS="\t"}{if ( $7 < 1e-4  && $7 >= 1e-10 ){print "ffff"}else if ( $7 < 1e-10 && $7 >= 1e-20 ){print "e3e3"}else if ( $7 < 1e-20 && $7 >= 1e-30 ){print "c6c6"}else if ( $7 < 1e-30 && $7 >= 1e-40 ){print "aaaa"}else if ( $7 < 1e-40 && $7 >= 1e-50 ){print "8d8d"}else if ( $7 < 1e-50 && $7 >= 1e-60 ){print "7171"}else if ( $7 < 1e-60 && $7 >= 1e-70 ){print "5454"}else if ( $7 < 1e-70 && $7 >= 1e-80 ){print "3838"}else if ( $7 < 1e-80 && $7 >= 1e-90 ){print "1b1b"}else if ( $7 < 1e-90 ){print "0000"}}')
    block_color=$(echo "$datablock"       | awk -v block_precolor="$block_precolor" 'BEGIN{FS="\t"}{if( ($5 >= $3) && ($6 >= $4) ){print "ff"block_precolor}else if( ($5 >= $3) && ($6 <  $4) ){print block_precolor"ff"}else if( ($5 <  $3) && ($6 <  $4) ){print "ff"block_precolor}else if( ($5 <  $3) && ($6 >= $4) ){print block_precolor"ff"}}')
    style_string="fill:#$block_color;fill-opacity:1;stroke:none"
    title_string="$sequence_1 $sequence_2 $info_str"
    echo "  <path d=\"m $block_upper_start,$block_preload $block_upper_end,0 -$block_lower_end,35 -$block_lower_start,0 z\" id=\"$block_id\" style=\"$style_string\" ><title>$title_string</title></path>" | perl -pe 's/\-\-/\+/g'
  done >> blocks.svg
done
map_width=$(echo "$genome_lengths" | grep -vi [a-z] | sort -n | uniq | awk '{print $1*0.017}' | tail -n1)
map_height=$(echo $num_comparisons | awk '{ print ((($1-1)*43)+68) }')
echo "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>" > full_$run_mode\_comparison.svg
echo "<svg xmlns=\"http://www.w3.org/2000/svg\" version=\"1.1\" width=\"$map_width""px\" height=\"$map_height""px\" viewBox=\"0 0 $map_width $map_height\" id=\"genome_comparison\">" >> full_$run_mode\_comparison.svg
cat blocks.svg genomes.svg >> full_$run_mode\_comparison.svg
echo "</svg>" >> full_$run_mode\_comparison.svg
svg_integrity=$(xmllint --noout full_"$run_mode"_comparison.svg)
if [ -z "$svg_integrity" ]
then
  echo "success" | perl -pe 's/\n//' 1>&2
  rm -rf genomes.svg blocks.svg sequence_1 sequence_2 blast_comparison_file
elif [ ! -z "$svg_integrity" ]
then
  echo "fail" | perl -pe 's/\n//' 1>&2
fi
exit 0

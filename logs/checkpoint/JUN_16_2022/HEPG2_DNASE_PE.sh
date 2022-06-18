#!/bin/bash

cell_line=HEPG2
data_type="DNASE_PE"

date=$(date +'%m.%d.%Y')
cur_file_name="HEPG2_DNASE_PE.sh"
setting="DNASE_PE_"$date
### SIGNAL INPUT
gpu=7
in_bam=/oak/stanford/groups/akundaje/projects/chrombpnet/model_inputs/DNASE/filtered_bams/HEPG2/HEPG2.merged.filtered.sorted.bam
overlap_peak=/oak/stanford/groups/akundaje/projects/chrombpnet/model_inputs/DNASE/optimal_overlap_peaks/HEPG2.overlap.optimal_peak.narrowPeak.gz

blacklist_region=/mnt/data/annotations/blacklist/GRch38/GRch38_unified_blacklist.bed.gz
chrom_sizes=/mnt/data/annotations/by_release/hg38/hg38.chrom.sizes
ref_fasta=/mnt/data/GRCh38_no_alt_analysis_set_GCA_000001405.15.fasta
genomewide_gc="/oak/stanford/groups/akundaje/anusri/refs/genomewide_gc_hg38_stride_1000_inputlen_2114.bed"
fold=/oak/stanford/groups/akundaje/projects/chrombpnet/model_inputs/ENCODE_ATAC_downloads/splits/fold_0.json
bias_threshold_factor=0.8
bias_filters=128
bias_dil=4
seed=1234

oak_dir=/oak/stanford/groups/akundaje/projects/chrombpnet_paper_new/$data_type/$cell_line/
main_dir=$PWD/results/chrombpnet/$data_type/$cell_line
data_dir=$main_dir/data
neg_dir=$main_dir/negatives_data
output_dir=$PWD/results/chrombpnet/$data_type/$cell_line/$setting
echo $output_dir
inputlen=2114

function timestamp {
    # Function to get the current time with the new line character
    # removed 
    
    # current time
    date +"%Y-%m-%d_%H-%M-%S" | tr -d '\n'
}


## CREATE DIRS
if [[ -d $main_dir ]] ; then
    echo "main director already exists"
else
    mkdir $main_dir
fi

#if [[ -d $output_dir ]] ; then
#    echo "output director already exists"
#else
#    mkdir $output_dir
#fi


### CREATE BIGWIGS AND REMOVE BLACKLIST FROM PEAK EDGES

if [[ -d $data_dir ]] ; then
    echo "bigwig director already exists"
else
    mkdir $data_dir
    bash step2_make_bigwigs_from_bams.sh $in_bam $data_dir"/"$cell_line $data_type $ref_fasta $chrom_sizes 
    
    logfile=$data_dir"/"$cell_line"_preprocessing.log"

    flank_size=$(( inputlen/2 ))
    echo $( timestamp ): "bedtools slop -i $blacklist_region -g $chrom_sizes -b $flank_size > $data_dir/temp.txt" | tee -a $logfile
    bedtools slop -i $blacklist_region -g $chrom_sizes -b $flank_size > $data_dir/temp.txt
    echo $( timestamp ): "bedtools intersect -v -a $overlap_peak -b $data_dir/temp.txt > $data_dir/peaks_no_blacklist.bed" | tee -a $logfile
    bedtools intersect -v -a $overlap_peak -b $data_dir/temp.txt  > $data_dir/peaks_no_blacklist.bed
    echo $( timestamp ): "rm  $data_dir/temp.txt" | tee -a $logfile
    rm  $data_dir/temp.txt

    echo $( timestamp ): "shuf -n 30000 $data_dir/peaks_no_blacklist.bed > $data_dir/30K.subsample.overlap.bed" | tee -a $logfile
    shuf -n 30000 $data_dir/peaks_no_blacklist.bed > $data_dir/30K.subsample.overlap.bed

    cp $PWD/$cur_file_name $data_dir
fi

overlap_peak=$data_dir/peaks_no_blacklist.bed

## MAKE NEGATIVES BED FILE
if [[ -d $neg_dir ]] ; then
    echo "negatives director already exists"
else
    mkdir $neg_dir
    bash step3_get_background_regions.sh $ref_fasta $chrom_sizes $blacklist_region $overlap_peak $inputlen $genomewide_gc $neg_dir $fold 
fi






# Scripts to do variant effect prediction using ChromBPNet

The scripts in this folder are used to do variant effect prediction using chrombpnet models. We tested these models on bQTLS (Tehranchi et al. 2016) and dsQTLS (Degner et al 2012). We benchmarked the performance of dsQTLs with deltaSVM (Lee et al. 2015). Scripts to reproduce these results will be provided soon.

## Usage

```
python snp_scoring.py -i [snp_data_tsv] -g [genome_fasta] -m [model_hdf5] -o [output_dir] -bs [batch_size] -dm [debug_mode_on]
```

The following assumptions are made with this script - make changes accordingly if the assumptions dont hold.

- The script is designed to work only with SNPs - so make sure reference and alternate allele are just one character. 
- The script returns the following three effect scores - 
    - log counts difference in alternate allele and reference allele predictions (`log_counts_diff`)
    - Sum of absolute difference in log probabilites per base (`log_probs_diff_abs_sum`) between alternate allele and reference allele predictions 
    - Jensenshannon distance between alternate allele profile probability predictions and reference allele profile probability predictions (`probs_jsd_diff`).
- Carefully read the input format of `snp_data_tsv` below.
- The input sequence length (`inputlen`) is inferred from the model. In chrombpnet models the `inputlen` used is an even number to ensure symmtery. So here we insert the allele at `inputlen`//2 locus (assuming 0-based indexing of sequence `[0,inputlen)`) - which means that the sequence left of allele is 1bp longer than the sequence right of allelle.
- If the reference/alternate allele are at the edge of chromosome - preventing us from generating an `inputlen` sequence - we will ignore this SNP and print the locus information of the ignored SNP. This might result in the final number of output SNPs being predicted on being smaller than the given input SNPs. Read the output format section to see how this effects the final output.

## Example Usage

```
python snp_scoring.py -i /mnt/lab_data2/anusri/variant_effect_prediction_example/subsample_test.csv -g /mnt/data/male.hg19.fa -m /path/to/model.hdf5 -o /path/to/store/output -bs 64
```

## Input Format

- snp_data_tsv: A TSV file with the following 5 columns -  chr, position (0-based) to insert the allele, reference allele, alternate alllele, meta-data. You can leave the meta-data empty too. 
    - Meta-data column can be used to provide the following information such as p-value significance of the SNP, observed effect scores etc. This information will be added as column information to the output `variant_scores.tsv` (see below) which you can use for downtream analysis. For example look at the input tsv file that I use here - `/mnt/lab_data2/anusri/variant_effect_prediction_example/subsample_test.csv` where the meta-data provides multiple SNP related information such as significance and observed effect scores as comma-seperated values. Provide any SNP related information to this column as **comma-seperated values**.
    - The reference genome loader used is `pyfaidx` which is 0-based and hence the allele position provided in `snp_data_tsv` is expected to be 0-based too. Always check if you are inserting the allele correctly by using the code in the `debug_mode_on`.
    - Make sure there are no duplicate rows in this file.
- genome_fasta: Reference geneome fasta. 
- model_hdf5: Model in hdf5 format.
- output_dir: Directory to store the output files. Make sure the directory already exists. The code generates two output files described below in output format section.
- batch_size: Batch size to use for model predictions.
- debug_mode_on: Takes a value of 1 or 0. This is by default set to 0. When set to 1 we score only the first 5 SNPs in `snp_data_tsv`. In addition we also print to the console the right and left flank of the locus where the SNP is being inserted in. You can check if these flanks match with the flanks as reported in existing databases such as dbSNP (https://www.ncbi.nlm.nih.gov/snp/). If it does not your position values in `snp_data_tsv` will need correction.


## Output Format

- variant_scores.tsv: A TSV file with 8 columns - five columns copied in from the `snp_data_tsv`  along with with the following three added columns -  `log_counts_diff`,  `log_probs_diff_abs_sum`, `probs_jsd_diff` which represent the following - 
    - `log_counts_diff`: log counts difference in alternate allele and reference allele predictions 
    - `log_probs_diff_abs_sum`: Sum of absolute difference in log probabilites per base between alternate allele and reference allele predictions 
    - `probs_jsd_diff`: Jensenshannon distance between alternate allele profile probability predictions and reference allele profile probability predictions. 
The number of rows in this TSV file can be less than rows provided in the `snp_data_tsv` - this is because we are skipping reference/alternate allele that fall at the edge of chromosome preventing us from generating an `inputlen` sequence. 
- predictions_at_snp.pkl: A pickle file containing a dictionary with the following keys - `rsids`, `ref_logcount_preds`, `alt_logcount_preds`, `ref_prob_preds`, `alt_prob_preds`. This pickle stores the model predictions at each of the SNP locations.
    - `rsids` consists of a list of strings - each value formed by concatenating the following 5 values (Chr, position (0-based) to insert the allele, reference allele, alternate alllele, meta-data) seperated by a underscore. An example rsid will look like this - `chr1_100054_A_G_0.55` when meta data is provided, when meta-data is empty it looks like this -  `chr1_100054_A_G_` 
    - `ref_logcount_preds`: Consists of the log count predictions when the reference allele is inserted. Has the same length as the `rsids`
    - `ref_logcount_preds`: Consists of the log count predictions when the alternate allele is inserted. Has the same length as the `rsids`
    - `ref_prob_preds`: Consists of the profile probability predictions when the reference allele is inserted. Has the same length as the `rsids`
    - `alt_prob_preds`: Consists of the profile probability predictions when the alternate allele is inserted. Has the same length as the `rsids`
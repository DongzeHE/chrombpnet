# exit when any command fails
set -e

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT

reference_fasta=$1
bigwig_path=$2
overlap_peak=$3
nonpeaks=$4
fold=$5
bias_threshold_factor=$6
output_dir=$7
bias_filters=$8
bias_dil=$9
seed=${10}
logfile=${11}

# defaults
inputlen=2114
outputlen=1000
filters=$bias_filters
n_dilation_layers=$bias_dil
seed=$seed

if [ -z "$bias_filters" ]
  then
    filters=128
fi

if [ -z "$bias_dil" ]
  then
    n_dilation_layers=4
fi

if [ -z "$seed" ]
  then
    seed=1234
fi

function timestamp {
    # Function to get the current time with the new line character
    # removed 
    
    # current time
    date +"%Y-%m-%d_%H-%M-%S" | tr -d '\n'
}

# create the log file
if [ -z "$logfile" ]
  then
    echo "No logfile supplied - creating one"
    logfile=$output_dir"/train_bias_model.log"
    touch $logfile
fi

# this script does the following -  
# (1) filters your peaks/nonpeaks (removes outliers and removes edge cases and creates a new filtered set)
# (2) filters non peaks based on the given bias threshold factor
# (3) Calculates the counts loss weight 
# (4) Creates a TSV file that can be loaded into the next step
echo $( timestamp ): "python $PWD/src/helpers/hyperparameters/find_bias_hyperparams.py \\
       --genome=$reference_fasta \\
       --bigwig=$bigwig_path \\
       --peaks=$overlap_peak \\
       --nonpeaks=$nonpeaks \\
       --outlier_threshold=0.99 \\
       --chr_fold_path=$fold \\
       --inputlen=$inputlen \\
       --outputlen=$outputlen \\
       --max_jitter=0 \\
       --filters=$filters \\
       --n_dilation_layers=$n_dilation_layers \\
       --bias_threshold_factor=$bias_threshold_factor \\
       --output_dir $output_dir" | tee -a $logfile

python $PWD/src/helpers/hyperparameters/find_bias_hyperparams.py \
       --genome=$reference_fasta \
       --bigwig=$bigwig_path \
       --peaks=$overlap_peak \
       --nonpeaks=$nonpeaks \
       --outlier_threshold=0.99 \
       --chr_fold_path=$fold \
       --inputlen=$inputlen \
       --outputlen=$outputlen \
       --max_jitter=0 \
       --filters=$filters \
       --n_dilation_layers=$n_dilation_layers \
       --bias_threshold_factor=$bias_threshold_factor \
       --output_dir $output_dir | tee -a $logfile

# this script does the following -  
# (1) trains a model on the given peaks/nonpeaks
# (2) The parameters file input to this script should be TSV seperated 
echo $( timestamp ): "python $PWD/src/training/train.py \\
       --genome=$reference_fasta \\
       --bigwig=$bigwig_path \\
       --nonpeaks=$output_dir/filtered.bias_nonpeaks.bed \\
       --params=$output_dir/bias_model_params.tsv \\
       --output_prefix=$output_dir/bias \\
       --chr_fold_path=$fold \\
       --seed=$seed \\
       --batch_size=64 \\
       --architecture_from_file=$PWD/src/training/models/bpnet_model.py \\
       --trackables logcount_predictions_loss loss logits_profile_predictions_loss val_logcount_predictions_loss val_loss val_logits_profile_predictions_loss" | tee -a $logfile

python $PWD/src/training/train.py \
       --genome=$reference_fasta \
       --bigwig=$bigwig_path \
       --nonpeaks=$output_dir/filtered.bias_nonpeaks.bed \
       --params=$output_dir/bias_model_params.tsv \
       --output_prefix=$output_dir/bias \
       --chr_fold_path=$fold \
       --seed=$seed \
       --batch_size=64 \
       --architecture_from_file=$PWD/src/training/models/bpnet_model.py \
       --trackables logcount_predictions_loss loss logits_profile_predictions_loss val_logcount_predictions_loss val_loss val_logits_profile_predictions_loss  | tee -a $logfile

# predictions and metrics on the bias model trained
echo $( timestamp ): "python $PWD/src/training/predict.py \\
        --genome=$reference_fasta \\
        --bigwig=$bigwig_path \\
        --nonpeaks=$output_dir/filtered.bias_nonpeaks.bed \\
        --chr_fold_path=$fold \\
        --inputlen=$inputlen \\
        --outputlen=$outputlen \\
        --output_prefix=$output_dir/bias \\
        --batch_size=256 \\
        --model_h5=$output_dir/bias.h5" | tee -a $logfile

python $PWD/src/training/predict.py \
        --genome=$reference_fasta \
        --bigwig=$bigwig_path \
        --nonpeaks=$output_dir/filtered.bias_nonpeaks.bed \
        --chr_fold_path=$fold \
        --inputlen=$inputlen \
        --outputlen=$outputlen \
        --output_prefix=$output_dir/bias \
        --batch_size=256 \
        --model_h5=$output_dir/bias.h5 | tee -a $logfile

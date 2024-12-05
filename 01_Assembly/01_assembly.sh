#!/bin/bash 

# this script is a wrapper for the assembly of the Cichlome project. 
# It will run the assembly of the reads using Megahit. 
# Then it will run quast to evaluate the assembly. 
# this script can be run on the frontend of the cluster and will submit the jobs to the cluster. 

# set output flags
while getopts c:o: flag
do
    case "${flag}" in
        o) out=${OPTARG};; # output directory
        c) config=${OPTARG};; # config file
    esac
done

# check if arguments are provided
if [ -z "$out" ] || [ -z "$config" ]
then
    echo "Arguments missing"
    echo "usage: $0 -o <output> -c <config>"
    exit 1
fi

# set config file
config_file=$config

# create log directory
mkdir -p log

echo "##############################################################"
echo "Running 01_Assembly.sh"
echo -e "##############################################################\n"

source ~/.bashrc
conda activate assembly_env

# use yq to parse the config file
samples=$(yq '.SAMPLES | keys[]' $config_file)

# loop over all samples and submit the assembly job
for sample in $samples
do
    # get the R1 file it is the first value of the sample key, yq doesn't recognize variables so we need to use eval
    R1=$(yq ".SAMPLES.$sample[0]" $config_file)
    R2=$(yq ".SAMPLES.$sample[1]" $config_file)

    # strip quotes
    R1=$(echo $R1 | sed 's/"//g')
    R2=$(echo $R2 | sed 's/"//g')
    sample=$(echo $sample | sed 's/"//g')

    # R1 and R2 path are relative to the config file, we to adjust them to be relative to the script
    # if the path is already absolute or starts with ~ we don't need to do anything
    if [[ ! $R1 == /* ]] && [[ ! $R1 == ~* ]]
    then
        R1=$(dirname $config_file)/$R1
        R2=$(dirname $config_file)/$R2
    fi

    # create output directory
    mkdir -p $out/assemblies
    out_dir=$out/assemblies/$sample

    # check if the assembly already exists
    if [ -f $out_dir/megahit.done ]
    then
        # check if the assembly is complete
        if [ -f $out_dir/${sample}.contigs.fa ]
        then
            echo -e "\nAssembly for $sample already exists, skipping"
            continue
        fi

        # if assembly is not complete, remove the directory
        echo -e "\nAssembly for $sample is incomplete, removing and rerunning"
        rm -r $out_dir
    fi

    # if there are less then 100 jobs in the queue, submit the job
    while [ $(squeue -u $USER | grep megahit | wc -l) -gt 100 ]
    do
        sleep 10
    done

    # submit job to the cluster 
    sbatch --job-name=megahit_$sample megahit.sh -1 $R1 -2 $R2 -p $sample -o $out_dir
done

# wait for all jobs to finish
echo -e "\nWaiting for all MEGAHIT jobs to finish..."
while [ $(squeue -u $USER | grep megahit | wc -l) -gt 0 ]
    do
        sleep 10
    done

# check if all jobs finished successfully
if [ $(grep -c "megahit.done" $out/assemblies/*/megahit.done | wc -l) -eq $(echo $samples | wc -w) ]
then
    echo -e "All MEGAHIT jobs finished successfully"
else
    echo -e "Not all MEGAHIT jobs finished successfully"
    exit 1
fi

echo "#####################################################################"
echo "Running QUAST to evaluate the assembly"
echo -e "#####################################################################\n"

for sample in $samples
do
    sample=$(echo $sample | sed 's/"//g')

    # set the output directory
    mkdir -p $out/quast
    out_dir=$out/quast/$sample

    # check if the assembly already exists, skip if it does
    if [ -f $out_dir/quast.done ]
    then
        echo -e "\nQuast for $sample already exists, skipping"
        continue
    fi

   # if there are less then 100 jobs in the queue, submit the job
    while [ $(squeue -u $USER | grep quast | wc -l) -gt 100 ]
        do
            sleep 10
        done

   # run quast
    sbatch --job-name=quast_$sample quast.sh -i $out/assemblies/$sample/${sample}.contigs.fa -o $out_dir
done

# wait for all jobs to finish
echo -e "\nWaiting for all QUAST jobs to finish..."
while [ $(squeue -u $USER | grep quast | wc -l) -gt 0 ]
    do
        sleep 10
    done

# get all quast output directories
quast_dirs=$(find $out/quast -maxdepth 1 -mindepth 1 -type d)

# check if number of quast directories is equal to the number of samples
if [ $(grep -c "quast.done" $out/quast/*/quast.done | wc -l ) -eq $(echo $samples | wc -w) ]
    then
        echo -e "\nGOOD: All QUAST jobs finished successfully"
    else
        echo -e "\n ERROR: Not all quast jobs finished successfully"
        exit 1
    fi

# run multiqc
source ~/.bashrc
conda activate assembly_env
echo -e "\nRunning multiqc"
multiqc --interactive -f -o $out $quast_dirs


echo -e "\n******01_Assembly.sh DONE******\n"



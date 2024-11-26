#!/bin/bash 

# this script is a wrapper for the MAGs binning of the Cichlome project. 
# it will index the assemblies. 
# Run the backmappping. 
# Process the mapping output. 
# Bin the mags.

# set output flags
while getopts c:o:t:a:s: flag
do
    case "${flag}" in
        o) out=${OPTARG};; # output directory
        c) config=${OPTARG};; # config file
        t) tmp=${OPTARG};; # tmp directory to dump intermediate mapping files
        a) assembly_dir=${OPTARG};; # assembly directory
        s) simka=${OPTARG};; # simka output directory
    esac
done

# check if arguments are provided
if [ -z "$out" ] || [ -z "$config" ] || [ -z "$tmp" ] || [ -z "$assembly_dir" ] || [ -z "$simka" ]
then
    echo "Arguments missing"
    echo "usage: $0 -o <output> -c <config> -t <tmp directory> -a <assembly directory> -s <simka directory>"
    exit 1
fi

# set config file
config_file=$config

# create log directory
mkdir -p log

# create output directory
mkdir -p $out

# create temporary directory
mkdir -p $tmp

# activate conda environment
source ~/.bashrc
conda activate assembly_env

# get samples
samples=$(yq '.SAMPLES | keys[]' $config_file)
samples=$(echo $samples | sed 's/"//g') # strip quotes

echo "##############################################################"
echo "Running 03_MAGs_assembly.sh"
echo -e "##############################################################\n"


echo "##############################################################"
echo "Index the assemblies"
echo -e "##############################################################\n"

for sample in $samples
do
    assembly=$assembly_dir/assemblies/$sample/$sample.contigs.fa

    index_dir=$out/index/$sample

    # check if the index already exists, if yes skip the creation
    if [ -f $index_dir/index.1.bt2 ]
    then
        echo -e "\n\tIndex of $assembly already exists, skipping"
        continue
    fi

    # index the assembly
    echo -e "\n\tIndexing $assembly"

    # if more than 100 jobs are already running, wait until there are less than 100 jobs running
    while [ $(squeue -u $USER | grep index | wc -l) -gt 100 ]
    do
        echo -e "\tMore than 100 jobs are running, waiting..."
        sleep 10
    done

    sbatch --job-name=index_${sample} index_sample.sh -o $index_dir -a $assembly
done

# wait for all jobs to finish
echo -e "\nWaiting for all indexing jobs to finish..."
while [ $(squeue -u $USER | grep index | wc -l) -gt 0 ]
do
    sleep 10
done

# check if all indexes were created
if [ $(ls $out/index | wc -l) -ne $(echo $samples | wc -w) ]
then
    echo "ERROR: Not all indexes were created"
    exit 1
else
    echo -e "\nAll indexes were created"
fi

echo "##############################################################"
echo "Run the backmapping"
echo -e "##############################################################\n"

simka_file=$simka/parse_simka_output/simka_table.tsv

# create hashmap where the keys are the assemblies in the simka file 
# and the values are number of rows each assembly has in the simka file
declare -A asmbls
while read -r asmbl sam; do
    if [ -z "${asmbls[$asmbl]}" ]; then
        asmbls[$asmbl]=1
    else
        asmbls[$asmbl]=$((${asmbls[$asmbl]} + 1))
    fi
done < <(tail -n +2 "$simka_file")

# iterate over the line of the simka file, skip the header
tail -n +2 $simka_file | while read -r asmbl sam
    do

        # get the index directory
        index=$out/index/$asmbl/index

        # add quotes to the sample name
        sam_n="\"$sam\""

        # get the reads
        R1=$(yq ".SAMPLES.$sam_n[0]" $config_file)
        R2=$(yq ".SAMPLES.$sam_n[1]" $config_file)
        R1=$(echo $R1 | sed 's/"//g')
        R2=$(echo $R2 | sed 's/"//g') # strip quotes

        # R1 and R2 path are relative to the config file, we to adjust them to be relative to the script
        # if the path is already absolute or starts with ~ we don't need to do anything
        if [[ ! $R1 == /* ]] && [[ ! $R1 == ~* ]]
            then
                R1=$(dirname $config_file)/$R1
                R2=$(dirname $config_file)/$R2
        fi

        # get absolute path
        R1=$(realpath $R1)
        R2=$(realpath $R2)

        # get the output directory
        out_dir=$tmp/$asmbl

        # check if there are less than 100 jobs running
        while [ $(squeue -u $USER | grep backmap | wc -l) -gt 100 ]
            do
                echo -e "\tMore than 100 jobs are running, waiting..."
                sleep 10
            done
        
        # check if the output file already exists, if yes skip the creation
        if [ -f $out_dir/${sam}_mapping.depth ]
            then
                echo -e "\n\tBackmapping of $asmbl for $sam already exists, skipping"
                continue
            fi

        # if more than 100 jobs are already running, wait until there are less than 100 jobs running
        while [ $(squeue -u $USER | grep backmap | wc -l) -gt 100 ]
            do
                echo -e "\tMore than 100 jobs are running, waiting..."
                sleep 10
            done

        # run the backmapping
        sbatch --job-name=backmap_assembly-${asmbl}_sample-${sam} backmap.sh -1 $R1 -2 $R2 -i $index -o $out_dir -s $sam  

    done

# wait for all jobs to finish
echo -e "\nWaiting for all backmapping jobs to finish..."
while [ $(squeue -u $USER | grep backmap | wc -l) -gt 0 ]
    do
        sleep 10
    done

# check if all backmapping jobs were created, use the asmbls hashmap to see that each directoiry has the correct number of files
for asmbl in $(echo ${!asmbls[@]})
    do
        if [ $(ls $tmp/$asmbl | wc -l) -ne ${asmbls[$asmbl]} ]
        then
            echo "ERROR: Not all backmapping jobs were created for $asmbl"
            exit 1
        else
            echo -e "\nAll backmapping jobs were created for $asmbl"
        fi
    done

echo "##############################################################"
echo "Bin the MAGs"
echo -e "##############################################################\n"

for asmbl in $samples; do
    out_dir=$out/MAGs
    assembly=$assembly_dir/assemblies/$asmbl/$asmbl.contigs.fa

    # check if the output file already exists, if yes skip the creation
    if [ -f $out_dir/{asmbl}_depths.txt ]
    then
        echo -e "\n\tBinning of $asmbl already exists, skipping"
        continue
    fi

    mkdir -p $out_dir

    # if more than 100 jobs are already running, wait until there are less than 100 jobs running
    while [ $(squeue -u $USER | grep bin | wc -l) -gt 100 ]
        do
            echo -e "\tMore than 100 jobs are running, waiting..."
            sleep 10
        done

    # bin the MAGs
    echo -e "\n\tBinning $asmbl"
    sbatch --job-name=bin_assembly-$asmbl bin_MAGs.sh -i $tmp/$asmbl -o $out_dir -a $asmbl -d $assembly 
done

# wait for all jobs to finish
echo -e "\nWaiting for all binning jobs to finish..."
while [ $(squeue -u $USER | grep bin | wc -l) -gt 0 ]
    do
        sleep 10
    done

# check if all bins were created
if [ $(ls $out/MAGs/*_MAGs | wc -l) -ne $(echo $samples | wc -w) ]
then
    echo "ERROR: Not all bins were created"
    exit 1
else
    echo -e "\nAll bins were created"
fi

echo "##############################################################"
echo "03_MAGs_assembly.sh finished"
echo -e "##############################################################\n"
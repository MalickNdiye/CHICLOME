#!/bin/bash 

# this script is a wrapper for the kmer clustering of the Cichlome project. 
# It first will create a list file to feed to simka. 
# then it will ran simka. 
# finally it will parse the simka output to obtain the combination of files for the backmapping. 

###################### FLAGS ######################
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


############# Prepare config and log files #############
# set config file
config_file=$config

# create log directory
mkdir -p log

echo "##############################################################"
echo "Running 02_Kmers_clustering.sh"
echo -e "##############################################################\n"

source ~/.bashrc
conda activate assembly_env # it contain yq to parse the config file

# use yq to parse the config file
samples=$(yq '.SAMPLES | keys[]' $config_file)

# create output directory
mkdir -p $out

echo "##############################################################"
echo "1) Creating list file for simka"
echo -e "##############################################################\n"

list_file=$out/simka_list.txt

# check if the list file already exists, if yes skip the creation
if [ ! -f $list_file ]
then
    for sample in $samples
    do
        # get the R1 file it is the first value of the sample key, yq doesn't recognize variables so we need to use eval
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

        # get absolute path
        R1=$(realpath $R1)
        R2=$(realpath $R2)

        echo "${sample}: ${R1} ; ${R2}" >> ${list_file}
    done
    echo -e "\tList file created in $list_file\n"
else
    echo -e "\tList file already exists, skipping\n"
fi


echo "##############################################################"
echo "2) run simka"
echo -e "##############################################################\n"
# set output directory
out_dir=$out/simka

# set simka parameters
maxcount=100
maxmerge=16
abund=2
maxreads=0 # with 0, it uses all the reads. This can maybe put to 5-10Mio to speed up the process, but it will be less accurate

# run simka
if [ ! -f $out_dir/simka.done ]
    then
        echo -e "\tRunning simka: command: simka.sh -i $list_file -o $out_dir -m $maxreads -a $abund -c $maxcount -d $maxmerge"
        sbatch --job-name=simka simka.sh -i $list_file -o $out_dir -m $maxreads -a $abund -c $maxcount -d $maxmerge
    else
        echo -e "\tSimka already ran, skipping"
fi

# wait for simka to finish, find jobname in squeue
echo -e "\tWaiting for SIMKA job to finish..."
while [ $(squeue -u $USER | grep simka | wc -l) -gt 0 ]
    do
        sleep 10
    done

# check if simka finished successfully if file $out_dir/mat_abundance_jaccard.csv.gz exists
if [ ! -f $out_dir/simka.done ]
    then
        echo -e "\tSimka failed, exiting"
        rm -rf $out_dir
        exit 1
    else
        echo -e "\tSimka finished successfully\n"
fi


echo "##############################################################"
echo "3) Parse simka output"
echo -e "##############################################################\n"

parse_output=$out/parse_simka_output
output_heatmap=$parse_output/heatmap.png
output_table=$parse_output/simka_table.tsv

mkdir -p $parse_output

# run Rscript to parse the simka output
source ~/.bashrc
conda activate Kmers_clustering_env

echo "\tRunning Rscript to parse simka output, command: Rscript --vanilla simka_heatmap_similar.R $out_dir/mat_abundance_jaccard.csv.gz $output_heatmap $output_table jaccard"
Rscript --vanilla simka_heatmap_similar.R $out_dir/mat_abundance_jaccard.csv.gz ${output_heatmap} ${output_table} jaccard

# check if the output files exist
if [ -f $output_heatmap ] && [ -f $output_table ]
    then
        echo -e "\tOutput files created in $parse_output\n"
    else
        echo -e "\tOutput files not created, exiting"
        exit 1
fi

echo "##############################################################"   
echo "02_Kmers_clustering.sh finished"
echo -e "##############################################################\n"

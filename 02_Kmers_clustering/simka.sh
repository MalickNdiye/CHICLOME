#!/bin/bash

#SBATCH --output=log/%x_simka.log
#SBATCH --error=log/%x_simka.err
#SBATCH --time=01:00:00
#SBATCH --mem=300G
#SBATCH --nodes=1
#SBATCH --cpus-per-task=16
#SBATCH --account=pengel_beemicrophage

# this script runs simka
source ~/.bashrc
conda activate Kmers_clustering_env

# set output flags
while getopts i:o:m:a:c:d: flag
do
    case "${flag}" in
        i) input=${OPTARG};; # input directory
        o) out=${OPTARG};; # output directory
        m) maxreads=${OPTARG};; # maximum number of reads
        a) abund=${OPTARG};; # mimimum abundance
        c) maxcount=${OPTARG};; # parallel counts
        d) maxmerge=${OPTARG};; # max processes
    esac
done

# check if arguments are provided
if [ -z "$input" ] || [ -z "$out" ] || [ -z "$maxreads" ] || [ -z "$abund" ] || [ -z "$maxcount" ] || [ -z "$maxmerge" ]
then
    echo "Arguments missing"
    echo "usage: $0 -i <input> -o <output> -m <maxreads> -a <abundance> -c <maxcount> -d <maxmerge>"
    exit 1
fi

# get number of processors
nproc=$(nproc)

# run simka
rm -rf $out
echo "running simka, command: simka -in $input -out $out -max-reads $maxreads -abundance-min $abund -max-count $maxcount -max-merge $maxmerge -max-memory $mem -nb-cores $nproc -out-tmp $out/tmp"
simka -in $input -out $out -max-reads $maxreads -abundance-min $abund \
    -max-count $maxcount -max-merge $maxmerge -max-memory 5000 -nb-cores $nproc -out-tmp $out/tmp # if too little memory is allocated to simka, it will just freeze, but the job will continue to run. so if you encounter something like this, just increase the memory


# check if the output directory exists
if [ -d $out ]
then
    echo "Output directory exists, simka finished"
else
    echo "Output directory does not exist, simka failed"
    rm -rf $out
    exit 1
fi

conda deactivate
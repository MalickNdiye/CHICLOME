#!/bin/bash

#SBATCH --output=log/%x_megahit.log
#SBATCH --error=log/%x_megahit.err
#SBATCH --time=02:00:00
#SBATCH --mem=50G
#SBATCH --nodes=1
#SBATCH --cpus-per-task=20
#SBATCH --account=pengel_beemicrophage

while getopts 1:2:p:o: flag
do
    case "${flag}" in
        1) R1=${OPTARG};;
        2) R2=${OPTARG};;
        o) out=${OPTARG};;
        p) prefix=${OPTARG};;
    esac
done

# check if arguments are provided
if [ -z "$R1" ] || [ -z "$R2" ] || [ -z "$out" ] || [ -z "$prefix" ]
then
    echo "Arguments missing"
    echo "usage: $0 -1 <R1> -2 <R2> -o <output> -p <prefix>"
    exit 1
fi

# set variables
threads=$(nproc)

# activate conda environment
source ~/.bashrc
mamba activate assembly_env

# run Megahit
echo -e "\nRunning Megahit"
echo "command: megahit -1 $R1 -2 $R2 -o $out --out-prefix $prefix -t $threads"

megahit -1 $R1 -2 $R2 -o $out --out-prefix $prefix  -t $threads # it may help to add --presets meta-large or --presets meta-sensitive https://www.metagenomics.wiki/tools/assembly/megahit

# if $out/$prefiix.contigs.fa exsis then Megahit finished
if [ -f $out/$prefix.contigs.fa ]
then
    touch $out/megahit.done
    echo -e "\nMegahit finished: otuput in $out"
else
    rm -rf $out
    echo "Megahit failed"
    exit 1
fi




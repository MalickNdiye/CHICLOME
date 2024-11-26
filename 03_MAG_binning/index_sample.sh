#!/bin/bash 

#SBATCH --output=log/%x_index_assembly.log
#SBATCH --error=log/%x_index_assembly.err
#SBATCH --time=01:00:00
#SBATCH --mem=20G
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --account=pengel_beemicrophage

while getopts a:o: flag
do
    case "${flag}" in
        a) assembly=${OPTARG};;
        o) out=${OPTARG};;
    esac
done

# check if arguments are provided
if [ -z "$assembly" ] || [ -z "$out" ]
then
    echo "Arguments missing"
    echo "usage: $0 -a <assembly> -o <output>"
    exit 1
fi

# set variables
threads=$(nproc)

# activate conda environment
source ~/.bashrc
conda activate mag_binning_env

# create output directory
mkdir -p $out

# index the assembly
echo -e "\nIndexing the assembly $assembly"
echo "command: bowtie2-build $assembly $out/index --threads $threads"
bowtie2-build $assembly $out/index --threads $threads

# check if the index was created
if [ ! -f $out/index.1.bt2 ]
then
    echo "ERROR: Indexing failed"
    rm -r $out
    exit 1
else
    echo -e "\nIndexing finished: output in $out/index"
fi



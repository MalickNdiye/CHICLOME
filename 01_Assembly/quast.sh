#!/bin/bash 

#SBATCH --output=log/%x_quast.log
#SBATCH --error=log/%x_quast.err
#SBATCH --time=00:30:00
#SBATCH --mem=30G
#SBATCH --nodes=1
#SBATCH --cpus-per-task=2
#SBATCH --account=pengel_beemicrophage

while getopts i:o: flag
do
    case "${flag}" in
        i) in=${OPTARG};;
        o) out=${OPTARG};;
    esac
done

# check if arguments are provided
if [ -z "$in" ] || [ -z "$out" ]
then
    echo "Arguments missing"
    echo "usage: $0 -i <input> -o <output>"
    exit 1
fi

# set variables
threads=$(nproc)

# activate conda environment
source ~/.bashrc
mamba activate assembly_env

# run Megahit
echo "Running quast"
echo "command: quast.py -t $threads --no-snps --no-sv --memory-efficient -o $out $in"

quast.py -t $threads --no-snps --no-sv --memory-efficient -o ${out} ${in} 

# check if quast finished successfully; i.e final directory exists
if [ ! -d "$out" ]; then
    echo "Quast failed"
    exit 1
fi

echo "Quast finished: otuput in $out"
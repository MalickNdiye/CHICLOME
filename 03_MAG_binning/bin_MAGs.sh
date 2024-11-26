#!/bin/bash 

#SBATCH --output=log/%x_mag_binning.log
#SBATCH --error=log/%x_mag_binning.err
#SBATCH --time=00:30:00
#SBATCH --mem=10G
#SBATCH --nodes=1
#SBATCH --cpus-per-task=6
#SBATCH --account=pengel_beemicrophage

# get arguments
while getopts i:o:a:d: flag
do
    case "${flag}" in
        i) input=${OPTARG};;
        o) output=${OPTARG};;
        a) assembly=${OPTARG};; # name of the sample
        d) assembly_file=${OPTARG};;
    esac
done

# check if arguments are provided
if [ -z "$input" ] || [ -z "$output" ] || [ -z "$assembly" ] || [ -z "$assembly_file" ]
then
    echo "Arguments missing"
    echo "usage: $0 -i <input> -o <output> -s <assembly>"
    exit 1
fi

source ~/.bashrc
conda activate mag_binning_env

# create output directory
mkdir -p $output
threads=$(nproc)

# summarize depths
echo -e "\nSummarizing depths"
echo "command: perl /home/bo4spe/bin/merge_depths.pl $input/*.depth > $output/${assembly}_depths.txt"
merge_depths.pl $input/*.depth > $output/${asmbl}_depths.txt

# check if the depths were created
if [ ! -f $output/${asmbl}_depths.txt ]
then
    echo "ERROR: Summarizing depths failed"
    exit 1
else
    echo -e "\nSummarizing depths finished: output in $output/${asmbl}_depths.txt"
fi

# run metabat2
echo -e "\nRunning metabat2"
echo "command: metabat2 -i $assembly_file -a $output/${asmbl}_depths.txt -o $output/${asmbl}_MAGs -m 2000 --maxEdges 500 -t $threads"
metabat2 -i $assmbly_file -a $output/${asmbl}_depths.txt -o $output/${asmbl}_MAGs -m 2000 --maxEdges 500 -t $threads

# check if the MAGs were created
if [ ! -d $output/${asmbl}_MAGs ]
then
    echo "ERROR: MAGs binning failed"
    exit 1
else
    echo -e "\nMAGs binning finished: output in $output/${asmbl}_MAGs"
fi




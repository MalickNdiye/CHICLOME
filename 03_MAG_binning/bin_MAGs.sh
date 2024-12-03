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
echo "command: ./merge_depths.pl $input/*.depth > $output/${assembly}_depths.txt"
mkdir -p $output/depths
./merge_depths.pl $input/*.depth > $output/depths/${assembly}_depths.txt

# check if the depths were created
if [ ! -f $output/depths/${assembly}_depths.txt ]
then
    echo "ERROR: Summarizing depths failed"
    exit 1
else
    echo -e "\nSummarizing depths finished: output in $output/${assembly}_depths.txt"
fi

# run metabat2
echo -e "\nRunning metabat2"
echo "command: metabat2 -i $assembly_file -a $output/${assembly}_depths.txt -o $output/${assembly}_MAGs -m 2000 --maxEdges 500 -t $threads"
mkdir -p $output/MAGs
metabat2 -i $assembly_file -a $output/depths/${assembly}_depths.txt -o $output/MAGs/${assembly}_MAG -m 2000 --maxEdges 500 -t $threads


# write a done file
touch $output/MAGs/${assembly}_MAGs.done

echo -e "\nMAGs binning finished: output bins named as $output/MAGs/${assembly}_MAGs*.fa"





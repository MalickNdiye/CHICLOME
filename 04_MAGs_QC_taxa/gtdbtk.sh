#!/bin/bash 

#SBATCH --output=log/%x_backmap.log
#SBATCH --error=log/%x_bakmap.err
#SBATCH --time=10:00:00
#SBATCH --mem=10G
#SBATCH --nodes=1
#SBATCH --cpus-per-task=15
#SBATCH --account=pengel_beemicrophage

# get arguments
while getopts o:m:d: flag
do
    case "${flag}" in
        o) out=${OPTARG};; # output directory
        m) mags=${OPTARG};; # mags directory
        d) gtdbtk_db=${OPTARG};; # checkm database
    esac
done

# check if arguments are provided
if [ -z "$out" ] || [ -z "$mags" ] || [ -z "$gtdbtk_db" ]
then
    echo "Arguments missing"
    echo "usage: $0 -o <output> -m <mags directory> -d <gtdbtk database>"
    exit 1
fi

# activate conda environment
source ~/.bashrc
conda activate MAGs_QC_taxa_env

threads=$(nproc)

# run gtdbtk
export GTDBTK_DATA_PATH=$gtdbtk_db
gtdbtk classify_wf --genome_dir $mags --extension fa --out_dir $out --cpus $threads

# if gtdbtk failed
if [ ! -s $out/gtdbtk.bac120.summary.tsv ]
then
    touch $out/gtdbtk.fail
    echo "gtdbtk failed"
    exit 1
else
    touch $out/gtdbtk.done
fi

echo "gtdbtk done"
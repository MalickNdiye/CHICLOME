#!/bin/bash 

#SBATCH --output=log/%x.log
#SBATCH --error=log/%x.err
#SBATCH --time=10:00:00
#SBATCH --mem=200G
#SBATCH --nodes=1
#SBATCH --cpus-per-task=15
#SBATCH --account=pengel_beemicrophage

# get arguments
while getopts o:m:d: flag
do
    case "${flag}" in
        o) out=${OPTARG};; # output directory
        m) mags=${OPTARG};; # mags directory
        d) checkm_db=${OPTARG};; # checkm database
    esac
done

# check if arguments are provided
if [ -z "$out" ] || [ -z "$mags" ]
then
    echo "Arguments missing"
    echo "usage: $0 -o <output> -m <mags directory>"
    exit 1
fi

# activate conda environment
source ~/.bashrc
conda activate MAGs_QC_taxa_env

threads=$(nproc)

# run checkm
echo "checkm data: $checkm_db"
export CHECKM_DATA_PATH=$checkm_db
checkm lineage_wf $mags $out -x fa --reduced_tree -t $threads
checkm qa $out/lineage.ms $out -o 2 --tab_table -t $threads -f $out/checkm_summary.txt

# if checkm_summary.txt is empty, then checkm failed
if [ ! -s $out/checkm_summary.txt ]
then
    echo "checkm failed"
    touch $out/checkm.fail
    exit 1
else
    touch $out/checkm.done
fi

echo "checkm done"


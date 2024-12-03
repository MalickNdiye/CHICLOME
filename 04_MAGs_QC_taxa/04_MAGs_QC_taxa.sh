#!/bin/bash 

# this script is a wrapper for the MAGs QC and taxonomy assignment pipeline
# it takes as input a directory containing MAGs in fasta format
# it outputs a directory containing the QC'd MAGs and a directory containing the taxonomy assignments


# set output flags
while getopts c:o:m: flag
do
    case "${flag}" in
        o) out=${OPTARG};; # output directory
        c) config=${OPTARG};; # config file
        m) mags=${OPTARG};; # mags directory
    esac
done

# check if arguments are provided
if [ -z "$out" ] || [ -z "$config" ] || [ -z "$mags" ]
then
    echo "Arguments missing"
    echo "usage: $0 -o <output> -c <config> -m <mags directory>"
    exit 1
fi

# set config file
config_file=$config

# create log directory
mkdir -p log

# create output directory
mkdir -p $out

echo "##############################################################"
echo "Running 04_MAGs_QC_taxa.sh"
echo -e "##############################################################\n"

echo "##############################################################"
echo "QC the MAGs: run checkm"
echo -e "##############################################################\n"

source ~/.bashrc
conda activate assembly_env

MAGs_dir=$mags/binning/MAGs
checkm_db=$(yq '.CHECKM_DB' $config_file)
checkm_db=$(echo $checkm_db | sed 's/"//g')

out_chkm=$out/checkm_QC

# check if output directory is complete
if [ -f $out_chkm/checkm.done ]
then
    echo "Output directory $out_chkm already exists. Skipping checkm."
else
    sbatch --job-name=checkm checkm.sh -o $out_chkm -m $MAGs_dir -d $checkm_db
fi

# wait for checkm to finish
echo "waiting for checkm to finish..."
while [ ! -f $out_chkm/checkm.done ]
    do
        if [ -f $out_chkm/checkm.fail ]
        then
            echo "checkm failed"
            rm -rf $out_chkm
            exit 1
        else
            sleep 10
        fi
    done

echo "##############################################################"
echo "taxonomically assign the MAGs: run gtdbtk"
echo -e "##############################################################\n"

out_gtdbtk=$out/gtdbtk
gtdbtk_db=$(yq '.GTDBTK_DB' $config_file)
gtdbtk_db=$(echo $gtdbtk_db | sed 's/"//g')

# check if output directory is complete
if [ -f $out_gtdbtk/gtdbtk.done ]
then
    echo "Output directory $out_gtdbtk already exists. Skipping gtdbtk."
else
    sbatch --job-name=gtdbtk gtdbtk.sh -o $out_gtdbtk -m $MAGs_dir -d $gtdbtk_db 
fi

# wait for gtdbtk to finish
echo "waiting for gtdbtk to finish..."
while [ ! -f $out_gtdbtk/gtdbtk.done ]
    do
        if [ -f $out_gtdbtk/gtdbtk.fail ]
        then
            echo "GTDB-TK failed"
            rm -rf $out_gtdbtk
            exit 1
        else
            sleep 10
        fi
    done

echo "##############################################################"
echo "04_MAGs_QC_taxa.sh has finished."
echo -e "##############################################################\n"

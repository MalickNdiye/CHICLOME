#!/bin/bash 

#SBATCH --output=log/%x_backmap.log
#SBATCH --error=log/%x_bakmap.err
#SBATCH --time=03:00:00
#SBATCH --mem=10G
#SBATCH --nodes=1
#SBATCH --cpus-per-task=15
#SBATCH --account=pengel_beemicrophage


while getopts 1:2:i:o:s: flag
do
    case "${flag}" in
        1) R1=${OPTARG};;
        2) R2=${OPTARG};;
        i) index=${OPTARG};;
        o) out=${OPTARG};;
        s) sample=${OPTARG};; # sample name
    esac
done

# check if arguments are provided
if [ -z "$R1" ] || [ -z "$R2" ] || [ -z "$index" ] || [ -z "$out" ] || [ -z "$sample" ]
then
    echo "Arguments missing"
    echo "usage: $0 -1 <R1> -2 <R2> -i <index> -o <output>"
    exit 1
fi

# set variables
threads=$(nproc)

# activate conda environment
source ~/.bashrc
conda activate mag_binning_env

# create output directory
mkdir -p $out

# run backmapping
echo -e "\nRunning backmapping"
echo "command: bowtie2 -x $index -1 $R1 -2 $R2 -S $out/${sample}_mapping.sam -p $threads"
bowtie2 -x $index -1 $R1 -2 $R2 -S $out/${sample}_mapping.sam -p $threads --very-fast # TODO remove --very-fast for more accurate mapping

# check if the mapping was created
if [ ! -f $out/${sample}_mapping.sam ]
then
    echo "ERROR: Mapping of $R1 and $R2 to $index failed"
    exit 1
else
    echo -e "\nMapping finished: output in $out/${sample}_mapping.sam"
fi

# convert sam to bam
echo -e "\nConverting sam to bam"
echo "samtools view -bh $out/${sample}_mapping.sam | samtools sort -T $out/tmp - > $out/${sample}_mapping.bam"
samtools view -bh $out/${sample}_mapping.sam | samtools sort -T $out/tmp - > $out/${sample}_mapping.bam

# check if the bam was created
if [ ! -f $out/${sample}_mapping.bam ]
then
    echo "ERROR: Converting sam to bam failed"
    exit 1
else
    echo -e "\nConversion finished: output in $out/${sample}_mapping.bam"
    rm $out/${sample}_mapping.sam
fi

# convert bam to .depth file
echo -e "\nConverting bam to .depth file"
export OMP_NUM_THREADS=$threads
jgi_summarize_bam_contig_depths --outputDepth $out/${sample}_mapping.depth $out/${sample}_mapping.bam

# check if the depth file was created
if [ ! -f $out/${sample}_mapping.depth ]
then
    echo "ERROR: Converting $out/${sample}_mapping.depth to .depth file failed"
    exit 1
else
    echo -e "\nConversion finished: output in $out/${sample}_mapping.depth"
    rm $out/${sample}_mapping.bam
fi

echo -e "\nBackmapping finished: output in $out/${sample}_mapping.depth"
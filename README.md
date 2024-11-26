# Introduction

This is the pipeline for the CHICLOME project. The aim is two reconstruct MAGs from several chiclids gut metagenomes samples. So far, the pipeline is divided in 4 steps (i.e., 4 directories):

- 01_Assembly: Assemble metagenomes and QC assemblies
- 02_Kmers_clustering: Cluster metagenomes in fucntion of kmer similarities
- 03_MAG_binning: Bin contigs into MAGs
- 04_MAGs_QC_taxa: QC the MAGs and assign them to a taxonomy

# Set Up conda Environments
This workflow will require to set up several conda environments. All the enironments are found in the `envs/` directory. We will use *mamba* to set up conda evironments. *mamba* is a faster version of conda, meaning that every conda command can be run by substituiong `conda` with `mamba`. 

To install `mamba` in your base conda environment: 
```
conda install -c conda-forge mamba 
```

once `mamba` is installed, you can set up a given environment with the command:
```
mamba env create -f <env>.yaml
```
where <env> is the path to the yaml file containing the specification for your conda environment. The created environment will be named following the `name:` section in the yaml file. 

To work within the conda environment:
```
mamba activate <env_name> # activate conda environment
... # Do stuff
mamba deactivate # deactivate conda env
```

To check which environments are available
```
mamba env list
```

# Config File
An important aspect of this workflow is the `config.yaml` file. This file is used to track the samples and the path to the initial read files. 

## Config file format
The config file should have the following structure:
```
SAMPLES:
  sam-1:
    - data/sam-1_R1_paired.fastq.gz
    - data/sam-1_R2_paired.fastq.gz
  sam-2:
    - data/sam-2_R1_paired.fastq.gz
    - data/sam-2_R2_paired.fastq.gz
...

CHECKM_DB: <path_to_checkm_db> # How to get these databases? it's explained below

GTDBTK_DB: <path_to_gtdbtk_db>
```
you can substitute *sam_1, sam_2,...* with a more informative sample name. The sample name doesn't need to be in the read file name, just know that all subsequent files that are generated in this pipeline will be named after the sample name you chose in the config file. PLEASE, do not use underscores ("_") in the sample name. Each sample block should contain the path to the R1 and R2 read files (in this order). the path should be RELATIVE to the position of the config.yaml file. Alternatively, you can give the ABSULUTE path to the read files

The config file has to be fed to each wrapper script (see below)

# Workflow
The workflow is split into several directories:

1. 01_assembly
2. 02_kmer_clustering
3. 03_MAGs
4. 04_MAGs_QC

Each directory contains the scripts for a part of the workflow. The script that has the same name as the directory is the *wrapper script*. This script launches all the other *auxiliary scripts* within the directory. Each wrapper script takes as input the config.yaml (to know which samples to process) and the output directory. the output directory of a given wrapper can be put anywhere and sometimes it is a necessary input for a subsequent wrapper script (e.g. `03_MAG_binning.sh` needs the output of `01_assembly.sh` and `02_kmer_clustering.sh`).

It is possible to run each auxiliary script by itself, this can be useful for debugging or test runs. However, at the end make sure that the directory structure of the output is the same as the one created by the wrapper script, otherwise this may cause issues for future wrappers.

each wrapper script will create a log directory that the user need

## 01_assembly
This section of the workflow uses [megahit](https://github.com/voutcn/megahit) to assemble the metagenomes. Then, it runs [QUAST](https://github.com/ablab/quast) to evaluate the assembly quality (download the `report.hml` from the output files to have an overview of the assembly). finally, it runs multiqc to aggragate all the QUAST reports in a single html file that can be explored on your favourite browser.

```
usage: ./01_assembly.sh 
-o <output> # output directory
-c <config> # config file
```

## 02_Kmers_clustering
This section of the workflow uses [simka](https://github.com/GATB/simka) to cluster the metagenomes in fucntion of their kmers similarity. Then, a costum R script is used to create the `simka_table.tsv` file. This is a tab delimited file containing the combination of assembly-reads to be used for the backmapping. For each assembly, only the 50 most similar reads file will be used for the backmapping. This is done to avoid a O(n^n) scaling of the backmapping (now n*50). 

```
usage: ./02_Kmers_clustering.sh 
-o <output> # output directory
-c <config> # config file
```

## 03_MAG_binning
This section of the workflow maps the `simka_table.tsv` combinations using [bowtie2](https://bowtie-bio.sourceforge.net/bowtie2/index.shtml). This is called backmapping and it's used to infer contigs that covariate in coverage across samples (likely from the same genomes). Once all the backmapping are completed, contigs are binned using [metabat2](https://pmc.ncbi.nlm.nih.gov/articles/PMC6662567/). 

```
usage: ./03_MAG_binning.sh 
-o <output> # output directory
-c <config> # config file
-t <tmp directory> # temporary directory
-a <assembly directory> # output directory of 01_Assembly
-s <simka directory> # output directory of 02_Kmers_clustering
```

#### Notes
for this section of the workflow, it is important to put the `tmp_directory` in a place with a lot of disk space. this is because this directory will contain all the backmapping files (a lot of data). Many HPC environments usually have a `/scratch` directory that has unlimited disk space, but where all the files are deleted after a certain amount of time. this is the perfect place to put these files

## 04_MAGs_QC_taxa
This section of the workflow uses [checkm](https://github.com/Ecogenomics/CheckM) to assess the quality of the MAGs. also, it uses [GTDB-Tk](https://github.com/Ecogenomics/GTDBTk) to taxonomically classify the MAGs.

```
usage: ./04_MAGs_QC_taxa.sh 
-o <output> # output directory
-c <config> # config file 
-m <mags directory> # output directory of 03_MAG_binning.sh 
```

#### Notes
This part require you to have installed the checkm and gtdbtk databases. Once you have created the MAGs_QC_taxa_env.yaml conda environment:
```
conda activate MAGs_QC_taxa_env
cd <directory/where/you/want/your/databases/to/be>

# checkm database
wget https://data.ace.uq.edu.au/public/CheckM_databases/checkm_data_2015_01_16.tar.gz
tar xvzf checkm_data_2015_01_16.tar.gz

# gtdbtk database
wget https://data.ace.uq.edu.au/public/gtdb/data/releases/latest/auxillary_files/gtdbtk_package/full_package/gtdbtk_data.tar.gz #~110GB, will take time
tar xvzf gtdbtk_data.tar.gz
```

Then put the paths of the unzipped databases in the config file (see above)

# Some Important Tips

## Script permission
remember to give permission to the scripts `chmod u+x <path_to_script>`

## Screens
*Wrappers* should be run on the FRONT END, since they will send individual jobs to the cluster. When running a *wrapper* script, it may take some time for it to finish, so it is better to run it withtin a [screen](https://www.geeksforgeeks.org/screen-command-in-linux-with-examples/) so that the the job doesn't stop when you disconnect from the cluster. 

## Adjust scripts
Since I didn't use the real data, for each script I guessed the memory and time requirements. it is important to go through each auxiliary script and modify them if some jobs fail because of lack of memory and/or time. if a job fails because of memory, the error will be raised when checking for the job status using `sacct`. If it fails because of time, the error will be raised in the logs.


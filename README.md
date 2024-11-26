# Introduction


# Set Up conda Environments
This workflow will require to set up several conda environments. All the enironments are found in the `envs/` directory. We will use *mamba* to set up conda evironments. *mamba* is a faster version of conda, meaning that every conda command can be run by substituiong `conda` with `mamba`. 

To install *mamba* in your base conda environment: 
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

# Config File
An important aspect of this workflow is the `config.yaml` file. This file is used to track the samples and the path to the initial read files. 

## Install yq
This workflow requires to set up a config file containing the path to the sample. To parse this file, we need to install `yq` in our base environment:
```
mamba install -c anaconda yq
```

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
```
you can substitute *sam_1, sam_2,...* with a more informative sample name. PLEASE, do not use underscores ("_") in the sample name. each sample block should contain the path to the R1 and R2 read files. the path should be RELATIVE to the position of the config.yaml file.

The config file has to be fed to each wrapper script (see below)

# Run scripts
remember to give permission to the scripts `chmod u+x <path_to_script>`

# Workflow
The workflow is split into several directories:

1. 01_assembly
2. 02_kmer_clustering
3. 03_MAGs
4. 04_MAGs_QC

Each directory contains the scripts for a part of the workflow. The script that has the same name as the directory is the *wrapper script*. This script launches all the other *auxiliary scripts* within the directory. Each wrapper script takes as input the config.yaml (to know which samples to process) and the output directory. the output directory of a given wrapper can be put anywhere and sometimes it is a necessary input for a subsequent wrapper script (e.g. *03_MAGs.sh* needs the output of *01_assembly.sh* and *02_kmer_clustering.sh*).

It is possible to run each individual script by itself, this can be useful for debugging or test runs. However, at the end make sure that the directory structure of the output is the same as the one created by the wrapper script, otherwise this may cause issues for future wrappers.

## 01_assembly
This section of the workflow uses megahit (https://github.com/voutcn/megahit) to assemble the metagenomes. Then, it runs QUAST (https://github.com/ablab/quast) to evaluate the assembly quality (download the `report.hml` from the output files to have an overview of the assembly). finally, it runs multiqc to aggragate all the QUAST reports in a single html file that can be explored on your favourite browser.

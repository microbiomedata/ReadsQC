# The Data Preprocessing workflow

## Summary

This workflow is replicate the [QA protocol](https://jgi.doe.gov/data-and-tools/bbtools/bb-tools-user-guide/data-preprocessing/) implemented at JGI for Illumina reads and use the program “rqcfilter2” from BBTools(38:44) which implements them as a pipeline. 

## Required Database

RQCFilterData Database Coming soon.  It includes reference datasets of artifacts, adapters, contaminants, phiX genome, host genomes.  

## Running Workflow in Cromwell
You should run this on cori. There are three ways to run the workflow.  
1. `SlurmCromwellShifter/`: The submit script will request a node and launch the Cromwell.  The Cromwell manages the workflow by using Shifter to run applications. 
2. `CromwellSlurmShifter/`: The Cromwell run in head node and manages the workflow by submitting each step of workflow to compute node where applications were ran by Shifter.

Description of the files in each sud-directory:
 - `.wdl` file: the WDL file for workflow definition
 - `.json` file: the example input for the workflow
 - `.conf` file: the conf file for running Cromwell.
 - `.sh` file: the shell script for running the example workflow

## The Docker image and Dockerfile can be found here

[microbiomedata/bbtools:38.44](https://hub.docker.com/r/microbiomedata/bbtools)

## Input files
expects: database path, fastq (illumina paired-end interleaved fastq), output path

```
{
    "jgi_rqcfilter.database": "/global/cfs/projectdirs/m3408/aim2/database", 
    "jgi_rqcfilter.input_files": [
        "/global/cfs/cdirs/m3408/ficus/8471.3.103168.CCGTCC.fastq.gz", 
        "/global/cfs/cdirs/m3408/ficus/8434.1.102069.GCCAAT.fastq.gz", 
        "/global/cfs/cdirs/m3408/ficus/8573.3.104455.GCCAAT.fastq.gz", 
        "/global/cfs/cdirs/m3408/ficus/8435.3.102098.CCGTCC.fastq.gz", 
        "/global/cfs/cdirs/m3408/ficus/8382.5.100461.AGTCAA.fastq.gz", 
        "/global/cfs/cdirs/m3408/ficus/8434.3.102077.AGTTCC.fastq.gz", 
        "/global/cfs/cdirs/m3408/ficus/8434.1.102069.ACAGTG.fastq.gz", 
        "/global/cfs/cdirs/m3408/ficus/8434.3.102077.ATGTCA.fastq.gz"
    ], 
    "jgi_rqcfilter.outdir": "/global/cfs/cdirs/m3408/ficus_rqcfiltered"
}
```

## Output files
```
```

## Workflow graph

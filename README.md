# The Data Preprocessing Workflow

## Summary

This workflow is a replicate of the [QA protocol](https://jgi.doe.gov/data-and-tools/software-tools/bbtools/bb-tools-user-guide/data-preprocessing/) implemented at JGI for Illumina reads.

This workflow utilizes the program `rqcfilter2` from BBTools to perform quality control on raw Illumina reads for **shortreads**. The workflow performs quality trimming, artifact removal, linker trimming, adapter trimming, and spike-in removal (using `BBDuk`), and performs human/cat/dog/mouse/microbe removal (using `BMap`).

This workflow performs quality control on long reads from PacBio. The workflow performs duplicate removal (using `pbmarkdup`), inverted repeat filtering (using BBTools 
`icecreamfinder.sh`), adapter trimming, and final filtering of reads with residual adapter sequences (using `bbduk`). The workflow is designed to handle input files in various formats, including .bam, .fq, or .fq.gz.

## Required Database

* [RQCFilterData Database](https://portal.nersc.gov/cfs/m3408/db/RQCFilterData.tgz): It is a 106G tar file includes reference datasets of artifacts, adapters, contaminants, phiX genome, host genomes.  

* Prepare the Database

```bash
	mkdir -p refdata
	wget https://portal.nersc.gov/cfs/m3408/db/RQCFilterData.tgz
	tar xvzf RQCFilterData.tgz -C refdata
	rm RQCFilterData.tgz
```

## The Docker image and Dockerfile can be found here

[microbiomedata/bbtools:38.96](https://hub.docker.com/r/microbiomedata/bbtools)

## Input files

1. the path to the interleaved fastq file (longreads and shortreads) 
2. forwards reads fastq file (when input_interleaved is false)
3. reverse reads fastq file (when input_interleaved is false)  
4. project id
5. if the input is interleaved (boolean) 
6. if the input is shortreads (boolean)

```
{
	"rqcfilter.input_files": ["https://portal.nersc.gov/project/m3408//test_data/smalltest.int.fastq.gz"],
    	"rqcfilter.input_fq1": [],
    	"rqcfilter.input_fq2": [],
    	"rqcfilter.proj": "nmdc:xxxxxxx",
   	"rqcfilter.interleaved": true,
    	"rqcfilter.shortRead": true
}
```

## Output files

The output will have one directory named by prefix of the fastq input file and a bunch of output files, including statistical numbers, status log and a shell script to reproduce the steps etc. 

The main QC fastq output is named by prefix.anqdpht.fast.gz. 

```
* Short Reads
    output/
    ├── nmdc_xxxxxxx_filtered.fastq.gz
    ├── nmdc_xxxxxxx_filterStats.txt
    ├── nmdc_xxxxxxx_filterStats2.txt
    ├── nmdc_xxxxxxx_readsQC.info
    └── nmdc_xxxxxxx_qa_stats.json
# Long Reads
    output/
    ├── nmdc_xxxxxxx_pbmarkdupStats.txt
    ├── nmdc_xxxxxxx_readsQC.info
    ├── nmdc_xxxxxxx_bbdukEndsStats.json
    ├── nmdc_xxxxxxx_icecreamStats.json
    ├── nmdc_xxxxxxx_filtered.fastq.gz
    └── nmdc_xxxxxxx_stats.json
```

## Link to Doc Site
Please refer [here](https://nmdc-workflow-documentation.readthedocs.io/en/latest/chapters/1_RQC_index.html) for more information.

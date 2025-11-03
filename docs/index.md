# Metagenome Reads QC Workflow

![ReadsQC Workflow](lrrqc_workflow2024.svg)


## Workflow Overview

### Short-Reads (Illumina)

This workflow utilizes the program `rqcfilter2` from BBTools to perform quality control on raw Illumina reads (single- or paired-end) for **shortreads**. The workflow performs quality trimming, artifact removal, linker trimming, adapter trimming, and spike-in removal (using `BBDuk`), and performs human/cat/dog/mouse/microbe removal (using `BBMap`).

The following parameters are used for `rqcfilter2` in this workflow

| Parameter                 | Description                                                                                   |
|---------------------------|-----------------------------------------------------------------------------------------------|
| `da`                      | Disable assertions.                                                                           |
| `threads`                 | Set number of threads to use.                                                                 |
| `Xmx`                     | Set maximum memory for Java, recommended 75% of memory allotted to task.                      |
| `rna=false`               | Trim Illumina TruSeq-RNA adapters.                                                            |
| `qtrim=r2`                | Quality-trim from right ends before mapping.                                                  |
| `trimq=0`                 | Trim quality threshold.                                                                       |
| `maxns=3`                 | Reads with more Ns than this will be discarded.                                               |
| `maq=3`                   | Reads with average quality (before trimming) below this will be discarded.                    |
| `minlen=51 `              | Reads shorter than this after trimming will be discarded. Pairs discarded only if both short. |
| `mlf=0.33`                | Reads shorter than this fraction of original length after trimming will be discarded.         |
| `phix=true`               | Remove reads containing phiX kmers.                                                           |
| `khist=true`              | Generate a kmer-frequency histogram of the output data.                                       |
| `kapa=true`               | Remove and quantify kapa tag.                                                                 |
| `trimpolyg=5`             | Trim reads that start or end with a G polymer at least this long.                             |
| `clumpify=true`           | Run clumpify; all deduplication flags require this.                                           |
| `removehuman=true`        | Remove human reads via mapping.                                                               |
| `removedog=true`          | Remove dog reads via mapping.                                                                 |
| `removecat=true`          | Remove cat reads via mapping.                                                                 |
| `removemouse=true`        | Remove mouse reads via mapping.                                                               |
| `barcodefilter=false`     | Disable improper barcodes filter.                                                             |
| `chastityfilter=true`     | Remove Illumina reads failing chastity filter.                                                |
| `trimfragadapter=true`    | Trim all known Illumina adapter sequences, including TruSeq and Nextera.                      |
| `removemicrobes=true`     | Remove common contaminant microbial reads via mapping, and place them in a separate file.     |

### Long-Reads (PacBio)

This workflow performs quality control on long-reads from PacBio. The workflow performs duplicate removal (using `pbmarkdup`), inverted repeat filtering (using BBTools 
`icecreamfinder.sh`), adapter trimming, and final filtering of reads with residual adapter sequences (using `bbduk`). The workflow is designed to handle input files in various formats, including `.bam`, `.fq`, or `.fq.gz`.


| Parameter                | Description                                                       |
|--------------------------|-------------------------------------------------------------------|
| `rmdup=true`             | Enables duplicate removal in the initial filtering.               |
| `k=20, mink=12`          | K-mer sizes for adapter detection and trimming (`k=20`, `mink=12`). |
| `edist=1`                | Error distance allowed for k-mer matches.                         |
| `ktrimtips=60`           | Trims adapters from the ends of reads.                            |
| `phix=true`              | Removes reads containing PhiX sequences.                          |
| `json=true`              | Outputs statistics in JSON format for easier parsing.             |
| `chastityfilter=true`    | Removes reads failing the chastity filter.                        |
| `removehuman=true`       | Removes human reads in contamination analysis (optional).         |
| `removemicrobes=true`    | Removes common microbial contaminants.                            |

## Workflow Availability

The workflow from GitHub uses all the listed docker images to run all third-party tools.

- Workflow: [GitHub](https://github.com/microbiomedata/ReadsQC)
- Docker image: [DockerHub](https://hub.docker.com/r/microbiomedata/bbtools)


## Requirements for Execution

**Recommended:**
- WDL-capable Workflow Execution Tool (**Cromwell**)
- Container Runtime (**Docker v2.1.0.3 or higher**)


## Hardware Requirements

- Disk space: 106 GB for RQCFilterData database
- Memory: >40 GB RAM

## Workflow Dependencies

#### Third Party Software (included in Docker image)

- [BBTools v38.96](https://jgi.doe.gov/data-and-tools/bbtools/) ([BSD-3-Clause-LBNL License](https://bitbucket.org/berkeleylab/jgi-bbtools/src/master/license.txt))

#### Requisite Database

Download and install the 106 GB RQCFilterData Database (artifacts, adapters, contaminants, phiX, host genomes):

```bash
mkdir refdata
wget http://portal.nersc.gov/dna/microbial/assembly/bushnell/RQCFilterData.tar
tar -xvf RQCFilterData.tar -C refdata
rm RQCFilterData.tar
```


## Sample Datasets

### Short-Reads

- Small dataset: [Ecoli 10x](https://portal.nersc.gov/cfs/m3408/test_data/ReadsQC_small_test_data.tgz) (Input/output included in tar.gz file)
- Zymobiomics mock-community DNA control ([SRR7877884](https://www.ncbi.nlm.nih.gov/sra/SRX4716743)), [dataset](https://portal.nersc.gov/cfs/m3408/test_data/SRR7877884/) (6.7G bases)
    - The non-interleaved raw FASTQ files are available as: [R1](https://portal.nersc.gov/cfs/m3408/test_data/SRR7877884/SRR7877884_1.fastq.gz), [R2](https://portal.nersc.gov/cfs/m3408/test_data/SRR7877884/SRR7877884_2.fastq.gz)
    - [The interleaved raw FASTQ file](https://portal.nersc.gov/cfs/m3408/test_data/SRR7877884/SRR7877884-int.fastq.gz)
    - [A 10% subset of the interleaved FASTQ](https://portal.nersc.gov/cfs/m3408/test_data/SRR7877884/SRR7877884-int-0.1.fastq.gz)

### Long-Reads

- Zymobiomics synthetic metagenome ([SRR13128014](https://portal.nersc.gov/cfs/m3408/test_data/SRR13128014.pacbio.subsample/SRR13128014.pacbio.subsample.ccs.fastq.gz)), subsampled (~57MB), original ~18G bases



## Input

A [JSON file](https://github.com/microbiomedata/ReadsQC/blob/documentation/input.json) containing:

1. Path to interleaved FASTQ file (longreads/shortreads)
2. Forward reads FASTQ file (if not interleaved)
3. Reverse reads FASTQ file (if not interleaved)
4. NCBI SRA accessions (mutually exclusive to above)
5. Project ID
6. Is input interleaved (boolean)
7. Is input shortreads (boolean)
8. (optional) Path to database directory

**Example (Short-Reads, Interleaved):**

```json
{
        "rqcfilter.input_files": ["https://portal.nersc.gov/cfs/m3408/test_data/smalltest.int.fastq.gz"],
        "rqcfilter.input_fq1": [],
        "rqcfilter.input_fq2": [],
        "rqcfilter.accessions": [],
        "rqcfilter.proj": "nmdc:xxxxxxx",
        "rqcfilter.interleaved": true,
        "rqcfilter.shortRead": true,
        "rqcfilter.database": "/path/to/refdata",
}
```

> **Note:**  
> In HPC environments, you can process multiple samples (interleaved/non-interleaved) for shortreads.  
> `"rqcfilter.input_files"` is an array for multiple samples.
>
> **Interleaved:**  
> `"rqcfilter.input_files": ["first-int.fastq","second-int.fastq"]`
>
> **Non-Interleaved:**  
> `"rqcfilter.input_fq1": ["first-int-R1.fastq","second-int-R1.fastq"], "rqcfilter.input_fq2": ["first-int-R2.fastq","second-int-R2.fastq"]`
>
> **Long-Reads:**  
> `"rqcfilter.input_files": ["PacBio.fastq"]`



## Output

The output directory will contain:

```
output/
├── nmdc_xxxxxxx_filtered.fastq.gz
├── nmdc_xxxxxxx_filterStats.txt
├── nmdc_xxxxxxx_filterStats2.txt
├── nmdc_xxxxxxx_readsQC.info
└── nmdc_xxxxxxx_qa_stats.json
```

**Example `filterStats.txt` (short-reads):**

```text
inputReads=250000
inputBases=37109226
qtrimmedReads=0
qtrimmedBases=0
qfilteredReads=208
qfilteredBases=10798
ktrimmedReads=456
ktrimmedBases=7726
kfilteredReads=0
kfilteredBases=0
outputReads=249398
outputBases=37003919
gcPolymerRatio=0.165888
```

| FileName                          | Description                                                         |
| ---------------------------------- | ------------------------------------------------------------------- |
| **Short-Reads**                   |                                                                     |
| `nmdc_xxxxxxx_filtered.fastq.gz`    | main output (clean data)                                            |
| `nmdc_xxxxxxx_filterStats.txt`      | summary statistics                                                  |
| `nmdc_xxxxxxx_filterStats2.txt`     | more detailed summary statistics                                    |
| `nmdc_xxxxxxx_readsQC.info`         | summary of parameters used in BBTools rqcfilter2                    |
| `nmdc_xxxxxxx_qa_stats.json`        | summary statistics of output/input bases and reads                  |
| **Long-Reads**                    |                                                                     |
| `nmdc_xxxxxxx_filtered.fastq.gz`    | main output (clean data)                                            |
| `nmdc_xxxxxxx_filterStats.txt`      | statistics from pbmarkdup duplicate removal                         |
| `nmdc_xxxxxxx_filterStats2.txt`     | more detailed summary statistics                                    |
| `nmdc_xxxxxxx_readsQC.info`         | summary of tools and docker containers used for long-reads QC        |
| `nmdc_xxxxxxx_qa_stats.json`        | summary statistics of output/input bases and reads                  |

> **Note:**  
> If input is SRA accessions (e.g., `"rqcfilter.accessions": ["SRR34992488"]`), the workflow also outputs the corresponding FASTQ files (e.g., `SRR34992488_1.fastq.gz`, `SRR34992488_2.fastq.gz`).

- [Example output (short-reads, SRR7877884, 10% subset)](https://portal.nersc.gov/cfs/m3408/test_data/SRR7877884/SRR7877884-0.1_MetaG/ReadsQC/)
- [Example output (long-reads, SRR13128014)](https://portal.nersc.gov/cfs/m3408/test_data/SRR13128014.pacbio.subsample/ReadsQC/)

> **Note:**  
> - `testset_fastq.gz`: raw data  
> - `testset/` or `testset_fastq/testset.fastq_filtered.fastq.gz`: QC results

---

## Version History

- v1.0.19 — 2025-10-02
- v1.0.14-alpha.1 — 2025-05-15
- v1.0.18 — 2025-04-25
- v1.0.17 — 2025-04-21
- v1.0.16 — 2025-03-18
- v1.0.15 — 2025-02-19
- v1.0.14 — 2025-01-13
- v1.0.13 — 2024-11-07
- v1.0.12 — 2024-09-30
- v1.0.11 — 2024-08-23
- v1.0.10 — 2024-06-14
- v1.0.9 — 2024-04-25
- v1.0.8 — 2023-07-24
- v1.0.7 — 2023-06-12
- 1.0.2 — 2021-04-12
- 1.0.1 — 2021-02-16
- 1.0.0 — 2021-01-14

Details available at https://github.com/microbiomedata/ReadsQC/releases

---

## Point of Contact

- Original author: Brian Bushnell <bbushnell@lbl.gov>
- Package maintainer: Chienchi Lo <chienchi@lanl.gov>, Valerie Li <vli@lanl.gov>


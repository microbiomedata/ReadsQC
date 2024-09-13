Reads QC Workflow (v1.0.10)
=============================

.. image:: rqc_workflow.png
   :align: center
   :scale: 50%


Workflow Overview
-----------------

This workflow utilizes the program “rqcfilter2” from BBTools to perform quality control on raw Illumina reads. The workflow performs quality trimming, artifact removal, linker trimming, adapter trimming, and spike-in removal (using BBDuk), and performs human/cat/dog/mouse/microbe removal (using BBMap).

The following parameters are used for "rqcfilter2" in this workflow::
 - da         : Disable assertions.
 - threads    : Set number of threads to use.
 - rna=false   : Trim Illumina TruSeq-RNA adapters.
 - qtrim=r     :  Quality-trim from right ends before mapping.
 - trimq=0     :  Trim quality threshold.
 - maxns=3     :  Reads with more Ns than this will be discarded.
 - maq=3       :  Reads with average quality (before trimming) below this will be discarded.
 - minlen=51   :  Reads shorter than this after trimming will be discarded.  Pairs will be discarded only if both are shorter.
 - mlf=0.33    :  Reads shorter than this fraction of original length after trimming will be discarded.
 - phix=true   :  Remove reads containing phiX kmers.
 - khist=true  :  Generate a kmer-frequency histogram of the output data.
 - kapa=true   :  Remove and quantify kapa tag
 - trimpolyg=5 :  Trim reads that start or end with a G polymer at least this long
 - clumpify=true       :  Run clumpify; all deduplication flags require this.
 - removehuman=true    :  Remove human reads via mapping.
 - removedog=true      :  Remove dog reads via mapping.
 - removecat=true      :  Remove cat reads via mapping.
 - removemouse=true    :  Remove mouse reads via mapping.
 - kapa=true           :  Remove and quantify kapa.
 - trimpolyg=5         :  Trim reads that start or end with a G polymer at least this long.
 - barcodefilter=false :  Disable improper barcodes filter
 - chastityfilter=true:  Remove illumina reads failing chastity filter.
 - trimfragadapter=true:  Trim all known Illumina adapter sequences, including TruSeq and Nextera.
 - removemicrobes=true :  Remove common contaminant microbial reads via mapping, and place them in a separate file.

 
Workflow Availability
---------------------

The workflow from GitHub uses all the listed docker images to run all third-party tools.
The workflow is available in GitHub: https://github.com/microbiomedata/ReadsQC; the corresponding
Docker image is available in DockerHub: https://hub.docker.com/r/microbiomedata/bbtools.

Requirements for Execution 
--------------------------

(recommendations are in **bold**) 

- WDL-capable Workflow Execution Tool (**Cromwell**)
- Container Runtime that can load Docker images (**Docker v2.1.0.3 or higher**) 

Hardware Requirements
---------------------

- Disk space: 106 GB for the RQCFilterData database 
- Memory: >40 GB RAM


Workflow Dependencies
---------------------

Third party software (This is included in the Docker image.)  
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- `BBTools v38.96 <https://jgi.doe.gov/data-and-tools/bbtools/>`_ (License: `BSD-3-Clause-LBNL <https://bitbucket.org/berkeleylab/jgi-bbtools/src/master/license.txt>`_)

Requisite database
~~~~~~~~~~~~~~~~~~

The RQCFilterData Database must be downloaded and installed. This is a 106 GB tar file which includes reference datasets of artifacts, adapters, contaminants, the phiX genome, and some host genomes.  

The following commands will download the database:: 

    mkdir refdata
    wget http://portal.nersc.gov/dna/microbial/assembly/bushnell/RQCFilterData.tar
    tar -xvf RQCFilterData.tar -C refdata
    rm RQCFilterData.tar	

Sample dataset(s)
-----------------

- small dataset: `Ecoli 10x <https://portal.nersc.gov/cfs/m3408/test_data/ReadsQC_small_test_data.tgz>`_ . You can find input/output in the downloaded tar gz file.

- large dataset: Zymobiomics mock-community DNA control (`SRR7877884 <https://www.ebi.ac.uk/ena/browser/view/SRR7877884>`_); the `original gzipped dataset <https://portal.nersc.gov/cfs/m3408/test_data/ReadsQC_large_test_data.tgz>`_ is ~5.7 GB.  You can find input/output in the downloaded tar gz file.


.. note::

    If the input data is paired-end data, it must be in interleaved format. The following command will interleave the files, using the above dataset as an example:
    
.. code-block:: bash    

    paste <(zcat SRR7877884_1.fastq.gz | paste - - - -) <(zcat SRR7877884_2.fastq.gz | paste - - - -) | tr '\t' '\n' | gzip -c > SRR7877884-int.fastq.gz
    
For testing purposes and for the following examples, we used a 10% sub-sampling of the above dataset: `SRR7877884-int-0.1.fastq.gz <https://portal.nersc.gov/cfs/m3408/test_data/SRR7877884-int-0.1.fastq.gz>`_. This dataset is already interleaved.

Inputs
------

A JSON file containing the following information: 

1.	the path to the database
2.	the path to the fastq file(s) (input data) 
3.      project prefix
4. 	Boolean variable for if the data is short reads


An example input JSON file is shown below:

.. code-block:: JSON

    {
        "rqcfilter.reference": "/path/to/refdata",
        "rqcfilter.input_files": [
            "/path/to/SRR7877884-int-0.1.fastq.gz "
        ],
        "rqcfilter.proj": "nmdc:xxx",
        "rqcfilter.shortRead": true
    }

.. note::

    In an HPC environment, parallel processing allows for processing multiple samples. The "jgi_rqcfilter.input_files" parameter is an array data structure. It can be used for multiple samples as input separated by a comma (,).
    Ex: "jgi_rqcfilter.input_files":[“first-int.fastq”,”second-int.fastq”]


Output
------

A directory named with the prefix of the FASTQ input file will be created and multiple output files are generated; the main QC FASTQ output is named prefix.anqdpht.fastq.gz. Using the dataset above as an example, the main output would be named SRR7877884-int-0.1.anqdpht.fastq.gz. Other files include statistics on the quality of the data; what was trimmed, detected, and filtered in the data; a status log, and a shell script documenting the steps implemented so the workflow can be reproduced.

An example output JSON file (filterStats.json) is shown below:
   
.. code-block:: JSON 
    
	{
	  "inputReads": 331126,
	  "kfilteredBases": 138732,
	  "qfilteredReads": 0,
	  "ktrimmedReads": 478,
	  "outputBases": 1680724,
	  "ktrimmedBases": 25248,
	  "kfilteredReads": 926,
	  "qtrimmedBases": 0,
	  "outputReads": 11212,
	  "gcPolymerRatio": 0.182857,
	  "inputBases": 50000026,
	  "qtrimmedReads": 0,
	  "qfilteredBases": 0
	}


Below is an example of all the output directory files with descriptions to the right.

==================================== ============================================================================
FileName                              Description
==================================== ============================================================================
SRR7877884-int-0.1.anqdpht.fastq.gz   main output (clean data)       
adaptersDetected.fa                   adapters detected and removed        
bhist.txt                             base composition histogram by position 
cardinality.txt                       estimation of the number of unique kmers 
commonMicrobes.txt                    detected common microbes 
file-list.txt                         output file list for rqcfilter2.sh 
filterStats.txt                       summary statistics 
filterStats.json                      summary statistics in JSON format 
filterStats2.txt                      more detailed summary statistics 
gchist.txt                            GC content histogram 
human.fq.gz                           detected human sequence reads 
ihist_merge.txt                       insert size histogram 
khist.txt                             kmer-frequency histogram 
kmerStats1.txt                        synthetic molecule (phix, linker, lamda, pJET) filter run log  
kmerStats2.txt                        synthetic molecule (short contamination) filter run log 
ktrim_kmerStats1.txt                  detected adapters filter run log 
ktrim_scaffoldStats1.txt              detected adapters filter statistics 
microbes.fq.gz                        detected common microbes sequence reads 
microbesUsed.txt                      common microbes list for detection 
peaks.txt                             number of unique kmers in each peak on the histogram 
phist.txt                             polymer length histogram 
refStats.txt                          human reads filter statistics 
reproduce.sh                          the shell script to reproduce the run
scaffoldStats1.txt                    detected synthetic molecule (phix, linker, lamda, pJET) statistics 
scaffoldStats2.txt                    detected synthetic molecule (short contamination) statistics 
scaffoldStatsSpikein.txt              detected skipe-in kapa tag statistics 
sketch.txt                            mash type sketch scanned result against nt, refseq, silva database sketches.  
spikein.fq.gz                         detected skipe-in kapa tag sequence reads 
status.log                            rqcfilter2.sh running log 
synth1.fq.gz                          detected synthetic molecule (phix, linker, lamda, pJET) sequence reads 
synth2.fq.gz                          detected synthetic molecule (short contamination) sequence reads 
==================================== ============================================================================


Version History
---------------

- 1.0.2 (release date **04/09/2021**; previous versions: 1.0.1)


Point of contact
----------------

- Original author: Brian Bushnell <bbushnell@lbl.gov>

- Package maintainer: Chienchi Lo <chienchi@lanl.gov>


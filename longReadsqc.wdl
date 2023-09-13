# LongReadsQC workflow
version 1.0

workflow LongReadsQC{
  input{
    File file
    String? output_path
    Int? coverage
    Boolean? ccs
    Boolean? dedup
    Boolean? entropy
    Int? genome_size
    Boolean? print_log
  }

  call pbfilter{
    input:
    file = file,
    output_path = output_path,
    coverage = coverage,
    ccs = ccs,
    dedup = dedup,
    entropy = entropy,
    genome_size = genome_size,
    print_log = print_log
  }
  output {
    Array[File?] outputFiles = pbfilter.outputFiles
  }
}

task pbfilter {
  input{
    File file
    String? output_path
    Int? coverage
    Boolean? ccs
    Boolean? dedup
    Boolean? entropy
    Int? genome_size
    Boolean? print_log
  }
  command <<<
  # path found from interactive session of docker container
    /jgi-rqc-pipeline/filter/pb_filter-15.py \
    ~{"-f" + file} \
    ~{"-o" + output_path} \
    ~{true="--ccs True" false="" ccs} \
    ~{true="-d True" false="" dedup} \
    ~{"-c" + coverage} \
    ~{true="-e True" false="" entropy} \
    ~{"-g" + genome_size} \
    ~{true="-pl True" false="" print_log} 
  >>>

  output {
    Array[File?] outputFiles = glob("${output_path}/*")
     }

  runtime {
        docker: "bryce911/rqc-pipeline:20230410 "
        continueOnReturnCode: true
    }
}


task pbmarkdup{
  input{

  }

  command <<<
  # need Pacbio smrtlink in the path
  pbmarkdup --log-level INFO -f -r pbio-2861.29528.bc2002_OA--bc2002_OA.bc2002_OA--bc2002_OA.ccs.bam pbio-2861.29528.bc2002_OA--bc2002_OA.bc2002_OA--bc2002_OA.ccs.
  dedup.bam
  >>>

  output{

  }

  runtime{
     docker: "microbiomedata/pbmarkdup:1.0"
        continueOnReturnCode: true
  }
}


task icecreamfilter{
  input{

  }

  command <<<
  # icecream filter - removes reads that are missing smrtlink adapters
  icecreamfinder.sh jni=t json=t ow=t cq=f keepshortreads=f trim=f ccs=t in=triangle.trim2.tmp.bam stats=triangle.json out=pbio-2861.29528.bc2002_OA--bc2002_OA.bc2
  002_OA--bc2002_OA.ccs.unsorted.filter.bam outb=pbio-2861.29528.bc2002_OA--bc2002_OA.bc2002_OA--bc2002_OA.ccs.bad.bam outa=pbio-2861.29528.bc2002_OA--bc2002_OA.bc
  2002_OA--bc2002_OA.ccs.ambig.bam
  >>>

  output{

  }

  runtime{
     docker: "bryce911/smrtlink:12.0.0.177059"
        continueOnReturnCode: true
  }
}

task bbdukEnds{
  input{

  }

  command <<<
  # bbduk - trim out adapter from read ends
  bbduk.sh k=20 mink=12 edist=1 mm=f ktrimtips=60 ref=/bbmap/resources/PacBioAdapter.fa in=pbio-2861.29528.bc2002_OA--bc2002_OA.bc2002_OA--bc2002_OA.ccs.dedup.bam
  out=triangle.trim.tmp.bam
  >>>

  output{

  }

  runtime{
     docker: "microbiomedata/bbtools:39.01"
        continueOnReturnCode: true
  }
}

task bbdukReads{
  input{

  }

  command <<<
  # bbduk - removes reads that still contain adapter sequence
  bbduk.sh k=24 edist=1 mm=f ref=/bbmap/resources/PacBioAdapter.fa in=triangle.trim.tmp.bam out=pbio-2861.29528.bc2002_OA--bc2002_OA.bc2002_OA--bc2002_OA.ccs.unsor
  ted.filter.bam
  >>>

  output{

  }

  runtime{
     docker: "microbiomedata/bbtools:39.01"
        continueOnReturnCode: true
  }
}
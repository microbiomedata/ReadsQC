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

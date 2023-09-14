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

  call pbmarkdup {

  }

  # call pbfilter{
  #   input:
  #   file = file,
  #   output_path = output_path,
  #   coverage = coverage,
  #   ccs = ccs,
  #   dedup = dedup,
  #   entropy = entropy,
  #   genome_size = genome_size,
  #   print_log = print_log
  # }
  # output {
  #   Array[File?] outputFiles = pbfilter.outputFiles
  # }
}

# task pbfilter {
#   input{
#     File file
#     String? output_path
#     Int? coverage
#     Boolean? ccs
#     Boolean? dedup
#     Boolean? entropy
#     Int? genome_size
#     Boolean? print_log
#   }
#   command <<<
#   # path found from interactive session of docker container
#     /jgi-rqc-pipeline/filter/pb_filter-15.py \
#     ~{"-f" + file} \
#     ~{"-o" + output_path} \
#     ~{true="--ccs True" false="" ccs} \
#     ~{true="-d True" false="" dedup} \
#     ~{"-c" + coverage} \
#     ~{true="-e True" false="" entropy} \
#     ~{"-g" + genome_size} \
#     ~{true="-pl True" false="" print_log} 
#   >>>

#   output {
#     Array[File?] outputFiles = glob("${output_path}/*")
#      }

#   runtime {
#         docker: "bryce911/rqc-pipeline:20230410 "
#         continueOnReturnCode: true
#     }
# }


task pbmarkdup{
  input{
    String? log_level
    File in_file
    String out_file
    Boolean? rmdup
    Boolean? overwrite
  }

  command <<<

  pbmarkdup \
  if (defined(log_level)) then ~{"--log-level" + log_level} else "--log-level INFO" \
  ~{true="--rmdup" false="" rmdup} \
  ~{true="--clobber" false="" overwrite} \
  ~{in_file} \
  ~{out_file} 

  gzip ~{out_file}
  
   >>>

  output{
    File out_fastq = "${out_file}.gz"
  }

  runtime{
     docker: "microbiomedata/pbmarkdup:1.0"
        continueOnReturnCode: true
  }
}


task icecreamfilter{
  input{
    File in_file
    File out_bad
    File out_good
  }

  command <<<

  icecreamfinder.sh \
  jin=t \
  ow=t \
  cq=f \
  keepshortreads=f \
  trim=f \
  ccs=t \
  ~{"in=" + in_file} \
  ~{"out=" + out_good} \
  ~{"outb=" + out_bad} 

  >>>

  output{
    File output_good = "${out_good}"
    File output_bad = "${out_bad}"
  }

  runtime{
     docker: "microbiomedata/bbtools:39.01"
        continueOnReturnCode: true
  }
}

task bbdukEnds{
  input{
    File? reference
    File in_file
    File out_file
  }

  command <<<

  # bbduk - trim out adapter from read ends
  bbduk.sh \
  k=20 \
  mink=12 \
  edist=1 \
  mm=f \
  ktrimtips=60 \
  if (defined(reference)) then ~{"ref=" + reference} else "ref=/bbmap/resources/PacBioAdapter.fa" \
  ~{"in=" + in_file} \
  ~{"out=" + out_file}
  >>>

  output{
    File out_fastq = "${out_file}.gz"
  }

  runtime{
     docker: "microbiomedata/bbtools:39.01"
        continueOnReturnCode: true
  }
}

task bbdukReads{
  input{
    File? reference
    File in_file
    File out_file
  }

  command <<<
  # bbduk - removes reads that still contain adapter sequence
  bbduk.sh \
  k=24 \
  edist=1 \
  mm=f \
  if (defined(reference)) then ~{"ref=" + reference} else "ref=/bbmap/resources/PacBioAdapter.fa" \
  ~{"in=" + in_file} \
  ~{"out=" + out_file}
  >>>

  output{
    File out_fastq = "${out_file}.gz"
  }

  runtime{
     docker: "microbiomedata/bbtools:39.01"
        continueOnReturnCode: true
  }
}
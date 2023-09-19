# LongReadsQC workflow
version 1.0

workflow LongReadsQC{
  input{
    File file
    String outdir
    String? log_level
    Boolean? rmdup
    Boolean? overwrite
    File? reference
  }

  call pbmarkdup {
    input: 
    in_file = file,
    outdir = outdir,
    log_level = log_level,
    rmdup = rmdup,
    overwrite = overwrite
  }

  call icecreamfilter {
    input:
    in_file = pbmarkdup.out_fastq,
    outdir = outdir
  }

  call bbdukEnds {
    input:
    in_file = icecreamfilter.output_good,
    outdir = outdir,
    reference = reference
  }

  call bbdukReads {
    input:
    in_file = bbdukEnds.out_fastq,
    outdir = outdir,
    reference = reference
  }

  output {
  File out_fastq = bbdukReads.out_fastq
    }

}

task pbmarkdup{
  input{
    File in_file
    String outdir
    String out_file = outdir + "/pbmarkdup.out"
    String? log_level
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
    String outdir
    String out_bad = outdir + "/icecreamfilter.out_bad.out.gz"
    String out_good = outdir + "/icecreamfilter.out_good.out.gz"
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
    String outdir
    String out_file = outdir + "/bbdukEnds.out.gz"
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
    File out_fastq = "${out_file}"
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
    String outdir
    String out_file = outdir + "/bbdukReads.out.gz"
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
    File out_fastq = "${out_file}"
  }

  runtime{
     docker: "microbiomedata/bbtools:39.01"
        continueOnReturnCode: true
  }
}


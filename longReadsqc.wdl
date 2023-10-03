# LongReadsQC workflow
## input can be .bam or .fq or .fq.gz
## output fq.gz
version 1.0

workflow LongReadsQC{
  input{
    File    file
    String  outdir
    String  prefix = basename(file)
    String  log_level='INFO'
    Boolean rmdup = true
    Boolean overwrite = true
    File?   reference
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
    prefix = prefix,
    outdir = outdir
  }

  call bbdukEnds {
    input:
    in_file = icecreamfilter.output_good,
    prefix = prefix,
    outdir = outdir,
    reference = reference
  }

  call bbdukReads {
    input:
    in_file = bbdukEnds.out_fastq,
    prefix = prefix,
    outdir = outdir,
    reference = reference
  }

  output {
  File out_fastq = bbdukReads.out_fastq
    }

}

task pbmarkdup{
  input{
    File     in_file
    String   outdir
    String   out_file = outdir + "/pbmarkdup.fq"
    String?  log_level
    Boolean? rmdup
    Boolean? overwrite
  }

  command <<<
  mkdir -m 755 -p ~{outdir}
  pbmarkdup \
  ~{if (defined(log_level)) then "--log-level " + log_level else  "--log-level INFO"  } \
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
    File   in_file
    String outdir
    String prefix
    String out_bad = outdir + "/" + prefix + ".icecreamfilter.out_bad.out.gz"
    String out_good = outdir + "/" + prefix + ".icecreamfilter.out_good.out.gz"
  }

  command <<<

  icecreamfinder.sh \
  jni=t \
  json=t \
  ow=t \
  cq=f \
  keepshortreads=f \
  trim=f \
  ccs=t \
  stats=triangle.json \
  ~{"in=" + in_file} \
  ~{"out=" + out_good} \
  ~{"outb=" + out_bad} 

  >>>

  output{
    File output_good = "${out_good}"
    File output_bad = "${out_bad}"
    File stats = "triangle.json"
  }

  runtime{
     docker: "microbiomedata/bbtools:39.01"
        continueOnReturnCode: true
  }
}

task bbdukEnds{
  input{
    File?  reference
    File   in_file
    String prefix
    String outdir
    String out_file = outdir + "/" + prefix + ".bbdukEnds.out.fq.gz"
  }

  command <<<

  # bbduk - trim out adapter from read ends
  bbduk.sh \
  k=20 \
  mink=12 \
  edist=1 \
  mm=f \
  ktrimtips=60 \
  json=t \
  ~{if (defined(reference)) then "ref=" + reference else "ref=/bbmap/resources/PacBioAdapter.fa" } \
  ~{"in=" + in_file} \
  ~{"out=" + out_file}
  >>>

  output{
    File out_fastq = "${out_file}"
    File stats = "stderr"
  }

  runtime{
     docker: "microbiomedata/bbtools:39.01"
        continueOnReturnCode: true
  }
}

task bbdukReads{
  input{
    File?  reference
    File   in_file
    String prefix
    String outdir
    String out_file = outdir + "/" + prefix + ".filtered.fq.gz"
  }

  command <<<
  # bbduk - removes reads that still contain adapter sequence
  bbduk.sh \
  k=24 \
  edist=1 \
  mm=f \
  json=t \
  ~{if (defined(reference)) then "ref=" + reference else "ref=/bbmap/resources/PacBioAdapter.fa" } \
  ~{"in=" + in_file} \
  ~{"out=" + out_file}
  >>>

  output{
    File out_fastq = "${out_file}"
    File stats = "stderr" 
  }

  runtime{
     docker: "microbiomedata/bbtools:39.01"
        continueOnReturnCode: true
  }
}


version 1.0
workflow sra {
    input {
        Array[String] accessions
        String outdir = "SRA_Downloaded"
        Boolean? clean
        String? platform_restrict
        Int? filesize_restrict
        Int? runs_restrict
        String container = "kaijli/sra2fastq:1.6"
    }

    call sra2fastq{
        input:
        accessions = accessions,
        outdir = outdir,
        clean = clean,
        platform_restrict = platform_restrict,
        filesize_restrict = filesize_restrict,
        runs_restrict = runs_restrict,
        container = container

    }
}

task sra2fastq {
    input {
        Array[String] accessions
        String outdir
        Boolean? clean
        String? platform_restrict
        Int? filesize_restrict
        Int? runs_restrict
        String container
    }
     command <<<

        sra2fastq.py ~{sep=' ' accessions} ~{"--outdir=" + outdir}  ~{true=" --clean True" false="" clean} ~{" --platform_restrict=" + platform_restrict} ~{" --filesize_restrict=" + filesize_restrict} ~{" --runs_restrict=" + runs_restrict}
    
    >>>
    output {
        Array[File] outputFiles = glob("${outdir}/*")
        Boolean isIllumina = if (glob("${outdir}/*.fastq.gz").size() > 1) true else false
    }

    runtime {
        memory: "16 GiB"
        cpu: 2
        docker: container
        continueOnReturnCode: true
    }
}
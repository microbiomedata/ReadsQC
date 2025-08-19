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
        if compgen -G "~{outdir}"/*metadata.txt > /dev/null; then
            if grep -iq "illumina" "~{outdir}"/*metadata.txt; then
                echo true > check_illumina.txt
            else
                echo false > check_illumina.txt
            fi
            if grep -iq "PAIRED" "~{outdir}"/*metadata.txt; then
                echo true > check_paired.txt
            else
                echo false > check_paired.txt
            fi
            if grep -iq "PacBio" "~{outdir}"/*metadata.txt; then
                echo true > check_pacbio.txt
            else
                echo false > check_pacbio.txt
            fi
        fi
    >>>
    output {
        Array[File] outputFiles = glob("~{outdir}/*")
        Array[File] output_fq1 = glob("~{outdir}/*_1.fastq.gz")
        Array[File] output_fq2 = glob("~{outdir}/*_2.fastq.gz")
        Boolean isIllumina = read_boolean("check_illumina.txt")
        Boolean isPaired = read_boolean("check_paired.txt")
        Boolean isPacBio = read_boolean("check_pacbio.txt")
    }

    runtime {
        memory: "16 GiB"
        cpu: 2
        docker: container
        continueOnReturnCode: true
    }
}
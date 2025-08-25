version 1.0
workflow sra {
    input {
        Array[String] accessions
        String outdir = "SRA_Downloaded"
        Boolean? clean
        String? platform_restrict
        Int? filesize_restrict
        Int? runs_restrict
        String container = "ghcr.io/lanl-bioinformatics/edge_sra2fastq:1.6.3"
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
    output {
        Array[String] outputFiles = sra2fastq.outputFiles
        Array[String] output_fq1 = sra2fastq.output_fq1   
        Array[String] output_fq2 = sra2fastq.output_fq2
        Boolean isIllumina = sra2fastq.isIllumina
        Boolean isPaired = sra2fastq.isPaired
        Boolean isPacBio = sra2fastq.isPacBio
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
        if compgen -G "~{outdir}"/*/*metadata.txt > /dev/null; then
            if grep -iq "illumina" "~{outdir}"/*/*metadata.txt; then
                echo true > check_illumina.txt
            else
                echo false > check_illumina.txt
            fi
            if grep -iq "PAIRED" "~{outdir}"/*/*metadata.txt; then
                echo true > check_paired.txt
            else
                echo false > check_paired.txt
            fi
            if grep -iq "PacBio" "~{outdir}"/*/*metadata.txt; then
                echo true > check_pacbio.txt
            else
                echo false > check_pacbio.txt
            fi
        else
            echo false > check_illumina.txt
            echo false > check_paired.txt
            echo false > check_pacbio.txt
        fi
    >>>
    output {
        Array[String] outputFiles = glob("~{outdir}/*/*fastq.gz")
        Array[String] output_fq1 = glob("~{outdir}/*/*_1.fastq.gz")
        Array[String] output_fq2 = glob("~{outdir}/*/*_2.fastq.gz")
        File?   metadata = glob("~{outdir}/*/*metadata.txt")[0]
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
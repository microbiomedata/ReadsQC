version 1.0
import "shortReadsqc.wdl" as srqc
import "longReadsqc.wdl" as lrqc
import "sra2fastq.wdl" as sra

workflow rqcfilter{
    input {
    Array[String]? input_files
    Array[String]? input_fq1
    Array[String]? input_fq2
    Array[String]? accessions
    File?          reference
    String         proj
    Boolean        interleaved
    Boolean        shortRead
    Boolean?       chastityfilter_flag
  }
    
    Boolean has_accessions = defined(accessions) && length(select_first([accessions, []])) > 0

    if (has_accessions) {
        call sra.sra as sra2fastq {
            input:
                accessions = select_first([accessions, []])
        }
    }

    Boolean is_shortReads  = select_first([sra2fastq.isIllumina, shortRead])
    Boolean is_interleaved = if (has_accessions) then false else interleaved
    Boolean is_Pacbio = select_first([sra2fastq.isPacBio, !shortRead])
    Boolean unsupported_platform = !(is_shortReads) && !(is_Pacbio)

    if (unsupported_platform) {
        call UnsupportedPlatformNotice
    }
    
    if (is_shortReads) {
        call srqc.ShortReadsQC {
            input:
                input_files = input_files,
                input_fq1 = if is_interleaved then [] else select_first([sra2fastq.output_fq1, input_fq1]),
                input_fq2 = if is_interleaved then [] else select_first([sra2fastq.output_fq2, input_fq2]),
                interleaved = is_interleaved,
                proj = proj,
                chastityfilter_flag = if (has_accessions) then false else chastityfilter_flag
        }
    }

    if (is_Pacbio) {
        call lrqc.LongReadsQC {
            input:
                file = select_first([sra2fastq.outputFiles, input_files])[0],
                proj = proj,
                reference = reference
        }
    }

    output {
        Array[File]? sra_fastq_files = sra2fastq.outputFiles
        File? filtered_final = if (is_shortReads) then ShortReadsQC.filtered_final else LongReadsQC.filtered_final
        File? filtered_stats_final = if (is_shortReads) then ShortReadsQC.filtered_stats_final else LongReadsQC.filtered_stats1
        File? filtered_stats2_final = if (is_shortReads) then ShortReadsQC.filtered_stats2_final else LongReadsQC.filtered_stats2
        File? rqc_info = if (is_shortReads) then ShortReadsQC.rqc_info else LongReadsQC.rqc_info
        File? stats = if (is_shortReads) then ShortReadsQC.stats else LongReadsQC.stats
    }
}

task UnsupportedPlatformNotice {
    command {
        echo "ERROR: Only Illumina and PacBio sequencing platforms are supported at this time." >&2
    }
    output {
        String msg = read_string(stderr())
    }
    runtime {
        memory: "1 GiB"
        cpu: 1
    }
}
version 1.0
import "shortReadsqc.wdl" as srqc
import "longReadsqc.wdl" as lrqc
import "sra2fastq.wdl" as sra

workflow rqcfilter{
    input {
    Array[String] input_files
    Array[String] input_fq1
    Array[String] input_fq2
    Array[String] accessions
    File?       reference
    String      proj
    Boolean     interleaved
    Boolean     shortRead_input
    Boolean?    chastityfilter_flag
  }

    if (length(accessions) > 1) {
        call sra.sra2fastq as sra2fastq {
            input:
                accessions = accessions
        }
    }

    Boolean shortReads = select_first([sra2fastq.isIllumina, shortRead_input])
    
    if (shortRead) {
        call srqc.ShortReadsQC {
            input:
                input_files = input_files,
                input_fq1 = input_fq1,
                input_fq2 = input_fq2,
                interleaved = interleaved,
                proj = proj,
                chastityfilter_flag = chastityfilter_flag
        }
    }

    if (!shortRead) {
        call lrqc.LongReadsQC {
            input:
                file = input_files[0],
                proj = proj,
                reference = reference
        }
    }

    output {
        File? filtered_final = if (shortRead) then ShortReadsQC.filtered_final else LongReadsQC.filtered_final
        File? filtered_stats_final = if (shortRead) then ShortReadsQC.filtered_stats_final else LongReadsQC.filtered_stats1
        File? filtered_stats2_final = if (shortRead) then ShortReadsQC.filtered_stats2_final else LongReadsQC.filtered_stats2
        File? rqc_info = if (shortRead) then ShortReadsQC.rqc_info else LongReadsQC.rqc_info
        File? stats = if (shortRead) then ShortReadsQC.stats else LongReadsQC.stats
    }
}
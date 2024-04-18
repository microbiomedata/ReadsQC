version 1.0
import "shortReadsqc.wdl" as srqc
import "longReadsqc.wdl" as lrqc

workflow rqcfilter{
    input{
    # String  outdir
    File?   reference
    Array[String] input_files
    String  proj
    Boolean shortRead 
  }
    if (shortRead) {
        call srqc.ShortReadsQC{
            input:
            input_files = input_files,
            proj = proj
        }
    }
    if (!shortRead) {
        call lrqc.LongReadsQC{
            input:
            file = input_files[0],
            proj = proj,
            # outdir = outdir,
            reference = reference
        }
    }
    output {
        # short reads
        File? filtered_final_srqc = ShortReadsQC.filtered_final
        File? filtered_stats_final_srqc = ShortReadsQC.filtered_stats_final
        File? filtered_stats2_final_srqc = ShortReadsQC.filtered_stats2_final
        File? rqc_info_srqc = ShortReadsQC.rqc_info
        # long reads
        File? filtered_final_lrqc = LongReadsQC.filtered_final
        File? filtered_stats_final_lrqc = LongReadsQC.filtered_stats1
        File? filtered_stats2_final_lrqc = LongReadsQC.filtered_stats2
        File? filtered_stats3_final_lrqc = LongReadsQC.filtered_stats3
        File? rqc_info_lrqc = LongReadsQC.rqc_info
    }
}
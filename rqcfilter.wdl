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
    Boolean gcloud_env=false
  }
    if (shortRead) {
        call srqc.ShortReadsQC{
            input:
            input_files = input_files,
            proj = proj,
            gcloud_env = gcloud_env
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
        File? filtered_final_srqc = ShortReadsQC.filtered_final
        File? filtered_stats_final_srqc = ShortReadsQC.filtered_stats_final
        File? filtered_stats2_final_srqc = ShortReadsQC.filtered_stats2_final
        File? rqc_info_srqc = ShortReadsQC.rqc_info
        File? out_fastq_lrqc = LongReadsQC.out_fastq
    }
}

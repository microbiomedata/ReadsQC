version 1.0
import "shortReadsqc.wdl" as srqc
import "longReadsqc.wdl" as lrqc

workflow chooseQC{
    input{
    String  outdir
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
            outdir = outdir,
            reference = reference
        }
    }
}


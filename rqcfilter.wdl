version 1.0
import "shortReadsqc.wdl" as srqc
import "longReadsqc.wdl" as lrqc

workflow rqcfilter{
    input {
    Array[Pair[File, String]] input_files
    Array[File] input_fq1
    Array[File] input_fq2
    File?       reference
    String      proj
    Boolean     interleaved
    Boolean     shortRead
  }

    scatter (file in input_files) {
        call processing {
            input: input_files = file
        }
    }

    if (shortRead) {
        call srqc.ShortReadsQC {
            input:
                input_files = processing.input_wdl,
                input_fq1 = input_fq1,
                input_fq2 = input_fq2,
                interleaved = interleaved,
                proj = proj
        }
    }

    if (!shortRead) {
        call lrqc.LongReadsQC {
            input:
                file = processing.input_wdl[0],
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

task processing {
  input {
      Pair[File, String] input_files
  }

  command <<<
      echo "INPUT FOLDER: $(ls ~{input_files.left})" >> test.txt
      cp  ~{input_files.left}  ~{input_files.right}
      ls -latr  >> test.txt
  >>>

  output {
      File input_wdl = "~{input_files.right}" 
  }

  runtime{
      memory: "2GiB"
      runtime_minutes: 10
      cpu: 2
  }
}
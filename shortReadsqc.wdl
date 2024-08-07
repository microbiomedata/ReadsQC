# Short reads QC workflow
version 1.0

workflow ShortReadsQC {
    input{
        String  container="bfoster1/img-omics:0.1.9"
        String  bbtools_container="microbiomedata/bbtools:38.96"
        String  workflow_container = "microbiomedata/workflowmeta:1.1.1"
        String  proj
        String  prefix=sub(proj, ":", "_")
        Array[String] input_files
        Array[String] input_fq1
        Array[String] input_fq2
        Boolean interleaved
        String  database="/refdata/"
    }

    if (interleaved) {
        scatter(file in input_files) {
            call stage_single {
                input:
                    container = container,
                    input_file = file
            }
            call rqcfilter as rqcInt {
            input:  
                input_fastq = stage_single.reads_fastq,
                container = bbtools_container,
                threads = "16",
                database = database,
                memory = "60G"
            }
            call finish_rqc as finrqcInt{
            input: 
                container = workflow_container,
                prefix = stage_single.input_files_prefix[0],
                filtered = rqcInt.filtered,
                filtered_stats = rqcInt.stat,
                filtered_stats2 = rqcInt.stat2
            }
        }
    }

    if (!interleaved) {
        scatter(file in zip(input_fq1,input_fq2)){
            call stage_interleave {
            input:
                output_interleaved = basename(file.left) + "_" + basename(file.right),
                input_fastq1 = file.left,
                input_fastq2 = file.right,
                container = bbtools_container,
                memory="10G"
            }
            call rqcfilter as rqcPE {
            input:  
                input_fastq = stage_interleave.reads_fastq,
                container = bbtools_container,
                threads = "16",
                database = database,
                memory = "60G"
            }
            call finish_rqc as finrqcPE{
            input: 
                container = workflow_container,
                prefix = stage_interleave.input_files_prefix[0],
                filtered = rqcPE.filtered,
                filtered_stats = rqcPE.stat,
                filtered_stats2 = rqcPE.stat2
            }

        }
    }
    
    call make_info_file {
        input: 
        info_file = if (interleaved) then select_first([rqcInt.info_file])[0] else select_first([rqcPE.info_file])[0],
        container = container,
        prefix = prefix
    }

    output {
        Array[File]? filtered_final = if (interleaved) then finrqcInt.filtered_final else finrqcPE.filtered_final
        Array[File]? filtered_stats_final = if (interleaved) then finrqcInt.filtered_stats_final else finrqcPE.filtered_stats_final
        Array[File]? filtered_stats2_final = if (interleaved) then finrqcInt.filtered_stats2_final else finrqcPE.filtered_stats2_final
        File rqc_info = make_info_file.rqc_info
    }
}

task stage_single {
    input{
        String container
        String target="raw.fastq.gz"
        String input_file
    }
   command <<<

    set -oeu pipefail
    if [ $( echo ~{input_file}|egrep -c "https*:") -gt 0 ] ; then
        wget ~{input_file} -O ~{target}
    else
        ln -s ~{input_file} ~{target} || cp ~{input_file} ~{target}
    fi

    # Create a prefix and save it
    name=$(basename "~{input_file}")
    prefix=${name%%.*}
    echo $prefix > fileprefix.txt

    # Capture the start time
    date --iso-8601=seconds > start.txt

   >>>

   output{
      File reads_fastq = "~{target}"
      String start = read_string("start.txt")
      Array[String] input_files_prefix = read_lines("fileprefix.txt")
   }
   runtime {
     memory: "1 GiB"
     cpu:  2
     maxRetries: 1
     docker: container
   }
}


task stage_interleave {
   input{
    String container
    String memory
    String target_reads_1="raw_reads_1.fastq.gz"
    String target_reads_2="raw_reads_2.fastq.gz"
    String input_fastq1
    String input_fastq2
    String output_interleaved
   }

   command <<<
       set -oeu pipefail
       if [ $( echo ~{input_fastq1} | egrep -c "https*:") -gt 0 ] ; then
           wget ~{input_fastq1} -O ~{target_reads_1}
           wget ~{input_fastq2} -O ~{target_reads_2}
       else
           ln -s ~{input_fastq1} ~{target_reads_1} || cp ~{input_fastq1} ~{target_reads_1}
           ln -s ~{input_fastq2} ~{target_reads_2} || cp ~{input_fastq2} ~{target_reads_2}
       fi

       reformat.sh -Xmx~{memory} in1=~{target_reads_1} in2=~{target_reads_2} out=~{output_interleaved}

        # Create a prefix and save it
        prefix=$(basename ~{input_fastq1} | sed -E 's/\.(fastq\.gz|fq\.gz|fastq|fq)$//')_$(basename ~{input_fastq2} | sed -E 's/\.(fastq\.gz|fq\.gz|fastq|fq)$//')
        echo $prefix > fileprefix.txt

        # Capture the start time
        date --iso-8601=seconds > start.txt
       
        # Validate that the read1 and read2 files are sorted correct to interleave
        reformat.sh -Xmx~{memory} verifypaired=t in=~{output_interleaved}

   >>>

   output{
      File reads_fastq = "~{output_interleaved}"
      String start = read_string("start.txt")
      Array[String] input_files_prefix = read_lines("fileprefix.txt")
   }
   runtime {
     memory: "10 GiB"
     cpu:  2
     maxRetries: 1
     docker: container
   }
}


task rqcfilter {
    input{
        File    input_fastq
        String  container
        String  database
        String  rqcfilterdata = database + "/RQCFilterData"
        Boolean chastityfilter_flag=true
        String? memory
        String? threads
        String  filename_outlog="stdout.log"
        String  filename_errlog="stderr.log"
        String  filename_stat="filtered/filterStats.txt"
        String  filename_stat2="filtered/filterStats2.txt"
        String  filename_stat_json="filtered/filterStats.json"
        String  filename_reproduce="filtered/reproduce.sh"
        String  system_cpu="$(grep \"model name\" /proc/cpuinfo | wc -l)"
        String  jvm_threads=select_first([threads,system_cpu])
        String  chastityfilter= if (chastityfilter_flag) then "cf=t" else "cf=f"
    }

    runtime {
        docker: container
        memory: "70 GB"
        cpu:  16
    }

     command<<<
        export TIME="time result\ncmd:%C\nreal %es\nuser %Us \nsys  %Ss \nmemory:%MKB \ncpu %P"
        set -euo pipefail

        rqcfilter2.sh \
            ~{if (defined(memory)) then "-Xmx" + memory else "-Xmx60G" }\
            -da \
            threads=~{jvm_threads} \
            ~{chastityfilter} \
            jni=t \
            in=~{input_fastq} \
            path=filtered \
            rna=f \
            trimfragadapter=t \
            qtrim=r \
            trimq=0 \
            maxns=3 \
            maq=3 \
            minlen=51 \
            mlf=0.33 \
            phix=t \
            removehuman=t \
            removedog=t \
            removecat=t \
            removemouse=t \
            khist=t \
            removemicrobes=t \
            sketch \
            kapa=t \
            clumpify=t \
            barcodefilter=f \
            trimpolyg=5 \
            usejni=f \
            rqcfilterdata=~{rqcfilterdata} \
            > >(tee -a  ~{filename_outlog}) \
            2> >(tee -a ~{filename_errlog}  >&2)

        python <<CODE
        import json
        f = open("~{filename_stat}",'r')
        d = dict()
        for line in f:
            if not line.rstrip():continue
            key,value=line.rstrip().split('=')
            d[key]=float(value) if 'Ratio' in key else int(value)

        with open("~{filename_stat_json}", 'w') as outfile:
            json.dump(d, outfile)
        CODE
        >>>

     output {
            File stdout = filename_outlog
            File stderr = filename_errlog
            File stat = filename_stat
            File stat2 = filename_stat2
            File info_file = filename_reproduce
            File filtered = glob("filtered/*fastq.gz")[0]
            File json_out = filename_stat_json
     }
}

task make_info_file {
    input{
        File          info_file
        String        prefix
        String        container
    }

    command<<<
        set -oeu pipefail
        sed -n 2,5p ~{info_file} 2>&1 | \
          perl -ne 's:in=/.*/(.*) :in=$1:; s/#//; s/BBTools/BBTools(1)/; print;' > \
         ~{prefix}_readsQC.info
        echo -e "\n(1) B. Bushnell: BBTools software package, http://bbtools.jgi.doe.gov/" >> \
         ~{prefix}_readsQC.info
    >>>

    output {
        File rqc_info = "~{prefix}_readsQC.info"
    }
    runtime {
        memory: "1 GiB"
        cpu:  1
        maxRetries: 1
        docker: container
    }
}

task finish_rqc {
    input {
        File   filtered_stats
        File   filtered_stats2
        File   filtered
        String container
        String prefix
    }

    command<<<

        set -oeu pipefail
        end=`date --iso-8601=seconds`
        # Generate QA objects
        ln -s ~{filtered} ~{prefix}_filtered.fastq.gz
        ln -s ~{filtered_stats} ~{prefix}_filterStats.txt
        ln -s ~{filtered_stats2} ~{prefix}_filterStats2.txt

       # Generate stats but rename some fields until the script is fixed.
       /scripts/rqcstats.py ~{filtered_stats} > stats.json
       cp stats.json ~{prefix}_qa_stats.json

    >>>
    output {
        File filtered_final = "~{prefix}_filtered.fastq.gz"
        File filtered_stats_final = "~{prefix}_filterStats.txt"
        File filtered_stats2_final = "~{prefix}_filterStats2.txt"
    }

    runtime {
        docker: container
        memory: "1 GiB"
        cpu:  1
    }
}
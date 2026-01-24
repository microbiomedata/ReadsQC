# Short reads QC workflow
version 1.0

workflow ShortReadsQC {
    input {
        String  container="bfoster1/img-omics:0.1.9"
        String  bbtools_container="microbiomedata/bbtools:38.96"
        String  workflow_container = "microbiomedata/workflowmeta:1.1.1"
        String  proj
        String  prefix=sub(proj, ":", "_")
        Array[File] input_files
        Array[File] input_fq1
        Array[File] input_fq2
        Boolean interleaved
        String  database="/refdata/"
        # runtime parameters for JAWS
        String  stage_single_mem = "1GB"
        Int     stage_single_cpu = 1
        Int     stage_single_run_mins = 10
        Int     stage_paired_mem = 10
        Int     stage_paired_cpu = 2
        Int     stage_paired_run_mins = 30
        Int     rqc_cpu = 8
        Int     rqc_mem = 180
        Int     rqc_run_mins = 1800
        String  make_info_mem = "1GB"
        Int     make_info_cpu = 1
        Int     make_info_run_mins = 5
        String  finish_rqc_mem = "1GB"
        Int     finish_rqc_cpu = 1
        Int     finish_rqc_run_mins = 5
    }

    if (interleaved) {
        call stage_single {
            input:
                container = container,
                memory=stage_single_mem,
                cpu = stage_single_cpu,
                run_mins = stage_single_run_mins
        }
    }

    if (!interleaved) {
        call stage_interleave {
            input:
                input_fastq1 = input_fq1,
                input_fastq2 = input_fq2,
                container = bbtools_container,
                memory = stage_paired_mem,
                cpu = stage_paired_cpu,
                run_mins = stage_paired_run_mins
            }
    }
    
    # Estimate RQC runtime at an hour per compress GB
   call rqcfilter as qc {
        input:
            input_fastq = if interleaved then stage_single.reads_fastq else stage_interleave.reads_fastq,
            database = database,
            container = bbtools_container,
            memory= rqc_mem,
            cpu = rqc_cpu,
            run_mins = rqc_run_mins
    }
    
    call make_info_file {
        input: 
            info_file = qc.info_file,
            prefix = prefix,
            container = container,
            memory=make_info_mem,
            cpu = make_info_cpu,
            run_mins = make_info_run_mins
    }

    call finish_rqc {
        input: 
            prefix = prefix,
            filtered = qc.filtered,
            filtered_stats = qc.stat,
            filtered_stats2 = qc.stat2,
            container=workflow_container,
            memory=finish_rqc_mem,
            cpu = finish_rqc_cpu,
            run_mins = finish_rqc_run_mins
    }

    output {
        File filtered_final = finish_rqc.filtered_final
        File filtered_stats_final = finish_rqc.filtered_stats_final
        File filtered_stats2_final = finish_rqc.filtered_stats2_final
        File rqc_info = make_info_file.rqc_info
        File stats = finish_rqc.json_out
    }
}

task stage_single {
    input {
        String target="raw.fastq.gz"
        Array[File] input_file
        String container
        String memory
        Int    cpu
        Int    run_mins
    }

    command <<<
    set -oeu pipefail

    for file in ~{sep= ' ' input_file}; do
        temp=$(basename $file)
        if [ $( echo $file|egrep -c "https*:") -gt 0 ] ; then
            wget $file -O $temp
        else
            ln -s $file $temp || cp $file $temp
        fi
        cat $temp >> ~{target}
    done

    # Capture the start time
    date --iso-8601=seconds > start.txt
    >>>

   output {
      File   reads_fastq = "~{target}"
      String start = read_string("start.txt")
   }
   runtime {
     memory: memory
     cpu:  cpu
     maxRetries: 1
     docker: container
     runtime_minutes: run_mins
   }
}


task stage_interleave {
   input {
        String target_reads_1="raw_reads_1.fastq.gz"
        String target_reads_2="raw_reads_2.fastq.gz"
        String output_interleaved="raw.fastq.gz"
        Array[File]  input_fastq1
        Array[File]  input_fastq2
        Int file_num = length(input_fastq1)
        String container
        Int    memory
        Int    cpu
        Int    run_mins
   }

   command <<<
       set -oeu pipefail
       
       # load wdl array to shell array
       FQ1_ARRAY=(~{sep=" " input_fastq1})
       FQ2_ARRAY=(~{sep=" " input_fastq2})
       
        for (( i = 0; i < ~{file_num}; i++ )) ;do
            fq1_name=$(basename ${FQ1_ARRAY[$i]})
            fq2_name=$(basename ${FQ2_ARRAY[$i]})
            if [ $( echo ${FQ1_ARRAY[$i]} | egrep -c "https*:") -gt 0 ] ; then
                    wget ${FQ1_ARRAY[$i]} -O $fq1_name
                    wget ${FQ2_ARRAY[$i]} -O $fq2_name
            else
                    ln -s ${FQ1_ARRAY[$i]} $fq1_name || cp ${FQ1_ARRAY[$i]} $fq1_name 
                    ln -s ${FQ2_ARRAY[$i]} $fq2_name || cp ${FQ2_ARRAY[$i]} $fq2_name
            fi
            
            cat $fq1_name  >> ~{target_reads_1}
            cat $fq2_name  >> ~{target_reads_2}
        done

        reformat.sh -Xmx~{memory}G in1=~{target_reads_1} in2=~{target_reads_2} out=~{output_interleaved}

        # Validate that the read1 and read2 files are sorted correctly
        reformat.sh -Xmx~{memory} verifypaired=t in=~{output_interleaved}

        # Capture the start time
        date --iso-8601=seconds > start.txt
    >>>

    output {
        File   reads_fastq = "~{output_interleaved}"
        String start = read_string("start.txt")
    }
   runtime {
     memory: "~{memory} GiB"
     cpu:  cpu
     maxRetries: 1
     docker: container
     runtime_minutes: run_mins
   }
}

task rqcfilter {
    input {
        File?   input_fastq
        String  container
        String  database
        String  rqcfilterdata = database + "/RQCFilterData"
        Boolean chastityfilter_flag=true
        Int     memory
        Int     xmxmem = floor(memory * 0.75)
        Int     cpu
        Int     threads = cpu * 2
        String  filename_outlog="stdout.log"
        String  filename_errlog="stderr.log"
        String  filename_stat="filtered/filterStats.txt"
        String  filename_stat2="filtered/filterStats2.txt"
        String  filename_stat_json="filtered/filterStats.json"
        String  filename_reproduce="filtered/reproduce.sh"
        String  system_cpu="$(grep \"model name\" /proc/cpuinfo | wc -l)"
        String  jvm_threads=select_first([threads,system_cpu])
        String? chastityfilter= if (chastityfilter_flag) then "cf=t" else "cf=f"
        Int     run_mins
    }

    command <<<

        export TIME="time result\ncmd:%C\nreal %es\nuser %Us \nsys  %Ss \nmemory:%MKB \ncpu %P"
        set -euo pipefail

        rqcfilter2.sh \
            ~{if (defined(memory)) then "-Xmx" + xmxmem + "G" else "-Xmx60G" }\
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
        File filtered = "filtered/raw.anqdpht.fastq.gz"
    }
    
    runtime {
        docker: container
        memory: "~{memory} GiB"
        cpu:  cpu
        runtime_minutes: run_mins
    }
}

task make_info_file {
    input {
        File   info_file
        String prefix
        String container
        String memory
        Int    cpu
        Int    run_mins
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
        memory: memory
        cpu:  cpu
        maxRetries: 1
        docker: container
        runtime_minutes: run_mins
    }
}

task finish_rqc {
    input {
        File   filtered_stats
        File   filtered_stats2
        File   filtered
        String prefix
        String container
        String memory
        Int    cpu
        Int    run_mins
    }

    command<<<

        set -oeu pipefail
        end=`date --iso-8601=seconds`
        # Generate QA objects
        ln -s ~{filtered} ~{prefix}_filtered.fastq.gz
        ln -s ~{filtered_stats} ~{prefix}_filterStats.txt
        ln -s ~{filtered_stats2} ~{prefix}_filterStats2.txt

       # Generate stats but rename some fields until the script is fixed.
       /scripts/rqcstats.py ~{filtered_stats} > ~{prefix}_qa_stats.json

    >>>

    output {
        File filtered_final = "~{prefix}_filtered.fastq.gz"
        File filtered_stats_final = "~{prefix}_filterStats.txt"
        File filtered_stats2_final = "~{prefix}_filterStats2.txt"
        File json_out = "~{prefix}_qa_stats.json"
    }
    runtime {
        docker: container
        memory: memory
        cpu:  cpu
        runtime_minutes: run_mins
    }
}
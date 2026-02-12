# Interleaved fastq QC workflow
version 1.0

workflow nmdc_rqcfilter {
    input{
        String  bbtools_container = "bryce911/bbtools:39.65"
        String  workflowmeta_container = "microbiomedata/workflowmeta:1.1.1"
        String  proj
        String  prefix=sub(proj, ":", "_")
        Array[String]  input_fastq1
        Array[String]  input_fastq2
        String  database="/refdata/"
        Boolean? chastityfilter_flag
        # runtime parameters for JAWS. All memory is GB
        Int stage_mem = 10
        Int stage_cpu = 2
        Int stage_run_mins = 30
        Int rqc_cpu = 32
        Int? rqc_threads        # typically the same as rqc_cpu
        Int rqc_mem = 180
        Int rqc_run_mins = 500
        Int json_mem = 1
        Int json_cpu = 1
        Int json_run_mins = 5
        Int make_info_mem = 1
        Int make_info_cpu = 1
        Int make_info_run_mins = 5
        Int finish_rqc_mem = 1
        Int finish_rqc_cpu = 1
        Int finish_rqc_run_mins = 5
    }

    call stage {
        input: 
            input_fastq1=input_fastq1,
            input_fastq2=input_fastq2,
            container=bbtools_container,
            memory=stage_mem,
            cpu = stage_cpu,
            run_mins = stage_run_mins
    }
    # Estimate RQC runtime at an hour per compress GB
    call rqcfilter as qc {
        input: 
            input_files=stage.interleaved_reads,
            database=database,
            chastityfilter_flag = chastityfilter_flag,
            container = bbtools_container,
            memory= rqc_mem,
            cpu = rqc_cpu,
            threads = rqc_threads,
            run_mins = rqc_run_mins
    }
    call stats_jsons {
        input:
            filtered_stats = qc.stat,
            container = workflowmeta_container,
            memory=json_mem,
            cpu = json_cpu,
            run_mins = json_run_mins
    }
    call make_info_file {
        input: 
            info_file = qc.info_file,
            prefix = prefix,
            container=workflowmeta_container,
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
            filter_json = stats_jsons.filter_stats,
            qa_json = stats_jsons.qa_stats,
            container=workflowmeta_container,
            memory=finish_rqc_mem,
            cpu = finish_rqc_cpu,
            run_mins = finish_rqc_run_mins
    }
    output {
        File filtered_final = finish_rqc.filtered_final
        File filtered_stats_final = finish_rqc.filtered_stats_final
        File filtered_stats2_final = finish_rqc.filtered_stats2_final
        File rqc_info = make_info_file.rqc_info
        File stats = finish_rqc.qa_stats_final      # renamed to match workflow automation
        File filter_json = finish_rqc.filter_json_final
    }
}

task stage {
    input{
        String target_reads_1="raw_reads_1.fastq.gz"
        String target_reads_2="raw_reads_2.fastq.gz"
        String output_interleaved="raw_interleaved.fastq.gz"
        Array[String] input_fastq1
        Array[String] input_fastq2
        Int file_num = length(input_fastq1)
        String container
        Int    memory
        Int    cpu
        Int    run_mins
    }

   command <<<
        time bash <<'EOF'
        set -euo pipefail

        # load wdl array to shell array
        FQ1_ARRAY=(~{sep=" " input_fastq1})
        FQ2_ARRAY=(~{sep=" " input_fastq2})
        
        for (( i = 0; i < ~{file_num}; i++ )) ;do
            fq1_name=$(basename ${FQ1_ARRAY[$i]})
            fq2_name=$(basename ${FQ2_ARRAY[$i]})
            if [ $( echo ${FQ1_ARRAY[$i]} | egrep -c "https*:") -gt 0 ] ; then
                wget --no-check-certificate ${FQ1_ARRAY[$i]} -O $fq1_name
                wget --no-check-certificate ${FQ2_ARRAY[$i]} -O $fq2_name
            else
                ln -s ${FQ1_ARRAY[$i]} $fq1_name || cp ${FQ1_ARRAY[$i]} $fq1_name 
                ln -s ${FQ2_ARRAY[$i]} $fq2_name || cp ${FQ2_ARRAY[$i]} $fq2_name
            fi
            
            cat $fq1_name  >> ~{target_reads_1}
            cat $fq2_name  >> ~{target_reads_2}
        done

        reformat.sh -Xmx~{memory}G in1=~{target_reads_1} in2=~{target_reads_2} out=~{output_interleaved}
        
        # Validate that the read1 and read2 files are sorted correctly
        reformat.sh -Xmx~{memory}G verifypaired=t in=~{output_interleaved}
        
        # Capture the start time
        date --iso-8601=seconds > start.txt
        EOF
    >>>

    output{
        File interleaved_reads = "~{output_interleaved}"
        String start = read_string("start.txt")
    }
    runtime {
        docker: container
        memory: "~{memory} GiB"
        cpu:  cpu
        runtime_minutes: run_mins
        maxRetries: 1
    }
}


task rqcfilter {
    input{
        File    input_files
        String  database
        String  rqcfilterdata = database + "/RQCFilterData"
        Boolean chastityfilter_flag=true
        Int     memory
        Int     xmxmem = floor(memory * 0.85)
        Int     cpu
        Int?    threads
        String  filename_outlog="stdout.log"
        String  filename_errlog="stderr.log"
        String  filename_stat="filtered/filterStats.txt"
        String  filename_stat2="filtered/filterStats2.txt"
        String  filename_reproduce="filtered/reproduce.sh"
        String  system_cpu="$(grep \"model name\" /proc/cpuinfo | wc -l)"
        String  jvm_threads=select_first([threads,cpu, system_cpu]) 
        String  chastityfilter= if (chastityfilter_flag) then "cf=t" else "cf=f"
        String  container
        Int     run_mins
    }

    command<<<
        export TIME="time result\ncmd:%C\nreal %es\nuser %Us \nsys  %Ss \nmemory:%MKB \ncpu %P"
        time bash <<'EOF'
        set -euo pipefail

        rqcfilter2.sh \
            ~{if (defined(memory)) then "-Xmx" + xmxmem + "G" else "-Xmx60G" }\
            -da \
            threads=~{jvm_threads} \
            ~{chastityfilter} \
            jni=t \
            in=~{input_files} \
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
        EOF
     >>>

    output {
        File stdout = filename_outlog
        File stderr = filename_errlog
        File stat = filename_stat
        File stat2 = filename_stat2
        File info_file = filename_reproduce
        File filtered = glob("filtered/*fastq.gz")[0]
    }
    runtime {
        docker: container
        memory: "~{memory} GiB"
        cpu:  cpu
        runtime_minutes: run_mins
        maxRetries: 1
    }
}

task stats_jsons {
    input {
        File   filtered_stats
        String filter_stats_json="filterStats.json"
        String qa_stats_json = "qa_stats.json"
        String container
        Int    memory
        Int    cpu
        Int    run_mins
    }

    command <<<
        time bash <<'EOF'
        python <<CODE
        import json
        f = open("~{filtered_stats}",'r')
        d = dict()
        for line in f:
            if not line.rstrip():
                continue
            key,value=line.rstrip().split('=')
            d[key]=float(value) if 'Ratio' in key else int(value)

        with open("~{filter_stats_json}", 'w') as outfile:
            json.dump(d, outfile, indent = 2)
        
        # rename some fields for wf automation.
        qa = {
            "input_read_bases": d['inputBases'],
            "input_read_count": d['inputReads'],
            "output_read_bases": d['outputBases']
            "output_read_count": d['outputReads'],
        }

        with open("~{qa_stats_json}", 'w') as outfile:
            json.dump(qa, outfile, indent = 2)

        CODE
        EOF
    >>>
    output {
        File filter_stats = filter_stats_json
        File qa_stats = qa_stats_json
    }
    runtime {
        docker: container
        memory: "~{memory} GiB"
        cpu:  cpu
        runtime_minutes: run_mins
        maxRetries: 1
    }
}

task make_info_file {
    input{
        File info_file
        String prefix
        String container
        Int    memory
        Int    cpu
        Int    run_mins
    }
    
    command<<<
        time bash <<'EOF'
        set -euo pipefail
        sed -n 2,5p ~{info_file} 2>&1 | \
            perl -ne 's:in=/.*/(.*) :in=$1:; s/#//; s/BBTools/BBTools(1)/; print;' > \
            ~{prefix}_readsQC.info
        echo -e "\n(1) B. Bushnell: BBTools software package, http://bbtools.jgi.doe.gov/" >> \
        ~{prefix}_readsQC.info
        EOF
    >>>

    output {
        File rqc_info = "~{prefix}_readsQC.info"
    }
    runtime {
        docker: container
        memory: "~{memory} GiB"
        cpu:  cpu
        runtime_minutes: run_mins
        maxRetries: 1
    }
}

task finish_rqc {
    input{
        File filtered_stats
        File filtered_stats2
        File filtered
        File filter_json
        File qa_json
        String prefix
        String container
        Int    memory
        Int    cpu
        Int    run_mins
    }
 
    command<<<
        time bash <<'EOF'
        set -euo pipefail
        end=`date --iso-8601=seconds`
        # Generate QA objects
        ln -s ~{filtered} ~{prefix}_filtered.fastq.gz
        ln -s ~{filtered_stats} ~{prefix}_filterStats.txt
        ln -s ~{filtered_stats2} ~{prefix}_filterStats2.txt
        ln -s ~{filter_json} ~{prefix}_filterStats.json
        ln -s ~{qa_json} ~{prefix}_qaStats.json
        EOF
    >>>
    output {
        File filtered_final = "~{prefix}_filtered.fastq.gz"
        File filtered_stats_final = "~{prefix}_filterStats.txt"
        File filtered_stats2_final = "~{prefix}_filterStats2.txt"
        File filter_json_final = "~{prefix}_filterStats.json"
        File qa_stats_final = "~{prefix}_qaStats.json"
    }

    runtime {
        docker: container
        memory: "~{memory} GiB"
        cpu:  cpu
        runtime_minutes: run_mins
        maxRetries: 1
    }
}
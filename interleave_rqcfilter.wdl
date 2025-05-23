# Interleaved fastq QC workflow
version 1.0
workflow nmdc_rqcfilter {
    input {
        String  container="bfoster1/img-omics:0.1.9"
        String  bbtools_container="microbiomedata/bbtools:38.96"
        String  workflowmeta_container="microbiomedata/workflowmeta:1.1.1"
        String  proj
        String  prefix=sub(proj, ":", "_")
        String  input_fastq1
        String  input_fastq2
        String  database="/refdata/"
        Int     rqc_mem = 180
    }

    call stage {
        input: 
            container=bbtools_container,
            memory=10,
            input_fastq1=input_fastq1,
            input_fastq2=input_fastq2
    }
    # Estimate RQC runtime at an hour per compress GB
    call rqcfilter as qc {
        input: 
            input_files=stage.interleaved_reads,
            threads=16,
            database=database,
            memory=rqc_mem,
            container = bbtools_container
    }
    call make_info_file {
        input: 
            info_file = qc.info_file,
            container=container,
            prefix = prefix
    }

    call finish_rqc {
        input: 
            container=workflowmeta_container,
            prefix = prefix,
            filtered = qc.filtered,
            filtered_stats = qc.stat,
            filtered_stats2 = qc.stat2
    }
    output {
        File filtered_final = finish_rqc.filtered_final
        File filtered_stats_final = finish_rqc.filtered_stats_final
        File filtered_stats2_final = finish_rqc.filtered_stats2_final
        File rqc_info = make_info_file.rqc_info
    }
}

task stage {
   input {
        String container
        Int    memory
        String target_reads_1="raw_reads_1.fastq.gz"
        String target_reads_2="raw_reads_2.fastq.gz"
        String output_interleaved="raw_interleaved.fastq.gz"
        String input_fastq1
        String input_fastq2
    }

   command <<<
       set -euo pipefail
       if [ $( echo ~{input_fastq1} | egrep -c "https*:") -gt 0 ] ; then
           wget ~{input_fastq1} -O ~{target_reads_1}
           wget ~{input_fastq2} -O ~{target_reads_2}
       else
           ln -s ~{input_fastq1} ~{target_reads_1} || cp ~{input_fastq1} ~{target_reads_1}
           ln -s ~{input_fastq2} ~{target_reads_2} || cp ~{input_fastq2} ~{target_reads_2}
       fi

       reformat.sh -Xmx~{memory}G in1=~{target_reads_1} in2=~{target_reads_2} out=~{output_interleaved}
       # Capture the start time
       date --iso-8601=seconds > start.txt
   >>>

   output{
      File interleaved_reads = "~{output_interleaved}"
      String start = read_string("start.txt")
   }

   runtime {
     memory: "~{memory} GiB"
     cpu:  2
     maxRetries: 1
     docker: container
   }
}


task rqcfilter {
    input {
        File    input_files
        String  container
        String  database
        String  rqcfilterdata = database + "/RQCFilterData"
        Boolean chastityfilter_flag=true
        Int     memory
        Int     xmxmem = floor(memory * 0.75)
        Int?    threads
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

    command <<<
        export TIME="time result\ncmd:%C\nreal %es\nuser %Us \nsys  %Ss \nmemory:%MKB \ncpu %P"
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

    runtime {
        docker: container
        memory: "~{memory} GiB"
        cpu:  16
    }
}

task make_info_file {
    input {
        File info_file
        String prefix
        String container
    }
    
    command<<<
        set -euo pipefail
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
        # File read
        File filtered_stats
        File filtered_stats2
        File filtered
        String container
        String prefix
        # String start
    }
 
    command<<<

        set -euo pipefail
        end=`date --iso-8601=seconds`
        # Generate QA objects
        ln -s ~{filtered} ~{prefix}_filtered.fastq.gz
        ln -s ~{filtered_stats} ~{prefix}_filterStats.txt
        ln -s ~{filtered_stats2} ~{prefix}_filterStats2.txt

       # Generate stats but rename some fields untilt the script is
       # fixed.
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

# LongReadsQC workflow
## input can be .bam or .fq or .fq.gz
## output fq.gz
version 1.0

workflow LongReadsQC {
    input {
        String  file    
        String  proj
        String  prefix=sub(proj, ":", "_")    
        String  log_level='INFO'
        Boolean rmdup = true
        Boolean overwrite = true
        File?   reference
        String  pbmarkdup_container="microbiomedata/pbmarkdup:1.1"
        String  bbtools_container="microbiomedata/bbtools:39.03"
        String  workflowmeta_container = "microbiomedata/workflowmeta:1.1.1"
        # String  outdir 
        # String  prefix = basename(file)
        Int stage_mem = 1
        Int stage_cpu = 2
        Int stage_run_mins = 30
        Int pbmarkdup_mem = 32
        Int pbmarkdup_cpu = 4
        Int pbmarkdup_run_mins = 300
        Int icecream_mem = 16
        Int icecream_cpu = 2
        Int icecream_run_mins = 300
        Int bbdukEnds_mem = 32
        Int bbdukEnds_cpu = 4
        Int bbdukEnds_run_mins = 300
        Int bbdukReads_mem = 32
        Int bbdukReads_cpu = 4
        Int bbdukReads_run_mins = 300
        Int make_info_mem = 1
        Int make_info_cpu = 1
        Int make_info_run_mins = 5
        Int finish_rqc_mem = 1
        Int finish_rqc_cpu = 1
        Int finish_rqc_run_mins = 5
    }

    call stage_longread {
        input:
            file = file,
            container = workflowmeta_container,
            memory=stage_mem,
            cpu = stage_cpu,
            run_mins = stage_run_mins
    }

    call pbmarkdup {
        input:
            in_file = stage_longread.reads_fastq,
            prefix = prefix,
            # outdir = outdir,
            log_level = log_level,
            rmdup = rmdup,
            container = pbmarkdup_container,
            overwrite = overwrite,
            memory=pbmarkdup_mem,
            cpu = pbmarkdup_cpu,
            run_mins = pbmarkdup_run_mins
        }

    call icecreamfilter {
        input:
            in_file = pbmarkdup.out_fastq,
            prefix = prefix,
            container = bbtools_container,
            memory=icecream_mem,
            cpu = icecream_cpu,
            run_mins = icecream_run_mins
            # outdir = outdir
    }

    call bbdukEnds {
        input:
            in_file = icecreamfilter.output_good,
            prefix = prefix,
            container = bbtools_container,
            # outdir = outdir,
            reference = reference,
            memory=bbdukEnds_mem,
            cpu = bbdukEnds_cpu,
            run_mins = bbdukEnds_run_mins
    }

    call bbdukReads {
        input:
            in_file = bbdukEnds.out_fastq,
            prefix = prefix,
            container = bbtools_container,
            # outdir = outdir,
            reference = reference,
            memory=bbdukReads_mem,
            cpu = bbdukReads_cpu,
            run_mins = bbdukReads_run_mins
    }

    call make_info_file {
        input:
            prefix = prefix,
            container=bbtools_container, 
            pbmarkdup_log = pbmarkdup.stats,
            memory=make_info_mem,
            cpu = make_info_cpu,
            run_mins = make_info_run_mins
    }

    call finish_rqc {
        input: 
            container = workflowmeta_container,
            prefix = prefix,
            filtered = bbdukReads.out_fastq,
            pbmarkdup_stats = pbmarkdup.stats,
            icecream_stats = icecreamfilter.stats,
            bbdukEnds_stats = bbdukEnds.stats,
            bbdukReads_stats = bbdukReads.stats,
            input_stats = flatten(pbmarkdup.input_stats),
            output_stats = flatten(bbdukReads.output_stats),
            memory=finish_rqc_mem,
            cpu = finish_rqc_cpu,
            run_mins = finish_rqc_run_mins
    }

    output {
        File rqc_info = make_info_file.rqc_info
        File filtered_final = finish_rqc.filtered_final
        File filtered_stats1 = finish_rqc.filtered_stats1_final
        File filtered_stats2 = finish_rqc.filtered_stats2_final
        File stats = finish_rqc.stats
        # File filter_stat_json = finish_rqc.json_out
    }

}

task stage_longread {
    input{
        String container
        String target="raw.fastq.gz"
        String file
        Int    memory
        Int    cpu
        Int    run_mins
    }

    command <<<
        time bash <<'EOF'
        set -oeu pipefail

        temp=$(basename "~{file}")

        if [ $(echo "~{file}" | egrep -c "https*:") -gt 0 ] ; then
            wget "~{file}" -O "$temp"
        else
            ln -s "~{file}" "$temp" || cp "~{file}" "$temp"
        fi
        ln -sf "$temp" "~{target}" || cp "$temp" "~{target}"

        # Capture the start time
        date --iso-8601=seconds > start.txt
        EOF
    >>>

    output{
        File reads_fastq = "~{target}"
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

task pbmarkdup {
    input {
        File   in_file
        String   prefix
        String   out_file = prefix + ".pbmarkdup.fq"
        String?  log_level
        Boolean? rmdup
        Boolean? overwrite
        String   container
        # String   outdir
        # String   out_file = outdir + "/pbmarkdup.fq"
        Int    memory
        Int    cpu
        Int    run_mins
    }

    command <<<
        time bash <<'EOF'
        set -oeu pipefail
        # mkdir -m 755 -p ~{"outdir"}
        pbmarkdup --version 
        pbmarkdup \
        ~{if (defined(log_level)) then "--log-level " + log_level else  "--log-level INFO"  } \
        ~{true="--rmdup" false="" rmdup} \
        ~{true="--clobber" false="" overwrite} \
        ~{in_file} \
        ~{out_file}

        gzip ~{out_file}
        #echo -e "inputReads\tinputBases" > input_size.txt
        seqtk size ~{in_file} > input_size.txt
        EOF
    >>>

    output {
        File out_fastq = "~{out_file}.gz"
        File outlog = 'stderr'
        File stats = 'stdout'
        Array[Array[String]] input_stats = read_tsv("input_size.txt")      }

    runtime {
        docker: container
        memory: "~{memory} GiB"
        cpu:  cpu
        runtime_minutes: run_mins
        continueOnReturnCode: true
        maxRetries: 1
    }
}


task icecreamfilter {
    input {
        File   in_file
        String prefix
        String out_bad = prefix + ".icecreamfilter.out_bad.out.gz"
        String out_good = prefix + ".icecreamfilter.out_good.out.gz"
        String container
        # String outdir
        # String out_bad = outdir + "/" + prefix + ".icecreamfilter.out_bad.out.gz"
        # String out_good = outdir + "/" + prefix + ".icecreamfilter.out_good.out.gz"
        Int    memory
        Int    cpu
        Int    run_mins
    }

    command <<<
        time bash <<'EOF'
        set -oeu pipefail
        icecreamfinder.sh \
            jni=t \
            json=t \
            ow=t \
            cq=f \
            keepshortreads=f \
            trim=f \
            ccs=t \
            stats=triangle.json \
            ~{"in=" + in_file} \
            ~{"out=" + out_good} \
            ~{"outb=" + out_bad} 
        EOF
    >>>

    output {
        File output_good = "~{out_good}"
        File output_bad = "~{out_bad}"
        File stats = "triangle.json"
    }
    runtime {
        docker: container
        memory: "~{memory} GiB"
        cpu:  cpu
        runtime_minutes: run_mins
        continueOnReturnCode: true
        maxRetries: 1
    }
}

task bbdukEnds {
    input {
        File?  reference
        File   in_file
        String prefix
        String out_file = prefix + ".bbdukEnds.out.fq.gz"
        String container
        # String outdir
        # String out_file = outdir + "/" + prefix + ".bbdukEnds.out.fq.gz"
        Int    memory
        Int    cpu
        Int    run_mins
    }

    command <<<
        time bash <<'EOF'
        set -oeu pipefail
        # bbduk - trim out adapter from read ends
        bbduk.sh \
            k=20 \
            mink=12 \
            edist=1 \
            mm=f \
            ktrimtips=60 \
            json=t \
            ~{if (defined(reference)) then "ref=" + reference else "ref=/bbmap/resources/PacBioAdapter.fa" } \
            ~{"in=" + in_file} \
            ~{"out=" + out_file} 
        
        grep -v _JAVA_OPTIONS stderr | grep -v 'Changed from' > bbdukEnds_stats.json
        EOF
    >>>

    output {
        File out_fastq = "~{out_file}"
        File stats = "bbdukEnds_stats.json"
    }

    runtime {
        docker: container
        memory: "~{memory} GiB"
        cpu:  cpu
        runtime_minutes: run_mins
        continueOnReturnCode: true
        maxRetries: 1
    }
}

task bbdukReads {
    input {
        File?  reference
        File   in_file
        String prefix
        String out_file = prefix + ".filtered.fq.gz"
        String container
        # String outdir
        # String out_file = outdir + "/" + prefix + ".filtered.fq.gz"
        Int    memory
        Int    cpu
        Int    run_mins
    }

    command <<<
        time bash <<'EOF'
        set -oeu pipefail
        # bbduk - removes reads that still contain adapter sequence
        bbduk.sh \
            k=24 \
            edist=1 \
            mm=f \
            json=t \
            ~{if (defined(reference)) then "ref=" + reference else "ref=/bbmap/resources/PacBioAdapter.fa" } \
            ~{"in=" + in_file} \
            ~{"out=" + out_file} 

        grep -v _JAVA_OPTIONS stderr | grep -v 'Changed from' > bbdukReads_stats.json

        #echo -e "outputReads\toutputBases" > output_size.txt
        seqtk size ~{out_file} > output_size.txt
        EOF
    >>>

    output {
        File out_fastq = "~{out_file}"
        File stats = "bbdukReads_stats.json" 
        Array[Array[String]] output_stats = read_tsv("output_size.txt")
    }

    runtime {
        docker: container
        memory: "~{memory} GiB"
        cpu:  cpu
        runtime_minutes: run_mins
        continueOnReturnCode: true
        maxRetries: 1
    }
}

task make_info_file {
    input {
        String prefix
        String container
        File pbmarkdup_log
        Int    memory
        Int    cpu
        Int    run_mins
    }

    command <<<
        time bash <<'EOF'
        set -oeu pipefail

        bbtools_version=$(grep "Version" /bbmap/README.md | sed 's/#//')
        pbmarkdup_version=$(grep "pbmarkdup" ~{pbmarkdup_log})

        echo -e "Long Reads QC Workflow - Info File" > ~{prefix}_readsQC.info
        echo -e "This workflow performs QC on PacBio metagenome sequencing files and produces filtered fastq files and statistics using the following tools and Docker containers" >> ~{prefix}_readsQC.info
        echo -e "The file first runs through ${pbmarkdup_version} (https://github.com/PacificBiosciences/pbmarkdup) to remove duplicate reads." >> ~{prefix}_readsQC.info
        echo -e "The files are then filtered for inverted repeats using icecreamfinder.sh (BBTools(1)${bbtools_version}) before trimming adapters from read ends using bbduk.sh (BBTools(1)${bbtools_version})." >> ~{prefix}_readsQC.info
        echo -e "Reads are run through bbduk.sh (BBTools(1)${bbtools_version}) a second time to remove any reads still containing adapter sequences." >> ~{prefix}_readsQC.info

        echo -e "\n(1) B. Bushnell: BBTools software package, http://bbtools.jgi.doe.gov/" >> ~{prefix}_readsQC.info
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
    input {
        File   pbmarkdup_stats
        File   icecream_stats
        File   bbdukEnds_stats
        File   bbdukReads_stats
        Array[String] input_stats
        Array[String]  output_stats
        File   filtered
        String container
        String prefix
        Int    memory
        Int    cpu
        Int    run_mins
    }
    # changed order to match wf automation
    Map [String, Int] stats_map = { 
                            "input_read_bases" : input_stats[1],
                            "input_read_count" : input_stats[0], 
                            "output_read_bases" : output_stats[1],
                            "output_read_count" : output_stats[0]
                        } 
    File stats_json = write_json(stats_map)

    command<<<
        time bash <<'EOF'
        set -oeu pipefail
        #end=$(date --iso-8601=seconds)
        # Generate QA objects
        ln -s ~{filtered} ~{prefix}_filtered.fastq.gz
        ln -s ~{pbmarkdup_stats} ~{prefix}_pbmarkdupStats.txt
        ln -s ~{icecream_stats} ~{prefix}_icecreamStats.json
        ln -s ~{bbdukEnds_stats} ~{prefix}_bbdukEndsStats.json
        ln -s ~{bbdukReads_stats} ~{prefix}_bbdukReadsStats.json
        
        sed -re 's/:"([0-9]+)"/:\1/g' ~{stats_json} | jq . > ~{prefix}_stats.json
        # jq version 1.5-1-a5b5cbe needs to be called with default filter options "."
        
        DUP=`grep TOTAL ~{prefix}_pbmarkdupStats.txt | awk  '{print $5}'`
        INVERTED=`jq .Reads_Filtered ~{prefix}_icecreamStats.json`
        ADAPTER1=`jq .readsRemoved ~{prefix}_bbdukEndsStats.json`
        ADAPTER2=`jq .readsRemoved ~{prefix}_bbdukReadsStats.json`
        jq ".Input=.input_read_count | del(.input_read_count, .input_read_bases) | .Output=.output_read_count | del(.output_read_count, .output_read_bases) | .Duplication=$DUP | .Inverted=$INVERTED | .Adapter=$ADAPTER1+$ADAPTER2 "  ~{prefix}_stats.json > ~{prefix}_filterStats2.json
        EOF
    >>>

    output {
        File filtered_final = "~{prefix}_filtered.fastq.gz"
        File filtered_stats1_final = "~{prefix}_pbmarkdupStats.txt"
        File filtered_stats2_final = "~{prefix}_filterStats2.json"
        File stats = "~{prefix}_stats.json"
    }

    runtime {
        docker: container
        memory: "~{memory} GiB"
        cpu:  cpu
        runtime_minutes: run_mins
        maxRetries: 1
    }
}
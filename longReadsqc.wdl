# LongReadsQC workflow
## input can be .bam or .fq or .fq.gz
## output fq.gz
version 1.0

workflow LongReadsQC {
    input {
        File  file    
        String  proj
        String  prefix=sub(proj, ":", "_")    
        String  log_level='INFO'
        Boolean rmdup = true
        Boolean overwrite = true
        File?   reference
        String  pbmarkdup_container="microbiomedata/pbmarkdup:1.1"
        String  bbtools_container="microbiomedata/bbtools:39.03"
        String  jq_container="microbiomedata/jq:1.6"
        # String  outdir 
        # String  prefix = basename(file)
    }

    call pbmarkdup {
        input: 
            in_file = file,
            prefix = prefix,
            # outdir = outdir,
            log_level = log_level,
            rmdup = rmdup,
            container = pbmarkdup_container,
            overwrite = overwrite
    }

    call icecreamfilter {
        input:
            in_file = pbmarkdup.out_fastq,
            prefix = prefix,
            container = bbtools_container
            # outdir = outdir
    }

    call bbdukEnds {
        input:
            in_file = icecreamfilter.output_good,
            prefix = prefix,
            container = bbtools_container,
            # outdir = outdir,
            reference = reference
    }

    call bbdukReads {
        input:
            in_file = bbdukEnds.out_fastq,
            prefix = prefix,
            container = bbtools_container,
            # outdir = outdir,
            reference = reference
    }

    call make_info_file {
        input:
            prefix = prefix,
            bbtools_container=bbtools_container, 
            pbmarkdup_log = pbmarkdup.outlog
    }

    call finish_rqc {
        input: 
            container = jq_container,
            prefix = prefix,
            filtered = bbdukReads.out_fastq,
            pbmarkdup_stats = pbmarkdup.stats,
            icecream_stats = icecreamfilter.stats,
            bbdukEnds_stats = bbdukEnds.stats,
            bbdukReads_stats = bbdukReads.stats,
            input_stats = flatten(pbmarkdup.input_stats),
            output_stats = flatten(bbdukReads.output_stats)
    }

    output {
        File rqc_info = make_info_file.rqc_info
        File filtered_final = finish_rqc.filtered_final
        File filtered_stats1 = finish_rqc.filtered_stats1_final
        File filtered_stats2 = finish_rqc.filtered_stats2_final
        File filtered_stats3 = finish_rqc.filtered_stats3_final
        File filtered_stats4 = finish_rqc.filtered_stats4_final
        File stats = finish_rqc.stats
        # File filter_stat_json = finish_rqc.json_out
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
    }

    command <<<

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

    >>>

    output {
        File out_fastq = "~{out_file}.gz"
        File outlog = stdout()
        File stats = stderr()
        Array[Array[String]] input_stats = read_tsv("input_size.txt")  
    }

    runtime {
        docker: container
        continueOnReturnCode: true
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
    }

    command <<<

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

    >>>

    output {
        File output_good = "~{out_good}"
        File output_bad = "~{out_bad}"
        File stats = "triangle.json"
    }

    runtime {
        docker: container
        continueOnReturnCode: true
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
    }

    command <<<

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

    >>>

    output {
        File out_fastq = "~{out_file}"
        File stats = "stderr"
    }

    runtime {
        docker: container
        continueOnReturnCode: true
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
    }

    command <<<

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

        #echo -e "outputReads\toutputBases" > output_size.txt
        seqtk size ~{out_file} > output_size.txt
    >>>

    output {
        File out_fastq = "~{out_file}"
        File stats = "stderr" 
        Array[Array[String]] output_stats = read_tsv("output_size.txt")
    }

    runtime {
        docker: container
        continueOnReturnCode: true
    }
}

task make_info_file {
    input {
        String prefix
        String bbtools_container
        File pbmarkdup_log
    }

    command <<<

        set -oeu pipefail

        bbtools_version=$(grep "Version" /bbmap/README.md | sed 's/#//')
        pbmarkdup_version=$(grep "pbmarkdup" ~{pbmarkdup_log})

        echo -e "Long Reads QC Workflow - Info File" > ~{prefix}_readsQC.info
        echo -e "This workflow performs QC on PacBio metagenome sequencing files and produces filtered fastq files and statistics using the following tools and Docker containers" >> ~{prefix}_readsQC.info
        echo -e "The file first runs through ${pbmarkdup_version} (https://github.com/PacificBiosciences/pbmarkdup) to remove duplicate reads." >> ~{prefix}_readsQC.info
        echo -e "The files are then filtered for inverted repeats using icecreamfinder.sh (BBTools(1)${bbtools_version}) before trimming adapters from read ends using bbduk.sh (BBTools(1)${bbtools_version})." >> ~{prefix}_readsQC.info
        echo -e "Reads are run through bbduk.sh (BBTools(1)${bbtools_version}) a second time to remove any reads still containing adapter sequences." >> ~{prefix}_readsQC.info

        echo -e "\n(1) B. Bushnell: BBTools software package, http://bbtools.jgi.doe.gov/" >> ~{prefix}_readsQC.info

    >>>

    output {
        File rqc_info = "~{prefix}_readsQC.info"
    }

    runtime {
        memory: "1 GiB"
        cpu:  1
        maxRetries: 1
        docker: bbtools_container
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
    }
    Map [String, Int] stats_map = { 
                            "input_read_count" : input_stats[0], 
                            "input_read_bases" : input_stats[1],
                            "output_read_count" : output_stats[0],
                            "output_read_bases" : output_stats[1]
                        }
    File stats_json = write_json(stats_map)

    command<<<

        set -oeu pipefail
        #end=$(date --iso-8601=seconds)
        # Generate QA objects
        ln -s ~{filtered} ~{prefix}_filtered.fastq.gz
        ln -s ~{pbmarkdup_stats} ~{prefix}_pbmarkdupStats.txt
        ln -s ~{icecream_stats} ~{prefix}_icecreamStats.json
        ln -s ~{bbdukEnds_stats} ~{prefix}_bbdukEndsStats.json
        ln -s ~{bbdukReads_stats} ~{prefix}_bbdukReadsStats.json
        sed -re 's/:"([0-9]+)"/:\1/g' ~{stats_json} | jq > ~{prefix}_stats.json
        
    >>>

    output {
        File filtered_final = "~{prefix}_filtered.fastq.gz"
        File filtered_stats1_final = "~{prefix}_pbmarkdupStats.txt"
        File filtered_stats2_final = "~{prefix}_icecreamStats.json"
        File filtered_stats3_final = "~{prefix}_bbdukEndsStats.json"
        File filtered_stats4_final = "~{prefix}_bbdukReadsStats.json"
        File stats = "~{prefix}_stats.json"
    }

    runtime {
        docker: container
        memory: "1 GiB"
        cpu:  1
    }
}
workflow jgi_rqcfilter {
    Array[File] input_files
    String? outdir
    String bbtools_container="microbiomedata/bbtools:38.90"
    String database="/refdata"
    String? memory
    String? threads

    scatter(file in input_files) {
        call rqcfilter{
             input:  input_file=file,
                     container=bbtools_container,
                     database=database,
                     memory=memory,
                     threads=threads
        }
    }

    # rqcfilter.stat implicit as Array because of scatter 
    call make_output {
       	input: outdir= outdir, rqcfilter_output=rqcfilter.stat
    }

    output{
        Array[File] clean_fastq_files = make_output.fastq_files
    }
    
    parameter_meta {
        input_files: "illumina paired-end interleaved fastq files"
	outdir: "The final output directory path"
        database : "database path to RQCFilterData directory"
        clean_fastq_files: "after QC fastq files"
        memory: "optional for jvm memory for bbtools, ex: 32G"
        threads: "optional for jvm threads for bbtools ex: 16"
    }
    meta {
        author: "Chienchi Lo, B10, LANL"
        email: "chienchi@lanl.gov"
        version: "1.0.2"
    }
}

task rqcfilter {
     File input_file
     String container
     String database
     String? memory
     String? threads
     String filename_outlog="stdout.log"
     String filename_errlog="stderr.log"
     String filename_stat="filtered/filterStats.txt"
     String filename_stat2="filtered/filterStats2.txt"
     String filename_stat_json="filtered/filterStats.json"
     String system_cpu="$(grep \"model name\" /proc/cpuinfo | wc -l)"
     String jvm_threads=select_first([threads,system_cpu])
     runtime {
            docker: container
            mem: memory
            database: database
     }

     command<<<
        #sleep 30
        export TIME="time result\ncmd:%C\nreal %es\nuser %Us \nsys  %Ss \nmemory:%MKB \ncpu %P"
        set -eo pipefail
        rqcfilter2.sh -Xmx${default="105G" memory} threads=${jvm_threads} jni=t in=${input_file} path=filtered rna=f trimfragadapter=t qtrim=r trimq=0 maxns=3 maq=3 minlen=51 mlf=0.33 phix=t removehuman=t removedog=t removecat=t removemouse=t khist=t removemicrobes=t sketch kapa=t clumpify=t tmpdir= barcodefilter=f trimpolyg=5 usejni=f rqcfilterdata=/databases/RQCFilterData  > >(tee -a ${filename_outlog}) 2> >(tee -a ${filename_errlog} >&2)

        python <<CODE
        import json
        f = open("${filename_stat}",'r')
        d = dict()
        for line in f:
            if not line.rstrip():continue
            key,value=line.rstrip().split('=')
            d[key]=float(value) if 'Ratio' in key else int(value)

        with open("${filename_stat_json}", 'w') as outfile:
            json.dump(d, outfile)
        CODE
     >>>
     output {
            File stdout = filename_outlog
            File stderr = filename_errlog
            File stat = filename_stat
            File stat2 = filename_stat2
     }
}

task make_output{
 	String outdir
	Array[String] rqcfilter_output
	String dollar ="$"
 
 	command<<<
			for i in ${sep=' ' rqcfilter_output}
			do
				rqcfilter_path=`dirname $i`
				f=${dollar}(basename $rqcfilter_path/*.anqdpht*)
				prefix=${dollar}{f%.anqdpht*}
				mkdir -p ${outdir}/$prefix
				cp -f $rqcfilter_path/* ${outdir}/$prefix/
				rm -f $rqcfilter_path/*
				echo ${outdir}/$prefix/$f
			done
 			chmod 764 -R ${outdir}
 	>>>
	runtime {
            mem: "1 GiB"
            cpu:  1
        }
	output{
		Array[String] fastq_files = read_lines(stdout())
	}
}


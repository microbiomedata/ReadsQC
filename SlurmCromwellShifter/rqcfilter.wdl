workflow jgi_rqcfilter {
    Array[File] input_files
    String? outdir
    String bbtools_container="microbiomedata/bbtools:38.44"
    String database="/global/cfs/projectdirs/m3408/aim2/database"

    scatter(file in input_files) {
        call rqcfilter{
             input:  input_file=file, container=bbtools_container, database=database
        }
    }
  
    # rqcfilter.stat implicit as Array because of scatter 
    call make_output {
       	input: outdir= outdir, rqcfilter_output=rqcfilter.stat
    }

}

task rqcfilter {
     File input_file
     String container
     String database
     String filename_outlog="stdout.log"
     String filename_errlog="stderr.log"
     String filename_stat="filtered/filterStats.txt"
     String filename_stat2="filtered/filterStats2.txt"
     String dollar="$"
     runtime {
            backend: "Local"
            docker: container
            memory: "120 GiB"
	    cpu:  16
            database: database
     }

     command {
        #sleep 30
        export TIME="time result\ncmd:%C\nreal %es\nuser %Us \nsys  %Ss \nmemory:%MKB \ncpu %P"
        set -eo pipefail
        rqcfilter2.sh -Xmx105g threads=${dollar}(grep "model name" /proc/cpuinfo | wc -l) jni=t in=${input_file} path=filtered rna=f trimfragadapter=t qtrim=r trimq=0 maxns=3 maq=3 minlen=51 mlf=0.33 phix=t removehuman=t removedog=t removecat=t removemouse=t khist=t removemicrobes=t sketch kapa=t clumpify=t tmpdir= barcodefilter=f trimpolyg=5 usejni=f rqcfilterdata=/databases/RQCFilterData  > >(tee -a ${filename_outlog}) 2> >(tee -a ${filename_errlog} >&2)
     }
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
 
 	command{
			for i in ${sep=' ' rqcfilter_output}
			do
				rqcfilter_path=`dirname $i`
				prefix=$(basename $rqcfilter_path/*.anqdpht.fastq.gz .anqdpht.fastq.gz)
 				mkdir -p ${outdir}/$prefix
				mv -f $rqcfilter_path/* ${outdir}/$prefix
			done
 			chmod 764 -R ${outdir}
 	}
}


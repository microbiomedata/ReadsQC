  String? memory="60G"
  String? threads="8"
  String  url="https://portal.nersc.gov/cfs/m3408/test_data/Ecoli_10x-int.fastq.gz"
  String  ref_json="https://raw.githubusercontent.com/microbiomedata/ReadsQC/master/test/small_test_filterStats.json"
```
## Docker contianers can be found here:
Bbtools: [microbiomedata/bbtools:38.44](https://hub.docker.com/r/microbiomedata/bbtools)
Comparjson: [microbiomedata/comparejson](https://hub.docker.com/r/microbiomedata/comparejson)

## Running Testing Validation Workflow

The command for running test validation is similar to that found in the submit.sh file, with the exception of switching out rqcfilter.wdl for rqc_test.wdl.

 - `rqc_test.wdl` file: the WDL file for workflow definition
 - `input.json` file: the test input for the workflow
 - `cromwell.conf` file: the conf file for running Cromwell.
 -  `cromwell.jar` file: the jar file for running Cromwell.
 -  `metadata_out.json` file: file collects run data, will be created after run of command
 
Example:
```
java -Dconfig.file=cromwell.conf -jar cromwell.jar run -m metadata_out.json -i input.json rqc_test.wdl
```

## Validation Metric
Validation metric is determined through a printed command line statement that will read:
```
"test.validate.result": ["No differences detected: test validated"]
```
or 
```
"test.validate.result": ["Test Failed"]
```

If test fails, please check inputs or contact local system administrators to ensure there are no system issues causing discrepency in results. 

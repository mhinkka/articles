#!/bin/bash
#Usage: test.sh <frameworks to test> <test names> <number of events> <run name> <number of repeats>
#Example: . test.sh "presto hive postgresql impala spark spark-caching" "flows" "100000 1000000 10000000 100000000" test 3

export HDFS_NAMENODE_URL=hdfs://10.0.207.57:8020
export IMPALA_DAEMON_ADDRESS=10.0.192.216:21000
export HIVE_DATABASE_URL=jdbc:hive2://localhost:10000

processTemplate()
{
  templateFile=$1
  outputFile=$2
  rm -f $outputFile
  sed < $templateFile > $outputFile \
   "/\${TEST/ {
      s:\${TEST_ROOT}:$TEST_ROOT:
      s:\${TEST_FRAMEWORK_ROOT}:$PWD:
      s:\${TEST_DATA_FILE}:$TEST_DATA_FILE:
      s:\${TEST_DATA_HDFS_PATH}:$TEST_DATA_HDFS_PATH:
      s:\${TEST_TEMP_RESULT_PATH}:$TEMP_FRAMEWORK_RESULT_PATH:
      s:\${TEST_RESULT_PATH}:$RESULT_PATH/results:
   }"
}

printfWithTime()
{
     printf "$(date --rfc-3339=seconds) \t$@\n"
}


set -x

export TEST_FRAMEWORKS=$1
if [ -z "$1" ]; then
  export TEST_FRAMEWORKS="postgresql"
fi

export ALL_TEST_NAMES=$2
if [ -z "$2" ]; then
  export ALL_TEST_NAMES="flows"
fi

export ALL_NUM_EVENTS=$3
if [ -z "$3" ]; then
  export ALL_NUM_EVENTS="100"
fi

export RUN_NAME=$4
if [ -z "$4" ]; then
  export RUN_NAME="unnamed"
fi

export NUM_REPEATS=$5
if [ -z "$5" ]; then
  export NUM_REPEATS=1
fi

for testName in $ALL_TEST_NAMES; do
    export TEST_NAME=$testName
    
    for numEvents in $ALL_NUM_EVENTS; do
	export NUM_EVENTS=$numEvents

	export ROOT_RESULT_PATH=$TEST_ROOT/results/$RUN_NAME-$TEST_NAME-$NUM_EVENTS
	export MEASUREMENT_RESULTS_FILE=$ROOT_RESULT_PATH/measurements.txt
	export TEMP_RESULT_PATH=/tmp/results
	export TEST_DATA_FILE=$ROOT_RESULT_PATH/test.csv

	rm -fr $ROOT_RESULT_PATH
	mkdir -p $ROOT_RESULT_PATH
	sudo rm -fr $TEMP_RESULT_PATH
	mkdir -p $TEMP_RESULT_PATH
	sudo chmod 777 $TEMP_RESULT_PATH
	
	printfWithTime "Copying test data consisting of $NUM_EVENTS events."
	head -$NUM_EVENTS $TEST_ROOT/testdata/test.csv > $TEST_DATA_FILE

	touch $MEASUREMENT_RESULTS_FILE
	sudo chmod a+w $MEASUREMENT_RESULTS_FILE

	printfWithTime "Running test named: $testName" >> $MEASUREMENT_RESULTS_FILE
	printfWithTime "Number of events: $numEvents\n" >> $MEASUREMENT_RESULTS_FILE

	frameworkId=0
	for framework in $TEST_FRAMEWORKS; do
	    frameworkId=$(($frameworkId + 1))
	    
	    printfWithTime "Starting to test framework: $framework (id: $frameworkId) at $(date --rfc-3339=seconds)"
	    
	    export RESULT_FRAMEWORK_DIRECTORY_NAME=$framework-$frameworkId
	    export TEMP_FRAMEWORK_RESULT_PATH=$TEMP_RESULT_PATH/$RESULT_FRAMEWORK_DIRECTORY_NAME
	    export RESULT_PATH=$ROOT_RESULT_PATH/$RESULT_FRAMEWORK_DIRECTORY_NAME
	    mkdir -p $RESULT_PATH
	    mkdir -p $TEMP_FRAMEWORK_RESULT_PATH
	    sudo chmod 777 $TEMP_FRAMEWORK_RESULT_PATH

	    printfWithTime "Starting testing framework: $framework (id: $frameworkId)" | tee -a $MEASUREMENT_RESULTS_FILE

	    case "$framework" in
		hive)
		    (cd hive && . ./test.sh) 2>&1 | tee $RESULT_PATH/log.txt
		    ;;
		postgresql)
		    (cd postgresql && . ./test.sh) 2>&1 | tee $RESULT_PATH/log.txt
		    ;;
		spark)
		    (cd spark && . ./test.sh my.Tester) 2>&1 | tee $RESULT_PATH/log.txt
		    ;;
		spark-parquet)
		    (cd spark && . ./test.sh my.TesterParquet) 2>&1 | tee $RESULT_PATH/log.txt
		    ;;
		spark-caching)
		    (cd spark && . ./test.sh my.TesterCaching 1) 2>&1 | tee $RESULT_PATH/log.txt
		    ;;
		impala)
		    (cd impala && . ./test.sh) 2>&1 | tee $RESULT_PATH/log.txt
		    ;;
		presto)
		    (cd presto && . ./test.sh) 2>&1 | tee $RESULT_PATH/log.txt
		    ;;
	    esac;

	    sudo rm -fr $TEMP_FRAMEWORK_RESULT_PATH
	    printfWithTime "Finished testing framework: $framework\n" >> $MEASUREMENT_RESULTS_FILE
	done;
	sudo rm -f $TEST_DATA_FILE
    done;
done;

set +x

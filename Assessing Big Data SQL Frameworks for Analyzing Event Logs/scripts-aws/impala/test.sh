#!/bin/bash

runScript()
{
    scriptFile=$1
    testId=$2
    generatedScriptFile=$RESULT_SCRIPT_PATH/$(basename $scriptFile)
    processTemplate $scriptFile $generatedScriptFile

    if [ -z "$testId" ]; then
	sudo -u ubuntu time -f "$(date --rfc-3339=seconds) \tElapsed: %E" -o $MEASUREMENT_RESULTS_FILE -a impala-shell -i $IMPALA_DAEMON_ADDRESS -f $generatedScriptFile
    else
	mkdir -p $RESULT_PATH/run-$testId/
	touch $RESULT_PATH/run-$testId/result.csv
	sudo -u ubuntu time -f "$(date --rfc-3339=seconds) \tElapsed: %E" -o $MEASUREMENT_RESULTS_FILE -a impala-shell -i $IMPALA_DAEMON_ADDRESS -f $generatedScriptFile -o $RESULT_PATH/run-$testId/result.csv

	if [[ -n $(find $RESULT_PATH/run-$testId/result.csv -size -10c) ]]; then
	    echo "TEST FAILED!" >> $MEASUREMENT_RESULTS_FILE
	fi
    fi
}

RESULT_SCRIPT_PATH=$RESULT_PATH/script
SCRIPT_PATH=$PWD/script
TEST_DATA_HDFS_PATH=/tmp/impala-test

mkdir -p $RESULT_SCRIPT_PATH

printfWithTime "Loading data..." >> $MEASUREMENT_RESULTS_FILE
sudo -u ubuntu hdfs dfs -mkdir -p $TEST_DATA_HDFS_PATH
sudo -u hdfs hdfs dfs -rm -f $TEST_DATA_HDFS_PATH/impala-test.csv
sudo -u ubuntu time -f "$(date --rfc-3339=seconds) \tElapsed: %E" -o $MEASUREMENT_RESULTS_FILE -a hdfs dfs -copyFromLocal $TEST_DATA_FILE $TEST_DATA_HDFS_PATH/impala-test.csv
runScript $SCRIPT_PATH/load.sql

printfWithTime "Performing warm-up run..." >> $MEASUREMENT_RESULTS_FILE
runScript $SCRIPT_PATH/$TEST_NAME.sql warmup

printfWithTime "Performing tests..." >> $MEASUREMENT_RESULTS_FILE
for ((i=1; i<=$NUM_REPEATS; i++ ))
do
    printfWithTime "Starting $framework test #$i..."
    runScript $SCRIPT_PATH/$TEST_NAME.sql $i
    printfWithTime "Finished $framework test #$i."
done;


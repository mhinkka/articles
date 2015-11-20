#!/bin/bash

runScript()
{
    scriptFile=$1
    testId=$2
    generatedScriptFile=$RESULT_SCRIPT_PATH/$(basename $scriptFile)
    processTemplate $scriptFile $generatedScriptFile

    if [ -z "$testId" ]; then
	sudo -u ubuntu time -f "$(date --rfc-3339=seconds) \tElapsed: %E" -o $MEASUREMENT_RESULTS_FILE -a beeline -u $HIVE_DATABASE_URL -n hive -p hive -d org.apache.hive.jdbc.HiveDriver -f $generatedScriptFile
    else
	sudo -u ubuntu time -f "$(date --rfc-3339=seconds) \tElapsed: %E" -o $MEASUREMENT_RESULTS_FILE -a beeline -u $HIVE_DATABASE_URL -n hive -p hive -d org.apache.hive.jdbc.HiveDriver -f $generatedScriptFile

	pattern=$TEMP_FRAMEWORK_RESULT_PATH/*
	if ! [ "$(echo $pattern)" != "$pattern" ]; 
	then 
	    echo "TEST FAILED!" >> $MEASUREMENT_RESULTS_FILE
	fi

	mkdir -p $RESULT_PATH/run-$testId/
	sudo mv $TEMP_FRAMEWORK_RESULT_PATH/* $RESULT_PATH/run-$testId/
    fi
}

RESULT_SCRIPT_PATH=$RESULT_PATH/script
SCRIPT_PATH=$PWD/script

mkdir -p $RESULT_SCRIPT_PATH

printfWithTime "Loading data..." >> $MEASUREMENT_RESULTS_FILE
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


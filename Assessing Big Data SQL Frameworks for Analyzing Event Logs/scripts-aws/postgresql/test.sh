#!/bin/bash

runScript()
{
    scriptFile=$1
    testId=$2
    generatedScriptFile=$RESULT_SCRIPT_PATH/$(basename $scriptFile)
    processTemplate $scriptFile $generatedScriptFile
    if [ -z "$testId" ]; then
	sudo -u postgres time -f "$(date --rfc-3339=seconds) \tElapsed: %E" -o $MEASUREMENT_RESULTS_FILE -a psql --file=$generatedScriptFile
    else
	sudo -u postgres time -f "$(date --rfc-3339=seconds) \tElapsed: %E" -o $MEASUREMENT_RESULTS_FILE -a psql --file=$generatedScriptFile
	mkdir -p $RESULT_PATH/run-$testId/
	sudo mv $TEMP_FRAMEWORK_RESULT_PATH.csv $RESULT_PATH/run-$testId/
	if [ ! -f $RESULT_PATH/run-$testId/$RESULT_FRAMEWORK_DIRECTORY_NAME.csv ]; then
	    echo "TEST FAILED!" >> $MEASUREMENT_RESULTS_FILE
	fi
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


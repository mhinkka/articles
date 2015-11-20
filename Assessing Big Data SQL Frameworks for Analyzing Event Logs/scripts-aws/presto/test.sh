#!/bin/bash

runScript()
{
    scriptFile=$1
    testId=$2
    generatedScriptFile=$RESULT_SCRIPT_PATH/$(basename $scriptFile)
    processTemplate $scriptFile $generatedScriptFile

    mkdir -p $RESULT_PATH/run-$testId/
    touch $RESULT_PATH/run-$testId/result.csv
    sudo -u ubuntu time -f "$(date --rfc-3339=seconds) \tElapsed: %E" -o $MEASUREMENT_RESULTS_FILE -a $PRESTO_COMMAND_LINE_INTERFACE_EXE --server localhost:8080 --catalog hive --schema default -f $generatedScriptFile >> $RESULT_PATH/run-$testId/result.csv

    if [[ -n $(find $RESULT_PATH/run-$testId/result.csv -size -10c) ]]; then
	echo "TEST FAILED!" >> $MEASUREMENT_RESULTS_FILE
    fi
}

runHiveScript()
{
    scriptFile=$1
    generatedScriptFile=$RESULT_SCRIPT_PATH/$(basename $scriptFile)
    processTemplate $scriptFile $generatedScriptFile

    sudo -u ubuntu time -f "$(date --rfc-3339=seconds) \tElapsed: %E" -o $MEASUREMENT_RESULTS_FILE -a beeline -u $HIVE_DATABASE_URL -n hive -p hive -d org.apache.hive.jdbc.HiveDriver -f $generatedScriptFile
}

RESULT_SCRIPT_PATH=$RESULT_PATH/script
SCRIPT_PATH=$PWD/script
PRESTO_COMMAND_LINE_INTERFACE_EXE=/ebsvol1/presto/presto

mkdir -p $RESULT_SCRIPT_PATH

printfWithTime "Loading data..." >> $MEASUREMENT_RESULTS_FILE
runHiveScript $SCRIPT_PATH/load.sql

printfWithTime "Performing warm-up run..." >> $MEASUREMENT_RESULTS_FILE
runScript $SCRIPT_PATH/$TEST_NAME.sql warmup

printfWithTime "Performing tests..." >> $MEASUREMENT_RESULTS_FILE
for ((i=1; i<=$NUM_REPEATS; i++ ))
do
    printfWithTime "Starting $framework test #$i..."
    runScript $SCRIPT_PATH/$TEST_NAME.sql $i
    printfWithTime "Finished $framework test #$i."
done;


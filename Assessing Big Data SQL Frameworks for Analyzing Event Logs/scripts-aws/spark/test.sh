#!/bin/bash

runScript()
{
    testName=$1
    testId=$2
    if [ -z "$testId" ]; then
	sudo -u spark time -f "$(date --rfc-3339=seconds) \tElapsed: %E" -o $MEASUREMENT_RESULTS_FILE -a spark-submit --executor-memory $EXECUTOR_MEMORY --class $TEST_CLASS script/target/Tester-1.0.jar $testName "$HDFS_NAMENODE_URL$TEST_DATA_HDFS_PATH" $NUM_REPEATS $TEMP_RESULT_PATH $TEMP_RESULT_PATH/spark.parquet
#	sudo -u spark time -f "$(date --rfc-3339=seconds) \tElapsed: %E" -o $MEASUREMENT_RESULTS_FILE -a spark-submit --executor-memory $EXECUTOR_MEMORY --total-executor-cores $EXECUTOR_CORES --class $TEST_CLASS script/target/Tester-1.0.jar $testName "$HDFS_NAMENODE_URL$TEST_DATA_HDFS_PATH" $NUM_REPEATS $TEMP_RESULT_PATH $TEMP_RESULT_PATH/spark.parquet
    else
	sudo -u spark time -f "$(date --rfc-3339=seconds) \tElapsed: %E" -o $MEASUREMENT_RESULTS_FILE -a spark-submit --executor-memory $EXECUTOR_MEMORY --class $TEST_CLASS script/target/Tester-1.0.jar $testName "$HDFS_NAMENODE_URL$TEST_DATA_HDFS_PATH" $NUM_REPEATS $TEMP_RESULT_PATH $TEMP_RESULT_PATH/spark.parquet
#	sudo -u spark time -f "$(date --rfc-3339=seconds) \tElapsed: %E" -o $MEASUREMENT_RESULTS_FILE -a spark-submit --executor-memory $EXECUTOR_MEMORY --total-executor-cores $EXECUTOR_CORES --class $TEST_CLASS script/target/Tester-1.0.jar $testName "$HDFS_NAMENODE_URL$TEST_DATA_HDFS_PATH" $NUM_REPEATS $TEMP_RESULT_PATH $TEMP_RESULT_PATH/spark.parquet
	mkdir -p $RESULT_PATH/run-$testId
	sudo mv $TEMP_RESULT_PATH/$TEST_NAME.txt $RESULT_PATH/run-$testId/result.txt
	if [ ! -f $RESULT_PATH/run-$testId/result.txt ]; then
	    echo "TEST FAILED!" >> $MEASUREMENT_RESULTS_FILE
	fi
    fi
}

EXECUTOR_MEMORY=640M
#EXECUTOR_CORES=1
RESULT_SCRIPT_PATH=$RESULT_PATH/script
SCRIPT_PATH=$PWD/script
TEST_CLASS=$1
TEST_DATA_HDFS_PATH=/tmp/spark-test.csv

numRepeats=$NUM_REPEATS
singleRun=1
if [ -z "$2" ]; 
then
  singleRun=0
fi

mkdir -p $RESULT_SCRIPT_PATH

printfWithTime "Loading data..." >> $MEASUREMENT_RESULTS_FILE
sudo -u spark time -f "$(date --rfc-3339=seconds) \tElapsed: %E" -o $MEASUREMENT_RESULTS_FILE -a hdfs dfs -copyFromLocal -f $TEST_DATA_FILE $TEST_DATA_HDFS_PATH
#runScript load

if [ "$singleRun" = "1" ];
then
    printfWithTime "Performing warm-up run and actual tests..." >> $MEASUREMENT_RESULTS_FILE 
    runScript $TEST_NAME combined
    egrep "^Finished spark" $RESULT_PATH/log.txt >> $MEASUREMENT_RESULTS_FILE
else
    printfWithTime "Performing warm-up run..." >> $MEASUREMENT_RESULTS_FILE
    runScript $TEST_NAME warmup

    printfWithTime "Performing tests..." >> $MEASUREMENT_RESULTS_FILE 
    for ((i=1; i<=$numRepeats; i++ ))
    do
	printfWithTime "Starting $framework test #$i..."
	runScript $TEST_NAME $i
	printfWithTime "Finished $framework test #$i."
    done;
fi;


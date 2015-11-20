#!/bin/bash

export PRESTO_SOURCE=/ebsvol1/presto/presto-server
export PRESTO_CONF_SOURCE_DIR=./conf
export PRESTO_TMP_DIR=/tmp/presto
export PEM=/ebsvol1/aws.pem

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

first=1
masterNode=""

mkdir -p $PRESTO_SOURCE/etc/
cp -f -r $PRESTO_CONF_SOURCE_DIR/* $PRESTO_SOURCE/etc/

for host in $(cat ../hosts); do 
    ssh -i $PEM -o StrictHostKeyChecking=no $host "sudo rm -f -r $PRESTO_HOME; sudo mkdir $PRESTO_HOME; sudo chown ubuntu $PRESTO_HOME"
    scp -q -i $PEM -o StrictHostKeyChecking=no -r $PRESTO_SOURCE/* ubuntu@$host:$PRESTO_HOME/

    if [ "$first" = "1" ];
    then
	masterNode=$host
	echo "Starting coordinator in $host..."
	scp -i $PEM -o StrictHostKeyChecking=no -r common-init.sh ubuntu@$host:~/
	scp -i $PEM -o StrictHostKeyChecking=no -r coordinator.sh ubuntu@$host:~/
	ssh -i $PEM -o StrictHostKeyChecking=no $host ". ~/coordinator.sh $masterNode $PRESTO_TMP_DIR $PRESTO_HOME"
	first=0
    else
	echo "Starting worker in $host..."
	scp -i $PEM -o StrictHostKeyChecking=no -r common-init.sh ubuntu@$host:~/
	scp -i $PEM -o StrictHostKeyChecking=no -r worker.sh ubuntu@$host:~/
	ssh -i $PEM -o StrictHostKeyChecking=no $host ". ~/worker.sh $masterNode $PRESTO_TMP_DIR $PRESTO_HOME"
    fi;
done;


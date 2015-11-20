#!/bin/bash
echo "Running common presto initialization on host:" $(hostname)

export JAVA_HOME=/usr/lib/jvm/java-7-oracle-cloudera

export masterNode=$1
export PRESTO_TMP_DIR=$2
export PRESTO_HOME=$3

echo "Master node: $masterNode"
echo "Presto temporary directory: $PRESTO_TMP_DIR"
echo "Presto home: $PRESTO_HOME"

export PRESTO_DATA_DIR=$PRESTO_TMP_DIR/data
export PRESTO_LOG_DIR=$PRESTO_TMP_DIR/log
export PRESTO_CONF_DIR=$PRESTO_HOME/etc
export PRESTO_DISCOVERY_PORT=8411
export PRESTO_PORT=8080
export HIVE_PORT=9083
export PRESTO_LOG_DIR=/tmp/presto/log
export JAVA_HOME=/usr/lib/jvm/java-7-oracle-cloudera/bin
export PATH=$JAVA_HOME:$PATH

processTemplate()
{
    templateFile=$1
    outputFile=$2
    rm -f $outputFile
    sed < $templateFile > $outputFile \
        "/\${TEST/ {
          s/\${TEST_NAMENODE}/$masterNode/
          s:\${TEST_PRESTO_HOME}:$PRESTO_HOME:
          s:\${TEST_PRESTO_NODE_ID}:$(uuidgen):
          s:\${TEST_PRESTO_DATA_DIR}:$PRESTO_DATA_DIR:
          s/\${TEST_PRESTO_DISCOVERY_HOST}/$masterNode/
          s/\${TEST_PRESTO_DISCOVERY_PORT}/$PRESTO_DISCOVERY_PORT/
          s/\${TEST_PRESTO_PORT}/$PRESTO_PORT/
          s/\${TEST_HIVE_PORT}/$HIVE_PORT/
        }"
}

rm -f -r $PRESTO_DATA_DIR
mkdir -p $PRESTO_DATA_DIR
rm -f -r $PRESTO_LOG_DIR
mkdir -p $PRESTO_LOG_DIR

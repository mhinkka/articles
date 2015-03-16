#!/bin/bash
LOCAL_DIR=$1
PRESTO_SOURCE_DIR=$2
PRESTO_CONF_DIR=$3
out=$4
masterHost=$5
HIVE_PORT=$6
PRESTO_PORT=$7
PRESTO_HIVE_CONNECTOR_NAME=$8

echo "Initializing presto config..."

if [ -z "$PRESTO_CONF_SOURCE_DIR" ]; then
  PRESTO_CONF_SOURCE_DIR=$PRESTO_CONF_DIR
fi

export PRESTO_LOCAL_COPY_DIR=$LOCAL_DIR/presto
echo $(hostname) "Copying presto from: " $PRESTO_SOURCE_DIR " to: " $PRESTO_LOCAL_COPY_DIR
rm -fr $PRESTO_LOCAL_COPY_DIR
mkdir -p $PRESTO_LOCAL_COPY_DIR
'cp' -fr $PRESTO_SOURCE_DIR $PRESTO_LOCAL_COPY_DIR
export PRESTO_LOCAL_COPY_HOME=$PRESTO_LOCAL_COPY_DIR/$(basename $PRESTO_SOURCE_DIR)
export PRESTO_LOCAL_COPY_CONF_DIR=$PRESTO_LOCAL_COPY_HOME/etc
mkdir -p $PRESTO_LOCAL_COPY_CONF_DIR/catalog

prestoDataDir=$out/presto/data
prestoDiscoveryDataDir=$out/presto/data/discovery
prestoLogDir=$out/presto/log
export PRESTO_DATA_DIR=$prestoDataDir
export PRESTO_LOG_DIR=$prestoLogDir

mkdir -p $prestoDataDir
mkdir -p $prestoDiscoveryDataDir
mkdir -p $prestoLogDir

prestoDiscoveryPort=8411

echo "Copying configuration from: $PRESTO_CONF_SOURCE_DIR"
'cp' -fr $PRESTO_CONF_SOURCE_DIR/* $PRESTO_LOCAL_COPY_CONF_DIR/

for f in $PRESTO_CONF_SOURCE_DIR/*.properties; do
   f2=$PRESTO_LOCAL_COPY_CONF_DIR/$(basename $f)
   rm -f $f2
   sed < $f > $f2 \
   "/\${HADOOP_TRITON/ {
      s/\${HADOOP_TRITON_NAMENODE}/$masterHost/
      s/\${HADOOP_TRITON_JOBTRACKER}/$masterHost/
      s/\${HADOOP_TRITON_JOBTRACKER_PORT}/$JOBTRACKER_PORT/
      s/\${HADOOP_TRITON_HDFS_PORT}/$HDFS_PORT/
      s:\${HADOOP_TRITON_HIVE_CONFIG_PATH}:$HADOOP_CONF_DIR:g
      s/\${HADOOP_TRITON_HIVE_PORT}/$HIVE_PORT/
      s/\${HADOOP_TRITON_PRESTO_PORT}/$PRESTO_PORT/
      s/\${HADOOP_TRITON_PRESTO_DISCOVERY_HOST}/$masterHost/
      s/\${HADOOP_TRITON_PRESTO_DISCOVERY_PORT}/$prestoDiscoveryPort/
      s:\${HADOOP_TRITON_PRESTO_DISCOVERY_DATA_DIR}:$prestoDiscoveryDataDir:
   }"
done

for f in $PRESTO_CONF_SOURCE_DIR/catalog/*.properties; do
   f2=$PRESTO_LOCAL_COPY_CONF_DIR/catalog/$(basename $f)
   rm -f $f2
   sed < $f > $f2 \
   "/\${HADOOP_TRITON/ {
      s/\${HADOOP_TRITON_NAMENODE}/$masterHost/
      s/\${HADOOP_TRITON_JOBTRACKER}/$masterHost/
      s/\${HADOOP_TRITON_JOBTRACKER_PORT}/$JOBTRACKER_PORT/
      s/\${HADOOP_TRITON_HDFS_PORT}/$HDFS_PORT/
      s:\${HADOOP_TRITON_HIVE_CONFIG_PATH}:$HADOOP_CONF_DIR:g
      s/\${HADOOP_TRITON_HIVE_PORT}/$HIVE_PORT/
      s/\${HADOOP_TRITON_PRESTO_PORT}/$PRESTO_PORT/
      s/\${HADOOP_TRITON_PRESTO_DISCOVERY_HOST}/$masterHost/
      s/\${HADOOP_TRITON_PRESTO_DISCOVERY_PORT}/$prestoDiscoveryPort/
      s/\${HADOOP_TRITON_PRESTO_HIVE_CONNECTOR_NAME}/$PRESTO_HIVE_CONNECTOR_NAME/
   }"
done

#!/bin/bash
echo "Launching presto coordinator on host:" $(hostname)

PRESTO_LOCAL_COPY_HOME=$1
PRESTO_LOCAL_COPY_CONF_DIR=$1/etc
PRESTO_LOG_DIR=$2
workerId=$3

echo -e "\
coordinator=true\n\
datasources=jmx\n\
discovery-server.enabled=true\n\
presto-metastore.db.type=h2\n\
presto-metastore.db.filename=var/db/MetaStore\n\
" >> $PRESTO_LOCAL_COPY_CONF_DIR/config.properties

sed < $PRESTO_LOCAL_COPY_CONF_DIR/node.properties > $PRESTO_LOCAL_COPY_CONF_DIR/node2.properties \
  "/\${HADOOP_TRITON/ {
    s:\${HADOOP_TRITON_PRESTO_NODE_ID}:$(uuidgen):
    s:\${HADOOP_TRITON_PRESTO_DATA_DIR}:$PRESTO_LOCAL_COPY_HOME/data:
  }"
rm -f $PRESTO_LOCAL_COPY_CONF_DIR/node.properties
mv $PRESTO_LOCAL_COPY_CONF_DIR/node2.properties $PRESTO_LOCAL_COPY_CONF_DIR/node.properties

#$PRESTO_DISCOVERY_HOME/bin/launcher --node-config=${PRESTO_DISCOVERY_CONF_DIR}/node.properties --jvm-config=${PRESTO_DISCOVERY_CONF_DIR}/jvm.config --config=${PRESTO_DISCOVERY_CONF_DIR}/config.properties --log-levels-file=${PRESTO_DISCOVERY_CONF_DIR}/log.properties --launcher-log-file=${PRESTO_LOG_DIR}/discovery-launcher.log --server-log-file=${PRESTO_LOG_DIR}/discovery-server.log run &

mkdir -p $PRESTO_LOG_DIR/conf-$workerId
cp -r $PRESTO_LOCAL_COPY_CONF_DIR $PRESTO_LOG_DIR/conf-$workerId

echo "Starting presto coordinator on host:" $(hostname)
$PRESTO_LOCAL_COPY_HOME/bin/launcher --launcher-log-file=$PRESTO_LOG_DIR/launcher-$3.log --server-log-file=$PRESTO_LOG_DIR/server-$3.log start &
echo "Presto coordinator started on host:" $(hostname)

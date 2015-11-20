#!/bin/bash
echo "Launching presto coordinator on host:" $(hostname)

. common-init.sh $1 $2 $3 $4 $5 $6 $7 $8 $9

processTemplate $PRESTO_CONF_DIR/jvm.config.in $PRESTO_CONF_DIR/jvm.config
processTemplate $PRESTO_CONF_DIR/node.properties.in $PRESTO_CONF_DIR/node.properties
processTemplate $PRESTO_CONF_DIR/config.properties.coordinator.in $PRESTO_CONF_DIR/config.properties
processTemplate $PRESTO_CONF_DIR/log.properties.in $PRESTO_CONF_DIR/log.properties
processTemplate $PRESTO_CONF_DIR/catalog/hive.properties.in $PRESTO_CONF_DIR/catalog/hive.properties

echo "Starting presto coordinator on host:" $(hostname)
$PRESTO_HOME/bin/launcher --verbose --launcher-log-file=$PRESTO_LOG_DIR/launcher.log --server-log-file=$PRESTO_LOG_DIR/server.log start &> $PRESTO_LOG_DIR/out.log
echo "Presto coordinator started on host:" $(hostname)

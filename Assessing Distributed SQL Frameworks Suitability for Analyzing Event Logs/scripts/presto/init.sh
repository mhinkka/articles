echo "Initializing presto config..."
mkdir -p $PRESTO_CONF_DIR
'cp' -fr conf/* $PRESTO_CONF_DIR
#'cp' -fr conf/* $CONF_DIR/presto
#srun --immediate conf/presto-common-init.sh $LOCAL_DIR $PRESTO_SOURCE_DIR $out $masterHost $HIVE_PORT $PRESTO_PORT

if [ -z "$PRESTO_HIVE_CONNECTOR_NAME" ]; then
  PRESTO_HIVE_CONNECTOR_NAME=hive-hadoop2
fi

echo "Running on all nodes: $PRESTO_CONF_DIR/presto-common-init.sh $LOCAL_DIR $PRESTO_SOURCE_DIR $PRESTO_CONF_DIR $out $masterHost $HIVE_PORT $PRESTO_PORT"
for host in $(cat $nodesFile); do ssh -o StrictHostKeyChecking=no $host "sleep 1;. $PRESTO_CONF_DIR/presto-common-init.sh $LOCAL_DIR $PRESTO_SOURCE_DIR $PRESTO_CONF_DIR $out $masterHost $HIVE_PORT $PRESTO_PORT $PRESTO_HIVE_CONNECTOR_NAME"; done

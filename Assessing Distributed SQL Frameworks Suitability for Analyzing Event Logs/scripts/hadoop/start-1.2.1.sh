echo "Starting hadoop..."

#echo "Copying hadoop 1.2.1 package..."
#rm -fr $HOME/hadoop/hadoo*
#'cp' -fr $WRKDIR/packages/hadoop-1.2.1 $HOME/hadoop/

export HADOOP_HOME=$HOME/hadoop/hadoop-1.2.1
export HADOOP_YARN_HOME=$HADOOP_HOME
export HADOOP_PREFIX=$HADOOP_HOME
export HADOOP_LOG_DIR=$OUT_DIR/hadoop/log
rm -f $HOME/hadoop/hadoop
ln -s $HADOOP_HOME $HOME/hadoop/hadoop

echo "HADOOP_HOME set to $HADOOP_HOME"

echo "Configuration root directory: $HADOOP_CONF_DIR"
mkdir -p $HADOOP_CONF_DIR
'cp' -f $HADOOP_HOME/conf/* $HADOOP_CONF_DIR/

slaveHostsFile=$HADOOP_CONF_DIR/slaves
rm -f $slaveHostsFile

'cp' -f $slaveHostsRootFile $slaveHostsFile

echo "Copying configurations..."
(cd ../hadoop && . ./init.sh)

# Copy configurations back to HOME after modifications since e.g. hive startup requires them. 
'cp' -f $HADOOP_CONF_DIR/* $HADOOP_HOME/conf/

echo "Starting hdfs..."
# Start HDFS everywhere
yes Y | $HADOOP_PREFIX/bin/hadoop --config $HADOOP_CONF_DIR namenode -format test
$HADOOP_HOME/bin/start-all.sh --config $HADOOP_CONF_DIR
#$HADOOP_PREFIX/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR --script hdfs start namenode

#$HADOOP_PREFIX/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR --script hdfs start datanode
#srun --immediate $HADOOP_PREFIX/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR --script hdfs start datanode

#$HADOOP_YARN_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR start resourcemanager

#$HADOOP_YARN_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR start nodemanager
#srun --immediate $HADOOP_YARN_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR start nodemanager

#$HADOOP_YARN_HOME/sbin/yarn-daemon.sh start proxyserver --config $HADOOP_CONF_DIR
#$HADOOP_PREFIX/sbin/mr-jobhistory-daemon.sh start historyserver --config $HADOOP_CONF_DIR

echo "Hdfs started."

echo "Waiting for everything to start up properly..."
sleep 15

echo "Hadoop started."

#echo "Going to sleep..."
#sleep 7200

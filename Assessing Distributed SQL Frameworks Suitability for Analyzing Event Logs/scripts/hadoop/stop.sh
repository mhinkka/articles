# Stop MapReduce and HDFS everywhere
echo "Stopping hdfs..."

#$HADOOP_PREFIX/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR --script hdfs stop namenode
$HADOOP_PREFIX/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR --script hdfs stop namenode

#$HADOOP_PREFIX/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR --script hdfs stop datanode
srun --immediate $HADOOP_PREFIX/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR --script hdfs stop datanode

$HADOOP_YARN_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR stop resourcemanager

#$HADOOP_YARN_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR stop nodemanager
srun --immediate $HADOOP_YARN_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR stop nodemanager

#$HADOOP_YARN_HOME/sbin/yarn-daemon.sh stop proxyserver --config $HADOOP_CONF_DIR

$HADOOP_PREFIX/sbin/mr-jobhistory-daemon.sh stop historyserver --config $HADOOP_CONF_DIR

#echo "Copying local results from $localResults to target directory $OUT_DIR/results-$(date +%s).tgz..."
#tar -cvzPf $OUT_DIR/results-$(date +%s).tgz $localResults

# Really kill Hadoop
echo "Kill all master java applications..."
killall -q -9 java hive launcher presto-server
sleep 10

echo "Kill all slave java applications..."
for host in $(cat $slaveHostsRootFile); do ssh -o StrictHostKeyChecking=no $host "killall -q -9 java hive launcher presto-server"; done
sleep 10

#echo "Going to sleep"
#sleep 7200

echo "Cleaning up temporary files from $localTemp and $localResults"
rm -fr $localTemp; rm -fr $localResults
for host in $(cat $slaveHostsRootFile); do ssh -o StrictHostKeyChecking=no $host "rm -fr $localTemp; rm -fr $localResults"; done

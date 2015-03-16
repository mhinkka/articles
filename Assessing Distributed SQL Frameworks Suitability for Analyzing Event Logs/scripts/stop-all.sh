$HADOOP_PREFIX/sbin/mr-jobhistory-daemon.sh stop historyserver --config $HADOOP_CONF_DIR
#$HADOOP_YARN_HOME/bin/yarn stop proxyserver --config $HADOOP_CONF_DIR
$HADOOP_YARN_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR stop nodemanager
$HADOOP_YARN_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR stop resourcemanager
$HADOOP_PREFIX/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR --script hdfs stop datanode
$HADOOP_PREFIX/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR --script hdfs stop namenode
killall -q -9 java hive launcher presto-server
for host in $(cat $hosts); do ssh -o StrictHostKeyChecking=no $host "killall -q -9 java hive launcher presto-server; rm -fr $localTemp; 
rm -fr $localResults"; done
for host in $(cat $hosts); do ssh -o StrictHostKeyChecking=no $host "rm -fr $localTemp; rm -fr $localResults"; done

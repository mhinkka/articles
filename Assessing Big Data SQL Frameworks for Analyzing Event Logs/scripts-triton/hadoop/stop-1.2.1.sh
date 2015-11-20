# Stop MapReduce and HDFS everywhere
echo "Stopping hdfs..."

$HADOOP_HOME/bin/stop-all.sh --config $HADOOP_CONF_DIR

# Really kill Hadoop
echo "Kill all master java applications..."
killall -q -9 java hive launcher presto-server
sleep 10

echo "Kill all slave java applications..."
for host in $(cat $slaveHostsRootFile); do ssh -o StrictHostKeyChecking=no $host "killall -q -9 java hive launcher presto-server"; done
sleep 10

#echo "Copying local results to target directory..."
#tar -cvzPf $OUT_DIR/results.tgz $localResults

echo "Cleaning up temporary files from $localTemp and $localResults"
rm -fr $localTemp; rm -fr $localResults
for host in $(cat $slaveHostsRootFile); do ssh -o StrictHostKeyChecking=no $host "rm -fr $localTemp; rm -fr $localResults"; done

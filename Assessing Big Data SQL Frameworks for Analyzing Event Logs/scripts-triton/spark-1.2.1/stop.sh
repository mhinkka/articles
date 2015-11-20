echo "Stopping spark servers..."
rm -fr $OUT_DIR/parquet
$SPARK_HOME/sbin/stop-all.sh

echo "Kill all master java applications..."
killall -q -9 java hive launcher presto-server
sleep 10

echo "Kill all slave java applications..."
for host in $(cat $slaveHostsRootFile); do ssh -o StrictHostKeyChecking=no $host "killall -q -9 java hive launcher presto-server"; done
sleep 10

echo "Spark servers stopped."

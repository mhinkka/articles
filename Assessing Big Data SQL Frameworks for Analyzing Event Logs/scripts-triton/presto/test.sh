echo "Testing $framework..."

echo PRESTO_PORT=8080
echo masterHost=$masterHost
export OUT_DIR=$out/$framework-$frameworkId
echo OUT_DIR=$out/$framework-$frameworkId
export CONF_DIR=$OUT_DIR/config
echo CONF_DIR=$OUT_DIR/config
export HADOOP_CONF_DIR=$CONF_DIR/hadoop
echo HADOOP_CONF_DIR=$CONF_DIR/hadoop
export HADOOP_LOG_DIR=$OUT_DIR/hadoop/log
echo HADOOP_LOG_DIR=$OUT_DIR/hadoop/log
export HIVE_CONF_DIR=$CONF_DIR/hive
echo HIVE_CONF_DIR=$CONF_DIR/hive
export LOCAL_DIR=$localTemp/presto
echo LOCAL_DIR=$localTemp/presto

export HIVE_BYTES_PER_REDUCER=1000000000 # default
#export HIVE_BYTES_PER_REDUCER=25000000 # slows down on 20M+8nodes
#export HIVE_BYTES_PER_REDUCER=50000000 # ok I guess...

echo "Copying custom hadoop configuration..."
export HADOOP_CONF_SOURCE_DIR=$PWD/hadoop-conf

#echo "Using non-native hadoop libraries."
#export HADOOP_LIBRARY_DIR="$HADOOP_HOME/lib-orig"

(cd ../hadoop && . ./start.sh)

echo "Initializing HDFS contents..."
hdfs --config $HADOOP_CONF_DIR dfs -mkdir -p /home/hinkkam2/git/hive/udf/
hdfs --config $HADOOP_CONF_DIR dfs -copyFromLocal $SCRIPT_ROOT/hive/udf/CollectAll.jar /home/hinkkam2/git/hive/udf/CollectAll.jar
hdfs --config $HADOOP_CONF_DIR dfs -mkdir -p /tmp
hdfs --config $HADOOP_CONF_DIR dfs -chmod g+w /tmp
hdfs --config $HADOOP_CONF_DIR dfs -mkdir -p /user/hive/warehouse
hdfs --config $HADOOP_CONF_DIR dfs -chmod g+w /user/hive/warehouse

#echo "Re-formatting timestamps for presto..."
#TEST_DATA_FILE=$out/test-presto.csv
#sed 's/\.\([0-9][0-9][0-9]\)/ \1/' $out/test.csv > $TEST_DATA_FILE

storageFormat=presto
(cd ../hive && . ./start.sh)

echo "Initializing and copying configurations..."
export PRESTO_SOURCE_DIR=$WRKDIR/packages/presto-server-0.77
echo PRESTO_SOURCE_DIR=$WRKDIR/packages/presto-server-0.77
export PRESTO_LOCAL_COPY_DIR=$LOCAL_DIR/presto
echo PRESTO_LOCAL_COPY_DIR=$LOCAL_DIR/presto
export PRESTO_LOCAL_COPY_HOME=$PRESTO_LOCAL_COPY_DIR/$(basename $PRESTO_SOURCE_DIR)
echo PRESTO_LOCAL_COPY_HOME=$PRESTO_LOCAL_COPY_DIR/$(basename $PRESTO_SOURCE_DIR)
export PRESTO_HOME=$PRESTO_LOCAL_COPY_HOME
echo PRESTO_HOME=$PRESTO_LOCAL_COPY_HOME
export PRESTO_LOCAL_COPY_CONF_DIR=$PRESTO_LOCAL_COPY_HOME/etc
echo PRESTO_LOCAL_COPY_CONF_DIR=$PRESTO_LOCAL_COPY_HOME/etc
export PRESTO_LOG_DIR=$OUT_DIR/log
echo PRESTO_LOG_DIR=$OUT_DIR/log
export PRESTO_CONF_DIR=$CONF_DIR/presto
echo PRESTO_CONF_DIR=$CONF_DIR/presto

(cd ../presto && . ./init.sh)

#export PATH=$HOME/java/jdk1.7.0_45/bin:$PATH

mkdir $localResults

#echo "Going to sleep"
#sleep 7200

$PRESTO_CONF_DIR/coordinator.sh $PRESTO_LOCAL_COPY_HOME $PRESTO_LOG_DIR $masterHost
for host in $(cat $slaveHostsRootFile); do ssh -o StrictHostKeyChecking=no $host "sleep 1;. $PRESTO_CONF_DIR/worker.sh $PRESTO_LOCAL_COPY_HOME $PRESTO_LOG_DIR $host"; done

sleep 30
echo "Presto servers started..."

prestoTestFile=$SCRIPT_ROOT/presto/script/$TEST_NAME.sql
echo "Starting test: $prestoTestFile" >> $out/results.txt

echo "Performing tests..."

#Ignore first test run
date >> $OUT_DIR/warm-up-results.txt
/usr/bin/time -o $OUT_DIR/warm-up-results.txt -a $HOME/presto/presto --server $masterHost:$PRESTO_PORT --catalog hive --schema default -f $prestoTestFile >> $localResults/presto.txt
date >> $OUT_DIR/warm-up-results.txt
  
for ((i=1; i<=$NUM_REPEATS; i++ ))
do
  date >> $out/results.txt
  echo "Starting $framework test #$i..." >> $out/results.txt
  echo "Starting $framework test #$i..."
  /usr/bin/time -o $out/results.txt -a $HOME/presto/presto --server $masterHost:$PRESTO_PORT --catalog hive --schema default -f $prestoTestFile >> $localResults/presto-$frameworkId-$i.txt
  echo "Finished $framework test #$i." >> $out/results.txt
  echo "Finished $framework test #$i."
done

echo "Copying local results from $localResults to target directory $OUT_DIR/results-$frameworkId.tgz..."
tar -cvzPf $OUT_DIR/results-$frameworkId.tgz $localResults

#echo "Going to sleep"
#sleep 7200

(cd ../hive && . ./stop.sh)

echo "$framework tests finished."

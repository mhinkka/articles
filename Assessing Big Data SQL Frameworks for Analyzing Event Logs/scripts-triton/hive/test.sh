echo "Testing $framework..."

export OUT_DIR=$out/$framework-$frameworkId
export CONF_DIR=$OUT_DIR/config
export HADOOP_CONF_DIR=$CONF_DIR/hadoop
export HIVE_CONF_DIR=$CONF_DIR/hive
export PRESTO_CONF_DIR=$PRESTO_HOME/etc
export LOCAL_DIR=$localTemp/hive
export HIVE_USER=$USER

#export HIVE_BYTES_PER_REDUCER=1000000000 # default
#export HIVE_BYTES_PER_REDUCER=25000000 # slows down on 20M+8nodes
export HIVE_BYTES_PER_REDUCER=50000000 # ok I guess...

#For hiveserver2:
#export HIVE_CONNECTION_STRING=jdbc:hive2://$masterHost:$HIVE_PORT/default;ssl=true;sslTrustStore=truststore.jks;sslTrustStorePassword=tsp

export HADOOP_FRAMEWORK_NAME=yarn

(cd ../hadoop && . ./start.sh)

#echo "Going to sleep..."
#sleep 7200

echo "Initializing HDFS contents..."
$HADOOP_HOME/bin/hadoop --config $HADOOP_CONF_DIR fs -mkdir -p /home/hinkkam2/git/hive/udf/
$HADOOP_HOME/bin/hadoop --config $HADOOP_CONF_DIR fs -copyFromLocal udf/CollectAll.jar /home/hinkkam2/git/hive/udf/CollectAll.jar

(cd ../hive && . ./start.sh)

#echo "Going to sleep..."
#sleep 7200

hiveTestFile=$OUT_DIR/script/$TEST_NAME.sql
echo "Starting test: $hiveTestFile" >> $out/results.txt

echo "Performing tests..."
#Ignore first test run
date >> $OUT_DIR/warm-up-results.txt
#withTimeout $HIVE_HOME/bin/hive --config $HIVE_CONF_DIR -f $hiveTestFile
#withTimeout /usr/bin/time -o $OUT_DIR/warm-up-results.txt -a beeline -n $HIVE_USER -u $HIVE_CONNECTION_STRING -f $hiveTestFile >> $OUT_DIR/warm-up-results.txt
withTimeout /usr/bin/time -o $OUT_DIR/warm-up-results.txt -a $HIVE_HOME/bin/hive --config $HIVE_CONF_DIR -f $hiveTestFile >> $OUT_DIR/warm-up-results.txt
date >> $OUT_DIR/warm-up-results.txt

#echo "Going to sleep..."
#sleep 7200

for ((i=1; i<=$NUM_REPEATS; i++ ))
do
  date >> $out/results.txt
  echo "Starting $framework test #$i..." >> $out/results.txt
  echo "Starting $framework test #$i..."
  withTimeout /usr/bin/time -o $out/results.txt -a $HIVE_HOME/bin/hive --config $HIVE_CONF_DIR -f $hiveTestFile >> $out/results.txt
#  withTimeout /usr/bin/time -o $out/results.txt -a beeline -n $HIVE_USER -u $HIVE_CONNECTION_STRING -f $hiveTestFile >> $out/results.txt
  echo "Finished $framework test #$i." >> $out/results.txt
  echo "Finished $framework test #$i."
done

(cd ../hadoop && . ./stop.sh)

echo "$framework tests finished."

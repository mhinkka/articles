echo "Testing $framework..."

export OUT_DIR=$out/$framework-$frameworkId
export CONF_DIR=$OUT_DIR/config
export HADOOP_CONF_DIR=$CONF_DIR/hadoop
export PRESTO_CONF_DIR=$PRESTO_HOME/etc
export SHARK_CONF_DIR=$CONF_DIR/shark
export LOCAL_DIR=$localTemp/shark
export HIVE_HOME=$SHARK_HOME
export HIVE_CONF_DIR=$SHARK_CONF_DIR

#export HIVE_BYTES_PER_REDUCER=1000000000 # default
#export HIVE_BYTES_PER_REDUCER=25000000 # slows down on 20M+8nodes
export HIVE_BYTES_PER_REDUCER=50000000 # ok I guess...

(cd ../shark && . ./start.sh)

hiveTestFile=$out/hive/script/$TEST_NAME.sql
#hiveTestFile=$out/hive/script/flows.sql
echo "Starting test: $hiveTestFile" >> $out/results.txt

echo "Performing tests..."
#Ignore first test run
date >> $OUT_DIR/warm-up-results.txt
withTimeout $HIVE_HOME/bin/hive --config $HIVE_CONF_DIR -f $hiveTestFile
withTimeout /usr/bin/time -o $OUT_DIR/warm-up-results.txt -a $HIVE_HOME/bin/shark --config $HIVE_CONF_DIR -f $hiveTestFile >> $OUT_DIR/warm-up-results.txt
date >> $OUT_DIR/warm-up-results.txt

for ((i=1; i<=$NUM_REPEATS; i++ ))
do
  date >> $out/results.txt
  echo "Starting $framework test #$i..." >> $out/results.txt
  echo "Starting $framework test #$i..."
  withTimeout /usr/bin/time -o $out/results.txt -a $HIVE_HOME/bin/shark --config $HIVE_CONF_DIR -f $hiveTestFile >> $out/results.txt
  echo "Finished $framework test #$i." >> $out/results.txt
  echo "Finished $framework test #$i."
done

(cd ../shark && . ./stop.sh)

echo "$framework tests finished."

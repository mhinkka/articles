echo "Testing $framework..."

export OUT_DIR=$out/$framework-$frameworkId
echo export OUT_DIR=$out/$framework-$frameworkId
export CONF_DIR=$OUT_DIR/config
echo export CONF_DIR=$OUT_DIR/config
export HADOOP_CONF_DIR=$CONF_DIR/hadoop
echo export HADOOP_CONF_DIR=$CONF_DIR/hadoop
export HIVE_CONF_DIR=$CONF_DIR/hive
echo export HIVE_CONF_DIR=$CONF_DIR/hive
export SPARK_CONF_DIR=$CONF_DIR/spark
echo export SPARK_CONF_DIR=$CONF_DIR/spark
export LOCAL_DIR=$localTemp/spark
echo export LOCAL_DIR=$localTemp/spark
export SPARK_HOME=$HOME/spark/spark
echo export SPARK_HOME=$HOME/spark/spark

TEST_CLASS=$1
echo TEST_CLASS=$1

numRepeats=$NUM_REPEATS
if [ -n "$2" ]; then
  numRepeats=$2
fi

echo numRepeats=$numRepeats

rm -f $SPARK_HOME
ln -s $HOME/spark/spark-1.2.1-bin-hadoop2.4 $SPARK_HOME

echo "Using spark from: $HOME/spark/spark-1.2.1-bin-hadoop2.4"

#export HIVE_BYTES_PER_REDUCER=1000000000 # default
#export HIVE_BYTES_PER_REDUCER=25000000 # slows down on 20M+8nodes
#export HIVE_BYTES_PER_REDUCER=50000000 # ok I guess...

#echo "Copying custom hadoop configuration..."
#export HADOOP_CONF_SOURCE_DIR=$PWD/hadoop-conf

#echo "Using non-native hadoop libraries."

#export HADOOP_LIBRARY_DIR="$HADOOP_HOME/lib-orig"
#(cd ../hive && . ./start.sh)

echo "Initializing and copying configurations..."
(cd ../spark-1.2.1 && . ./init.sh)

#export PATH=$HOME/java/jdk1.7.0_45/bin:$PATH

mkdir $localResults

$SPARK_HOME/sbin/start-all.sh
#sleep 10

echo "Spark servers started..."

echo "Loading test data..."
mkdir -p $OUT_DIR/results
mkdir -p $OUT_DIR/parquet

date >> $OUT_DIR/load-results.txt
withTimeout /usr/bin/time -o $OUT_DIR/load-results.txt -a $SPARK_HOME/bin/spark-submit --executor-memory 16G --total-executor-cores 100 --class $TEST_CLASS script/target/Tester-1.0.jar load $OUT_DIR 1 $OUT_DIR/parquet >> $OUT_DIR/load-results.txt
date >> $OUT_DIR/load-results.txt

echo "Starting test: $TEST_NAME" >> $out/results.txt

echo "Performing tests..."

#Ignore first test run
date >> $OUT_DIR/warm-up-results.txt

withTimeout /usr/bin/time -o $OUT_DIR/warm-up-results.txt -a $SPARK_HOME/bin/spark-submit --executor-memory 16G --total-executor-cores 100 --class $TEST_CLASS script/target/Tester-1.0.jar $TEST_NAME $OUT_DIR 0 $OUT_DIR/parquet >> $OUT_DIR/warm-up-results.txt

date >> $OUT_DIR/warm-up-results.txt
  
for ((i=1; i<=$numRepeats; i++ ))
do
  date >> $out/results.txt
  echo "Starting $framework test #$i..." >> $out/results.txt
  echo "Starting $framework test #$i..."

  withTimeout /usr/bin/time -o $out/results.txt -a $SPARK_HOME/bin/spark-submit --executor-memory 16G --total-executor-cores 100 --class $TEST_CLASS script/target/Tester-1.0.jar $TEST_NAME $OUT_DIR $NUM_REPEATS $OUT_DIR/parquet >> $out/results.txt

  echo "Finished $framework test #$i." >> $out/results.txt
  echo "Finished $framework test #$i."
done

#echo "Going to sleep"
#sleep 7200

(cd ../spark-1.2.1 && . ./stop.sh)

echo "$framework tests finished."

salloc --time=0-04:00:00 --mem-per-cpu=5000 -p short -N 2

export HADOOP_HOME=$HOME/hadoop/hadoop-2.4.0
export HADOOP_YARN_HOME=$HADOOP_HOME
export HADOOP_PREFIX=$HADOOP_HOME
export HIVE_HOME=$HOME/hive/apache-hive-0.13.1-bin
export PRESTO_HOME=$HOME/presto/presto-server-0.75
export SHARK_HOME=~/shark/shark-0.9.1-bin-hadoop2/
export JAVA_HOME=/usr

NUM_REPEATS=10
HDFS_PORT=9000
JOBTRACKER_PORT=9001
HIVE_PORT=9083
PRESTO_PORT=8080
SHARK_PORT=7077
TIME_LIMIT=$(((3 * 60 + 55) * 60)) # seconds: should give us a few minutes of cleanup time over the sbatch limit

START_TIME=$(date +%s)

# Utils
function min { [[ $1 -lt $2 ]] && echo $1 || echo $2; }

function withTimeout
{
  timeRemaining=$((TIME_LIMIT - $(date +%s) + START_TIME))
  if [[ $timeRemaining -le 0 ]]; then
    ret=124
  else
    timeout -sKILL $((timeRemaining+30)) timeout $timeRemaining "$@"
    ret=$?
  fi
  if [[ $ret = 124 || $ret = 137 ]]; then
    echo "!!! TIMED OUT: $@"
    exit 42
  fi
}

# Cleanup function in case we timeout, or if we exit in some other unexpected
# fashion (which shouldn't happen, but it's good to have this for that case as
# well).
#
# Note that this has only 30 seconds (scontrol show config | grep KillWait) to
# complete, so don't try to do too much!
cleanupOnTimeout() {
   (cd hive && . ./stop.sh)

   # Clear the temporary directories everywhere
   echo "Clearing temporary directories..."
   srun --immediate rm -rf $localTemp
   rm -fr $localResults
}


storageFormat="rcfile"
suffix="manual"
NUM_REPEATS=1

out=$(readlink -f $WRKDIR/manual-$SLURM_NNODES-$storageFormat$suffix)

rm -fr $out
mkdir -p $out
chmod 755 $out

echo "Start time: $(date)"
echo "Number of nodes: $SLURM_NNODES"
echo "Storage type: $storageFormat"
echo "Hadoop: $HADOOP_HOME"
echo "HIVE: $HIVE_HOME"
echo "Presto: $PRESTO_HOME"
echo "Shark: $SHARK_HOME"
echo "Spark: $SPARK_HOME"

head -1000 $WRKDIR/103M_events.csv > $out/test.csv

export SCRIPT_ROOT=$PWD
export PATH=$HADOOP_HOME/bin:$HIVE_HOME/bin:$PRESTO_HOME/bin:$PATH

masterHost=$(hostname)
echo "Master host: $(hostname)"

echo "Copying templated configurations..."
#(cd hadoop && . ./deploy.sh)
#(cd hive && . ./deploy.sh)
#(cd presto && . ./deploy.sh)
#(cd shark && . ./deploy.sh)

# Get SLURM info about our configuration (hostnames and job ID)

slaveHostsRootFile=$out/slaves
#srun --immediate hostname | grep -v $masterHost > $slaveHostsRootFile
srun --immediate hostname | grep -v $masterHost > $slaveHostsRootFile-init
for host in $(cat $slaveHostsRootFile-init); do echo "$host-ib" >> $slaveHostsRootFile; done
rm -f $slaveHostsRootFile-init

slaveCount=$(wc -l < $slaveHostsRootFile)
echo "Slave count: $slaveCount"

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#[[ $slaveCount -eq 0 ]] && echo>&2 "Not enough slaves!" && exit 2
echo "Slaves: "
for host in $(cat $slaveHostsRootFile); do echo $host; done

jobID=$SLURM_JOB_ID
echo "Job id: $jobID"

localTemp=/tmp/$USER/triton-$jobID
localResults=/tmp/$USER/results
echo "Local temp dir: $localTemp"
echo "Local results dir: $localResults"

# Make sure everything's dead before we start
echo "Killing all"
killall -q -9 java hive launcher presto-server
for host in $(cat $slaveHostsRootFile); do ssh -o StrictHostKeyChecking=no $host "killall -q -9 java hive launcher presto-server"; done

trap cleanupOnTimeout EXIT

echo "Result directory: $out" > $out/results.txt
date >> $out/results.txt

##############################################################
# Startup complete...

# ... but depending on what you're doing next you might need to sleep for a
# minute or two until everything's fully up and running

#(cd hadoop && . ./test.sh)
#(cd hive && . ./test.sh)

#BEGIN !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!(cd presto && . ./test.sh)

cd presto

echo "Testing presto..."

export OUT_DIR=$out/presto
export CONF_DIR=$OUT_DIR/config
export HADOOP_CONF_DIR=$CONF_DIR/hadoop
export HIVE_CONF_DIR=$CONF_DIR/hive
export PRESTO_CONF_DIR=$PRESTO_HOME/etc
export LOCAL_DIR=$localTemp/presto

export HIVE_BYTES_PER_REDUCER=1000000000 # default
#export HIVE_BYTES_PER_REDUCER=25000000 # slows down on 20M+8nodes
#export HIVE_BYTES_PER_REDUCER=50000000 # ok I guess...

#BEGIN !!!!!!!!!!!!!!!(cd ../hive && . ./start.sh)
cd ../hive

echo "Starting hive..."
#BEGIN !!!!!!!!(cd ../hadoop && . ./start.sh)
cd ../hadoop
echo "Starting hadoop..."

echo "Configuration root directory: $CONF_DIR"
mkdir -p $HADOOP_CONF_DIR
'cp' -f $HADOOP_HOME/conf/* $HADOOP_CONF_DIR/

slaveHostsFile=$HADOOP_CONF_DIR/slaves
rm -f $slaveHostsFile

'cp' -f $slaveHostsRootFile $slaveHostsFile

echo "Copying custom hadoop configuration..."
export HADOOP_CONF_SOURCE_DIR=$PWD/hadoop-conf

echo "Using non-native hadoop libraries."
export HADOOP_LIBRARY_DIR="$HADOOP_HOME/lib-orig"

echo "Copying configurations..."
#(cd ../hadoop && . ./init.sh)

echo "Starting hdfs..."
# Start HDFS everywhere
#confargs="--config $HADOOP_CONF_DIR"
yes Y | $HADOOP_PREFIX/bin/hdfs namenode -format test
#$HADOOP_HOME/bin/start-dfs.sh
#HADOOP_HOME/bin/start-all.sh
$HADOOP_PREFIX/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR --script hdfs start namenode
$HADOOP_PREFIX/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR --script hdfs start datanode
#srun --immediate $HADOOP_PREFIX/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR --script hdfs start datanode


$HADOOP_YARN_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR start resourcemanager
$HADOOP_YARN_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR start nodemanager
#$HADOOP_YARN_HOME/sbin/yarn-daemon.sh start proxyserver --config $HADOOP_CONF_DIR
$HADOOP_PREFIX/sbin/mr-jobhistory-daemon.sh start historyserver --config $HADOOP_CONF_DIR

echo "Hdfs started."

echo "Waiting for everything to start up properly..."
sleep 15

echo "Hadoop started."

#END !!!!!!!!(cd ../hadoop && . ./start.sh)
cd ../hive

echo "Configuration root directory: $CONF_DIR"
mkdir -p $HIVE_CONF_DIR
'cp' -f $HIVE_HOME/conf/* $HIVE_CONF_DIR/

echo "Copying configurations..."
(cd ../hive && . ./init.sh)
(cd ../presto && . ./init.sh)

echo "Starting hive service..."
#$HIVE_HOME/bin/hive --service hiveserver -p $hivePort -v &
#$HIVE_HOME/bin/hive --service hiveserver2 &
withTimeout $HIVE_HOME/bin/hive --config $HIVE_CONF_DIR --service hiveserver -p $HIVE_PORT -v &

echo "Waiting for everything to start up properly..."
sleep 15

if [[ "$storageFormat" == "textfile" ]];
then
  echo "Loading and storing data as TextFile..." >> $OUT_DIR/load-results.txt
  echo "Loading and storing data as TextFile..."
  date >> $OUT_DIR/load-results.txt
  withTimeout /usr/bin/time -o $OUT_DIR/load-results.txt -a $HIVE_HOME/bin/hive --config $HIVE_CONF_DIR -f $out/hive/script/load-textfile.sql >> $OUT_DIR/load-results.t\
xt
else
  echo "Loading and storing data as RCFile..." >> $OUT_DIR/load-results.txt
  echo "Loading and storing data as RCFile..."
  date >> $OUT_DIR/load-results.txt
  withTimeout /usr/bin/time -o $OUT_DIR/load-results.txt -a $HIVE_HOME/bin/hive --config $HIVE_CONF_DIR -f $out/hive/script/load-rcfile.sql >> $OUT_DIR/load-results.txt
fi

##################################################################
#$HIVE_HOME/bin/hive --config $HIVE_CONF_DIR


#END !!!!!!!!!!!!!!!(cd ../hive && . ./start.sh)
cd ../presto

export PRESTO_LOCAL_COPY_DIR=$LOCAL_DIR/presto
export PRESTO_LOCAL_COPY_HOME=$PRESTO_LOCAL_COPY_DIR/$(basename $PRESTO_HOME)
export PRESTO_LOCAL_COPY_CONF_DIR=$PRESTO_LOCAL_COPY_HOME/etc
export PRESTO_LOG_DIR=$OUT_DIR/log

mkdir $localResults

rm -f $PRESTO_CONF_DIR/multi-prog.config
echo 0    $PRESTO_CONF_DIR/coordinator.sh $PRESTO_LOCAL_COPY_HOME $PRESTO_LOG_DIR %t \& > $PRESTO_CONF_DIR/multi-prog.config
for ((i=1; i<$slaveCount; i++ ))
do
  echo $i    $PRESTO_CONF_DIR/worker.sh $PRESTO_LOCAL_COPY_HOME $PRESTO_LOG_DIR %t \& >> $PRESTO_CONF_DIR/multi-prog.config
done
#for ((i=1; i<$slaveCount; i++ ))
#do
#  echo $i    $PRESTO_CONF_DIR/worker.sh %t \& >> $PRESTO_CONF_DIR/multi-prog.config
#done
srun --multi-prog -n$slaveCount $PRESTO_CONF_DIR/multi-prog.config
echo "Presto servers started..."

prestoTestFile=$SCRIPT_ROOT/presto/script/$TEST_NAME.sql
echo "Starting test: $prestoTestFile" >> $out/results.txt

echo "Performing tests..."






#END !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!(cd presto && . ./test.sh)

#(cd shark && . ./test.sh)

date >> $out/results.txt

echo "Test finished..."
echo "Test finished..." >> $out/results.txt

echo "All tests done."

#sleep 3000

(cd hive && . ./stop.sh)

# sed -n -e 's/\(^.*system \)\([^e]*\)\(.*$\)/\2/p' -e 's/Starting \(.*\) test #1\.\.\./\1/p' -e 's!^.*hinkkam2.\(.*\)$!\1!p' < results.txt
# ls */results.txt | xargs sed -n -e 's/\(^.*system \)\([^e]*\)\(.*$\)/\2/p' -e 's/Starting \(.*\) test #1\.\.\./\1/p' -e 's!^Result.*hinkkam2.\(.*\)$!\1!p'

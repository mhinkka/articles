#!/bin/bash
#Usage: sbatch triton.sh <name> <storage format> <suffix> <number of events> <number of repeats> <test name> <frameworks>
#Defaults:
# <storage format>: rcfile
# <suffix>: <empty>
# <number of events>: 1000
# <number of repeats>: 1
# <test name>: flows
# <frameworks>: "hive presto spark"
#Check memory usage: sacct -j -l <job id> | less -S

##SBATCH --time=0-00:15:00 --mem-per-cpu=500
#SBATCH -o out.log
#SBATCH -e error.log
#SBATCH -p ${LAUNCHER_TAG_PARTITION}
#SBATCH --nodes ${LAUNCHER_TAG_NUM_NODES}
#SBATCH --ntasks ${LAUNCHER_TAG_NUM_NODES}
#SBATCH --cpus-per-task=12
##SBATCH --mem-per-cpu=5000
##SBATCH --qos=short
#SBATCH --exclusive
#SBATCH --time=0-04:00:00

# There is a banch of Opterons with 64GB ech:  64GB cn[81-112], then Xeons
# Westmere cn[225-248] have 96GB, and recently installed IvyBridges ivy[17-24]
# have 256G each.
# 336 compute nodes HP ProLiant BL465c G6, each equipped with 2x Six-Core AMD Opteron 2435 
# 2.6GHz processors. 192 compute nodes cn[01-64,68-80,249-360] have 32GB, 32 have 64GB 
# cn[81-112], 112 others have 16GB cn[361-488], 4xDDR Infiniband port and local 10k SAS 
# drive with diskspace available ~215GB.
# 142 compute nodes HP SL390s G7, each equiped with 2x Intel Xeon X5650 2.67GHz (Westmere 
# six-core each). 118 compute nodes cn[113-224], tb[003-008] have 48 GB of DDR3-1066 memory,
# others cn[225-248] have 96GB, each node has 4xQDR Infiniband port,  cn[113-224], 
# tb[003-008] have about 830 GB of local diskspace (2 striped 7.2k SATA drives), while 
# cn[225-248] about 380GB on single drive. 16 nodes have by two additional SATA drives.
# 10 compute nodes gpu[001-011] are HP SL390s G7 for gpu computing. Same configuration as 
# above but they are 2U high and have 2x Tesla 2090 card each.
# 2 fat nodes HP DL580 G7 4U, 4x Xeon, 6x SATA drives, 1TB of DDR3-1066 memory each and 
# 4xQDR Infiniband port.
# 48 compute nodes ivy[01-48] are HP SL230s G8 with 2x Xeon E5 2680 v2 10-core CPUs. First 
# 24 nodes have 256 GB of DDR3-1667 memory and the other 24 are equipped with 64 GB.

#SBATCH -w ${LAUNCHER_TAG_NODES}

##SBATCH --constraint=opteron
##SBATCH --constraint=xeonib
##SBATCH --constraint=xeon
##SBATCH --constraint=[xeon|xeonib]

##SBATCH --open-mode=append
##SBATCH --mem-per-cpu=5000
##SBATCH --mail-user=markku.hinkka@aalto.fi
##SBATCH --mail-type=ALL

#salloc --time=0-04:00:00 --mem-per-cpu=5000 -p short -N 2

export HADOOP_HOME=$HOME/hadoop/hadoop
export HADOOP_YARN_HOME=$HADOOP_HOME
export HADOOP_PREFIX=$HADOOP_HOME
export HIVE_HOME=$HOME/hive/apache-hive-0.13.1-bin
#export PRESTO_HOME=$HOME/presto/presto-server-0.75
export SHARK_HOME=~/shark/shark-0.9.1-bin-hadoop2
export SPARK_HOME=~/spark/spark-1.0.2-bin-hadoop2
export JAVA_HOME=/usr
export SCALA_HOME=~/scala/scala

NUM_REPEATS=10
HDFS_PORT=9000
JOBTRACKER_PORT=9001
HIVE_PORT=9083
PRESTO_PORT=8080
SHARK_PORT=7077
SPARK_PORT=7077

TIME_LIMIT=$(((3 * 60 + 55) * 60)) # seconds: should give us a few minutes of cleanup time over the sbatch limit
TIME_LIMIT_AFTER_BEING_LOCKED=$(((3 * 60) * 60)) # seconds: should give us a one hour to run the test

START_TIME=$(date +%s)

echo "Script start time: $START_TIME"

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
    echo "Killed/timed out: $@"
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
  if [[ -d $LOCK ]]; then
    rm -fr $LOCK

    (cd hive && . ./stop.sh)
    (cd spark && . ./stop.sh)

    # Clear the temporary directories everywhere
    echo "Clearing temporary directories..."
    srun --immediate rm -rf $localTemp
    rm -fr $localResults
  fi
}


storageFormat=$2
if [ -z "$2" ]; then
  storageFormat="rcfile"
fi

suffix=""
if [ -n "$3" ]; then
  suffix="-$3"
fi

if [ -n "$4" ]; then
  NUM_EVENTS=$4
else
  NUM_EVENTS=1000
fi

if [ -n "$5" ]; then
  NUM_REPEATS=$5
else
  NUM_REPEATS=1
fi

if [ -n "$6" ]; then
  TEST_NAME=$6
else
  TEST_NAME=flows
fi

if [ -n "$7" ]; then
  FRAMEWORKS=$7
else
  FRAMEWORKS="hive presto spark"
fi


echo $WRKDIR/runs/$1-$SLURM_NNODES-$storageFormat$suffix-$TEST_NAME
# Fetch command line arguments
out=$(readlink -f $WRKDIR/runs/$1-$SLURM_NNODES-$storageFormat$suffix-$TEST_NAME)

[[ -z "$out" ]] && exit 1
if [[ -e $out ]]; then
   if [[ ! -d $out ]]; then
      echo>&2 "$out is not a directory!"
      exit 1
   fi
   rm -fr $out
fi
mkdir -p $out
chmod 755 $out

exec &>$out/script.log

echo "Start time: $(date)"
echo "Output directory: $out"
echo "Number of nodes: $SLURM_NNODES"
echo "Storage type: $storageFormat"
echo "Number of events: $NUM_EVENTS"
echo "Number of repeats: $NUM_REPEATS"
echo "Test name: $TEST_NAME"
echo "Hadoop: $HADOOP_HOME"
echo "HIVE: $HIVE_HOME"
echo "Presto: $PRESTO_HOME"
echo "Shark: $SHARK_HOME"
echo "Spark: $SPARK_HOME"
echo "Frameworks to test: $FRAMEWORKS"

LOCK=$WRKDIR/runs/TEST_CURRENTLY_RUNNING
until mkdir $LOCK; do
  timeRemaining=$((TIME_LIMIT_AFTER_BEING_LOCKED - $(date +%s) + START_TIME))
  if [[ $timeRemaining -le 0 ]]; then
    echo "Unable to start the test run due to other test being run at the same time"
    exit 6
  fi
  echo "$(date) Another test is already running. Retrying in one minute."
  sleep 60
done

echo $out >> $LOCK/$SLURM_JOB_ID

#sleep 7200

export SCRIPT_ROOT=$PWD

echo "Copying test scripts from $SCRIPT_ROOT to $out/scripts.tgz"
tar --exclude='.git' -czPf $out/scripts.tgz $SCRIPT_ROOT

echo "Copying test data consisting of $NUM_EVENTS events."
head -$NUM_EVENTS $WRKDIR/test.csv > $out/test.csv

export PATH=$HADOOP_HOME/bin:$HIVE_HOME/bin:$PRESTO_HOME/bin:$PATH

masterHost=$(hostname)
echo "Master host: $(hostname)"

echo "Copying templated configurations..."
(cd presto && . ./deploy.sh)
(cd shark && . ./deploy.sh)

# Get SLURM info about our configuration (hostnames and job ID)

slaveHostsRootFile=$out/slaves
#srun --immediate hostname | grep -v $masterHost > $slaveHostsRootFile
srun --immediate hostname | grep -v $masterHost > $slaveHostsRootFile-init
for host in $(cat $slaveHostsRootFile-init); do echo "$host-ib" >> $slaveHostsRootFile; done
rm -f $slaveHostsRootFile-init

slaveCount=$(wc -l < $slaveHostsRootFile)
nodesFile=$out/nodes
cp $slaveHostsRootFile $nodesFile
echo "$masterHost-ib" >> $nodesFile

echo "Slave count: $slaveCount"
[[ $slaveCount -eq 0 ]] && echo>&2 "Not enough slaves!" && exit 2
echo "Slaves: "
for host in $(cat $slaveHostsRootFile); do echo $host; done

jobID=$SLURM_JOB_ID
echo "Job id: $jobID"

echo "Supplied TMPDIR: $TMPDIR"

if [ -z "$TMPDIR" ]; then
  TMPDIR="/tmp/"
fi

localTemp=$TMPDIR$USER/triton-$jobID
localResults=$TMPDIR$USER/results
echo "Local temp dir: $localTemp"
echo "Local results dir: $localResults"

# Make sure everything's dead before we start
echo "Killing all"
killall -q -9 java hive launcher presto-server
for host in $(cat $slaveHostsRootFile); do ssh -o StrictHostKeyChecking=no $host "killall -q -9 java hive launcher presto-server"; done

# Uncomment the following two lines in order to automatically delete all the files in the 
# local directories of the worker hosts before starting the actual tests.
# echo "Deleting old local files under /local..."
# for host in $(cat $nodesFile); do ssh -o StrictHostKeyChecking=no $host "find /local -maxdepth 1 -user $USER | xargs rm -fr"; done


trap cleanupOnTimeout EXIT

echo "Result directory: $out" > $out/results.txt
date >> $out/results.txt

##############################################################
# Startup complete...

# ... but depending on what you're doing next you might need to sleep for a
# minute or two until everything's fully up and running

frameworkId=0
for framework in $FRAMEWORKS; do
    frameworkId=$(($frameworkId + 1))

    echo "Starting to test framework: $framework (id: $frameworkId) at $(date --rfc-3339=seconds)"

    #(cd hadoop && . ./test.sh)

    case "$framework" in
	hive)
	    (cd hive && . ./test-1.2.1.sh)
	    ;;
	hive-parquet)
	    TEST_PREFIX="parquet-"
	    (cd hive && . ./test-1.2.1.sh)
	    ;;
	hive2)
	    (cd hive && . ./test.sh)
	    ;;
	presto)
	    if [ "$TEST_NAME" = "variations" ]; then 
		echo "Presto doesn't support $TEST_NAME-test. Skipped..."
	    else
		(cd presto && . ./test-1.2.1.sh)
                #  (cd presto && . ./test-1.2.1-0.60.sh)
	    fi
	    ;;
	presto-parquet)
	    TEST_PREFIX="parquet-"
	    if [ "$TEST_NAME" = "variations" ]; then 
		echo "Presto doesn't support $TEST_NAME-test. Skipped..."
	    else
		(cd presto && . ./test-1.2.1.sh)
                #  (cd presto && . ./test-1.2.1-0.60.sh)
	    fi
	    ;;
	presto2)
	    if [ "$TEST_NAME" = "variations" ]; then 
		echo "Presto doesn't support $TEST_NAME-test. Skipped..."
	    else
                (cd presto && . ./test.sh)
	    fi
	    ;;
	spark)
	    (cd spark && . ./test.sh my.Tester)
	    ;;
	spark-parquet)
	    (cd spark && . ./test.sh my.TesterParquet)
	    ;;
	spark-caching)
	    (cd spark && . ./test.sh my.TesterCaching 1)
	    ;;
	spark2)
	    (cd spark-1.2.1 && . ./test.sh my.Tester)
	    ;;
	spark2-parquet)
	    (cd spark-1.2.1 && . ./test.sh my.TesterParquet)
	    ;;
	spark2-caching)
	    (cd spark-1.2.1 && . ./test.sh my.TesterCaching 1)
	    ;;
    esac
done;

rm -fr $LOCK

date >> $out/results.txt

echo "Test finished..."
echo "Test finished..." >> $out/results.txt

echo "All tests done."
echo "End time: $(date)"

#sleep 3000

# sed -n -e 's/\(^.*system \)\([^e]*\)\(.*$\)/\2/p' -e 's/Starting \(.*\) test #1\.\.\./\1/p' -e 's!^.*hinkkam2.\(.*\)$!\1!p' < results.txt
# ls */results.txt | xargs sed -n -e 's/\(^.*system \)\([^e]*\)\(.*$\)/\2/p' -e 's/Starting \(.*\) test #1\.\.\./\1/p' -e 's!^Result.*hinkkam2.\(.*\)$!\1!p'

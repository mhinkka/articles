#!/bin/bash
#Usage: launcher.sh <run name> <script template> <test names> <node counts> <number of events> <number of repeats> <frameworks to test>
#Example: . launcher.sh test triton.template.sh "flows variations" "4 8" 10000000 3 "hive hive2 presto presto2 spark spark-parquet spark-caching"

runName=$1
if [ -z "$1" ]; then
  runName="unnamed"
fi

scriptTemplate=$2
if [ -z "$2" ]; then
  scriptTemplate=triton.template.sh
fi

allTestNames=$3
if [ -z "$3" ]; then
#  allTestNames="flows variations"
  allTestNames="flows"
fi

allNodeCounts=$4
if [ -z "$4" ]; then
#  allNodeCounts="4 8 16"
  allNodeCounts="4"
fi

allNumEvents=$5
if [ -z "$5" ]; then
#  allNumEvents="1000 5000 10000 20000 50000 100000 200000 500000 1000000"
  allNumEvents="5000"
fi

numRepeats=$6
if [ -z "$6" ]; then
  numRepeats=1
fi

frameworks=$7
if [ -z "$7" ]; then
  frameworks="spark presto hive"
fi

echo "Launching test labeled $runName..."

LAUNCHER_DIR=$PWD/launchers
rm -fr $LAUNCHER_DIR
mkdir -p $LAUNCHER_DIR

for nodeCount in $allNodeCounts; do
    echo "Generating script for node count: $nodeCount"

    if [ $nodeCount -gt 8 ]; then
	partition="pbatch"
	lastNode=340
    else
	partition="short"
	lastNode=480
    fi

    firstNode=$(($lastNode - $nodeCount + 1))

    f=$LAUNCHER_DIR/triton-$nodeCount.sh
    rm -f $f
    sed < $scriptTemplate > $f "
      s/\${LAUNCHER_TAG_NUM_NODES}/$nodeCount/
      s/\${LAUNCHER_TAG_NODES}/cn[$firstNode-$lastNode]/
      s/\${LAUNCHER_TAG_PARTITION}/$partition/
    "
    chmod +x $f
done;

i=0

for testName in $allTestNames; do
    for nodeCount in $allNodeCounts; do
	if [ $nodeCount -gt 8 ]; then
	    lastNode=340
	else
	    lastNode=480
	fi

	firstNode=$(($lastNode - $nodeCount + 1))
	nodes="cn[$firstNode-$lastNode]"

	for numEvents in $allNumEvents; do
	    echo "Running $numRepeats test(s) of type $testName using $nodeCount cores on event log containing $numEvents events using nodes $nodes to test frameworks: $frameworks."
	    i=$(($i+1))
            sbatch $LAUNCHER_DIR/triton-$nodeCount.sh $runName rcfile $numEvents $numEvents $numRepeats $testName "$frameworks"
#            . $LAUNCHER_DIR/triton-$nodeCount.sh $runName rcfile $numEvents $numEvents $numRepeats $testName $frameworks
	done;
    done;
done;
echo "Launched total of $i tests."
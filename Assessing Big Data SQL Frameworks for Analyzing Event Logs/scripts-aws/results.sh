#!/bin/bash
RUNS_ROOT_PATH=$PWD/results
#RUNS_ROOT_PATH=/home/ubuntu/aws/results/test-large-flows-10000000/
RESULTS_DIR=$PWD/generated

'rm' -fr $RESULTS_DIR
mkdir -p $RESULTS_DIR

showResults()
{
    files=$1
    for fileName in $files; do
	gawk -v resultDir="$RESULTS_DIR" -v numNodes="4" -f ./results.awk $fileName
    done;
}

echo "Successful tests:"
files=$(find $RUNS_ROOT_PATH -path "*/measurements.txt")
showResults "$files"

echo "Finalizing results..."
files=$(find $RESULTS_DIR/ -type f)
for fileName in $files; do
        newFileName="$(basename "$fileName").dat"
	    sort -gk 1 "$fileName" > $RESULTS_DIR/$newFileName
	        'rm' -f $fileName;
		done;

rm -fr /tmp/firstvalidpresto.tmp
rm -fr /tmp/firstvalidsparkflows.tmp

#!/bin/bash
RUNS_ROOT_PATH=$WRKDIR/runs
ls $RUNS_ROOT_PATH/*/*/load-results.txt | xargs -n 1 ./load-results-for-one.sh

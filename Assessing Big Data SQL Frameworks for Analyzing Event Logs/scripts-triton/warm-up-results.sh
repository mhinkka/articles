#!/bin/bash
RUNS_ROOT_PATH=$WRKDIR/runs
ls $RUNS_ROOT_PATH/*/*/warm-up-results.txt | xargs -n 1 ./warm-up-results-for-one.sh

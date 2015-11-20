#!/bin/bash
# Script to multiply the number of events in a event log file. 
# For every iteration, an unique trace identifier prefix is added to events.
# Usage: ./buildtestdata.sh <repeat count> <event log filename>
# Example: ./buildtestdata.sh 2 bpi_2013_challenge.csv
seq -w 1 $1 | xargs -I COUNT awk '{print "COUNT" $0}' $2

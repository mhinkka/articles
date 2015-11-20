#!/bin/bash

for host in $(cat ../hosts); do 
    echo "Querying Presto status in $host..."
    ssh -i $PEM -o StrictHostKeyChecking=no $host "$PRESTO_HOME/bin/launcher status"
done;


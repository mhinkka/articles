#!/bin/bash
export PEM=/ebsvol1/aws.pem

for host in $(cat ../hosts); do 
    echo "Stopping Presto in $host..."
    ssh -i $PEM -o StrictHostKeyChecking=no $host "$PRESTO_HOME/bin/launcher stop"
done;


#!/bin/bash
alias sparksh='sudo -u spark spark-shell --executor-memory 512m'
export JAVA_HOME=/usr/lib/jvm/java-7-oracle-cloudera
export PATH=$JAVA_HOME:$PATH
export CLASSPATH=$(hadoop classpath)
export TEST_ROOT=$HOME/aws
export PRESTO_HOME=/usr/bin/presto-server

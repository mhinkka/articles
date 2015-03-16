echo "Initializing shark config..."
hiveMetastorePath=$out/hive/Metastore
rm -fr $hiveMetastorePath
hiveTempStatsStorePath=$out/hive/TempStatsStore
rm -fr $hiveTempStatsStorePath

hiveLogDir=$out/hive/log
hiveQuerylogLocation=$out/hive/querylog
hiveScratchDir=$LOCAL_DIR/hiveScratchDir

echo "Hive(shark)BytesPerReducer: $HIVE_BYTES_PER_REDUCER"

for f in $SHARK_HOME/conf/*-site.xml; do
   f2=$SHARK_CONF_DIR/$(basename $f)
   rm -f $f2
   sed < $f > $f2 \
   "/\${HADOOP_TRITON/ {
      s/\${HADOOP_TRITON_NAMENODE}/$masterHost/
      s/\${HADOOP_TRITON_JOBTRACKER}/$masterHost/
      s/\${HADOOP_TRITON_JOBTRACKER_PORT}/$JOBTRACKER_PORT/
      s/\${HADOOP_TRITON_HDFS_PORT}/$HDFS_PORT/
      s/\${HADOOP_TRITON_HIVE_BYTES_PER_REDUCER}/$HIVE_BYTES_PER_REDUCER/
      s:\${HADOOP_TRITON_HIVE_METASTORE_PATH}:$hiveMetastorePath:
      s:\${HADOOP_TRITON_HIVE_TEMP_STATS_STORE_PATH}:$hiveTempStatsStorePath:
      s:\${HADOOP_TRITON_TMP}:$LOCAL_DIR:
      s:\${HADOOP_TRITON_HIVE_SCRATCHDIR}:$hiveScratchDir:
      s:\${HADOOP_TRITON_HIVE_QUERYLOG_LOCATION}:$hiveQuerylogLocation:
      s:\${HADOOP_TRITON_HIVE_LOG_DIR}:$hiveLogDir:
   }"
done

rm -f $SHARK_CONF_DIR/hive-env.sh
echo "SHARK_CONF_DIR=$SHARK_CONF_DIR; HIVE_CONF_DIR=$SHARK_CONF_DIR;" > $SHARK_CONF_DIR/hive-env.sh

hdfs dfs -mkdir -p /home/hinkkam2/git/hive/udf/
hdfs dfs -copyFromLocal udf/CollectAll.jar /home/hinkkam2/git/hive/udf/CollectAll.jar
hdfs dfs -mkdir -p /tmp
hdfs dfs -chmod g+w /tmp
hdfs dfs -mkdir -p /user/hive/warehouse
hdfs dfs -chmod g+w /user/hive/warehouse

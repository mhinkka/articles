echo "Initializing hive config..."

if [ -z "$HIVE_CONF_SOURCE_DIR" ]; then
  HIVE_CONF_SOURCE_DIR="conf"
fi

echo "Copying configuration from: $HIVE_CONF_SOURCE_DIR"

hiveMetastorePath=$OUT_DIR/Metastore
rm -fr $hiveMetastorePath
hiveTempStatsStorePath=$OUT_DIR/TempStatsStore
rm -fr $hiveTempStatsStorePath

hiveLogDir=$OUT_DIR/log
hiveQuerylogLocation=$OUT_DIR/querylog
hiveScratchDir=$LOCAL_DIR/hiveScratchDir
mkdir -p $hiveLogDir
chmod 1777 $hiveLogDir
mkdir -p $hiveQuerylogLocation
chmod 1777 $hiveQuerylogLocation

echo "HiveBytesPerReducer: $HIVE_BYTES_PER_REDUCER"

for f in $HIVE_CONF_SOURCE_DIR/*-site.xml; do
   f2=$HIVE_CONF_DIR/$(basename $f)
   rm -f $f2
   sed < $f > $f2 \
   "/\${HADOOP_TRITON/ {
      s/\${HADOOP_TRITON_NAMENODE}/$masterHost/
      s/\${HADOOP_TRITON_JOBTRACKER}/$masterHost/
      s/\${HADOOP_TRITON_JOBTRACKER_PORT}/$JOBTRACKER_PORT/
      s/\${HADOOP_TRITON_HDFS_PORT}/$HDFS_PORT/
      s/\${HADOOP_TRITON_HIVE_PORT}/$HIVE_PORT/
      s/\${HADOOP_TRITON_HIVE_HOST}/$masterHost/
      s/\${HADOOP_TRITON_HIVE_BYTES_PER_REDUCER}/$HIVE_BYTES_PER_REDUCER/
      s:\${HADOOP_TRITON_HIVE_METASTORE_PATH}:$hiveMetastorePath:
      s:\${HADOOP_TRITON_HIVE_TEMP_STATS_STORE_PATH}:$hiveTempStatsStorePath:
      s:\${HADOOP_TRITON_TMP}:$LOCAL_DIR:
      s:\${HADOOP_TRITON_HIVE_SCRATCHDIR}:$hiveScratchDir:
      s:\${HADOOP_TRITON_HIVE_QUERYLOG_LOCATION}:$hiveQuerylogLocation:
      s:\${HADOOP_TRITON_HIVE_LOG_DIR}:$hiveLogDir:
   }"
done

rm -f $HIVE_CONF_DIR/hive-env.sh
#sed < $HIVE_CONF_SOURCE_DIR/hive-env.sh > $HIVE_CONF_DIR/hive-env.sh "1i \
#HIVE_CONF_DIR=$HIVE_CONF_DIR; \
#"
echo "HIVE_CONF_DIR=$HIVE_CONF_DIR;" > $HIVE_CONF_DIR/hive-env.sh

if [ -z "$TEST_DATA_FILE" ]; then
  TEST_DATA_FILE="$out/test.csv"
fi

echo "Loading test data from $TEST_DATA_FILE"

# Move scripts to target
mkdir -p $OUT_DIR/script
for f in script/*; do
   f2=$OUT_DIR/script/$(basename $f)
   rm -f $f2
   sed < $f > $f2 \
   "/\${HADOOP_TRITON/ {
      s:\${HADOOP_TRITON_TARGET}:$out:
      s:\${HADOOP_TRITON_RESULT_DIR}:$OUT_DIR/results:
      s:\${HADOOP_TRITON_SOURCE_DIR}:$OUT_DIR:
      s:\${HADOOP_TRITON_TEST_DATA_FILE}:$TEST_DATA_FILE:
   }"
done

mkdir -p $OUT_DIR/udf
'cp' -fr udf/* $OUT_DIR/udf


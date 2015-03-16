echo "Initializing shark config..."
mkdir -p $SPARK_CONF_DIR

'cp' -f $slaveHostsRootFile $SPARK_CONF_DIR/

for f in conf/*; do
   f2=$SPARK_CONF_DIR/$(basename $f)
   rm -f $f2
   sed < $f > $f2 \
   "/\${HADOOP_TRITON/ {
      s/\${HADOOP_TRITON_NAMENODE}/$masterHost/
      s/\${HADOOP_TRITON_SPARK_PORT}/$SPARK_PORT/
      s:\${HADOOP_TRITON_OUTPUT_DIR}:$OUT_DIR:
      s:\${HADOOP_TRITON_LOCAL_DIR}:$LOCAL_DIR:
   }"
done

# Copy all configurations to spark home
'cp' -f $SPARK_CONF_DIR/* $SPARK_HOME/conf/

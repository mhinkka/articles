echo "Starting hive..."

echo "Configuration root directory: $HIVE_CONF_DIR"
mkdir -p $HIVE_CONF_DIR
'cp' -f $HIVE_HOME/conf/* $HIVE_CONF_DIR/

echo "Copying configurations..."
(cd ../hive && . ./init.sh)

# Copy configurations back to HOME after modifications since e.g. hive startup requires them.
# This is required for hadoop configs. Not sure about hive, but added here just to be safe.
'cp' -f $HIVE_CONF_DIR/* $HIVE_HOME/conf/

echo "Starting hive service..."

echo withTimeout $HIVE_HOME/bin/hive --config $HIVE_CONF_DIR --service hiveserver -p $HIVE_PORT -v --hiveconf hive.root.logger=INFO,console
withTimeout $HIVE_HOME/bin/hive --config $HIVE_CONF_DIR --service hiveserver -p $HIVE_PORT -v --hiveconf hive.root.logger=INFO,console &
#withTimeout $HIVE_HOME/bin/hiveserver2 &

echo "Waiting for everything to start up properly..."
sleep 15

if [[ "$storageFormat" == "textfile" ]];
then
  echo "Loading and storing data as TextFile..." >> $OUT_DIR/load-results.txt
  echo "Loading and storing data as TextFile..."
  date >> $OUT_DIR/load-results.txt
  withTimeout /usr/bin/time -o $OUT_DIR/load-results.txt -a $HIVE_HOME/bin/hive --config $HIVE_CONF_DIR -f $OUT_DIR/script/${TEST_PREFIX}load-textfile.sql >> $OUT_DIR/load-results.txt
#  withTimeout /usr/bin/time -o $OUT_DIR/load-results.txt -a beeline -n $HIVE_USER -u $HIVE_CONNECTION_STRING -f $OUT_DIR/script/${TEST_PREFIX}load-textfile.sql >> $OUT_DIR/load-results.txt
elif [[ "$storageFormat" == "presto" ]];
then
  echo "Loading and storing data in RCFile with special datetime handling for presto..." >> $OUT_DIR/load-results.txt
  echo "Loading and storing data as RCFile with special datetime handling for presto..."
  date >> $OUT_DIR/load-results.txt
  withTimeout /usr/bin/time -o $OUT_DIR/load-results.txt -a $HIVE_HOME/bin/hive --config $HIVE_CONF_DIR -f $OUT_DIR/script/${TEST_PREFIX}load-presto.sql >> $OUT_DIR/load-results.txt
#  withTimeout /usr/bin/time -o $OUT_DIR/load-results.txt -a beeline -n $HIVE_USER -u $HIVE_CONNECTION_STRING -f $OUT_DIR/script/${TEST_PREFIX}load-textfile.sql >> $OUT_DIR/load-results.txt
else
  echo "Loading and storing data as RCFile..." >> $OUT_DIR/load-results.txt
  echo "Loading and storing data as RCFile..."
  date >> $OUT_DIR/load-results.txt
  withTimeout /usr/bin/time -o $OUT_DIR/load-results.txt -a $HIVE_HOME/bin/hive --config $HIVE_CONF_DIR -f $OUT_DIR/script/${TEST_PREFIX}load-rcfile.sql >> $OUT_DIR/load-results.txt
#  withTimeout /usr/bin/time -o $OUT_DIR/load-results.txt -a beeline -n $HIVE_USER -u $HIVE_CONNECTION_STRING -f $OUT_DIR/script/${TEST_PREFIX}load-rcfile.sql >> $OUT_DIR/load-results.txt
fi

date >> $OUT_DIR/load-results.txt

#'cp' -f $out/results.txt $out/warm-up-results.txt

echo "Hive started."

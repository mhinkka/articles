echo "Starting shark..."
(cd ../hadoop && . ./start.sh)

echo "Configuration root directory: $CONF_DIR"
mkdir -p $HIVE_CONF_DIR
'cp' -f $HIVE_HOME/conf/* $HIVE_CONF_DIR/

echo "Copying configurations..."
(cd ../hive && . ./init.sh)
(cd ../presto && . ./init.sh)

echo "Starting hive service..."
#$HIVE_HOME/bin/hive --service hiveserver -p $hivePort -v &
withTimeout $HIVE_HOME/bin/shark --config $HIVE_CONF_DIR --service hiveserver -p $HIVE_PORT -v &

echo "Waiting for everything to start up properly..."
sleep 15

if [[ "$storageFormat" == "textfile" ]];
then
  echo "Loading and storing data as TextFile..." >> $OUT_DIR/load-results.txt
  echo "Loading and storing data as TextFile..."
  date >> $OUT_DIR/load-results.txt
  withTimeout /usr/bin/time -o $OUT_DIR/load-results.txt -a $HIVE_HOME/bin/shark --config $HIVE_CONF_DIR -f $out/hive/script/load-textfile.sql >> $OUT_DIR/load-results.txt
else
  echo "Loading and storing data as RCFile..." >> $OUT_DIR/load-results.txt
  echo "Loading and storing data as RCFile..."
  date >> $OUT_DIR/load-results.txt
  withTimeout /usr/bin/time -o $OUT_DIR/load-results.txt -a $HIVE_HOME/bin/shark --config $HIVE_CONF_DIR -f $out/hive/script/load-rcfile.sql >> $OUT_DIR/load-results.txt
fi

date >> $OUT_DIR/load-results.txt

#'cp' -f $out/results.txt $out/warm-up-results.txt

echo "Shark started."

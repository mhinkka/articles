echo "Initializing hadoop config..."

if [ -z "$HADOOP_CONF_SOURCE_DIR" ]; then
  HADOOP_CONF_SOURCE_DIR="conf"
fi

echo "Copying configuration from: $HADOOP_CONF_SOURCE_DIR"

if [ -z "$HADOOP_LIBRARY_DIR" ]; then
  HADOOP_LIBRARY_DIR="$HADOOP_HOME/lib-compiled"
fi

if [ -z "$HADOOP_FRAMEWORK_NAME" ]; then
  HADOOP_LIBRARY_DIR="classic"
fi

if [[ -d $HADOOP_LIBRARY_DIR ]]; then 
  echo "Using hadoop libraries from $HADOOP_LIBRARY_DIR"
  rm -f $HADOOP_HOME/lib
  ln -s $HADOOP_LIBRARY_DIR $HADOOP_HOME/lib 
fi

export HADOOP_IDENT_STRING=$USER-$jobID
export HADOOP_PID_DIR=$LOCAL_DIR/hadoop-pids

echo "Local temp dir: $LOCAL_DIR"
echo "Hadoop log dir: $HADOOP_LOG_DIR"
echo "Hadoop pid dir: $HADOOP_PID_DIR"
dfsDomainSocketPath=$out/DfsDomainSocketPath
#mkdir -p $dfsDomainSocketPath
dfsDataDir=$LOCAL_DIR/DfsDataDir
dfsNamenodeNameDir=$LOCAL_DIR/DfsNamenodeNameDir
mkdir -p $dfsNamenodeNameDir
dfsUserName=$USER

mkdir -p $HADOOP_LOG_DIR $HADOOP_PID_DIR
for f in $HADOOP_CONF_SOURCE_DIR/*-site.xml; do
   f2=$HADOOP_CONF_DIR/$(basename $f)
   rm -f $f2
   sed < $f > $f2 \
   "/\${HADOOP_TRITON/ {
      s/\${HADOOP_TRITON_NAMENODE}/$masterHost/
      s/\${HADOOP_TRITON_JOBTRACKER}/$masterHost/
      s/\${HADOOP_TRITON_FRAMEWORK_NAME}/$HADOOP_FRAMEWORK_NAME/
      s/\${HADOOP_TRITON_JOBTRACKER_PORT}/$JOBTRACKER_PORT/
      s/\${HADOOP_TRITON_HDFS_PORT}/$HDFS_PORT/
      s/\${HADOOP_TRITON_DFS_REPLICATION}/$(min 3 $slaveCount)/
      s/\${HADOOP_TRITON_DFS_USER}/$dfsUserName/
      s:\${HADOOP_TRITON_TMP}:$LOCAL_DIR:
      s:\${HADOOP_TRITON_DFS_DATA_DIR}:$dfsDataDir:
      s:\${HADOOP_TRITON_DFS_NAMENODE_NAME_DIR}:$dfsNamenodeNameDir:
      s:\${HADOOP_TRITON_DFS_DOMAIN_SOCKET_PATH}:$dfsDomainSocketPath:
   }"
done

rm -f $HADOOP_CONF_DIR/hadoop-env.sh
touch $HADOOP_CONF_SOURCE_DIR/hadoop-env.sh
cp $HADOOP_CONF_SOURCE_DIR/hadoop-env.sh $HADOOP_CONF_DIR/hadoop-env.sh
echo "\
HADOOP_CONF_DIR=$HADOOP_CONF_DIR; \
HADOOP_LOG_DIR=$HADOOP_LOG_DIR; \
HADOOP_IDENT_STRING=$HADOOP_IDENT_STRING; \
HADOOP_PID_DIR=$HADOOP_PID_DIR; \
" >> $HADOOP_CONF_DIR/hadoop-env.sh

rm -f $HADOOP_CONF_DIR/yarn-env.sh
touch $HADOOP_CONF_SOURCE_DIR/yarn-env.sh
cp $HADOOP_CONF_SOURCE_DIR/yarn-env.sh $HADOOP_CONF_DIR/yarn-env.sh
echo "\
YARN_LOG_DIR=$HADOOP_LOG_DIR; \
" >> $HADOOP_CONF_DIR/yarn-env.sh

echo "
<configuration>
  <property>
    <name>yarn.scheduler.capacity.root.queues</name>
    <value>a,b</value>
    <description>The queues at the this level (root is the root queue).
    </description>
  </property>
  <property>
    <name>yarn.scheduler.capacity.root.a.capacity</name>
    <value>50</value>
    <description>
Queue capacity in percentage (%) as a float (e.g. 12.5). The sum of capacities for all queues, at each level, must be equal to 100. Applications in the queue may consume more resources than the queue's capacity if there are free resources, providing elasticity.
    </description>
  </property>
  <property>
    <name>yarn.scheduler.capacity.root.b.capacity</name>
    <value>50</value>
    <description>
Queue capacity in percentage (%) as a float (e.g. 12.5). The sum of capacities for all queues, at each level, must be equal to 100. Applications in the queue may consume more resources than the queue's capacity if there are free resources, providing elasticity.
    </description>
  </property>
</configuration>
" > $HADOOP_CONF_DIR/capacity-scheduler.xml

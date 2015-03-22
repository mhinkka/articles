export JAVA_HOME=/usr/lib/jvm/java-1.6.0-openjdk-1.6.0.34.x86_64
export HADOOP_HOME=~/hadoop/hadoop
export HADOOP_PREFIX=$HADOOP_HOME
export HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_HOME/lib/native
export HADOOP_OPTS="-Djava.library.path=$HADOOP_HOME/lib"
export HADOOP_YARN_HOME=$HADOOP_HOME
export HIVE_HOME=~/hive/apache-hive-0.13.1-bin
export PRESTO_HOME=~/presto/presto-server-0.75
export PRESTO_DISCOVERY_HOME=~/presto/discovery-server-1.16
export SHARK_HOME=~/shark/shark-0.9.1-bin-hadoop2
export SCALA_HOME=~/scala/scala
export SPARK_HOME=~/spark/spark
export MAVEN_HOME=~/maven/apache-maven-3.2.5

export PATH=$HADOOP_HOME/bin:$HIVE_HOME/bin:$PRESTO_HOME/bin:$SHARK_HOME/bin:$SCALA_HOME/bin:$SPARK_HOME/bin:$PATH

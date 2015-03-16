mkdir -p DistributedRank_classes
javac -cp $HIVE_HOME/lib/hive-exec-0.12.0.jar:$HADOOP_HOME/hadoop-core-1.2.1.jar -d DistributedRank_classes DistributedRank.java
jar -cvf DistributedRank.jar -C DistributedRank_classes/ .

mkdir -p CollectAll_classes
javac -J-Xms16m -J-Xmx1024m -cp $HIVE_HOME/lib/hive-exec-0.12.0.jar:$HADOOP_HOME/hadoop-core-1.2.1.jar -d CollectAll_classes CollectAll.java
jar -J-Xms16m -J-Xmx1024m -cvf CollectAll.jar -C CollectAll_classes/ .

mkdir -p Tester_classes
javac -cp $SPARK_HOME/lib/spark-assembly-1.0.2-hadoop1.0.4.jar:$SPARK_HOME/lib/hive.jar:$SPARK_HOME/lib/core.jar:$SPARK_HOME/lib/catalyst.jar -J-Xms16m -J-Xmx1024m -d Tester_classes *.java
jar -J-Xms16m -J-Xmx1024m -cvf Tester.jar -C Tester_classes/ .
#javac -cp $HIVE_HOME/lib/hive-exec-0.12.0.jar:$HADOOP_HOME/hadoop-core-1.2.1.jar -d DistributedRank_classes DistributedRank.java
#jar -cvf DistributedRank.jar -C DistributedRank_classes/ .

export CLASSPATH=$(hadoop classpath)

mkdir -p DistributedRank_classes
javac -cp /opt/cloudera/parcels/CDH-5.4.2-1.cdh5.4.2.p0.2/jars/hive-exec-1.1.0-cdh5.4.2.jar:/usr/share/cmf/lib/cdh5/hadoop-core-2.6.0-mr1-cdh5.4.0.jar:/opt/cloudera/parcels/CDH-5.4.2-1.cdh5.4.2.p0.2/jars/hadoop-common-2.6.0-cdh5.4.2.jar -d DistributedRank_classes DistributedRank.java

jar -cvf DistributedRank.jar -C DistributedRank_classes/ .

mkdir -p CollectAll_classes
javac -J-Xms16m -J-Xmx1024m -cp /opt/cloudera/parcels/CDH-5.4.2-1.cdh5.4.2.p0.2/jars/hive-exec-1.1.0-cdh5.4.2.jar:/usr/share/cmf/lib/cdh5/hadoop-core-2.6.0-mr1-cdh5.4.0.jar:/opt/cloudera/parcels/CDH-5.4.2-1.cdh5.4.2.p0.2/jars/hadoop-common-2.6.0-cdh5.4.2.jar -d CollectAll_classes CollectAll.java

jar -J-Xms16m -J-Xmx1024m -cvf CollectAll.jar -C CollectAll_classes/ .

DROP TABLE IF EXISTS events;
-- The EXTERNAL clause means the data is located outside the central location
-- for Impala data files and is preserved when the associated Impala table is dropped.
-- We expect the data to already exist in the directory specified by the LOCATION clause.
CREATE EXTERNAL TABLE events (evt_case STRING, evt_event STRING, evt_timestamp TIMESTAMP) 
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
LOCATION '${TEST_DATA_HDFS_PATH}';

DROP TABLE IF EXISTS events;
CREATE TABLE events (evt_case STRING, evt_event STRING, evt_timestamp TIMESTAMP) ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' STORED AS RCFILE;

CREATE TABLE events_text (evt_case STRING, evt_event STRING, evt_timestamp TIMESTAMP) ROW FORMAT DELIMITED FIELDS TERMINATED BY ',';
LOAD DATA LOCAL INPATH '${HADOOP_TRITON_TARGET}/test.csv' OVERWRITE INTO TABLE events_text;

INSERT OVERWRITE TABLE events SELECT * FROM events_text;
DROP TABLE events_text;
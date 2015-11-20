DROP TABLE IF EXISTS events;
CREATE TABLE events (evt_case VARCHAR, evt_event VARCHAR, evt_timestamp TIMESTAMP);
\copy events FROM '${TEST_DATA_FILE}' DELIMITER ',' CSV

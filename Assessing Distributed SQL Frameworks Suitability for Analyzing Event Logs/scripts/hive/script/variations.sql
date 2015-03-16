ADD JAR ${HADOOP_TRITON_SOURCE_DIR}/udf/CollectAll.jar;

DROP TEMPORARY FUNCTION IF EXISTS collect_all;
CREATE TEMPORARY FUNCTION collect_all AS 'com.example.CollectAll';

INSERT OVERWRITE LOCAL DIRECTORY '${HADOOP_TRITON_RESULT_DIR}' 
ROW FORMAT DELIMITED 
FIELDS TERMINATED BY ',' 
SELECT 
  count(1) var_count,
  var_event_count,
  var_event_types 
FROM 
  (
    SELECT
      x.evt_case AS var_name,
      count(1) AS var_event_count,
      collect_all(x.evt_event) AS var_event_types
    FROM
      ( 
        SELECT
          y.evt_case,
          y.evt_event,
          y.evt_timestamp
        FROM
          events y
        ORDER BY
          y.evt_timestamp ASC
      ) x
    GROUP BY
      x.evt_case
  ) x
GROUP BY
  var_event_types, var_event_count;

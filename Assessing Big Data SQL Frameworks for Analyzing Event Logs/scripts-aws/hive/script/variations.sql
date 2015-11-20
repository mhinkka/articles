INSERT OVERWRITE LOCAL DIRECTORY '${TEST_TEMP_RESULT_PATH}' 
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
      collect_list(x.evt_event) AS var_event_types
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

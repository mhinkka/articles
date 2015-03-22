INSERT OVERWRITE LOCAL DIRECTORY '${HADOOP_TRITON_RESULT_DIR}' 
ROW FORMAT DELIMITED 
FIELDS TERMINATED BY ',' 
SELECT *
FROM
(
  SELECT
    count(1) AS tra_count,
    x.evt_event AS tra_event,
    y.evt_event AS tra_next_event,
    (SUM(UNIX_TIMESTAMP(y.evt_timestamp) - UNIX_TIMESTAMP(x.evt_timestamp))) AS tra_duration,
    (PERCENTILE(UNIX_TIMESTAMP(y.evt_timestamp) - UNIX_TIMESTAMP(x.evt_timestamp), 0.5)) AS tra_duration_median
  FROM
    (SELECT
    evt_case,
    evt_event,
    evt_timestamp,
    ROW_NUMBER() OVER (PARTITION BY evt_case ORDER BY evt_timestamp ASC, evt_event ASC) AS evt_asc_rank
  FROM
    events) x 
      JOIN (SELECT
    evt_case,
    evt_event,
    evt_timestamp,
    ROW_NUMBER() OVER (PARTITION BY evt_case ORDER BY evt_timestamp ASC, evt_event ASC) AS evt_asc_rank
  FROM
    events) y ON 
        ((x.evt_case = y.evt_case) AND (x.evt_asc_rank = y.evt_asc_rank-1))
  GROUP BY
    x.evt_event, y.evt_event
UNION ALL
  SELECT
    count(1) AS tra_count,
    '_START' AS tra_event,
    evt_event AS tra_next_event,
    0.0 AS tra_duration,
    0.0 AS tra_duration_median
  FROM
    (SELECT
    evt_case,
    evt_event,
    evt_timestamp,
    ROW_NUMBER() OVER (PARTITION BY evt_case ORDER BY evt_timestamp ASC, evt_event ASC) AS evt_asc_rank
  FROM
    events) x
  WHERE
    evt_asc_rank = 1
  GROUP BY
    evt_event
UNION ALL
  SELECT
    count(1) AS tra_count,
    evt_event AS tra_event,
    '_END' AS tra_next_event,
    0.0 AS tra_duration,
    0.0 AS tra_duration_median
  FROM
    (SELECT
    evt_case,
    evt_event,
    ROW_NUMBER() OVER (PARTITION BY evt_case ORDER BY evt_timestamp DESC, evt_event DESC) AS evt_desc_rank
  FROM
    events) x
  WHERE
    evt_desc_rank = 1
  GROUP BY
    evt_event
) unionResult
ORDER BY
  tra_count DESC, tra_event ASC, tra_next_event ASC;

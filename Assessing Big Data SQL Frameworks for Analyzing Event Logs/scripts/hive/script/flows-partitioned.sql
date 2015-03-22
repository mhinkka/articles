DROP TABLE IF EXISTS events_with_rank;
CREATE TABLE events_with_rank (evt_event STRING, evt_timestamp TIMESTAMP, evt_asc_rank INT, evt_desc_rank INT)
PARTITIONED BY(evt_case STRING);

INSERT INTO TABLE events_with_rank
SELECT
  evt_case,
  evt_event,
  evt_timestamp,
  ROW_NUMBER() OVER (PARTITION BY evt_case ORDER BY evt_timestamp ASC, evt_event ASC) AS evt_asc_rank,
  ROW_NUMBER() OVER (PARTITION BY evt_case ORDER BY evt_timestamp DESC, evt_event DESC) AS evt_desc_rank
FROM
  events;

INSERT OVERWRITE LOCAL DIRECTORY '/triton/cse/work/hinkkam2/runs/indextest-4-rcfile-100000-flows/hive-1/results'
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
SELECT *
FROM
(
  SELECT
    count(1) AS tra_count,
    x.evt_event AS tra_event,
    y.evt_event AS tra_next_event,
    (SUM(UNIX_TIMESTAMP(y.evt_timestamp) - UNIX_TIMESTAMP(x.evt_timestamp))) AS tra_duration
  FROM
    events_with_rank x
      JOIN events_with_rank y ON
        ((x.evt_case = y.evt_case) AND (x.evt_asc_rank = y.evt_asc_rank-1))
  GROUP BY
    x.evt_event, y.evt_event
UNION ALL
  SELECT
    count(1) AS tra_count,
    '_START' AS tra_event,
    evt_event AS tra_next_event,
    0.0 AS tra_duration
  FROM
    events_with_rank x
  WHERE
    evt_asc_rank = 1
  GROUP BY
    evt_event
UNION ALL
  SELECT
    count(1) AS tra_count,
    evt_event AS tra_event,
    '_END' AS tra_next_event,
    0.0 AS tra_duration
  FROM
    events_with_rank x
  WHERE
    evt_desc_rank = 1
  GROUP BY
    evt_event
) unionResult
ORDER BY
  tra_count DESC, tra_event ASC, tra_next_event ASC;

DROP TABLE IF EXISTS events_with_rank;

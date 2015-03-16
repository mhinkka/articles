ADD jar /home/hinkkam2/git/hive/udf/DistributedRank.jar;
CREATE TEMPORARY FUNCTION DistributedRank AS 'com.example.DistributedRank';

DROP TABLE IF EXISTS events_with_rank;
CREATE TABLE events_with_rank (evt_id INT, evt_case STRING, evt_event STRING, evt_timestamp TIMESTAMP, evt_asc_rank INT, evt_desc_rank INT);

INSERT INTO TABLE events_with_rank
SELECT
  x.evt_id,
  evt_case,
  evt_event,
  evt_timestamp,
  evt_asc_rank,
  evt_desc_rank
FROM  
(SELECT *, DistributedRank(evt_case) AS evt_asc_rank
FROM 
  (
    SELECT *
    FROM events
    DISTRIBUTE BY evt_case SORT BY evt_timestamp
  ) TMP1) x
 JOIN 
(SELECT evt_id, DistributedRank(evt_case) AS evt_desc_rank
FROM 
  (
    SELECT *
    FROM events
    DISTRIBUTE BY evt_case SORT BY evt_timestamp DESC
  ) TMP2) y ON 
  (x.evt_id = y.evt_id);



INSERT OVERWRITE LOCAL DIRECTORY '${HADOOP_TRITON_TARGET}/shark/results' 
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
    0.0 AS tra_duration,
    0.0 AS tra_duration_median
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
    0.0 AS tra_duration,
    0.0 AS tra_duration_median
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

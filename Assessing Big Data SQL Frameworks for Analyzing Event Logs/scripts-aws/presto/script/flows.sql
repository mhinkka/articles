/* Flow analysis */
WITH events_with_rank AS 
(
  SELECT
    evt_case,
    evt_event,
    evt_timestamp,
    ROW_NUMBER() OVER (PARTITION BY evt_case ORDER BY evt_timestamp ASC) AS evt_asc_rank,
    ROW_NUMBER() OVER (PARTITION BY evt_case ORDER BY evt_timestamp DESC) AS evt_desc_rank
/*
    https://github.com/facebook/presto/issues/1833
    ROW_NUMBER() OVER (PARTITION BY evt_case ORDER BY evt_timestamp ASC, evt_event ASC) AS evt_asc_rank,
    ROW_NUMBER() OVER (PARTITION BY evt_case ORDER BY evt_timestamp DESC, evt_event DESC) AS evt_desc_rank
*/

  FROM
    events
) 
SELECT *
FROM
(
  SELECT
    count(1) AS tra_count,
    x.evt_event AS tra_event,
    y.evt_event AS tra_next_event,
    SUM(date_diff('second', x.evt_timestamp, y.evt_timestamp)) AS tra_duration
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
    CAST(0.0 AS BIGINT) AS tra_duration
  FROM
    events_with_rank
  WHERE
    evt_asc_rank = 1
  GROUP BY
    evt_event
UNION ALL
  SELECT
    count(1) AS tra_count,
    evt_event AS tra_event,
    '_END' AS tra_next_event,
    CAST(0.0 AS BIGINT) AS tra_duration
  FROM
    events_with_rank
  WHERE
    evt_desc_rank = 1
  GROUP BY
    evt_event
) unionResult
ORDER BY
  tra_count DESC, tra_event ASC, tra_next_event ASC;




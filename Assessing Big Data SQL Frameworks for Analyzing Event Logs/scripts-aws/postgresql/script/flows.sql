DROP TABLE IF EXISTS events_with_rank;
CREATE TABLE events_with_rank (evt_case VARCHAR, evt_event VARCHAR, evt_timestamp TIMESTAMP, evt_asc_rank INT, evt_desc_rank INT);

INSERT INTO events_with_rank
SELECT
  evt_case,
  evt_event,
  evt_timestamp,
  ROW_NUMBER() OVER (PARTITION BY evt_case ORDER BY evt_timestamp ASC, evt_event ASC) AS evt_asc_rank,
  ROW_NUMBER() OVER (PARTITION BY evt_case ORDER BY evt_timestamp DESC, evt_event DESC) AS evt_desc_rank
FROM
  events;

COPY (
SELECT *
FROM
(
  SELECT
    count(1) AS tra_count,
    x.evt_event AS tra_event,
    y.evt_event AS tra_next_event,
    (SUM(y.evt_timestamp - x.evt_timestamp)) AS tra_duration
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
    NULL AS tra_duration
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
    NULL AS tra_duration
  FROM
    events_with_rank x
  WHERE
    evt_desc_rank = 1
  GROUP BY
    evt_event
) unionResult
ORDER BY
  tra_count DESC, tra_event ASC, tra_next_event ASC
)
TO '${TEST_TEMP_RESULT_PATH}.csv' WITH CSV;

DROP TABLE IF EXISTS events_with_rank;

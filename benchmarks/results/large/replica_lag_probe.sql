\set ON_ERROR_STOP on
CREATE TABLE replica_lag_probe (
    id integer PRIMARY KEY,
    payload text NOT NULL,
    written_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

-- Generate a deterministic 50,000-row, approximately 25.6 MB replay probe.
INSERT INTO replica_lag_probe (id, payload)
SELECT row_id,
       string_agg(md5(row_id::text || ':' || chunk_id::text), '' ORDER BY chunk_id)
FROM generate_series(1, 50000) AS rows(row_id)
CROSS JOIN generate_series(1, 16) AS chunks(chunk_id)
GROUP BY row_id;

SELECT count(*) AS committed_rows,
       pg_current_wal_lsn() AS primary_target_lsn,
       pg_size_pretty(pg_database_size(current_database())) AS probe_database_size
FROM replica_lag_probe;

SELECT application_name, state, sync_state, sent_lsn, write_lsn, flush_lsn,
       replay_lsn, write_lag, flush_lag, replay_lag
FROM pg_stat_replication;

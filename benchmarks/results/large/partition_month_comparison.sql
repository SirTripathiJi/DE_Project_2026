\set ON_ERROR_STOP on
SET search_path TO practo;

\echo 'ORDINARY TABLE: count appointments in June 2026, three executions'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT count(*) FROM appointments
WHERE slot_start >= TIMESTAMPTZ '2026-06-01 00:00:00+05:30'
  AND slot_start < TIMESTAMPTZ '2026-07-01 00:00:00+05:30';
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT count(*) FROM appointments
WHERE slot_start >= TIMESTAMPTZ '2026-06-01 00:00:00+05:30'
  AND slot_start < TIMESTAMPTZ '2026-07-01 00:00:00+05:30';
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT count(*) FROM appointments
WHERE slot_start >= TIMESTAMPTZ '2026-06-01 00:00:00+05:30'
  AND slot_start < TIMESTAMPTZ '2026-07-01 00:00:00+05:30';

\echo 'PARTITIONED TABLE: same June 2026 count, three executions'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT count(*) FROM appointments_partitioned
WHERE slot_start >= TIMESTAMPTZ '2026-06-01 00:00:00+05:30'
  AND slot_start < TIMESTAMPTZ '2026-07-01 00:00:00+05:30';
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT count(*) FROM appointments_partitioned
WHERE slot_start >= TIMESTAMPTZ '2026-06-01 00:00:00+05:30'
  AND slot_start < TIMESTAMPTZ '2026-07-01 00:00:00+05:30';
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT count(*) FROM appointments_partitioned
WHERE slot_start >= TIMESTAMPTZ '2026-06-01 00:00:00+05:30'
  AND slot_start < TIMESTAMPTZ '2026-07-01 00:00:00+05:30';

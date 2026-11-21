\set ON_ERROR_STOP on
SET search_path TO practo;

\echo 'ROW COUNTS: source versus populated partition candidate'
SELECT (SELECT count(*) FROM appointments) AS base_rows,
       (SELECT count(*) FROM appointments_partitioned) AS partitioned_rows,
       (SELECT count(*) FROM appointments_partitioned WHERE tableoid <> 'practo.appointments_partitioned_default'::regclass) AS non_default_partition_rows;
SELECT c.relname AS populated_partition, count(*) AS rows
FROM appointments_partitioned a
JOIN pg_class c ON c.oid = a.tableoid
GROUP BY c.relname ORDER BY c.relname;

\echo 'RESULT EQUIVALENCE: R05-shaped appointment/patient result, EXCEPT ALL both directions'
WITH base_result AS (
    SELECT a.appointment_id, p.full_name, a.slot_start, a.status, a.checked_in_at
    FROM appointments a JOIN patients p ON p.patient_id = a.patient_id
    WHERE a.doctor_id = 16 AND a.slot_start >= '2026-06-30' AND a.slot_start < '2026-07-01'
), partition_result AS (
    SELECT a.appointment_id, p.full_name, a.slot_start, a.status, a.checked_in_at
    FROM appointments_partitioned a JOIN patients p ON p.patient_id = a.patient_id
    WHERE a.doctor_id = 16 AND a.slot_start >= '2026-06-30' AND a.slot_start < '2026-07-01'
)
SELECT 'base_minus_partitioned' AS direction, count(*) AS differing_rows
FROM (SELECT * FROM base_result EXCEPT ALL SELECT * FROM partition_result) d
UNION ALL
SELECT 'partitioned_minus_base', count(*)
FROM (SELECT * FROM partition_result EXCEPT ALL SELECT * FROM base_result) d;

\echo 'BASE TABLE: R05-shaped EXPLAIN ANALYZE, three executions'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE) SELECT a.appointment_id, p.full_name, a.slot_start, a.status, a.checked_in_at
FROM appointments a JOIN patients p ON p.patient_id = a.patient_id
WHERE a.doctor_id = 16 AND a.slot_start >= '2026-06-30' AND a.slot_start < '2026-07-01'
ORDER BY a.slot_start;
EXPLAIN (ANALYZE, BUFFERS, VERBOSE) SELECT a.appointment_id, p.full_name, a.slot_start, a.status, a.checked_in_at
FROM appointments a JOIN patients p ON p.patient_id = a.patient_id
WHERE a.doctor_id = 16 AND a.slot_start >= '2026-06-30' AND a.slot_start < '2026-07-01'
ORDER BY a.slot_start;
EXPLAIN (ANALYZE, BUFFERS, VERBOSE) SELECT a.appointment_id, p.full_name, a.slot_start, a.status, a.checked_in_at
FROM appointments a JOIN patients p ON p.patient_id = a.patient_id
WHERE a.doctor_id = 16 AND a.slot_start >= '2026-06-30' AND a.slot_start < '2026-07-01'
ORDER BY a.slot_start;

\echo 'PARTITIONED TABLE: same R05-shaped query, three executions'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE) SELECT a.appointment_id, p.full_name, a.slot_start, a.status, a.checked_in_at
FROM appointments_partitioned a JOIN patients p ON p.patient_id = a.patient_id
WHERE a.doctor_id = 16 AND a.slot_start >= '2026-06-30' AND a.slot_start < '2026-07-01'
ORDER BY a.slot_start;
EXPLAIN (ANALYZE, BUFFERS, VERBOSE) SELECT a.appointment_id, p.full_name, a.slot_start, a.status, a.checked_in_at
FROM appointments_partitioned a JOIN patients p ON p.patient_id = a.patient_id
WHERE a.doctor_id = 16 AND a.slot_start >= '2026-06-30' AND a.slot_start < '2026-07-01'
ORDER BY a.slot_start;
EXPLAIN (ANALYZE, BUFFERS, VERBOSE) SELECT a.appointment_id, p.full_name, a.slot_start, a.status, a.checked_in_at
FROM appointments_partitioned a JOIN patients p ON p.patient_id = a.patient_id
WHERE a.doctor_id = 16 AND a.slot_start >= '2026-06-30' AND a.slot_start < '2026-07-01'
ORDER BY a.slot_start;

\echo 'POPULATED PARTITION PRUNING: bounded June 2026 range'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT appointment_id, patient_id, doctor_id, slot_start, status
FROM appointments_partitioned
WHERE slot_start >= TIMESTAMPTZ '2026-06-01 00:00:00+05:30'
  AND slot_start <  TIMESTAMPTZ '2026-07-01 00:00:00+05:30';

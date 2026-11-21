\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout = '180s';
SET LOCAL maintenance_work_mem = '512MB';
SET LOCAL track_io_timing = on;
SET LOCAL search_path TO practo;

-- Add the candidate index transactionally so the current R24 SQL can use it.
CREATE INDEX idx_r24_experiment_covering
    ON appointments (doctor_id, slot_start, appointment_id)
    WHERE status <> 'CANCELLED';

SELECT pg_size_pretty(pg_relation_size('idx_r24_experiment_covering'))
       AS experimental_index_size;

-- Three executions of the unchanged current optimized query.
EXPLAIN (ANALYZE, BUFFERS, SETTINGS)
WITH duplicate_slots AS MATERIALIZED (
    SELECT doctor_id, slot_start
    FROM appointments
    WHERE status <> 'CANCELLED'
    GROUP BY doctor_id, slot_start
    HAVING count(*) > 1
)
SELECT a.doctor_id, a.slot_start, a.appointment_id,
       b.appointment_id AS other_appointment_id
FROM duplicate_slots d
JOIN appointments a
  ON a.doctor_id = d.doctor_id AND a.slot_start = d.slot_start
 AND a.status <> 'CANCELLED'
JOIN appointments b
  ON b.doctor_id = d.doctor_id AND b.slot_start = d.slot_start
 AND b.status <> 'CANCELLED' AND b.appointment_id > a.appointment_id
ORDER BY a.slot_start DESC;

EXPLAIN (ANALYZE, BUFFERS, SETTINGS)
WITH duplicate_slots AS MATERIALIZED (
    SELECT doctor_id, slot_start
    FROM appointments
    WHERE status <> 'CANCELLED'
    GROUP BY doctor_id, slot_start
    HAVING count(*) > 1
)
SELECT a.doctor_id, a.slot_start, a.appointment_id,
       b.appointment_id AS other_appointment_id
FROM duplicate_slots d
JOIN appointments a
  ON a.doctor_id = d.doctor_id AND a.slot_start = d.slot_start
 AND a.status <> 'CANCELLED'
JOIN appointments b
  ON b.doctor_id = d.doctor_id AND b.slot_start = d.slot_start
 AND b.status <> 'CANCELLED' AND b.appointment_id > a.appointment_id
ORDER BY a.slot_start DESC;

EXPLAIN (ANALYZE, BUFFERS, SETTINGS)
WITH duplicate_slots AS MATERIALIZED (
    SELECT doctor_id, slot_start
    FROM appointments
    WHERE status <> 'CANCELLED'
    GROUP BY doctor_id, slot_start
    HAVING count(*) > 1
)
SELECT a.doctor_id, a.slot_start, a.appointment_id,
       b.appointment_id AS other_appointment_id
FROM duplicate_slots d
JOIN appointments a
  ON a.doctor_id = d.doctor_id AND a.slot_start = d.slot_start
 AND a.status <> 'CANCELLED'
JOIN appointments b
  ON b.doctor_id = d.doctor_id AND b.slot_start = d.slot_start
 AND b.status <> 'CANCELLED' AND b.appointment_id > a.appointment_id
ORDER BY a.slot_start DESC;

-- Do not retain the candidate index in the benchmark database.
ROLLBACK;

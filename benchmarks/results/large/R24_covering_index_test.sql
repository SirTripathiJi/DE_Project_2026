\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout = '180s';
SET LOCAL maintenance_work_mem = '512MB';
SET LOCAL work_mem = '64MB';
SET LOCAL track_io_timing = on;
SET LOCAL search_path TO practo;

-- This experimental index is deliberately transactional and is rolled back.
CREATE INDEX idx_r24_experiment_covering
    ON appointments (doctor_id, slot_start, appointment_id)
    WHERE status <> 'CANCELLED';

SELECT pg_size_pretty(pg_relation_size('idx_r24_experiment_covering'))
       AS experimental_index_size;

EXPLAIN (ANALYZE, BUFFERS, SETTINGS)
WITH duplicate_slots AS MATERIALIZED (
    SELECT doctor_id, slot_start,
           array_agg(appointment_id ORDER BY appointment_id) AS appointment_ids
    FROM appointments
    WHERE status <> 'CANCELLED'
    GROUP BY doctor_id, slot_start
    HAVING count(*) > 1
)
SELECT d.doctor_id, d.slot_start,
       d.appointment_ids[i], d.appointment_ids[j] AS other_appointment_id
FROM duplicate_slots d
CROSS JOIN LATERAL generate_subscripts(d.appointment_ids, 1) AS first_index(i)
CROSS JOIN LATERAL generate_subscripts(d.appointment_ids, 1) AS second_index(j)
WHERE i < j
ORDER BY d.slot_start DESC;

-- The temporary index must not survive this experiment.
ROLLBACK;

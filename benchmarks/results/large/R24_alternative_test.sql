\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout = '120s';
SET LOCAL work_mem = '64MB';
SET LOCAL track_io_timing = on;
SET LOCAL search_path TO practo;

-- Candidate: collect IDs during the grouped pass and generate unordered pairs
-- from each duplicate slot, avoiding the two post-aggregation appointment probes.
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

-- Exact row-multiset comparison against the current optimized query.
WITH current_result AS MATERIALIZED (
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
), candidate_result AS MATERIALIZED (
    SELECT d.doctor_id, d.slot_start,
           d.appointment_ids[i] AS appointment_id,
           d.appointment_ids[j] AS other_appointment_id
    FROM (
        SELECT doctor_id, slot_start,
               array_agg(appointment_id ORDER BY appointment_id) AS appointment_ids
        FROM appointments
        WHERE status <> 'CANCELLED'
        GROUP BY doctor_id, slot_start
        HAVING count(*) > 1
    ) d
    CROSS JOIN LATERAL generate_subscripts(d.appointment_ids, 1) AS first_index(i)
    CROSS JOIN LATERAL generate_subscripts(d.appointment_ids, 1) AS second_index(j)
    WHERE i < j
)
SELECT (SELECT count(*) FROM current_result) AS current_rows,
       (SELECT count(*) FROM candidate_result) AS candidate_rows,
       (SELECT count(*) FROM (
            (SELECT * FROM current_result EXCEPT ALL SELECT * FROM candidate_result)
            UNION ALL
            (SELECT * FROM candidate_result EXCEPT ALL SELECT * FROM current_result)
       ) differences) AS difference_rows;
ROLLBACK;

\set ON_ERROR_STOP on
SET search_path TO practo;

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
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
 AND b.status <> 'CANCELLED'
 AND b.appointment_id > a.appointment_id
ORDER BY a.slot_start DESC;

WITH original AS MATERIALIZED (
    SELECT a.doctor_id, a.slot_start, a.appointment_id,
           b.appointment_id AS other_appointment_id
    FROM appointments a
    JOIN appointments b ON b.doctor_id = a.doctor_id
                       AND b.slot_start = a.slot_start
                       AND b.appointment_id > a.appointment_id
    WHERE a.status <> 'CANCELLED' AND b.status <> 'CANCELLED'
), duplicate_slots AS MATERIALIZED (
    SELECT doctor_id, slot_start
    FROM appointments
    WHERE status <> 'CANCELLED'
    GROUP BY doctor_id, slot_start
    HAVING count(*) > 1
), candidate AS MATERIALIZED (
    SELECT a.doctor_id, a.slot_start, a.appointment_id,
           b.appointment_id AS other_appointment_id
    FROM duplicate_slots d
    JOIN appointments a
      ON a.doctor_id = d.doctor_id AND a.slot_start = d.slot_start
     AND a.status <> 'CANCELLED'
    JOIN appointments b
      ON b.doctor_id = d.doctor_id AND b.slot_start = d.slot_start
     AND b.status <> 'CANCELLED'
     AND b.appointment_id > a.appointment_id
)
SELECT (SELECT count(*) FROM original) AS original_rows,
       (SELECT count(*) FROM candidate) AS candidate_rows,
       (SELECT count(*) FROM (
           (SELECT * FROM original EXCEPT ALL SELECT * FROM candidate)
           UNION ALL
           (SELECT * FROM candidate EXCEPT ALL SELECT * FROM original)
       ) differences) AS multiset_difference_rows;

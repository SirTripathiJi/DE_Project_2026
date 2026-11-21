-- Isolated retiming workload for the verified R24 large-scale rewrite.
-- The official optimized workload remains in sql/06_optimized_queries.sql.
-- @R24
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
-- @END

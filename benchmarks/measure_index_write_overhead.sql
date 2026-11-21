\set ON_ERROR_STOP on
SET statement_timeout = '20min';
SET maintenance_work_mem = '512MB';
SET search_path TO practo, pg_temp;

-- Isolated, session-temporary copies. Both contain the same full large-data
-- appointments snapshot and a primary key; only the indexed copy receives the
-- ten workload secondary indexes from sql/05_indexes.sql.
CREATE TEMP TABLE write_no_secondary AS
SELECT * FROM practo.appointments;
CREATE TEMP TABLE write_with_secondary AS
SELECT * FROM practo.appointments;

ALTER TABLE write_no_secondary ADD PRIMARY KEY (appointment_id);
ALTER TABLE write_with_secondary ADD PRIMARY KEY (appointment_id);

CREATE INDEX write_idx_doctor_slot
    ON write_with_secondary (doctor_id, slot_start)
    INCLUDE (appointment_id, patient_id, status, checked_in_at, clinic_id);
CREATE INDEX write_idx_patient_status_slot
    ON write_with_secondary (patient_id, status, slot_start)
    INCLUDE (appointment_id, doctor_id, consult_type, clinic_id);
CREATE INDEX write_idx_active_doctor_slot
    ON write_with_secondary (doctor_id, slot_start)
    WHERE status <> 'CANCELLED';
CREATE INDEX write_idx_slot_start
    ON write_with_secondary (slot_start DESC, appointment_id ASC)
    INCLUDE (patient_id, doctor_id, clinic_id, consult_type,
             status, payment_status, fee, consult_ended_at);
CREATE INDEX write_idx_completed_slot
    ON write_with_secondary (slot_start)
    INCLUDE (appointment_id, patient_id, doctor_id, clinic_id, consult_type, fee)
    WHERE status = 'COMPLETED';
CREATE INDEX write_idx_booked_slot
    ON write_with_secondary (slot_start)
    INCLUDE (appointment_id, doctor_id, patient_id, consult_type, slot_end)
    WHERE status = 'BOOKED';
CREATE INDEX write_idx_noshow_slot
    ON write_with_secondary (slot_start)
    INCLUDE (doctor_id)
    WHERE status = 'NO_SHOW';
CREATE INDEX write_idx_completed_pending_slot
    ON write_with_secondary (slot_start DESC, appointment_id ASC)
    INCLUDE (patient_id, clinic_id, fee)
    WHERE status = 'COMPLETED' AND payment_status = 'PENDING';
CREATE INDEX write_idx_unfinished_slot_end
    ON write_with_secondary (slot_end)
    INCLUDE (appointment_id, status)
    WHERE status IN ('BOOKED', 'CHECKED_IN') AND consult_ended_at IS NULL;
CREATE INDEX write_idx_booked_doctor_slot
    ON write_with_secondary (doctor_id, slot_start)
    INCLUDE (appointment_id, payment_status)
    WHERE status = 'BOOKED';

ANALYZE write_no_secondary;
ANALYZE write_with_secondary;

-- Fixed, identical 5,000 BOOKED appointment IDs for both copies.
CREATE TEMP TABLE write_ids AS
SELECT appointment_id
FROM practo.appointments
WHERE status = 'BOOKED'
ORDER BY appointment_id
LIMIT 5000;
ALTER TABLE write_ids ADD PRIMARY KEY (appointment_id);
SELECT count(*) AS fixed_rows_per_trial FROM write_ids;

-- Record storage by relation. The secondary-index total excludes the common PK.
SELECT 'no_secondary' AS variant,
       pg_table_size('write_no_secondary') AS table_bytes,
       pg_indexes_size('write_no_secondary') AS all_index_bytes,
       0::bigint AS secondary_index_bytes
UNION ALL
SELECT 'with_10_secondary',
       pg_table_size('write_with_secondary'),
       pg_indexes_size('write_with_secondary'),
       pg_indexes_size('write_with_secondary')
         - pg_relation_size('write_with_secondary_pkey');

-- Same PK-driven state transition. Each run rolls back and vacuums the target
-- before the next trial so dead tuples do not accumulate between measurements.
BEGIN;
EXPLAIN (ANALYZE, BUFFERS)
UPDATE write_no_secondary t
SET status = 'CHECKED_IN', checked_in_at = t.slot_start - interval '5 minutes'
FROM write_ids i WHERE t.appointment_id = i.appointment_id;
ROLLBACK;
VACUUM (ANALYZE) write_no_secondary;

BEGIN;
EXPLAIN (ANALYZE, BUFFERS)
UPDATE write_with_secondary t
SET status = 'CHECKED_IN', checked_in_at = t.slot_start - interval '5 minutes'
FROM write_ids i WHERE t.appointment_id = i.appointment_id;
ROLLBACK;
VACUUM (ANALYZE) write_with_secondary;

BEGIN;
EXPLAIN (ANALYZE, BUFFERS)
UPDATE write_with_secondary t
SET status = 'CHECKED_IN', checked_in_at = t.slot_start - interval '5 minutes'
FROM write_ids i WHERE t.appointment_id = i.appointment_id;
ROLLBACK;
VACUUM (ANALYZE) write_with_secondary;

BEGIN;
EXPLAIN (ANALYZE, BUFFERS)
UPDATE write_no_secondary t
SET status = 'CHECKED_IN', checked_in_at = t.slot_start - interval '5 minutes'
FROM write_ids i WHERE t.appointment_id = i.appointment_id;
ROLLBACK;
VACUUM (ANALYZE) write_no_secondary;

BEGIN;
EXPLAIN (ANALYZE, BUFFERS)
UPDATE write_no_secondary t
SET status = 'CHECKED_IN', checked_in_at = t.slot_start - interval '5 minutes'
FROM write_ids i WHERE t.appointment_id = i.appointment_id;
ROLLBACK;
VACUUM (ANALYZE) write_no_secondary;

BEGIN;
EXPLAIN (ANALYZE, BUFFERS)
UPDATE write_with_secondary t
SET status = 'CHECKED_IN', checked_in_at = t.slot_start - interval '5 minutes'
FROM write_ids i WHERE t.appointment_id = i.appointment_id;
ROLLBACK;
VACUUM (ANALYZE) write_with_secondary;

-- All test objects disappear when this session disconnects.

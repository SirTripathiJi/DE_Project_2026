\set ON_ERROR_STOP on
SET search_path TO practo;

-- Isolated experiment only: copy every appointment into the candidate table.
-- The original practo.appointments table and its foreign keys remain untouched.
INSERT INTO appointments_partitioned (
    appointment_id, patient_id, doctor_id, clinic_id, consult_type,
    booked_at, slot_start, slot_end, reason, status, checked_in_at,
    consult_started_at, consult_ended_at, fee, payment_status
)
SELECT
    appointment_id, patient_id, doctor_id, clinic_id, consult_type,
    booked_at, slot_start, slot_end, reason, status, checked_in_at,
    consult_started_at, consult_ended_at, fee, payment_status
FROM appointments;

ANALYZE appointments_partitioned;

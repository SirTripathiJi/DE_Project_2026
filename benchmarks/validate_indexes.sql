\set ON_ERROR_STOP on
SET search_path TO practo;

WITH expected(indexname) AS (
    VALUES
        ('idx_doctor_specializations_primary_spec_doctor'),
        ('idx_doctors_verified_experience'),
        ('idx_clinics_city_clinic'),
        ('idx_schedules_inclinic_doctor_weekday_start'),
        ('idx_appointments_doctor_slot'),
        ('idx_appointments_patient_status_slot'),
        ('idx_appointments_active_doctor_slot'),
        ('idx_appointments_slot_start'),
        ('idx_appointments_completed_slot'),
        ('idx_appointments_booked_slot'),
        ('idx_appointments_noshow_slot'),
        ('idx_appointments_completed_pending_slot'),
        ('idx_appointments_unfinished_slot_end'),
        ('idx_appointments_booked_doctor_slot'),
        ('idx_prescriptions_follow_up_date'),
        ('idx_prescription_items_medicine_trgm'),
        ('idx_patients_allergies_gin'),
        ('idx_schedules_clinic_id'),
        ('idx_doctors_languages_gin')
)
SELECT e.indexname,
       i.indexrelid IS NOT NULL AS exists,
       coalesce(i.indisvalid, false) AS valid,
       pg_size_pretty(pg_relation_size(i.indexrelid)) AS size,
       pg_relation_size(i.indexrelid) AS size_bytes
FROM expected e
LEFT JOIN pg_class c ON c.relname = e.indexname
LEFT JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = 'practo'
LEFT JOIN pg_index i ON i.indexrelid = c.oid
ORDER BY e.indexname;

DO $validate_indexes$
DECLARE
    expected_count INTEGER := 19;
    actual_count INTEGER;
BEGIN
    SELECT count(*) INTO actual_count
    FROM pg_indexes
    WHERE schemaname = 'practo'
      AND indexname IN (
        'idx_doctor_specializations_primary_spec_doctor', 'idx_doctors_verified_experience',
        'idx_clinics_city_clinic', 'idx_schedules_inclinic_doctor_weekday_start',
        'idx_appointments_doctor_slot', 'idx_appointments_patient_status_slot',
        'idx_appointments_active_doctor_slot', 'idx_appointments_slot_start',
        'idx_appointments_completed_slot', 'idx_appointments_booked_slot',
        'idx_appointments_noshow_slot', 'idx_appointments_completed_pending_slot',
        'idx_appointments_unfinished_slot_end', 'idx_appointments_booked_doctor_slot',
        'idx_prescriptions_follow_up_date', 'idx_prescription_items_medicine_trgm',
        'idx_patients_allergies_gin', 'idx_schedules_clinic_id', 'idx_doctors_languages_gin'
      );
    IF actual_count <> expected_count THEN
        RAISE EXCEPTION 'Expected % tuning indexes, found %', expected_count, actual_count;
    END IF;
    IF EXISTS (
        SELECT 1 FROM pg_index i
        JOIN pg_class c ON c.oid = i.indexrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'practo'
          AND c.relname LIKE 'idx\_%' ESCAPE '\'
          AND (NOT i.indisvalid OR NOT i.indisready)
    ) THEN
        RAISE EXCEPTION 'A tuning index is invalid or not ready';
    END IF;
    RAISE NOTICE 'All % tuning indexes exist and are valid (PASS)', actual_count;
END
$validate_indexes$;

SELECT c.relname AS table_name,
       pg_table_size(c.oid) AS table_bytes,
       pg_indexes_size(c.oid) AS all_index_bytes,
       pg_size_pretty(pg_table_size(c.oid)) AS table_size,
       pg_size_pretty(pg_indexes_size(c.oid)) AS all_index_size
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'practo' AND c.relkind = 'r'
ORDER BY c.relname;

SELECT pg_database_size(current_database()) AS database_bytes,
       pg_size_pretty(pg_database_size(current_database())) AS database_size;

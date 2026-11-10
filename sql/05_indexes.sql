-- Phase 4 indexes for the Practo 30-query workload.
-- Run after sql/02_load_data.sql, before ANALYZE and the optimized benchmark.
-- Primary-key / UNIQUE indexes from sql/01_schema.sql are already present and
-- are not recreated here. The partial unique index on the primary doctor
-- specialization is also created by 01_schema.sql.

SET search_path TO practo;

-- R01, R08, R15, R25: specialize doctor searches and primary-specialization
-- joins/aggregations. spec_id is the equality key; doctor_id supports the join.
-- R01 filters Dermatologist via spec_id and requires primary specialists only
-- for R08/R15/R25, so keep this separate from the non-partial join index.
CREATE INDEX idx_doctor_specializations_primary_spec_doctor
    ON doctor_specializations (spec_id, doctor_id)
    WHERE is_primary = TRUE;

-- R01: after finding the relevant doctors, require verified providers and sort
-- by experience descending. Partial index keeps only verified doctors; id is
-- included for the specialization join. INCLUDE may support an index-only read
-- of the result columns, subject to visibility-map state.
CREATE INDEX idx_doctors_verified_experience
    ON doctors (experience_years DESC, doctor_id)
    INCLUDE (full_name, consultation_fee)
    WHERE is_verified = TRUE;

-- R01, R18, R19: clinic-to-city filtering followed by schedule joins. The
-- primary key of clinics already handles clinic_id lookups; city_id is the
-- selective equality predicate, with clinic_id available for the join.
CREATE INDEX idx_clinics_city_clinic
    ON clinics (city_id, clinic_id);

-- R02, R03, W01: doctor schedule lookup. The PK starts with doctor_id and
-- already supports R02 and W01; this partial index narrows R03 to physical
-- clinic schedules and orders by weekday/start_time. It is separate because
-- NULL clinic_id rows represent video availability and are not needed by R03.
CREATE INDEX idx_schedules_inclinic_doctor_weekday_start
    ON doctor_schedules (doctor_id, weekday, start_time)
    INCLUDE (end_time, slot_minutes, clinic_id)
    WHERE clinic_id IS NOT NULL;

-- R03, R05, R09, R12, R16, R17, R19, R20, R22, R24, W01, W02, W04, W05:
-- appointment access by doctor/time, patient/status/time, or date range/order.
-- These indexes target independent predicates; avoid one oversized composite
-- index that cannot serve the different leading-column requirements.
CREATE INDEX idx_appointments_doctor_slot
    ON appointments (doctor_id, slot_start)
    INCLUDE (appointment_id, patient_id, status, checked_in_at, clinic_id);

CREATE INDEX idx_appointments_patient_status_slot
    ON appointments (patient_id, status, slot_start)
    INCLUDE (appointment_id, doctor_id, consult_type, clinic_id);

-- R03: active-slot anti-lookup. Partial index excludes cancelled appointments
-- and supports equality on doctor_id/slot_start for the NOT EXISTS probe.
CREATE INDEX idx_appointments_active_doctor_slot
    ON appointments (doctor_id, slot_start)
    WHERE status <> 'CANCELLED';

-- R05, R09, R12, R16, R17, R19, R20: timestamp range filters, grouping and
-- latest-consultation lookup. slot_start is leading so bounded time windows and
-- newest-first pagination can use the B-tree. INCLUDE helps selected reporting
-- aggregates where an index-only scan is possible.
CREATE INDEX idx_appointments_slot_start
    ON appointments (slot_start DESC)
    INCLUDE (appointment_id, patient_id, doctor_id, clinic_id, consult_type,
             status, payment_status, fee, consult_ended_at);

-- R04/R08/R09/R16/R17/R20 and W02/W04: common fixed-status date windows.
-- Separate partial indexes reduce entries for the read/report and write paths.
CREATE INDEX idx_appointments_completed_slot
    ON appointments (slot_start)
    INCLUDE (appointment_id, patient_id, doctor_id, clinic_id, consult_type, fee)
    WHERE status = 'COMPLETED';

CREATE INDEX idx_appointments_booked_slot
    ON appointments (slot_start)
    INCLUDE (appointment_id, doctor_id, patient_id, consult_type, slot_end)
    WHERE status = 'BOOKED';

-- R08: NO_SHOW branch of status-filtered yearly aggregate. Complements the
-- completed partial index; year predicate is a slot_start range after rewrite.
CREATE INDEX idx_appointments_noshow_slot
    ON appointments (slot_start)
    INCLUDE (doctor_id)
    WHERE status = 'NO_SHOW';

-- R21: rare unpaid completed appointments, sorted newest slot first.
CREATE INDEX idx_appointments_completed_pending_slot
    ON appointments (slot_start DESC)
    INCLUDE (appointment_id, patient_id, clinic_id, fee)
    WHERE status = 'COMPLETED' AND payment_status = 'PENDING';

-- W04: scheduled appointments to transition when their slots have ended.
-- Partial predicate follows the two eligible statuses; slot_end is the range.
CREATE INDEX idx_appointments_unfinished_slot_end
    ON appointments (slot_end)
    INCLUDE (appointment_id, status)
    WHERE status IN ('BOOKED', 'CHECKED_IN') AND consult_ended_at IS NULL;

-- W05: cancel a doctor's booked appointments in a date range.
CREATE INDEX idx_appointments_booked_doctor_slot
    ON appointments (doctor_id, slot_start)
    INCLUDE (appointment_id, payment_status)
    WHERE status = 'BOOKED';

-- R07, R11, R15: prescription appointment is UNIQUE already and supports
-- appointment_id lookup. follow_up_date supports the bounded due-date scan.
CREATE INDEX idx_prescriptions_follow_up_date
    ON prescriptions (follow_up_date, prescription_id)
    WHERE follow_up_date IS NOT NULL;

-- R10, R15: prescription_items PK begins with prescription_id and serves the
-- prescription join. Medicine substring search uses pg_trgm GIN.
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_prescription_items_medicine_trgm
    ON prescription_items USING GIN (medicine_name gin_trgm_ops);

-- R10: allergy array containment predicate.
CREATE INDEX idx_patients_allergies_gin
    ON patients USING GIN (allergies);

-- R13: NOT IN over schedule clinic IDs benefits from a direct clinic_id index.
-- It also supports clinic-schedule existence probes in R01/R18/R19.
CREATE INDEX idx_schedules_clinic_id
    ON doctor_schedules (clinic_id)
    WHERE clinic_id IS NOT NULL;

-- R14: appointment_id is UNIQUE in doctor_reviews already and supports the
-- join; no additional review index is proposed for the full aggregation.

-- R15: primary specializations are already indexed above. The primary key on
-- prescription_items (prescription_id, line_no) serves prescription-to-items.

-- R18: exact array membership for a language value.
CREATE INDEX idx_doctors_languages_gin
    ON doctors USING GIN (languages);

-- R22: slot_start supports ORDER BY slot_start DESC, but OFFSET 100000 must
-- still walk skipped entries. A query rewrite to keyset pagination is needed
-- to remove that cost; no extra index can eliminate a large OFFSET by itself.

-- Analyze after creating the indexes so PostgreSQL can plan using fresh stats.
ANALYZE;

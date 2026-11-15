-- Practo CP4 / Phase 5 design example: RANGE partition appointments by slot_start.
-- REVIEW ONLY. This file is not an automatic migration. It creates a separate
-- candidate table and never drops, renames, or alters practo.appointments.
-- Do not execute against the live project database without review and a planned
-- migration window. It assumes the original practo schema/tables exist.

SET search_path TO practo;

-- The column names and types below match sql/01_schema.sql. PostgreSQL requires
-- a partitioned table's PRIMARY KEY / UNIQUE constraints to include every
-- partition key. Therefore this candidate uses (appointment_id, slot_start).
-- That composite key does NOT guarantee appointment_id is globally unique
-- across all partitions. Existing prescriptions and doctor_reviews reference
-- appointment_id alone; those foreign keys cannot target this composite key.
-- A production design must preserve global ID uniqueness separately or carry
-- slot_start into child references and use a composite FK before cutover.
CREATE TABLE appointments_partitioned (
    appointment_id INTEGER NOT NULL,
    patient_id INTEGER NOT NULL,
    doctor_id INTEGER NOT NULL,
    clinic_id INTEGER,
    consult_type VARCHAR(20) NOT NULL,
    booked_at TIMESTAMPTZ NOT NULL,
    slot_start TIMESTAMPTZ NOT NULL,
    slot_end TIMESTAMPTZ NOT NULL,
    reason TEXT,
    status VARCHAR(20) NOT NULL,
    checked_in_at TIMESTAMPTZ,
    consult_started_at TIMESTAMPTZ,
    consult_ended_at TIMESTAMPTZ,
    fee NUMERIC(10,2) NOT NULL,
    payment_status VARCHAR(20) NOT NULL,

    CONSTRAINT pk_appointments_partitioned
        PRIMARY KEY (appointment_id, slot_start),
    CONSTRAINT fk_appt_part_patient
        FOREIGN KEY (patient_id) REFERENCES practo.patients(patient_id) ON DELETE RESTRICT,
    CONSTRAINT fk_appt_part_doctor
        FOREIGN KEY (doctor_id) REFERENCES practo.doctors(doctor_id) ON DELETE RESTRICT,
    CONSTRAINT fk_appt_part_clinic
        FOREIGN KEY (clinic_id) REFERENCES practo.clinics(clinic_id) ON DELETE RESTRICT,
    CONSTRAINT chk_appt_part_consult_type
        CHECK (consult_type IN ('IN_CLINIC', 'VIDEO')),
    CONSTRAINT chk_appt_part_status
        CHECK (status IN ('BOOKED', 'CHECKED_IN', 'COMPLETED', 'CANCELLED', 'NO_SHOW')),
    CONSTRAINT chk_appt_part_payment_status
        CHECK (payment_status IN ('PAID', 'PENDING', 'REFUNDED')),
    CONSTRAINT chk_appt_part_slot_time CHECK (slot_end > slot_start),
    CONSTRAINT chk_appt_part_fee CHECK (fee >= 0),
    CONSTRAINT chk_appt_part_clinic_type CHECK (
        (consult_type = 'IN_CLINIC' AND clinic_id IS NOT NULL)
        OR (consult_type = 'VIDEO' AND clinic_id IS NULL)
    ),
    CONSTRAINT chk_appt_part_checkin_type CHECK (
        checked_in_at IS NULL OR consult_type = 'IN_CLINIC'
    ),
    CONSTRAINT chk_appt_part_consult_timestamps CHECK (
        (consult_started_at IS NULL AND consult_ended_at IS NULL)
        OR (consult_started_at IS NOT NULL AND consult_ended_at IS NOT NULL
            AND consult_ended_at >= consult_started_at)
    )
) PARTITION BY RANGE (slot_start);

-- Seed coverage was checked from all 150,000 rows in
-- seed_data/appointments.csv (not from a live database):
--   slot_start min = 2025-01-01 12:20:00+05:30
--   slot_start max = 2026-07-15 21:45:00+05:30
--   booked_at min  = 2025-01-01 00:00:00+05:30
--   booked_at max  = 2026-06-30 23:54:45+05:30
-- The booked_at range is not the slot_start range. These local-time monthly
-- bounds cover the verified slot_start months Jan 2025 through Jul 2026.
-- DEFAULT remains as a safety net for other dates; add future monthly
-- partitions before they are needed and monitor rows routed to DEFAULT.
CREATE TABLE appointments_partitioned_2025_01 PARTITION OF appointments_partitioned
    FOR VALUES FROM ('2025-01-01 00:00:00+05:30') TO ('2025-02-01 00:00:00+05:30');
CREATE TABLE appointments_partitioned_2025_02 PARTITION OF appointments_partitioned
    FOR VALUES FROM ('2025-02-01 00:00:00+05:30') TO ('2025-03-01 00:00:00+05:30');
CREATE TABLE appointments_partitioned_2025_03 PARTITION OF appointments_partitioned
    FOR VALUES FROM ('2025-03-01 00:00:00+05:30') TO ('2025-04-01 00:00:00+05:30');
CREATE TABLE appointments_partitioned_2025_04 PARTITION OF appointments_partitioned
    FOR VALUES FROM ('2025-04-01 00:00:00+05:30') TO ('2025-05-01 00:00:00+05:30');
CREATE TABLE appointments_partitioned_2025_05 PARTITION OF appointments_partitioned
    FOR VALUES FROM ('2025-05-01 00:00:00+05:30') TO ('2025-06-01 00:00:00+05:30');
CREATE TABLE appointments_partitioned_2025_06 PARTITION OF appointments_partitioned
    FOR VALUES FROM ('2025-06-01 00:00:00+05:30') TO ('2025-07-01 00:00:00+05:30');
CREATE TABLE appointments_partitioned_2025_07 PARTITION OF appointments_partitioned
    FOR VALUES FROM ('2025-07-01 00:00:00+05:30') TO ('2025-08-01 00:00:00+05:30');
CREATE TABLE appointments_partitioned_2025_08 PARTITION OF appointments_partitioned
    FOR VALUES FROM ('2025-08-01 00:00:00+05:30') TO ('2025-09-01 00:00:00+05:30');
CREATE TABLE appointments_partitioned_2025_09 PARTITION OF appointments_partitioned
    FOR VALUES FROM ('2025-09-01 00:00:00+05:30') TO ('2025-10-01 00:00:00+05:30');
CREATE TABLE appointments_partitioned_2025_10 PARTITION OF appointments_partitioned
    FOR VALUES FROM ('2025-10-01 00:00:00+05:30') TO ('2025-11-01 00:00:00+05:30');
CREATE TABLE appointments_partitioned_2025_11 PARTITION OF appointments_partitioned
    FOR VALUES FROM ('2025-11-01 00:00:00+05:30') TO ('2025-12-01 00:00:00+05:30');
CREATE TABLE appointments_partitioned_2025_12 PARTITION OF appointments_partitioned
    FOR VALUES FROM ('2025-12-01 00:00:00+05:30') TO ('2026-01-01 00:00:00+05:30');
CREATE TABLE appointments_partitioned_2026_01 PARTITION OF appointments_partitioned
    FOR VALUES FROM ('2026-01-01 00:00:00+05:30') TO ('2026-02-01 00:00:00+05:30');
CREATE TABLE appointments_partitioned_2026_02 PARTITION OF appointments_partitioned
    FOR VALUES FROM ('2026-02-01 00:00:00+05:30') TO ('2026-03-01 00:00:00+05:30');
CREATE TABLE appointments_partitioned_2026_03 PARTITION OF appointments_partitioned
    FOR VALUES FROM ('2026-03-01 00:00:00+05:30') TO ('2026-04-01 00:00:00+05:30');
CREATE TABLE appointments_partitioned_2026_04 PARTITION OF appointments_partitioned
    FOR VALUES FROM ('2026-04-01 00:00:00+05:30') TO ('2026-05-01 00:00:00+05:30');
CREATE TABLE appointments_partitioned_2026_05 PARTITION OF appointments_partitioned
    FOR VALUES FROM ('2026-05-01 00:00:00+05:30') TO ('2026-06-01 00:00:00+05:30');
CREATE TABLE appointments_partitioned_2026_06 PARTITION OF appointments_partitioned
    FOR VALUES FROM ('2026-06-01 00:00:00+05:30') TO ('2026-07-01 00:00:00+05:30');
CREATE TABLE appointments_partitioned_2026_07 PARTITION OF appointments_partitioned
    FOR VALUES FROM ('2026-07-01 00:00:00+05:30') TO ('2026-08-01 00:00:00+05:30');
CREATE TABLE appointments_partitioned_default PARTITION OF appointments_partitioned DEFAULT;

-- Indexes from sql/05_indexes.sql that target appointments must be recreated
-- for this parent: doctor_slot, patient_status_slot, active_doctor_slot,
-- slot_start, completed_slot, booked_slot, noshow_slot,
-- completed_pending_slot, unfinished_slot_end, booked_doctor_slot.
-- CREATE INDEX on the partitioned parent creates/attaches matching child
-- indexes (subject to the PostgreSQL version and migration procedure). Build
-- and validate each index before cutover; indexes on the old table do not move.
CREATE INDEX appt_part_doctor_slot
    ON appointments_partitioned (doctor_id, slot_start)
    INCLUDE (appointment_id, patient_id, status, checked_in_at, clinic_id);
CREATE INDEX appt_part_patient_status_slot
    ON appointments_partitioned (patient_id, status, slot_start)
    INCLUDE (appointment_id, doctor_id, consult_type, clinic_id);
CREATE INDEX appt_part_active_doctor_slot
    ON appointments_partitioned (doctor_id, slot_start)
    WHERE status <> 'CANCELLED';
CREATE INDEX appt_part_slot_start
    ON appointments_partitioned (slot_start DESC)
    INCLUDE (appointment_id, patient_id, doctor_id, clinic_id, consult_type,
             status, payment_status, fee, consult_ended_at);
CREATE INDEX appt_part_completed_slot
    ON appointments_partitioned (slot_start)
    INCLUDE (appointment_id, patient_id, doctor_id, clinic_id, consult_type, fee)
    WHERE status = 'COMPLETED';
CREATE INDEX appt_part_booked_slot
    ON appointments_partitioned (slot_start)
    INCLUDE (appointment_id, doctor_id, patient_id, consult_type, slot_end)
    WHERE status = 'BOOKED';
CREATE INDEX appt_part_noshow_slot
    ON appointments_partitioned (slot_start) INCLUDE (doctor_id)
    WHERE status = 'NO_SHOW';
CREATE INDEX appt_part_completed_pending_slot
    ON appointments_partitioned (slot_start DESC)
    INCLUDE (appointment_id, patient_id, clinic_id, fee)
    WHERE status = 'COMPLETED' AND payment_status = 'PENDING';
CREATE INDEX appt_part_unfinished_slot_end
    ON appointments_partitioned (slot_end) INCLUDE (appointment_id, status)
    WHERE status IN ('BOOKED', 'CHECKED_IN') AND consult_ended_at IS NULL;
CREATE INDEX appt_part_booked_doctor_slot
    ON appointments_partitioned (doctor_id, slot_start)
    INCLUDE (appointment_id, payment_status)
    WHERE status = 'BOOKED';

-- EXPLAIN pruning check. With slot_start bounds in the WHERE clause, the plan
-- should show only the matching monthly partition (partition pruning). Run as
-- a read-only plan inspection after the candidate table contains/has statistics
-- for data; this query does not alter rows.
EXPLAIN (COSTS, VERBOSE)
SELECT appointment_id, patient_id, doctor_id, slot_start, status
FROM appointments_partitioned
WHERE slot_start >= TIMESTAMPTZ '2026-06-01 00:00:00+05:30'
  AND slot_start <  TIMESTAMPTZ '2026-07-01 00:00:00+05:30';

-- Safe migration outline (manual, separately reviewed; not run automatically):
-- 1. Resolve global appointment_id uniqueness and prescription/review FK design.
-- 2. Create this candidate table and partitions alongside the original table.
-- 3. Recreate and validate required indexes, constraints, and permissions.
-- 4. Copy rows explicitly by column list (INSERT INTO candidate (...) SELECT ...
--    FROM practo.appointments); create any later month partitions first.
-- 5. Validate total counts, per-month counts, checksums/key comparisons, FK
--    relationships, and query results. Run ANALYZE on the candidate.
-- 6. Benchmark the optimized workload and confirm pruning with EXPLAIN.
-- 7. During a controlled maintenance window, pause writes, reconcile the final
--    delta, validate again, then switch application/table references through
--    a reviewed cutover procedure. Keep the original table available for
--    rollback until the new path is verified. Do not drop it from this script.

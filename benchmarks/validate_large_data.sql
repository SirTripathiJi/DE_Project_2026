\set ON_ERROR_STOP on
SET search_path TO practo;

-- Exact row counts from the CSV parser preflight. Fail closed on a partial load.
DO $validate_large_counts$
DECLARE
    r RECORD;
    actual_count BIGINT;
BEGIN
    FOR r IN SELECT * FROM (VALUES
        ('cities', 10::BIGINT),
        ('specializations', 15::BIGINT),
        ('doctors', 60000::BIGINT),
        ('doctor_specializations', 74000::BIGINT),
        ('clinics', 30000::BIGINT),
        ('doctor_schedules', 609747::BIGINT),
        ('patients', 800000::BIGINT),
        ('appointments', 3000000::BIGINT),
        ('prescriptions', 1944432::BIGINT),
        ('prescription_items', 4861080::BIGINT),
        ('doctor_reviews', 608179::BIGINT)
    ) AS expected(table_name, expected_count)
    LOOP
        EXECUTE format('SELECT count(*) FROM practo.%I', r.table_name) INTO actual_count;
        IF actual_count <> r.expected_count THEN
            RAISE EXCEPTION '% row count: expected %, found %', r.table_name, r.expected_count, actual_count;
        END IF;
        RAISE NOTICE '%: % rows (PASS)', r.table_name, actual_count;
    END LOOP;
END
$validate_large_counts$;

-- Cross-table checks, in addition to PK/FK/CHECK constraints enforced at load.
DO $validate_large_integrity$
BEGIN
    IF EXISTS (
        SELECT 1 FROM practo.appointments
        WHERE (consult_type = 'IN_CLINIC' AND clinic_id IS NULL)
           OR (consult_type = 'VIDEO' AND clinic_id IS NOT NULL)
    ) THEN RAISE EXCEPTION 'consultation type / clinic rule failed'; END IF;

    IF EXISTS (
        SELECT 1 FROM practo.appointments a
        WHERE a.consult_type = 'IN_CLINIC'
          AND NOT EXISTS (
              SELECT 1 FROM practo.doctor_schedules s
              WHERE s.doctor_id = a.doctor_id
                AND s.clinic_id = a.clinic_id
                AND s.weekday = EXTRACT(ISODOW FROM a.slot_start)::INTEGER
                AND s.start_time <= a.slot_start::TIME
                AND s.end_time >= a.slot_end::TIME
          )
    ) THEN RAISE EXCEPTION 'in-clinic appointment does not match a doctor schedule'; END IF;

    IF EXISTS (
        SELECT 1 FROM practo.prescriptions p
        JOIN practo.appointments a USING (appointment_id)
        WHERE a.status <> 'COMPLETED'
    ) THEN RAISE EXCEPTION 'prescription references a non-completed appointment'; END IF;

    IF EXISTS (
        SELECT 1 FROM practo.doctors d
        LEFT JOIN practo.doctor_specializations ds
          ON ds.doctor_id = d.doctor_id AND ds.is_primary
        GROUP BY d.doctor_id
        HAVING count(ds.spec_id) <> 1
    ) THEN RAISE EXCEPTION 'each doctor must have exactly one primary specialization'; END IF;

    RAISE NOTICE 'consultation type / clinic consistency: PASS';
    RAISE NOTICE 'in-clinic doctor schedule consistency: PASS';
    RAISE NOTICE 'prescription lifecycle consistency: PASS';
    RAISE NOTICE 'exactly one primary specialization per doctor: PASS';
END
$validate_large_integrity$;

\copy (SELECT table_name AS table, expected_count AS expected_rows, actual_count AS actual_rows, (actual_count = expected_count)::TEXT AS passed FROM (SELECT 'cities'::TEXT AS table_name, 10::BIGINT AS expected_count, count(*) AS actual_count FROM practo.cities UNION ALL SELECT 'specializations', 15, count(*) FROM practo.specializations UNION ALL SELECT 'doctors', 60000, count(*) FROM practo.doctors UNION ALL SELECT 'doctor_specializations', 74000, count(*) FROM practo.doctor_specializations UNION ALL SELECT 'clinics', 30000, count(*) FROM practo.clinics UNION ALL SELECT 'doctor_schedules', 609747, count(*) FROM practo.doctor_schedules UNION ALL SELECT 'patients', 800000, count(*) FROM practo.patients UNION ALL SELECT 'appointments', 3000000, count(*) FROM practo.appointments UNION ALL SELECT 'prescriptions', 1944432, count(*) FROM practo.prescriptions UNION ALL SELECT 'prescription_items', 4861080, count(*) FROM practo.prescription_items UNION ALL SELECT 'doctor_reviews', 608179, count(*) FROM practo.doctor_reviews) counts ORDER BY table_name) TO 'benchmarks/results/large/row_counts.csv' WITH (FORMAT CSV, HEADER TRUE);

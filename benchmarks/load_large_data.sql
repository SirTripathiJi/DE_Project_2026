
-- =====================================================
-- PRACTO DATABASE PROJECT
-- CP1 - Phase 2: Data Loading
-- Team: T0035 | Section: E
-- =====================================================

\set ON_ERROR_STOP on

SET search_path TO practo;


-- =====================================================
-- 1. CITIES
-- =====================================================

\copy practo.cities FROM 'large_data/cities.csv' WITH (FORMAT CSV, HEADER TRUE);


-- =====================================================
-- 2. SPECIALIZATIONS
-- =====================================================

\copy practo.specializations FROM 'large_data/specializations.csv' WITH (FORMAT CSV, HEADER TRUE);


-- =====================================================
-- 3. DOCTORS
-- =====================================================

\copy practo.doctors FROM 'large_data/doctors.csv' WITH (FORMAT CSV, HEADER TRUE);


-- =====================================================
-- 4. CLINICS
-- =====================================================

\copy practo.clinics FROM 'large_data/clinics.csv' WITH (FORMAT CSV, HEADER TRUE);


-- =====================================================
-- 5. DOCTOR SPECIALIZATIONS
-- =====================================================

\copy practo.doctor_specializations FROM 'large_data/doctor_specializations.csv' WITH (FORMAT CSV, HEADER TRUE);


-- =====================================================
-- 6. DOCTOR SCHEDULES
-- =====================================================

\copy practo.doctor_schedules FROM 'large_data/doctor_schedules.csv' WITH (FORMAT CSV, HEADER TRUE);


-- =====================================================
-- 7. PATIENTS
-- =====================================================

\copy practo.patients FROM 'large_data/patients.csv' WITH (FORMAT CSV, HEADER TRUE);


-- =====================================================
-- 8. APPOINTMENTS
-- =====================================================

\copy practo.appointments FROM 'large_data/appointments.csv' WITH (FORMAT CSV, HEADER TRUE);


-- =====================================================
-- 9. PRESCRIPTIONS
-- =====================================================

\copy practo.prescriptions FROM 'large_data/prescriptions.csv' WITH (FORMAT CSV, HEADER TRUE);


-- =====================================================
-- 10. PRESCRIPTION ITEMS
-- =====================================================

\copy practo.prescription_items FROM 'large_data/prescription_items.csv' WITH (FORMAT CSV, HEADER TRUE);


-- =====================================================
-- 11. DOCTOR REVIEWS
-- =====================================================

\copy practo.doctor_reviews FROM 'large_data/doctor_reviews.csv' WITH (FORMAT CSV, HEADER TRUE);


-- =====================================================
-- UPDATE TABLE STATISTICS
-- =====================================================

ANALYZE;

-- =====================================================
-- END OF DATA LOADING SCRIPT
-- =====================================================

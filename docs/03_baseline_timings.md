# Phase 3: Baseline Query Performance Report

This report records the committed baseline benchmark evidence before the CP3 workload-specific indexes and query rewrites. Timings below are reconstructed from the three `Execution Time` lines in each raw plan and checked against `benchmarks/results/baseline/summary.csv`.

## Method

- Workload: unchanged `queries/workload_30.sql` (25 reads R01–R25 and 5 writes W01–W05).
- Each query has three recorded `EXPLAIN (ANALYZE, BUFFERS)` runs in its corresponding raw plan file.
- The baseline results table uses the required five columns; workload descriptions and plan explanations follow in a separate context table.
- W01–W05 are wrapped in `BEGIN`/`ROLLBACK` by `benchmarks/run_benchmark.sh`.
- Average is the arithmetic mean of the three raw execution times, rounded to three decimal milliseconds; it matches the summary CSV.
- The scan column reflects node names in the recorded plans. The explanation summarizes the access pattern visible in those plans.

## Baseline results

| Query ID | Run 1 | Run 2 | Run 3 | Average |
|---|---:|---:|---:|---:|
| R01 | 2.570 | 1.258 | 1.154 | 1.661 |
| R02 | 0.184 | 0.213 | 0.185 | 0.194 |
| R03 | 9.822 | 8.084 | 8.228 | 8.711 |
| R04 | 6.738 | 6.811 | 6.652 | 6.734 |
| R05 | 5.052 | 5.701 | 5.184 | 5.312 |
| R06 | 0.039 | 0.020 | 0.024 | 0.028 |
| R07 | 0.256 | 0.042 | 0.038 | 0.112 |
| R08 | 17.945 | 18.072 | 18.243 | 18.087 |
| R09 | 8.263 | 8.139 | 8.266 | 8.223 |
| R10 | 24.834 | 16.346 | 16.572 | 19.251 |
| R11 | 18.896 | 16.863 | 17.378 | 17.712 |
| R12 | 30.088 | 24.395 | 24.378 | 26.287 |
| R13 | 2.785 | 2.672 | 2.655 | 2.704 |
| R14 | 19.617 | 19.677 | 21.772 | 20.355 |
| R15 | 24.444 | 21.264 | 22.356 | 22.688 |
| R16 | 9.694 | 9.764 | 9.553 | 9.670 |
| R17 | 39.492 | 36.891 | 37.317 | 37.900 |
| R18 | 4.378 | 4.218 | 4.340 | 4.312 |
| R19 | 5220.064 | 4624.461 | 4713.057 | 4852.527 |
| R20 | 7.932 | 8.035 | 7.978 | 7.982 |
| R21 | 8.310 | 8.306 | 8.303 | 8.306 |
| R22 | 33.646 | 33.579 | 33.960 | 33.728 |
| R23 | 0.511 | 0.020 | 0.024 | 0.185 |
| R24 | 53.113 | 21.044 | 22.273 | 32.143 |
| R25 | 19.634 | 20.028 | 19.666 | 19.776 |
| W01 | 1.126 | 0.521 | 0.522 | 0.723 |
| W02 | 7.443 | 6.860 | 6.827 | 7.043 |
| W03 | 0.679 | 0.112 | 0.113 | 0.301 |
| W04 | 9.599 | 8.966 | 8.859 | 9.141 |
| W05 | 6.895 | 7.003 | 6.737 | 6.878 |

## Query and plan context

| Query ID | Workload operation | Type | Scan nodes in plan | Why the plan is slow or fast |
|---|---|---|---|---|
| R01 | Find a doctor: verified dermatologists practising in Bengaluru, most experienced first | READ | Seq Scan on doctor_specializations; Seq Scan on specializations; Index Scan using doctors_pkey on doctors; Index Scan using pk_doctor_schedules on doctor_schedules; Seq Scan on clinics | Joins doctor, specialization, schedule and clinic relations; sequential scans of small dimensions dominate this selective search. |
| R02 | Doctor profile: doctor 217's weekly timetable with clinic names | READ | Index Scan using pk_doctor_schedules on doctor_schedules; Seq Scan on clinics | The doctor schedule primary key narrows the lookup to one doctor; the clinic table is small. |
| R03 | Slot picker: doctor 217's free in-clinic slots on Friday 3 July 2026 | READ | Index Scan using pk_doctor_schedules on doctor_schedules; Seq Scan on appointments | The free-slot anti-check scans appointments for each generated candidate slot. |
| R04 | "My appointments": patient 90's upcoming appointments | READ | Seq Scan on appointments; Index Scan using doctors_pkey on doctors; Seq Scan on clinics | Without a patient/status index, the plan scans all appointments before joining the matching patient records. |
| R05 | Doctor's queue: doctor 16's appointments on 30 June 2026 | READ | Seq Scan on appointments; Index Scan using patients_pkey on patients | DATE(slot_start) prevents a simple timestamp range lookup, so the plan scans appointments for one doctor-day. |
| R06 | Sign-in with mobile number | READ | Index Scan using patients_phone_key on patients | A unique phone index provides a direct patient lookup. |
| R07 | Prescription view: the prescription and medicines of appointment 18872 | READ | Index Scan using prescriptions_appointment_id_key on prescriptions; Index Scan using pk_prescription_items on prescription_items | Unique prescription appointment and prescription-item primary-key indexes serve the small lookup. |
| R08 | Quality: no-show rate per specialization in 2026 | READ | Seq Scan on appointments; Seq Scan on doctor_specializations; Seq Scan on specializations | A year-wide status aggregate scans appointments and joins specialization mappings. |
| R09 | Clinic experience: average minutes patients waited after their slot time, per clinic (June 2026) | READ | Seq Scan on appointments | The June clinic waiting-time aggregate scans appointments before grouping. |
| R10 | Patient safety: patients allergic to penicillin who were prescribed amoxicillin | READ | Seq Scan on appointments; Seq Scan on patients; Index Scan using prescriptions_appointment_id_key on prescriptions; Index Scan using pk_prescription_items on prescription_items | The allergy and medicine match joins several relations; the baseline plan scans patients and appointments. |
| R11 | Care team: follow-ups due in the first week of July 2026 that the patient has not booked yet | READ | Seq Scan on appointments; Seq Scan on prescriptions; Index Scan using appointments_pkey on appointments | The due-follow-up anti-join scans prescriptions and appointments to find unbooked follow-ups. |
| R12 | Product analytics: video vs in-clinic appointments per month in 2026 | READ | Seq Scan on appointments | Year extraction and monthly aggregation require scanning appointments. |
| R13 | Clinic partnerships: clinics where no doctor has any schedule | READ | Seq Scan on clinics; Seq Scan on doctor_schedules | The clinic and schedule subquery scans include NULL clinic IDs; NOT IN therefore returns no clinics. |
| R14 | Doctor ranking: average rating and recommendation rate (at least 10 reviews) | READ | Seq Scan on appointments; Seq Scan on doctor_reviews | Doctor ranking aggregates broad appointment and review populations. |
| R15 | Pharmacy partners: most prescribed medicines per primary specialization in June 2026 | READ | Seq Scan on prescription_items; Seq Scan on appointments; Seq Scan on prescriptions; Seq Scan on doctor_specializations; Seq Scan on specializations | Medicine ranking joins and aggregates prescription items, appointments, prescriptions and specializations. |
| R16 | Finance: fees collected per clinic in June 2026 | READ | Seq Scan on appointments; Seq Scan on clinics | The June fee report scans appointments and clinics before grouping by clinic. |
| R17 | Population health: completed appointments by patient age group and blood group (2026) | READ | Seq Scan on appointments; Seq Scan on patients | The population-health query scans appointments and patients and groups by age and blood group. |
| R18 | Search filter: Tamil-speaking doctors with Chennai clinics | READ | Seq Scan on doctor_schedules; Seq Scan on doctors; Seq Scan on clinics | Language and city filters scan schedules, doctors and clinics without the later GIN and city indexes. |
| R19 | City report: June 2026 completed consultations and latest consultation of every doctor with a Bengaluru clinic | READ | Seq Scan on doctor_schedules; Seq Scan on clinics; Seq Scan on doctors; Seq Scan on appointments | Correlated appointment subqueries repeat full appointment scans per doctor, producing the dominant baseline cost. |
| R20 | Platform analytics: completed appointments per day and running total, June 2026 | READ | Seq Scan on appointments | The June daily running-total report scans appointments, then groups and windows the matching rows. |
| R21 | Finance: completed in-clinic consultations whose fee is still unpaid | READ | Seq Scan on appointments | The completed unpaid-fee query scans appointments to select and order eligible rows. |
| R22 | Support console: all appointments, newest first, page 4,001 (25 per page) | READ | Seq Scan on appointments | The deep OFFSET page scans and sorts appointments, including many rows that are discarded. |
| R23 | Verification team: look up a doctor by medical council registration number | READ | Index Scan using doctors_registration_no_key on doctors | A unique registration-number index provides a direct doctor lookup. |
| R24 | Data quality: two active appointments of the same doctor in the same slot (double bookings) | READ | Seq Scan on appointments | The active double-booking self-join scans appointments to compare matching doctor-slot rows. |
| R25 | Care quality: patients who saw 3 or more different doctors of the same specialization in 2026 | READ | Seq Scan on appointments; Seq Scan on doctor_specializations | The patient/specialization pattern aggregates completed appointments and specialization mappings. |
| W01 | Book: patient 90 books doctor 217's 10:30 slot on Friday 3 July 2026 | WRITE | Index Scan using pk_doctor_schedules on doctor_schedules; Index Scan using doctors_pkey on doctors | The insert-select uses schedule and doctor primary-key lookups; transaction work is small. |
| W02 | Reception: check in the earliest BOOKED in-clinic appointment of 1 July 2026 | WRITE | Seq Scan on appointments; Index Scan using appointments_pkey on appointments | The update must scan appointments to find the earliest eligible booked in-clinic visit, then update by primary key. |
| W03 | Doctor: add notes and a follow-up date to the prescription of appointment 18872 | WRITE | Index Scan using prescriptions_appointment_id_key on prescriptions | A unique appointment-to-prescription index locates the single prescription row. |
| W04 | Nightly job (run at 00:00 on 2 July 2026): BOOKED appointments whose slot has ended become NO_SHOW | WRITE | Seq Scan on appointments | The batch update scans appointments for booked rows whose slot has ended. |
| W05 | Doctor on leave: cancel and refund all of doctor 504's appointments on 3 July 2026 | WRITE | Seq Scan on appointments | The cancellation/refund update scans appointments for one doctor and date before updating matches. |

## Plan highlights

R19 is the slowest query at 4,852.527 ms. R17 (37.900 ms) and R22 (33.728 ms) are the next largest costs. See their raw plans for the access paths and row counts. Exact per-query evidence is in the linked raw plans.

R06 (0.023 ms) and R23 (0.023 ms) use unique-key index lookups. R07 (0.046 ms) also uses its unique prescription appointment and prescription-item primary-key indexes.

R13 returns no rows in this baseline. The `NOT IN` subquery contains NULL `clinic_id` values from video schedules; SQL NULL semantics make the predicate UNKNOWN for otherwise unmatched clinics. CP3 replaces it with `NOT EXISTS` and intentionally returns the 292 clinics without schedules.

## Evidence files

- [Baseline summary CSV](../benchmarks/results/baseline/summary.csv)
- Raw plans: `../benchmarks/results/baseline/R01.txt` through `R25.txt` and `W01.txt` through `W05.txt`.
- The baseline artifacts are stored under `benchmarks/results/baseline/`.

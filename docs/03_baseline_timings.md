# Phase 3 — Baseline Query Timings

## 1. Overview

- **Project:** DE Project 2026 — Practo Doctor Appointments Database
- **Database:** `practo_db`
- **Database schema:** `practo`
- **Workload:** `queries/workload_30.sql`
- **Total queries:** 30 (25 READ and 5 WRITE)
- **Runs per query:** 3
- **Measurement:** `EXPLAIN (ANALYZE, BUFFERS)`; execution time reported in milliseconds (ms)
- **Raw execution plans:** `benchmarks/results/before/`
- **Summary output:** `benchmarks/results/before/summary.csv`

## 2. Run timings

| Item | Recorded value |
|---|---|
| Database | `practo_db` |
| PostgreSQL schema | `practo` |
| Workload file | `queries/workload_30.sql` |
| Benchmark phase/directory | `before` / `benchmarks/results/before/` |
| Runs per query | 3 |
| Timing source | `Execution Time` from `EXPLAIN (ANALYZE, BUFFERS)` |
| WRITE handling | Benchmark script wraps writes in a transaction and rolls them back |
| Consolidated evidence | `benchmarks/results/before/summary.csv` |
| Per-query evidence | `R01.txt`–`R25.txt`, `W01.txt`–`W05.txt` |

Command recorded from the completed run:

```bash
./benchmarks/run_benchmark.sh practo_db before
```

**Naming note:** The faculty README describes the Phase 3 output directory as `benchmarks/results/baseline/` and illustrates the phase argument `baseline`. The benchmark script used for this run accepts `before`/`after`, and the actual evidence was produced under `benchmarks/results/before/`. The `before` results are reported transparently here; do not rename the directory or claim it is `baseline` unless the script/output is reconciled with the faculty's required naming convention.

The three runs per query were already present in the supplied `before.zip`; this report extracts and verifies those recorded runs rather than claiming a new live rerun. Each Run 1/2/3 value below was extracted from the corresponding raw plan file. Each displayed average is the arithmetic mean of those three raw `Execution Time` values, rounded to three decimal places. The raw files and summary CSV should be committed as evidence for these figures.

## 2. Run timings — complete results

All times are milliseconds (ms).

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---:|---:|---:|---:|---:|
| R01: Find a doctor: verified dermatologists practising in Bengaluru, most experienced first | READ | 3.302 | 2.011 | 1.647 | 2.320 |
| R02: Doctor profile: doctor 217's weekly timetable with clinic names | READ | 0.283 | 0.265 | 0.245 | 0.264 |
| R03: Slot picker: doctor 217's free in-clinic slots on Friday 3 July 2026 | READ | 10.362 | 8.778 | 8.178 | 9.106 |
| R04: My appointments: patient 90's upcoming appointments | READ | 6.275 | 6.369 | 6.575 | 6.406 |
| R05: Doctor's queue: doctor 16's appointments on 30 June 2026 | READ | 5.381 | 4.881 | 4.771 | 5.011 |
| R06: Sign-in with mobile number | READ | 0.023 | 0.020 | 0.020 | 0.021 |
| R07: Prescription view: the prescription and medicines of appointment 18872 | READ | 0.698 | 0.041 | 0.039 | 0.259 |
| R08: Quality: no-show rate per specialization in 2026 | READ | 19.146 | 18.886 | 18.628 | 18.887 |
| R09: Clinic experience: average minutes patients waited after their slot time, per clinic (June 2026) | READ | 7.694 | 7.495 | 7.366 | 7.518 |
| R10: Patient safety: patients allergic to penicillin who were prescribed amoxicillin | READ | 22.761 | 16.476 | 16.331 | 18.523 |
| R11: Care team: follow-ups due in the first week of July 2026 that the patient has not booked yet | READ | 15.987 | 15.825 | 15.724 | 15.845 |
| R12: Product analytics: video vs in-clinic appointments per month in 2026 | READ | 22.416 | 21.783 | 21.942 | 22.047 |
| R13: Clinic partnerships: clinics where no doctor has any schedule | READ | 2.485 | 2.317 | 2.444 | 2.415 |
| R14: Doctor ranking: average rating and recommendation rate (at least 10 reviews) | READ | 17.308 | 17.263 | 17.548 | 17.373 |
| R15: Pharmacy partners: most prescribed medicines per primary specialization in June 2026 | READ | 19.868 | 19.178 | 19.302 | 19.449 |
| R16: Finance: fees collected per clinic in June 2026 | READ | 8.936 | 8.838 | 8.711 | 8.828 |
| R17: Population health: completed appointments by patient age group and blood group (2026) | READ | 39.938 | 39.584 | 40.505 | 40.009 |
| R18: Search filter: Tamil-speaking doctors with Chennai clinics | READ | 4.037 | 3.950 | 3.668 | 3.885 |
| R19: City report: June 2026 completed consultations and latest consultation of every doctor with a Bengaluru clinic | READ | 4417.225 | 4353.562 | 4331.229 | 4367.339 |
| R20: Platform analytics: completed appointments per day and running total, June 2026 | READ | 8.073 | 7.606 | 7.564 | 7.748 |
| R21: Finance: completed in-clinic consultations whose fee is still unpaid | READ | 8.433 | 8.115 | 7.727 | 8.092 |
| R22: Support console: all appointments, newest first, page 4,001 (25 per page) | READ | 32.642 | 31.659 | 31.947 | 32.083 |
| R23: Verification team: look up a doctor by medical council registration number | READ | 0.027 | 0.020 | 0.022 | 0.023 |
| R24: Data quality: two active appointments of the same doctor in the same slot | READ | 20.710 | 19.726 | 20.375 | 20.270 |
| R25: Care quality: patients who saw 3 or more different doctors of the same specialization in 2026 | READ | 18.414 | 18.431 | 17.926 | 18.257 |
| W01: Book: patient 90 books doctor 217's 10:30 slot on Friday 3 July 2026 | WRITE | 0.578 | 0.499 | 0.492 | 0.523 |
| W02: Reception: check in the earliest BOOKED in-clinic appointment of 1 July 2026 | WRITE | 6.567 | 6.351 | 6.375 | 6.431 |
| W03: Doctor: add notes and a follow-up date to the prescription of appointment 18872 | WRITE | 0.152 | 0.121 | 0.116 | 0.130 |
| W04: Nightly job (run at 00:00 on 2 July 2026): BOOKED appointments whose slot has ended become NO_SHOW | WRITE | 8.448 | 8.731 | 8.525 | 8.568 |
| W05: Doctor on leave: cancel and refund all of doctor 504's appointments on 3 July 2026 | WRITE | 6.558 | 6.489 | 6.426 | 6.491 |
| **Total (sum of all 30)** | — | **4734.727** | **4655.270** | **4632.368** | **4674.121** |

**Interpretation:** The Run 1/2/3 totals are sums of the raw query execution times: 4734.727 ms, 4655.270 ms and 4632.368 ms. The Average column total (4674.121 ms) is the sum of the individually rounded per-query averages. The mean of the three raw run totals is 4674.122 ms; the 0.001 ms difference is caused by rounding each query average to three decimals. This is not the wall-clock duration of the benchmark script.

## 3. Scan type and why each query is slow or fast

Scan nodes below are reproduced from the benchmark summary. A sequential scan is not automatically a defect: it can be appropriate when a query reads a large fraction of a table or performs broad aggregation. The explanations are interpretations of observed nodes and timings; optimization decisions must be validated against full plans.

| Query | Observed scan nodes | Why the query is relatively fast or slow |
|---|---|---|
| R01 | Seq Scan on doctor_specializations; Seq Scan on specializations; Index Scan using doctors_pkey on doctors; Index Scan using pk_doctor_schedules on doctor_schedules; Seq Scan on clinics | Selective filters and joins benefit from existing doctor/schedule indexes; scans of the specialization bridge and clinics add work. |
| R02 | Index Scan using pk_doctor_schedules on doctor_schedules; Seq Scan on clinics | Very fast indexed schedule lookup; the clinic relation is scanned to obtain clinic details. |
| R03 | Index Scan using pk_doctor_schedules on doctor_schedules; Seq Scan on appointments | The schedule lookup is indexed, but appointments are scanned to exclude already-booked slots. |
| R04 | Seq Scan on appointments; Index Scan using doctors_pkey on doctors; Seq Scan on clinics | Appointments are scanned to find the patient's upcoming rows; doctor lookup uses its primary-key index and clinics are scanned. |
| R05 | Seq Scan on appointments; Index Scan using patients_pkey on patients | Appointments are scanned for the queue and patient rows are reached through the patient primary-key index. |
| R06 | Index Scan using patients_phone_key on patients | Very fast point lookup through the unique patient phone index. |
| R07 | Index Scan using prescriptions_appointment_id_key on prescriptions; Index Scan using pk_prescription_items on prescription_items | Very fast lookup through the unique appointment-to-prescription index and prescription-item primary-key index. |
| R08 | Seq Scan on appointments; Seq Scan on doctor_specializations; Seq Scan on specializations | Scans appointments and specialization mapping tables to aggregate no-show rates by specialization. |
| R09 | Seq Scan on appointments | Scans appointments to filter and aggregate the June 2026 waiting-time data. |
| R10 | Seq Scan on appointments; Seq Scan on patients; Index Scan using prescriptions_appointment_id_key on prescriptions; Index Scan using pk_prescription_items on prescription_items | Scans appointments and patients; prescription joins use existing indexes, but base filtering remains scan-heavy. |
| R11 | Seq Scan on appointments; Seq Scan on prescriptions; Index Scan using appointments_pkey on appointments | Scans appointments and prescriptions to identify follow-ups and booking status; an appointments index is also used. |
| R12 | Seq Scan on appointments | Scans appointments for month/type aggregation; this is a broad analytical aggregation rather than a selective lookup. |
| R13 | Seq Scan on clinics; Seq Scan on doctor_schedules | Scans clinics and doctor_schedules to identify clinics without schedules. |
| R14 | Seq Scan on appointments; Seq Scan on doctor_reviews | Scans appointments and doctor_reviews to aggregate ratings and appointment outcomes. |
| R15 | Seq Scan on prescription_items; Seq Scan on appointments; Seq Scan on prescriptions; Seq Scan on doctor_specializations; Seq Scan on specializations | Scans prescription items, appointments, prescriptions and specialization mappings to aggregate medicine counts. |
| R16 | Seq Scan on appointments; Seq Scan on clinics | Scans appointments and clinics for clinic-level fee aggregation. |
| R17 | Seq Scan on appointments; Seq Scan on patients | Scans appointments and patients for age/blood-group aggregation; broad scans explain the higher cost. |
| R18 | Seq Scan on doctor_schedules; Seq Scan on doctors; Seq Scan on clinics | Scans schedules and joins doctors/clinics; this remains relatively quick at the seed-data scale. |
| R19 | Seq Scan on doctor_schedules; Seq Scan on clinics; Seq Scan on doctors; two correlated Seq Scan subplans on appointments | The outer joins are relatively small; the dominant cost is two appointment-table subplans executed 480 times each. Each execution scans approximately 150,000 rows, producing about 2.61 million shared-buffer hits per subplan across all loops. |
| R20 | Seq Scan on appointments | Scans appointments for daily counts and a running-total calculation over the June period. |
| R21 | Seq Scan on appointments | Scans appointments to filter and report completed but unpaid consultations. |
| R22 | Seq Scan on appointments | Scans appointments for a deep OFFSET page; processing and skipping a large prefix of rows makes it expensive. |
| R23 | Index Scan using doctors_registration_no_key on doctors | Very fast point lookup through the unique doctors_registration_no index. |
| R24 | Seq Scan on appointments | Scans appointments to detect same-doctor/same-slot conflicts. |
| R25 | Seq Scan on appointments; Seq Scan on doctor_specializations | Scans appointments and doctor_specializations to find patients seeing multiple doctors in the same specialization. |
| W01 | Index Scan using pk_doctor_schedules on doctor_schedules; Index Scan using doctors_pkey on doctors | Uses doctor and schedule primary-key indexes for the booking operation. |
| W02 | Seq Scan on appointments; Index Scan using appointments_pkey on appointments | Scans appointments to find the oldest eligible booking, then uses the appointments primary-key index for the target row. |
| W03 | Index Scan using prescriptions_appointment_id_key on prescriptions | Very fast target lookup through the unique prescription appointment_id index. |
| W04 | Seq Scan on appointments | Scans appointments to find and update all eligible past slots; the broad batch update explains the higher write time. |
| W05 | Seq Scan on appointments | Scans appointments to identify all affected doctor/date rows for cancellation/refund updates. |

## 4. Key findings

### 5.1 Highest average execution times

| Rank | Query | Average (ms) |
|---:|---|---:|
| 1 | R19 | 4367.339 |
| 2 | R17 | 40.009 |
| 3 | R22 | 32.083 |
| 4 | R12 | 22.047 |
| 5 | R24 | 20.270 |
| 6 | R15 | 19.449 |
| 7 | R08 | 18.887 |
| 8 | R10 | 18.523 |

- `R19` is the clear outlier at 4367.339 ms (approximately 4.37 seconds). Its plan includes scans across schedules, clinics, doctors and appointments.
- `R17` and `R22` are the next most expensive queries. Their plans show broad scans on appointments and patients (R17), and appointments (R22).
- `R12`, `R24`, `R15`, `R08`, `R10` and `R25` are additional candidates for plan-level investigation.

### 5.2 Fastest queries

| Query | Average (ms) | Main observed access path |
|---|---:|---|
| R06 | 0.021 | Index Scan using patients_phone_key on patients |
| R23 | 0.023 | Index Scan using doctors_registration_no_key on doctors |
| W03 | 0.130 | Index Scan using prescriptions_appointment_id_key on prescriptions |
| R07 | 0.259 | Index Scan using prescriptions_appointment_id_key on prescriptions; Index Scan using pk_prescription_items on prescription_items |
| R02 | 0.264 | Index Scan using pk_doctor_schedules on doctor_schedules; Seq Scan on clinics |

These are selective lookups supported by existing unique or primary-key indexes. Their low measured times are consistent with the access paths shown in the plans.

### 5.3 READ and WRITE observations

- READ queries account for 25 workload items; WRITE queries account for 5.
- Sequential scans on `appointments` appear frequently because it is central to many operational and analytical queries.
- WRITE timings are measured under rollback-protected transactions. They are not a full production throughput or concurrency benchmark.
- A scan node alone does not prove an optimization opportunity. Phase 4 decisions should also consider predicates, actual/estimated rows, buffers, loops, sorts and hash operations.

### 5.4 Detailed diagnosis of R19 from its raw execution plans

R19 is not merely slow because it contains sequential scans. Its raw plans show a specific repeated-work pattern:

- The outer part of the plan joins `doctor_schedules`, `clinics` and `doctors`, then returns 480 qualifying doctors. The outer schedule/clinic work takes only a few milliseconds.
- `SubPlan 1` runs **480 loops**. In each loop, it sequentially scans `appointments` for the doctor's completed appointments in June 2026. Each loop removes approximately 149,998 rows by its filter and returns about 2.26 rows to the aggregate.
- `SubPlan 2` also runs **480 loops**. It performs another sequential scan of `appointments` for each doctor. Each loop removes approximately 149,950 rows and returns about 49.60 rows to the aggregate.
- Each subplan reports **1,305,600 shared-buffer hits** across its 480 loops. Together, the two subplans account for approximately **2,611,200 shared-buffer hits**. These are buffer hits, not physical disk reads.
- The three measured execution times are **4417.225 ms**, **4353.562 ms** and **4331.229 ms**. The reported average is **4367.339 ms**.

This evidence supports the conclusion that repeated correlated scans of the 150,000-row `appointments` table dominate R19. It is stronger and more specific than attributing the delay to sequential scans in general.

**Phase 4 implication:** inspect whether the two per-doctor aggregates can be computed once for the relevant doctor set and joined back, rather than rescanning `appointments` for every doctor. Any rewrite must preserve the exact result, including doctors with no matching June consultations and the required latest-consultation behavior. Validate equivalence against the original query before comparing timings. Index candidates should be evaluated from the rewritten query's actual plan; this report does not prescribe an untested index.

## 5. Notes

1. These measurements describe one machine, one PostgreSQL instance, one seed dataset and one measurement session.
2. Hardware model, operating-system version, PostgreSQL minor version, memory configuration and background workload were not captured in the supplied benchmark evidence. They are intentionally not invented here.
3. Three repetitions satisfy the project protocol but are a small sample. Cache warming and normal system noise can affect individual runs.
4. `Execution Time` is PostgreSQL executor timing from `EXPLAIN ANALYZE`; it is not end-to-end application latency and excludes client/network rendering time.
5. Sequential scans can be appropriate for broad scans and aggregations. Indexes should be added only when supported by query shape and full plan evidence.
6. The faculty-provided workload must remain unchanged. Any discovered semantic issue should be documented and addressed in the optimization deliverable rather than silently editing the baseline workload.

## 6. Phase 4 optimization priorities

| Priority | Query | Reason to investigate |
|---|---|---|
| 1 | R19 | Two correlated appointment subplans each execute 480 full scans; inspect a set-based rewrite and verify result equivalence before testing indexes. |
| 2 | R17 | Relatively expensive aggregation involving appointments and patients. |
| 3 | R22 | Deep OFFSET pagination may require processing/skipping a large prefix of rows. |
| 4 | R12 | Monthly grouping over appointments; inspect date predicates and aggregation plan. |
| 5 | R24 | Double-booking detection may compare many appointment rows; inspect join/aggregation strategy. |

These are investigation priorities, not pre-approved index prescriptions. Every index must be justified in `sql/05_indexes.sql`; every rewritten query must preserve the required result set and ordering.

## 7. Conclusion

The baseline measurement completed for all 30 workload queries with three runs per query. The sum of the 30 per-query averages is **4674.121 ms**. `R19` is the dominant performance outlier, while several selective lookups already use existing unique/primary-key indexes and execute in sub-millisecond time.

This report establishes the pre-optimization reference only. It makes no claim that any query has been optimized or that any performance target has been met. Phase 4 must use the same workload, dataset, machine and measurement method; preserve raw plans; justify every index/rewrite; and prove result equivalence for rewritten queries.

---

*Evidence source: supplied `before.zip` containing `summary.csv` and all 30 raw plan files, together with the faculty project brief in the repository README. Query labels follow the Phase 3 deliverable table in that brief. R19's repeated-loop diagnosis was checked directly against all three raw R19 plans.*

# CP3 Phase 4: Query Optimization Report

## Executive summary

The optimized workload substantially reduced elapsed time for selective lookups, date-window searches, and the R19 city report. Using the average execution times in the saved summaries, 27 of 30 queries were faster, 3 were slower, and 0 were unchanged at the recorded precision. R19 improved from 4,852.527 ms to 24.267 ms (199.96×), the largest gain. After the CP4 scale investigation, R24 was rewritten and remeasured on the seed database; the current five-run mean is 17.945 ms and its current large-data mean is recorded separately in the scalability report.

R13 is a correctness correction as well as a query rewrite. Its original `NOT IN` returns no rows when the subquery contains NULL clinic IDs; the optimized `NOT EXISTS` returns the 292 clinics without schedules. Its timing difference is therefore not a strictly like-for-like result comparison.

The baseline summary contains three executions per query; the optimized summary contains five. All timings below are the actual `avg_ms` values from those CSVs. Speedup is calculated as `baseline avg_ms / optimized avg_ms`; a value below 1× indicates a slowdown.

## Before/after timing and per-query technique

| Query | Baseline avg (ms) | Optimized avg (ms) | Speedup / slowdown | Technique or explanation |
|---|---:|---:|---:|---|
| R01 | 1.661 | 1.597 | 1.04×; 3.9% faster | Replaced multiplicative joins and `DISTINCT` with specialization and clinic `EXISTS` checks; verified-doctor, specialization, and city indexes appear in the plan. |
| R02 | 0.194 | 0.433 | 0.45×; 123.2% slower | No rewrite; the schedule primary key serves the doctor lookup. Clinic lookup remains a small sequential scan. |
| R03 | 8.711 | 0.091 | 95.73×; 99.0% faster | Uses the partial in-clinic schedule index and active doctor/slot index for the availability anti-lookup. |
| R04 | 6.734 | 0.086 | 78.30×; 98.7% faster | Uses the patient/status/slot covering index to find the patient’s booked appointments. |
| R05 | 5.312 | 0.105 | 50.59×; 98.0% faster | Replaced `DATE(slot_start)` with a half-open timestamp range; the doctor/slot index serves the lookup and ordering. |
| R06 | 0.028 | 0.022 | 1.27×; 21.4% faster | No rewrite; existing unique phone index serves the exact lookup. |
| R07 | 0.112 | 0.045 | 2.49×; 59.8% faster | No rewrite; prescription appointment uniqueness and the prescription-item primary key serve the joins. |
| R08 | 18.087 | 12.476 | 1.45×; 31.0% faster | Uses a half-open 2026 timestamp range instead of extracting the year; the plan reads the slot-start index. |
| R09 | 8.223 | 2.472 | 3.33×; 69.9% faster | No rewrite; the completed-appointment partial slot index serves the June window. |
| R10 | 19.251 | 19.964 | 0.96×; 3.7% slower | No rewrite; the allergy containment predicate uses the patients’ GIN index. The remaining joins still touch appointments, prescriptions, and prescription items. |
| R11 | 17.712 | 1.640 | 10.80×; 90.7% faster | No rewrite; uses the follow-up-date index and an indexed active-appointment anti-lookup. |
| R12 | 26.287 | 9.751 | 2.70×; 62.9% faster | Replaced year extraction with a half-open timestamp range; the slot-start index supports the bounded scan. |
| R13 | 2.704 | 0.590 | 4.58×; 78.2% faster | Replaced NULL-sensitive `NOT IN` with `NOT EXISTS`; the clinic-ID schedule index supports the existence check. |
| R14 | 20.355 | 19.084 | 1.07×; 6.2% faster | No rewrite; ranking aggregates the review population, so both plans scan appointments and reviews. |
| R15 | 22.688 | 21.484 | 1.06×; 5.3% faster | No rewrite; the broad prescription-to-appointment-specialization aggregation still uses sequential scans. |
| R16 | 9.670 | 1.779 | 5.44×; 81.6% faster | No rewrite; the June timestamp range uses the slot-start index before clinic aggregation. |
| R17 | 37.900 | 32.731 | 1.16×; 13.6% faster | No rewrite; the completed-slot partial index narrows appointments, but patient joining and age-group aggregation remain broad. |
| R18 | 4.312 | 2.659 | 1.62×; 38.3% faster | Replaced `= ANY(array)` with GIN-supported array containment and schedule/clinic joins with `EXISTS`. |
| R19 | 4,852.527 | 24.267 | 199.96×; 99.5% faster | Aggregates appointment statistics once by doctor and left-joins them, rather than running two correlated appointment scans per doctor. |
| R20 | 7.982 | 1.066 | 7.49×; 86.6% faster | Replaced the cast-to-date filter with a half-open timestamp range; uses the completed-slot partial index. |
| R21 | 8.306 | 0.094 | 88.36×; 98.9% faster | No rewrite; the completed-and-pending partial covering index supplies the newest 100 rows. |
| R22 | 33.728 | 7.911 | 4.26×; 76.5% faster | Preserved `OFFSET 100000 LIMIT 25`; the slot-start index supplies descending order without a full sort. The large offset remains. |
| R23 | 0.185 | 0.084 | 2.20×; 54.6% faster | No rewrite; the existing unique registration-number index serves the lookup. |
| R24 | 32.143 | 17.945 | 1.79×; 44.2% faster | Scale-driven rewrite groups duplicate active `(doctor_id, slot_start)` values once, then joins through the active doctor/slot indexes; current seed timing is five runs, recorded in `benchmarks/results/optimized_r24_scale_fix_seed/`. |
| R25 | 19.776 | 15.066 | 1.31×; 23.8% faster | No rewrite; uses the completed-slot partial index with the primary-specialization association. |
| W01 | 0.723 | 0.834 | 0.87×; 15.4% slower | SQL unchanged; schedule and doctor primary keys serve the insert-select. The insert also maintains the appointment indexes. |
| W02 | 7.043 | 0.245 | 28.75×; 96.5% faster | SQL unchanged; the booked-slot partial index finds the earliest eligible appointment, then the appointment primary key updates it. |
| W03 | 0.301 | 0.154 | 1.95×; 48.8% faster | SQL unchanged; prescription appointment uniqueness serves the update lookup. The follow-up-date index may add maintenance work. |
| W04 | 9.141 | 6.499 | 1.41×; 28.9% faster | SQL unchanged; the partial unfinished-slot-end index finds eligible rows. |
| W05 | 6.878 | 0.245 | 28.07×; 96.4% faster | SQL unchanged; the booked-doctor/slot partial index finds the affected appointments. |

\* R13’s output intentionally changes: baseline returns 0 rows; optimized returns 292. The timing ratio describes measured elapsed time, not equivalent-result performance.

## Five largest improvements: plan evidence

Average times below come from the summary CSVs. The plan details and buffer counts are from run 1 of each raw plan file; run-level plan times need not equal the multi-run average.

1. **R19 — 199.96×.** Average time fell from 4,852.527 ms to 24.267 ms. The baseline plan runs two sequential scans of `appointments` as correlated subplans, each with 480 loops; the first-run plan reports 2,611,500 shared-buffer hits. The optimized plan scans appointments once into a `HashAggregate` grouped by doctor and joins the result; its first-run plan reports 3,002 shared-buffer hits. This removes the repeated work responsible for R19’s baseline cost. See [baseline R19 plan](../benchmarks/results/baseline/R19.txt) and [optimized R19 plan](../benchmarks/results/optimized/R19.txt).

2. **R03 — 95.73×.** Average time fell from 8.711 ms to 0.091 ms. The baseline availability anti-check sequentially scans appointments. The optimized plan uses `idx_schedules_inclinic_doctor_weekday_start` and the partial `idx_appointments_active_doctor_slot` index-only scan. First-run shared-buffer hits fell from 2,723 to 7. See [baseline R03 plan](../benchmarks/results/baseline/R03.txt) and [optimized R03 plan](../benchmarks/results/optimized/R03.txt).

3. **R21 — 88.36×.** Average time fell from 8.306 ms to 0.094 ms. The baseline plan parallel-scans appointments and performs a top-N sort. The optimized plan reads the required rows in order from `idx_appointments_completed_pending_slot` using an index-only scan, without that full scan-and-sort path. First-run shared-buffer hits fell from 2,758 to 1 (the optimized plan also reports 2 shared-buffer reads). See [baseline R21 plan](../benchmarks/results/baseline/R21.txt) and [optimized R21 plan](../benchmarks/results/optimized/R21.txt).

4. **R04 — 78.30×.** Average time fell from 6.734 ms to 0.086 ms. The baseline plan scans all appointments and sequentially scans clinics during the join. The optimized plan uses `idx_appointments_patient_status_slot` and primary-key lookups for doctors and clinics. First-run shared-buffer hits fell from 2,755 to 9 (the optimized plan also reports 7 shared-buffer reads). See [baseline R04 plan](../benchmarks/results/baseline/R04.txt) and [optimized R04 plan](../benchmarks/results/optimized/R04.txt).

5. **R05 — 50.59×.** Average time fell from 5.312 ms to 0.105 ms. The baseline plan uses a parallel sequential scan of appointments for the doctor/date condition. The timestamp-range rewrite allows `idx_appointments_doctor_slot` to provide an index-only scan; the patient primary key serves the remaining join. First-run shared-buffer hits fell from 2,726 to 6 (the respective plans also report 6 and 7 shared-buffer reads). See [baseline R05 plan](../benchmarks/results/baseline/R05.txt) and [optimized R05 plan](../benchmarks/results/optimized/R05.txt).

## Result-equivalence validation

On 21 November 2026, the original and current optimized SQL for every changed read query was executed against the existing PostgreSQL 18.7 seed validation databases (`cp3_audit_base_20261119` and `cp3_audit_opt_20261119`). The checker compares ordered rows, row multisets, SHA-256 digests and `EXCEPT ALL` in both directions. Its reproducible implementation is `benchmarks/validate_equivalence.py`; the latest captured output is [equivalence_check_20261121.txt](../benchmarks/results/optimized/equivalence_check_20261121.txt). The earlier captures are retained as historical evidence.

R01, R05, R08, R12, R19 and R20 produced identical ordered rows. R18 returned the same 360-row multiset and the same order after adding a stable doctor-ID tie-breaker. The current R24 rewrite returned the same 559-row multiset; row order can differ because its `ORDER BY slot_start` does not define order among equal timestamps. R13 intentionally changed from 0 rows to 292 unscheduled clinics due to the NULL-correctness fix described below. Seed result validation does not by itself prove equivalence on every possible future database state.

The literal workload comparisons for R21 and R22 in the earlier captures show different rows at their LIMIT/OFFSET boundaries because `slot_start` is not unique. The current checker adds `appointment_id ASC` to the reference execution, matching the stable ordering in the optimized SQL; the latest run reports identical ordered rows and multisets for both queries. This proves equivalence under deterministic tie ordering, not identical boundary membership against the literal, non-unique ordering. The faculty workload itself remains unchanged.

## R13 NULL correctness

The original R13 condition was `clinic_id NOT IN (SELECT clinic_id FROM doctor_schedules)`. Video schedules have `clinic_id IS NULL`. Under SQL three-valued logic, when the subquery contains NULL and no equal clinic ID is found, `NOT IN` evaluates to UNKNOWN; the `WHERE` clause therefore rejects every clinic. On the measured data, baseline R13 returns zero rows. The optimized query uses `NOT EXISTS (SELECT 1 FROM doctor_schedules sc WHERE sc.clinic_id = c.clinic_id)`, which is not poisoned by unrelated NULLs and returns the 292 unscheduled clinics. This intentionally fixes the result, rather than preserving the incorrect baseline output.

## Write-query performance and index maintenance

The baseline and optimized averages show the net change for the five write statements, all measured with rollback. The table reports the observed difference; it does not by itself isolate index-maintenance cost from run-to-run and database-state effects.

| Query | Baseline mean (ms) | Optimized mean (ms) | Change (ms) | Observed result |
|---|---:|---:|---:|---|
| W01 | 0.723 | 0.834 | +0.111 | Slower by 15.4%; small absolute increase, attribution to index maintenance is not isolated. |
| W02 | 7.043 | 0.245 | −6.798 | Faster; the booked-slot partial index narrows candidate selection. |
| W03 | 0.301 | 0.154 | −0.147 | Faster in these runs; added index maintenance did not outweigh the indexed lookup. |
| W04 | 9.141 | 6.499 | −2.642 | Faster; the unfinished-slot partial index narrows the update set. |
| W05 | 6.878 | 0.245 | −6.633 | Faster; the booked-doctor/slot partial index narrows candidate selection. |

The summed averages are 24.086 ms baseline and 7.977 ms optimized, a 3.02× lower total for one execution of each statement. This is a workload before/after comparison, not a controlled estimate of index-only write cost. The full three-run/five-run source measurements remain in the raw plan files and summaries; each write is wrapped in `BEGIN`/`ROLLBACK`.

### Controlled secondary-index write experiment

On 21 November 2026, `benchmarks/measure_index_write_overhead.sql` copied the same 3,000,000 large-data appointments into two session-temporary tables. Both had the same primary key; one had no secondary indexes and the other had the ten appointments indexes from `sql/05_indexes.sql`. Each trial updated the same 5,000 `BOOKED` appointment IDs to `CHECKED_IN` and set `checked_in_at`, using the primary key for row lookup. Each update ran under `EXPLAIN (ANALYZE, BUFFERS)`, was rolled back, and the target table was vacuumed before its next trial. The order was interleaved. Table and index sizes were measured on the two copies.

| Variant | Table bytes | Primary-key index bytes | Secondary-index bytes | Three-run mean (ms) |
|---|---:|---:|---:|---:|
| Primary key only | 440,410,112 | 67,403,776 | 0 | 9.845 |
| Primary key + ten workload indexes | 440,410,112 | 67,403,776 | 951,377,920 | 115.362 |

For this specific 5,000-row status transition, the indexed copy took 105.517 ms more on average (11.72× the primary-key-only time). The identical source rows, primary-key access, update values, row count, and rollback procedure make secondary-index maintenance the controlled difference in this experiment. The raw plans and sizes are in [index_write_overhead.log](../benchmarks/results/large/index_write_overhead.log) and [index_write_overhead.csv](../benchmarks/results/large/index_write_overhead.csv); the repeatable setup is the SQL file above.

This is not a production write-latency estimate: PostgreSQL temporary tables are session-scoped and are not WAL-logged, so WAL, durable commit, replica, and production concurrency costs are excluded ([PostgreSQL temporary tables](https://www.postgresql.org/docs/18/sql-createtable.html)). It isolates the local cost of maintaining these secondary indexes for this update shape; it does not imply the same multiplier for W01–W05. The earlier W-query measurements remain the appropriate net workload results.

## Index storage compared with table storage

Measured on 18 November 2026 in the fresh `cp1_validation` database after loading the 11 seed CSVs, applying `sql/05_indexes.sql`, and running `ANALYZE`. The figures are PostgreSQL `pg_table_size`, `pg_indexes_size`, and `pg_database_size`; the schema totals cover all 11 ordinary `practo` tables:

| Storage measure | Size |
|---|---:|
| Table storage (`pg_table_size`) | 58,073,088 bytes (55.38 MiB) |
| Index storage (`pg_indexes_size`) | 77,889,536 bytes (74.28 MiB) |
| Tables plus indexes | 135,962,624 bytes (129.66 MiB) |
| Database total (`pg_database_size`) | 144,668,351 bytes (137.97 MiB) |

Index storage is 1.34× table storage, or 34.1% larger; it accounts for 57.3% of the combined table-plus-index total. The largest table is `appointments` (22,323,200 table bytes and 51,150,848 index bytes); the largest index is `idx_appointments_slot_start` (13,156,352 bytes). The largest `prescription_items` table is 18,522,112 bytes, with 12,623,872 bytes of indexes. These values include primary/unique indexes and all indexes from `sql/05_indexes.sql`; they are a fresh seed measurement, not a large-data measurement.

Largest measured indexes in the same fresh database:

| Index | Table | Bytes | MiB |
|---|---|---:|---:|
| `idx_appointments_slot_start` | appointments | 13,156,352 | 12.55 |
| `idx_appointments_doctor_slot` | appointments | 11,051,008 | 10.54 |
| `idx_appointments_patient_status_slot` | appointments | 10,149,888 | 9.68 |
| `idx_appointments_completed_slot` | appointments | 7,168,000 | 6.84 |
| `idx_prescription_items_medicine_trgm` | prescription_items | 7,135,232 | 6.80 |
| `pk_prescription_items` | prescription_items | 5,488,640 | 5.23 |

### Size of every Phase 4 workload index

The following read-only `pg_relation_size` measurements were taken on 21 November 2026 from `cp3_audit_opt_20261119` (PostgreSQL 18.7). `table_bytes` uses `pg_table_size`. This table covers each of the 19 workload indexes created by `sql/05_indexes.sql`; primary-key and other schema indexes are not included. The raw CSV records database, version, timestamp and exact byte counts.

| Table | Index | Index size (bytes) | Table size (bytes) | Index / table |
|---|---|---:|---:|---:|
| appointments | `idx_appointments_active_doctor_slot` | 4,276,224 | 23,060,480 | 18.544% |
| appointments | `idx_appointments_booked_doctor_slot` | 114,688 | 23,060,480 | 0.497% |
| appointments | `idx_appointments_booked_slot` | 139,264 | 23,060,480 | 0.604% |
| appointments | `idx_appointments_completed_pending_slot` | 1,236,992 | 23,060,480 | 5.364% |
| appointments | `idx_appointments_completed_slot` | 7,168,000 | 23,060,480 | 31.083% |
| appointments | `idx_appointments_doctor_slot` | 13,443,072 | 23,060,480 | 58.295% |
| appointments | `idx_appointments_noshow_slot` | 491,520 | 23,060,480 | 2.131% |
| appointments | `idx_appointments_patient_status_slot` | 12,566,528 | 23,060,480 | 54.494% |
| appointments | `idx_appointments_slot_start` | 13,344,768 | 23,060,480 | 57.869% |
| appointments | `idx_appointments_unfinished_slot_end` | 98,304 | 23,060,480 | 0.426% |
| clinics | `idx_clinics_city_clinic` | 57,344 | 204,800 | 28.000% |
| doctor_schedules | `idx_schedules_clinic_id` | 212,992 | 1,875,968 | 11.354% |
| doctor_schedules | `idx_schedules_inclinic_doctor_weekday_start` | 1,236,992 | 1,875,968 | 65.939% |
| doctor_specializations | `idx_doctor_specializations_primary_spec_doctor` | 90,112 | 196,608 | 45.833% |
| doctors | `idx_doctors_languages_gin` | 24,576 | 458,752 | 5.357% |
| doctors | `idx_doctors_verified_experience` | 155,648 | 458,752 | 33.929% |
| patients | `idx_patients_allergies_gin` | 81,920 | 4,587,520 | 1.786% |
| prescription_items | `idx_prescription_items_medicine_trgm` | 7,135,232 | 18,522,112 | 38.523% |
| prescriptions | `idx_prescriptions_follow_up_date` | 671,744 | 7,512,064 | 8.942% |

Raw measurement: [index_storage_detailed.csv](../benchmarks/results/optimized/index_storage_detailed.csv), produced by [measure_index_storage.sql](../benchmarks/measure_index_storage.sql).

## Queries with little or no improvement

- **R01** was 3.9% faster. **R02** was 123.2% slower in relative terms but only 0.239 ms slower in absolute terms (0.194 to 0.433 ms). Its plan still uses the schedule primary key; the low absolute runtime makes repeated measurements important before treating this as a material service regression.
- **R24**'s original CP3 query was a broad active-appointment self-join. The scale-driven grouped rewrite now returns the same seed row multiset and averages 17.945 ms on seed data; its large-data before/after evidence is discussed in the Phase 5 report.
- **W01** was 0.111 ms slower (15.4%) in these runs. It is a short write; the evidence does not isolate index-maintenance cost from timing variation.
- **R14 and R15** improved 6.2% and 5.3%. Both aggregate broadly across reviews or prescription items and their related rows, so the query-specific indexes do not remove most of the work.

Other moderate improvements also leave substantial work in place: R10 still joins several large relations after the allergy GIN lookup; R17 still joins and groups many completed appointments; and R22 still advances through the 100,000 rows required by its specified offset.

## Overall conclusions

The most effective changes combined selective predicates with indexes already defined for their access paths. The R19 aggregation rewrite removed repeated full-table work, while R03–R05 and R21 replaced broad appointment scans with indexed lookups. Date-range predicates in R05, R08, R12, and R20 allow B-tree range scans without changing their date-window semantics.

The workload’s measured improvements come with index storage of 74.28 MiB, compared with 55.38 MiB of table storage in the stated seed measurement. Some low-cost queries remain flat or slower. R22 retains the prescribed page size and offset, with a stable `appointment_id ASC` tie-breaker; the selected rows at a timestamp tie boundary are not guaranteed to match the literal workload's unspecified order. R13's output is intentionally corrected for NULL behavior. R24's later scale rewrite is included in the current optimized SQL and has separate seed and large-data measurements.

## Measurement sources and artifacts

- [Baseline summary](../benchmarks/results/baseline/summary.csv) and [optimized summary](../benchmarks/results/optimized/summary.csv)
- [Latest seed result-equivalence check](../benchmarks/results/optimized/equivalence_check_20261121.txt) and [reusable checker](../benchmarks/validate_equivalence.py)
- Raw plans: `benchmarks/results/baseline/{R01–R25,W01–W05}.txt` and `benchmarks/results/optimized/{R01–R25,W01–W05}.txt`
- Index definitions: [sql/05_indexes.sql](../sql/05_indexes.sql)
- Per-index size evidence: [index_storage_detailed.csv](../benchmarks/results/optimized/index_storage_detailed.csv)
- Controlled secondary-index write experiment: [setup SQL](../benchmarks/measure_index_write_overhead.sql), [raw plans](../benchmarks/results/large/index_write_overhead.log), and [timings and sizes](../benchmarks/results/large/index_write_overhead.csv)
- Optimized workload: [sql/06_optimized_queries.sql](../sql/06_optimized_queries.sql)

Baseline raw plans contain three runs per query; optimized raw plans contain five. No measurements or missing query timings were filled in or estimated.

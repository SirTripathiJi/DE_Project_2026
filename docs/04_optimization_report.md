# CP3 Phase 4: Query Optimization Report

## Executive summary

The optimized workload substantially reduced elapsed time for selective lookups, date-window searches, and the R19 city report. Using the average execution times in the saved summaries, 27 of 30 queries were faster, 3 were slower, and 0 were unchanged at the recorded precision. R19 improved from 4,852.527 ms to 24.267 ms (199.96×), the largest gain.

R13 is a correctness correction as well as a query rewrite. Its original `NOT IN` returns no rows when the subquery contains NULL clinic IDs; the optimized `NOT EXISTS` returns the 292 clinics without schedules. Its timing difference is therefore not a strictly like-for-like result comparison.

The baseline summary contains three executions per query; the optimized summary contains five. All timings below are the actual `avg_ms` values from those CSVs. Speedup is calculated as `baseline avg_ms / optimized avg_ms`; a value below 1× indicates a slowdown.

## Before/after timing and per-query technique

| Query | Baseline avg (ms) | Optimized avg (ms) | Speedup / slowdown | Technique or explanation |
|---|---:|---:|---:|---|
| R01 | 1.661 | 1.597 | 1.04×; 3.8% faster | Replaced multiplicative joins and `DISTINCT` with specialization and clinic `EXISTS` checks; verified-doctor, specialization, and city indexes appear in the plan. |
| R02 | 0.194 | 0.433 | 0.45×; 123.4% slower | No rewrite; the schedule primary key serves the doctor lookup. Clinic lookup remains a small sequential scan. |
| R03 | 8.711 | 0.091 | 95.94×; 99.0% faster | Uses the partial in-clinic schedule index and active doctor/slot index for the availability anti-lookup. |
| R04 | 6.734 | 0.086 | 77.94×; 98.7% faster | Uses the patient/status/slot covering index to find the patient’s booked appointments. |
| R05 | 5.312 | 0.105 | 50.79×; 98.0% faster | Replaced `DATE(slot_start)` with a half-open timestamp range; the doctor/slot index serves the lookup and ordering. |
| R06 | 0.028 | 0.022 | 1.24×; 19.0% faster | No rewrite; existing unique phone index serves the exact lookup. |
| R07 | 0.112 | 0.045 | 2.50×; 60.0% faster | No rewrite; prescription appointment uniqueness and the prescription-item primary key serve the joins. |
| R08 | 18.087 | 12.476 | 1.45×; 31.0% faster | Uses a half-open 2026 timestamp range instead of extracting the year; the plan reads the slot-start index. |
| R09 | 8.223 | 2.472 | 3.33×; 69.9% faster | No rewrite; the completed-appointment partial slot index serves the June window. |
| R10 | 19.251 | 19.964 | 0.96×; 3.7% slower | No rewrite; the allergy containment predicate uses the patients’ GIN index. The remaining joins still touch appointments, prescriptions, and prescription items. |
| R11 | 17.712 | 1.640 | 10.80×; 90.7% faster | No rewrite; uses the follow-up-date index and an indexed active-appointment anti-lookup. |
| R12 | 26.287 | 9.751 | 2.70×; 62.9% faster | Replaced year extraction with a half-open timestamp range; the slot-start index supports the bounded scan. |
| R13 | 2.704 | 0.590 | 4.59×; 78.2% faster | Replaced NULL-sensitive `NOT IN` with `NOT EXISTS`; the clinic-ID schedule index supports the existence check. |
| R14 | 20.355 | 19.084 | 1.07×; 6.2% faster | No rewrite; ranking aggregates the review population, so both plans scan appointments and reviews. |
| R15 | 22.688 | 21.484 | 1.06×; 5.3% faster | No rewrite; the broad prescription-to-appointment-specialization aggregation still uses sequential scans. |
| R16 | 9.670 | 1.779 | 5.44×; 81.6% faster | No rewrite; the June timestamp range uses the slot-start index before clinic aggregation. |
| R17 | 37.900 | 32.731 | 1.16×; 13.6% faster | No rewrite; the completed-slot partial index narrows appointments, but patient joining and age-group aggregation remain broad. |
| R18 | 4.312 | 2.659 | 1.62×; 38.3% faster | Replaced `= ANY(array)` with GIN-supported array containment and schedule/clinic joins with `EXISTS`. |
| R19 | 4,852.527 | 24.267 | 199.96×; 99.5% faster | Aggregates appointment statistics once by doctor and left-joins them, rather than running two correlated appointment scans per doctor. |
| R20 | 7.982 | 1.066 | 7.49×; 86.6% faster | Replaced the cast-to-date filter with a half-open timestamp range; uses the completed-slot partial index. |
| R21 | 8.306 | 0.094 | 88.37×; 98.9% faster | No rewrite; the completed-and-pending partial covering index supplies the newest 100 rows. |
| R22 | 33.728 | 7.911 | 4.26×; 76.5% faster | Preserved `OFFSET 100000 LIMIT 25`; the slot-start index supplies descending order without a full sort. The large offset remains. |
| R23 | 0.185 | 0.084 | 2.19×; 54.4% faster | No rewrite; the existing unique registration-number index serves the lookup. |
| R24 | 32.143 | 22.223 | 1.45×; 30.9% faster | No rewrite; the broad self-join still uses a sequential scan to find duplicate active slots. |
| R25 | 19.776 | 15.066 | 1.31×; 23.8% faster | No rewrite; uses the completed-slot partial index with the primary-specialization association. |
| W01 | 0.723 | 0.834 | 0.87×; 15.4% slower | SQL unchanged; schedule and doctor primary keys serve the insert-select. The insert also maintains the appointment indexes. |
| W02 | 7.043 | 0.245 | 28.80×; 96.5% faster | SQL unchanged; the booked-slot partial index finds the earliest eligible appointment, then the appointment primary key updates it. |
| W03 | 0.301 | 0.154 | 1.95×; 48.8% faster | SQL unchanged; prescription appointment uniqueness serves the update lookup. The follow-up-date index may add maintenance work. |
| W04 | 9.141 | 6.499 | 1.41×; 28.9% faster | SQL unchanged; the partial unfinished-slot-end index finds eligible rows. |
| W05 | 6.878 | 0.245 | 28.03×; 96.4% faster | SQL unchanged; the booked-doctor/slot partial index finds the affected appointments. |

\* R13’s output intentionally changes: baseline returns 0 rows; optimized returns 292. The timing ratio describes measured elapsed time, not equivalent-result performance.

## Five largest improvements: plan evidence

Average times below come from the summary CSVs. The plan details and buffer counts are from run 1 of each raw plan file; run-level plan times need not equal the multi-run average.

1. **R19 — 199.96×.** Average time fell from 4,852.527 ms to 24.267 ms. The baseline plan runs two sequential scans of `appointments` as correlated subplans, each with 480 loops; the first-run plan reports 2,611,500 shared-buffer hits. The optimized plan scans appointments once into a `HashAggregate` grouped by doctor and joins the result; its first-run plan reports 3,002 shared-buffer hits. This removes the repeated work responsible for R19’s baseline cost. See [baseline R19 plan](../benchmarks/results/baseline/R19.txt) and [optimized R19 plan](../benchmarks/results/optimized/R19.txt).

2. **R03 — 95.73×.** Average time fell from 8.711 ms to 0.091 ms. The baseline availability anti-check sequentially scans appointments. The optimized plan uses `idx_schedules_inclinic_doctor_weekday_start` and the partial `idx_appointments_active_doctor_slot` index-only scan. First-run shared-buffer hits fell from 2,723 to 7. See [baseline R03 plan](../benchmarks/results/baseline/R03.txt) and [optimized R03 plan](../benchmarks/results/optimized/R03.txt).

3. **R21 — 88.36×.** Average time fell from 8.306 ms to 0.094 ms. The baseline plan parallel-scans appointments and performs a top-N sort. The optimized plan reads the required rows in order from `idx_appointments_completed_pending_slot` using an index-only scan, without that full scan-and-sort path. First-run shared-buffer hits fell from 2,758 to 1 (the optimized plan also reports 2 shared-buffer reads). See [baseline R21 plan](../benchmarks/results/baseline/R21.txt) and [optimized R21 plan](../benchmarks/results/optimized/R21.txt).

4. **R04 — 78.30×.** Average time fell from 6.734 ms to 0.086 ms. The baseline plan scans all appointments and sequentially scans clinics during the join. The optimized plan uses `idx_appointments_patient_status_slot` and primary-key lookups for doctors and clinics. First-run shared-buffer hits fell from 2,755 to 9 (the optimized plan also reports 7 shared-buffer reads). See [baseline R04 plan](../benchmarks/results/baseline/R04.txt) and [optimized R04 plan](../benchmarks/results/optimized/R04.txt).

5. **R05 — 50.59×.** Average time fell from 5.312 ms to 0.105 ms. The baseline plan uses a parallel sequential scan of appointments for the doctor/date condition. The timestamp-range rewrite allows `idx_appointments_doctor_slot` to provide an index-only scan; the patient primary key serves the remaining join. First-run shared-buffer hits fell from 2,726 to 6 (the respective plans also report 6 and 7 shared-buffer reads). See [baseline R05 plan](../benchmarks/results/baseline/R05.txt) and [optimized R05 plan](../benchmarks/results/optimized/R05.txt).

## Result-equivalence validation

On 19 November 2026, the original and optimized SQL for every changed read query was executed against a fresh PostgreSQL 18.7 validation database loaded from the official seed CSVs and indexed with `sql/05_indexes.sql`. Results were compared as row multisets. The reproducible checker is `benchmarks/validate_equivalence.py`; its captured output is [equivalence_check.txt](../benchmarks/results/optimized/equivalence_check.txt).

R01, R05, R08, R12, R19 and R20 produced identical ordered rows. R18 returned the same 360-row multiset; row order differed among doctors tied on experience because the query does not specify a unique tie-breaker. R13 intentionally changed from 0 rows to 292 unscheduled clinics due to the NULL-correctness fix described below. These are seed-data checks; large-data equivalence remains untested until faculty provides that dataset.

The literal workload comparisons for R21 and R22 in `equivalence_check.txt` and `equivalence_check_final.txt` show different rows at their LIMIT/OFFSET boundaries: the first capture differs by two rows for each query, and the final capture differs by one row for R21 and two for R22. Their prescribed `ORDER BY slot_start DESC` keys are not unique, so SQL does not guarantee which tied rows appear at those boundaries. The optimized queries add `appointment_id ASC` as a secondary sort. `equivalence_check_deterministic.txt` applies that same secondary sort to the reference queries and reports identical ordered rows and multisets. This validates the deterministic ordering variant; it does not establish identical boundary membership against the literal workload for every dataset. The faculty workload itself remains unchanged.

## R13 NULL correctness

The original R13 condition was `clinic_id NOT IN (SELECT clinic_id FROM doctor_schedules)`. Video schedules have `clinic_id IS NULL`. Under SQL three-valued logic, when the subquery contains NULL and no equal clinic ID is found, `NOT IN` evaluates to UNKNOWN; the `WHERE` clause therefore rejects every clinic. On the measured data, baseline R13 returns zero rows. The optimized query uses `NOT EXISTS (SELECT 1 FROM doctor_schedules sc WHERE sc.clinic_id = c.clinic_id)`, which is not poisoned by unrelated NULLs and returns the 292 unscheduled clinics. This intentionally fixes the result, rather than preserving the incorrect baseline output.

## Write-query performance and index maintenance

The sum of the five write-query average timings is 24.086 ms for baseline and 7.977 ms for optimized; that is 3.02× lower measured elapsed time across one representative execution of each write query. W02, W04, and W05 improved with indexes that narrow the candidate rows. W01 was slower by 0.111 ms, while W03 was faster by 0.147 ms. The added indexes require maintenance on writes, which can contribute to overhead; for these short queries, the measured differences are also small enough that run-to-run variance matters. The benchmark rolls each write back, so these runs do not persist their data changes.

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

## Queries with little or no improvement

- **R01 and R02** were slower by 0.7% and 4.0%, respectively, at low absolute runtimes. Their plans use relevant indexes, so the differences are small relative to sub-3-ms execution and should not be treated as a material regression from these runs alone.
- **R24** was slower by 2.9%. It still requires comparing active appointment pairs and returned 559 rows; the measured plan uses a sequential scan of appointments. The current query/index arrangement does not avoid the broad pair search.
- **W01 and W03** were slower by 27.0% and 10.8%. They are short writes, and additional index maintenance is a possible contributor; these measurements do not isolate that cost from timing variation.
- **R23** was unchanged at the CSV’s three-decimal precision because the registration-number unique index already served the baseline query.
- **R14 and R15** improved only 2.0% and 1.4%. Both aggregate broadly across reviews or prescription items and their related rows, so the query-specific indexes do not remove most of the work.

Other moderate improvements also leave substantial work in place: R10 still joins several large relations after the allergy GIN lookup; R17 still joins and groups many completed appointments; and R22 still advances through the 100,000 rows required by its specified offset.

## Overall conclusions

The most effective changes combined selective predicates with indexes already defined for their access paths. The R19 aggregation rewrite removed repeated full-table work, while R03–R05 and R21 replaced broad appointment scans with indexed lookups. Date-range predicates in R05, R08, R12, and R20 allow B-tree range scans without changing their date-window semantics.

The workload’s measured improvements come with index storage of 74.28 MiB, compared with 55.38 MiB of table storage on the fresh validation database. Some low-cost queries remained flat or slightly slower, and R24 remains a broad self-join. R22 retains the prescribed page size and offset, with an added `appointment_id ASC` tie-breaker; rows selected at a timestamp tie boundary can therefore differ from one execution of the literal workload. The original workload has no unique tie-breaker for R18, R21 or R22; the optimized SQL adds `doctor_id` for R18 and `appointment_id` for R21/R22. R13’s output is intentionally corrected for NULL behavior.

## Measurement sources and artifacts

- [Baseline summary](../benchmarks/results/baseline/summary.csv) and [optimized summary](../benchmarks/results/optimized/summary.csv)
- [Seed result-equivalence check](../benchmarks/results/optimized/equivalence_check.txt) and [reusable checker](../benchmarks/validate_equivalence.py)
- Raw plans: `benchmarks/results/baseline/{R01–R25,W01–W05}.txt` and `benchmarks/results/optimized/{R01–R25,W01–W05}.txt`
- Index definitions: [sql/05_indexes.sql](../sql/05_indexes.sql)
- Optimized workload: [sql/06_optimized_queries.sql](../sql/06_optimized_queries.sql)

Baseline raw plans contain three runs per query; optimized raw plans contain five. No measurements or missing query timings were filled in or estimated.

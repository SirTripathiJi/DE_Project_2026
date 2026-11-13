# CP3 Phase 4: Query Optimization Report

## Executive summary

The optimized workload substantially reduced elapsed time for selective lookups, date-window searches, and the R19 city report. Using the average execution times in the saved summaries, 24 of 30 queries were faster, five were slower, and R23 was unchanged at the summaries’ three-decimal precision. R19 improved from 4,226.709 ms to 21.123 ms (200.10×), the largest gain.

R13 is a correctness correction as well as a query rewrite. Its original `NOT IN` returns no rows when the subquery contains NULL clinic IDs; the optimized `NOT EXISTS` returns the 292 clinics without schedules. Its timing difference is therefore not a strictly like-for-like result comparison.

The baseline summary contains three executions per query; the optimized summary contains five. All timings below are the actual `avg_ms` values from those CSVs. Speedup is calculated as `baseline avg_ms / optimized avg_ms`; a value below 1× indicates a slowdown.

## Before/after timing and per-query technique

| Query | Baseline avg (ms) | Optimized avg (ms) | Speedup / slowdown | Technique or explanation |
|---|---:|---:|---:|---|
| R01 | 2.458 | 2.476 | 0.99×; 0.7% slower | Replaced multiplicative joins and `DISTINCT` with specialization and clinic `EXISTS` checks; verified-doctor, specialization, and city indexes appear in the plan. |
| R02 | 0.223 | 0.232 | 0.96×; 4.0% slower | No rewrite; the schedule primary key serves the doctor lookup. Clinic lookup remains a small sequential scan. |
| R03 | 11.478 | 0.118 | 97.27×; 99.0% faster | Uses the partial in-clinic schedule index and active doctor/slot index for the availability anti-lookup. |
| R04 | 8.366 | 0.043 | 194.56×; 99.5% faster | Uses the patient/status/slot covering index to find the patient’s booked appointments. |
| R05 | 5.235 | 0.033 | 158.64×; 99.4% faster | Replaced `DATE(slot_start)` with a half-open timestamp range; the doctor/slot index serves the lookup and ordering. |
| R06 | 0.023 | 0.022 | 1.05×; 4.3% faster | No rewrite; existing unique phone index serves the exact lookup. |
| R07 | 0.046 | 0.041 | 1.12×; 10.9% faster | No rewrite; prescription appointment uniqueness and the prescription-item primary key serve the joins. |
| R08 | 20.726 | 11.302 | 1.83×; 45.5% faster | Uses a half-open 2026 timestamp range instead of extracting the year; the plan reads the slot-start index. |
| R09 | 8.059 | 2.129 | 3.79×; 73.6% faster | No rewrite; the completed-appointment partial slot index serves the June window. |
| R10 | 17.541 | 15.320 | 1.14×; 12.7% faster | No rewrite; the allergy containment predicate uses the patients’ GIN index. The remaining joins still touch appointments, prescriptions, and prescription items. |
| R11 | 16.120 | 1.285 | 12.54×; 92.0% faster | No rewrite; uses the follow-up-date index and an indexed active-appointment anti-lookup. |
| R12 | 22.351 | 9.117 | 2.45×; 59.2% faster | Replaced year extraction with a half-open timestamp range; the slot-start index supports the bounded scan. |
| R13 | 2.570 | 0.543 | 4.73×; 78.9% lower time* | Replaced NULL-sensitive `NOT IN` with `NOT EXISTS`; the clinic-ID schedule index supports the existence check. |
| R14 | 18.107 | 17.745 | 1.02×; 2.0% faster | No rewrite; ranking aggregates the review population, so both plans scan appointments and reviews. |
| R15 | 19.798 | 19.516 | 1.01×; 1.4% faster | No rewrite; the broad prescription-to-appointment-specialization aggregation still uses sequential scans. |
| R16 | 9.064 | 2.020 | 4.49×; 77.7% faster | No rewrite; the June timestamp range uses the slot-start index before clinic aggregation. |
| R17 | 39.311 | 34.336 | 1.14×; 12.7% faster | No rewrite; the completed-slot partial index narrows appointments, but patient joining and age-group aggregation remain broad. |
| R18 | 3.952 | 1.903 | 2.08×; 51.8% faster | Replaced `= ANY(array)` with GIN-supported array containment and schedule/clinic joins with `EXISTS`. |
| R19 | 4,226.709 | 21.123 | 200.10×; 99.5% faster | Aggregates appointment statistics once by doctor and left-joins them, rather than running two correlated appointment scans per doctor. |
| R20 | 8.671 | 1.172 | 7.40×; 86.5% faster | Replaced the cast-to-date filter with a half-open timestamp range; uses the completed-slot partial index. |
| R21 | 8.273 | 0.089 | 92.96×; 98.9% faster | No rewrite; the completed-and-pending partial covering index supplies the newest 100 rows. |
| R22 | 30.988 | 7.867 | 3.94×; 74.6% faster | Preserved `OFFSET 100000 LIMIT 25`; the slot-start index supplies descending order without a full sort. The large offset remains. |
| R23 | 0.023 | 0.023 | 1.00×; unchanged at reported precision | No rewrite; the existing unique registration-number index serves the lookup. |
| R24 | 19.790 | 20.365 | 0.97×; 2.9% slower | No rewrite; the broad self-join still uses a sequential scan to find duplicate active slots. |
| R25 | 17.904 | 13.202 | 1.36×; 26.3% faster | No rewrite; uses the completed-slot partial index with the primary-specialization association. |
| W01 | 0.507 | 0.644 | 0.79×; 27.0% slower | SQL unchanged; schedule and doctor primary keys serve the insert-select. The insert also maintains the appointment indexes. |
| W02 | 6.899 | 0.322 | 21.43×; 95.3% faster | SQL unchanged; the booked-slot partial index finds the earliest eligible appointment, then the appointment primary key updates it. |
| W03 | 0.120 | 0.133 | 0.90×; 10.8% slower | SQL unchanged; prescription appointment uniqueness serves the update lookup. The follow-up-date index may add maintenance work. |
| W04 | 9.287 | 5.851 | 1.59×; 37.0% faster | SQL unchanged; the partial unfinished-slot-end index finds eligible rows. |
| W05 | 6.758 | 0.215 | 31.43×; 96.8% faster | SQL unchanged; the booked-doctor/slot partial index finds the affected appointments. |

\* R13’s output intentionally changes: baseline returns 0 rows; optimized returns 292. The timing ratio describes measured elapsed time, not equivalent-result performance.

## Five largest improvements: plan evidence

Average times below come from the summary CSVs. The plan details and buffer counts are from run 1 of each raw plan file; run-level plan times need not equal the multi-run average.

1. **R19 — 200.10×.** Average time fell from 4,226.709 ms to 21.123 ms. The baseline plan runs two sequential scans of `appointments` as correlated subplans, each with 480 loops; the raw plan reports 2,611,500 shared-buffer hits. The optimized plan scans appointments once into a `HashAggregate` grouped by doctor and joins the result; its first-run plan reports 3,004 shared-buffer hits. This removes the repeated work responsible for R19’s baseline cost. See [baseline R19 plan](../benchmarks/results/baseline/R19.txt) and [optimized R19 plan](../benchmarks/results/optimized/R19.txt).

2. **R04 — 194.56×.** Average time fell from 8.366 ms to 0.043 ms. The baseline plan scans all appointments and sequentially scans clinics during the join. The optimized plan uses `idx_appointments_patient_status_slot` and primary-key lookups for doctors and clinics. First-run shared-buffer hits fell from 2,755 to 19. See [baseline R04 plan](../benchmarks/results/baseline/R04.txt) and [optimized R04 plan](../benchmarks/results/optimized/R04.txt).

3. **R05 — 158.64×.** Average time fell from 5.235 ms to 0.033 ms. The baseline plan uses a parallel sequential scan of appointments for the doctor/date condition. The timestamp-range rewrite allows `idx_appointments_doctor_slot` to provide an index-only scan; the patient primary key serves the remaining join. First-run shared-buffer hits fell from 2,732 to 16. See [baseline R05 plan](../benchmarks/results/baseline/R05.txt) and [optimized R05 plan](../benchmarks/results/optimized/R05.txt).

4. **R03 — 97.27×.** Average time fell from 11.478 ms to 0.118 ms. The baseline availability anti-check sequentially scans appointments. The optimized plan uses `idx_schedules_inclinic_doctor_weekday_start` and the partial `idx_appointments_active_doctor_slot` index-only scan. First-run shared-buffer hits fell from 2,723 to 13. See [baseline R03 plan](../benchmarks/results/baseline/R03.txt) and [optimized R03 plan](../benchmarks/results/optimized/R03.txt).

5. **R21 — 92.96×.** Average time fell from 8.273 ms to 0.089 ms. The baseline plan parallel-scans appointments and performs a top-N sort. The optimized plan reads the required rows in order from `idx_appointments_completed_pending_slot` using an index-only scan, without that full scan-and-sort path. First-run shared-buffer hits fell from 2,758 to 98. See [baseline R21 plan](../benchmarks/results/baseline/R21.txt) and [optimized R21 plan](../benchmarks/results/optimized/R21.txt).

## R13 NULL correctness

The original R13 condition was `clinic_id NOT IN (SELECT clinic_id FROM doctor_schedules)`. Video schedules have `clinic_id IS NULL`. Under SQL three-valued logic, when the subquery contains NULL and no equal clinic ID is found, `NOT IN` evaluates to UNKNOWN; the `WHERE` clause therefore rejects every clinic. On the measured data, baseline R13 returns zero rows. The optimized query uses `NOT EXISTS (SELECT 1 FROM doctor_schedules sc WHERE sc.clinic_id = c.clinic_id)`, which is not poisoned by unrelated NULLs and returns the 292 unscheduled clinics. This intentionally fixes the result, rather than preserving the incorrect baseline output.

## Write-query performance and index maintenance

The sum of the five write-query average timings is 23.571 ms for baseline and 7.165 ms for optimized; that is 3.29× lower measured elapsed time across one representative execution of each write query. W02, W04, and W05 improved with indexes that narrow the candidate rows. W01 and W03 were slower by 0.137 ms and 0.013 ms respectively. The added indexes require maintenance on writes, which can contribute to overhead; for these short queries, the measured differences are also small enough that run-to-run variance matters. The benchmark rolls each write back, so these runs do not persist their data changes.

## Index storage compared with table storage

Using PostgreSQL relation sizes in the existing `akshattripathi` database, summed across the 11 ordinary tables in schema `practo`:

| Storage measure | Size |
|---|---:|
| Table storage (`pg_table_size`) | 58,302,464 bytes (55.60 MiB) |
| Index storage (`pg_indexes_size`) | 78,389,248 bytes (74.76 MiB) |
| Tables plus indexes | 136,691,712 bytes (130.36 MiB) |

Index storage is 1.34× table storage, or 34.5% larger than table storage; it accounts for 57.3% of the combined table-plus-index total. These values include the database’s existing primary-key/unique indexes and the additional indexes defined by `sql/05_indexes.sql`; they are the measured sizes at report preparation time.

## Queries with little or no improvement

- **R01 and R02** were slower by 0.7% and 4.0%, respectively, at low absolute runtimes. Their plans use relevant indexes, so the differences are small relative to sub-3-ms execution and should not be treated as a material regression from these runs alone.
- **R24** was slower by 2.9%. It still requires comparing active appointment pairs and returned 559 rows; the measured plan uses a sequential scan of appointments. The current query/index arrangement does not avoid the broad pair search.
- **W01 and W03** were slower by 27.0% and 10.8%. They are short writes, and additional index maintenance is a possible contributor; these measurements do not isolate that cost from timing variation.
- **R23** was unchanged at the CSV’s three-decimal precision because the registration-number unique index already served the baseline query.
- **R14 and R15** improved only 2.0% and 1.4%. Both aggregate broadly across reviews or prescription items and their related rows, so the query-specific indexes do not remove most of the work.

Other moderate improvements also leave substantial work in place: R10 still joins several large relations after the allergy GIN lookup; R17 still joins and groups many completed appointments; and R22 still advances through the 100,000 rows required by its specified offset.

## Overall conclusions

The most effective changes combined selective predicates with indexes already defined for their access paths. The R19 aggregation rewrite removed repeated full-table work, while R03–R05 and R21 replaced broad appointment scans with indexed lookups. Date-range predicates in R05, R08, R12, and R20 allow B-tree range scans without changing their date-window semantics.

The workload’s measured improvements come with index storage of 74.76 MiB, compared with 55.60 MiB of table storage. Some low-cost queries remained flat or slightly slower, and R24 remains a broad self-join. R22 keeps its original pagination semantics and its large-offset traversal. R13’s output is intentionally corrected for NULL behavior.

## Measurement sources and artifacts

- [Baseline summary](../benchmarks/results/baseline/summary.csv) and [optimized summary](../benchmarks/results/optimized/summary.csv)
- Raw plans: `benchmarks/results/baseline/{R01–R25,W01–W05}.txt` and `benchmarks/results/optimized/{R01–R25,W01–W05}.txt`
- Index definitions: [sql/05_indexes.sql](../sql/05_indexes.sql)
- Optimized workload: [sql/06_optimized_queries.sql](../sql/06_optimized_queries.sql)

Baseline raw plans contain three runs per query; optimized raw plans contain five. No measurements or missing query timings were filled in or estimated.

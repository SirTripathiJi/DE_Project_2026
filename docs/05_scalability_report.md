# Phase 5: Scalability Report

## 1. Objective and growth target

Phase 5 evaluates whether the Phase 4 optimized workload can support the project brief's expected **20× appointment growth**. The seed has 150,000 appointments; the expected large dataset has approximately 3,000,000 appointments. Until faculty releases `large_data.zip`, large-dataset timings, actual growth ratios, and large-dataset storage measurements are **PENDING**. No target is reported as met on the large dataset without a measurement.

## 2. Seed baseline and Phase 4 context

The project brief lists 150,000 seed appointments (1 Jan 2025–30 Jun 2026) and 626,367 total rows across 11 tables. The validated counts in `docs/02_schema_design.md` match those figures. The large-data brief estimates approximately 4,862,000 prescription items, 1,945,000 prescriptions, 800,000 patients, and 610,000 doctor schedules, in addition to about 3,000,000 appointments.

Phase 4's `benchmarks/results/optimized/summary.csv` records averages from five runs of `sql/06_optimized_queries.sql` on the seed database. Those values are used below as the seed timing baseline. The optimization report documents selective/composite/partial indexes, sargable date ranges, the R19 aggregation rewrite, and the R13 `NOT IN` to `NOT EXISTS` correctness fix (R13's result intentionally changes from zero rows to the 292 clinics without schedules). The Phase 4 report notes remaining broad work in R10, R14, R15, R17, R24 and the OFFSET traversal in R22. Phase 4 seed timings do not prove performance on the large dataset.

## 3. Results for all 30 queries

Large timings and growth ratios are pending because `large_data.zip` has not been released. Target labels reproduce the query groups and limits in `README.md`. “Pending measurement” means no large-data target status can yet be assigned. The explanation column records the existing optimization or the main scale question to investigate; it does not claim that an unmeasured fix has worked.

| Query | Optimized on seed (ms) | Optimized on large (ms) | Growth ratio | Performance target | Target status | Explanation / fix to investigate |
|---|---:|---:|---:|---|---|---|
| R01 | 2.476 | PENDING | PENDING | < 250 ms | Pending measurement | Verified-doctor, specialization and city/schedule indexes; inspect selectivity and join rows. |
| R02 | 0.232 | PENDING | PENDING | < 5 ms | Pending measurement | Doctor schedule primary key; clinic relation is small. |
| R03 | 0.118 | PENDING | PENDING | < 5 ms | Pending measurement | Partial in-clinic schedule index plus active doctor/slot anti-lookup. |
| R04 | 0.043 | PENDING | PENDING | < 5 ms | Pending measurement | Patient/status/slot covering index; selective patient lookup. |
| R05 | 0.033 | PENDING | PENDING | < 5 ms | Pending measurement | Doctor/slot index and half-open time range. |
| R06 | 0.022 | PENDING | PENDING | < 5 ms | Pending measurement | Unique patient phone lookup. |
| R07 | 0.041 | PENDING | PENDING | < 5 ms | Pending measurement | Unique prescription appointment lookup and prescription-item primary key. |
| R08 | 11.302 | PENDING | PENDING | < 5,000 ms | Pending measurement | Date-range index helps, but year aggregate and specialization joins scan/group many rows. |
| R09 | 2.129 | PENDING | PENDING | < 5,000 ms | Pending measurement | Completed appointment partial index over June window. |
| R10 | 15.320 | PENDING | PENDING | < 5,000 ms | Pending measurement | Allergy GIN helps filter patients; inspect appointment/prescription/item join volume. |
| R11 | 1.285 | PENDING | PENDING | < 250 ms | Pending measurement | Follow-up-date index and indexed active-appointment anti-lookup. |
| R12 | 9.117 | PENDING | PENDING | < 5,000 ms | Pending measurement | Slot-start range index; monthly grouping still processes matching appointments. |
| R13 | 0.543 | PENDING | PENDING | < 250 ms | Pending measurement | `NOT EXISTS` avoids NULL-sensitive `NOT IN`; clinic/schedule lookup. |
| R14 | 17.745 | PENDING | PENDING | < 5,000 ms | Pending measurement | Broad review/appointment aggregation; inspect aggregate and join plans. |
| R15 | 19.516 | PENDING | PENDING | < 5,000 ms | Pending measurement | Broad prescription-item/appointment/specialization aggregation. |
| R16 | 2.020 | PENDING | PENDING | < 5,000 ms | Pending measurement | Slot-start date range, then clinic fee aggregation. |
| R17 | 34.336 | PENDING | PENDING | < 5,000 ms | Pending measurement | Completed-slot partial index; patient joins and age/blood-group aggregation. |
| R18 | 1.903 | PENDING | PENDING | < 250 ms | Pending measurement | Language GIN plus city and clinic schedule predicates. |
| R19 | 21.123 | PENDING | PENDING | < 5,000 ms | Pending measurement | Aggregates appointments once per doctor; check city-specific working set. |
| R20 | 1.172 | PENDING | PENDING | < 5,000 ms | Pending measurement | Completed-slot range scan and running total over June rows. |
| R21 | 0.089 | PENDING | PENDING | < 250 ms | Pending measurement | Partial index for completed, pending payments, ordered by slot. |
| R22 | 7.867 | PENDING | PENDING | < 250 ms | Pending measurement | Index provides newest-first order, but `OFFSET 100000` still traverses skipped rows. |
| R23 | 0.023 | PENDING | PENDING | < 5 ms | Pending measurement | Unique registration-number index lookup. |
| R24 | 20.365 | PENDING | PENDING | < 5,000 ms | Pending measurement | Broad self-join for active same-doctor/same-slot collisions; inspect pair counts and join strategy. |
| R25 | 13.202 | PENDING | PENDING | < 5,000 ms | Pending measurement | Completed appointments plus primary-specialization grouping. |
| W01 | 0.644 | PENDING | PENDING | < 5 ms | Pending measurement | Insert-select uses schedule/doctor keys; appointment index maintenance adds write work. |
| W02 | 0.322 | PENDING | PENDING | < 5 ms | Pending measurement | Booked-slot partial index locates candidate, then primary key update. |
| W03 | 0.133 | PENDING | PENDING | < 5 ms | Pending measurement | Unique prescription appointment lookup; follow-up index maintenance is a write cost. |
| W04 | 5.851 | PENDING | PENDING | < 1,000 ms | Pending measurement | Partial unfinished-slot-end index; large eligible update count and WAL need measurement. |
| W05 | 0.215 | PENDING | PENDING | < 250 ms | Pending measurement | Partial booked doctor/slot index locates affected rows. |

Targets above are exactly the Phase 5 groups from the project brief: real-time screens **under 5 ms**, interactive search/tools **under 250 ms**, reports/analytics **under 5,000 ms**, and batch W04 **under 1,000 ms**. The status is pending for every query until the large-data benchmark is run.

## 4. Expected growth analysis (not measured)

Every classification and reason below is a **hypothesis based on the current SQL shape, indexes, and seed plans**, not a measured growth result. Each of the 30 queries is assigned to exactly one group. Revisit these assignments after the large-data run; “approximately with data volume” means work may rise with the number of rows matched or processed, and does not assert an exact 20× ratio.

### Expected to remain relatively stable (hypothesis)

- **R02:** one doctor's schedules by the `(doctor_id, weekday, start_time)` primary key; the clinic lookup is against a small reference table.
- **R03:** one doctor's weekly in-clinic schedules and indexed active appointment probes at candidate slots; output is limited to that doctor's availability.
- **R04:** one patient's booked appointments via the patient/status/slot index, followed by primary-key lookups.
- **R05:** one doctor's bounded day range via the doctor/slot index, then patient key lookups.
- **R06:** exact phone lookup on the patients' unique index.
- **R07:** one appointment's prescription via its unique appointment key, then prescription items via their composite primary key.
- **R11:** indexed follow-up-date range followed by appointment-key checks; growth depends on the narrow due-date window rather than a full appointment scan.
- **R21:** bounded top-100 lookup using the partial completed/pending slot index.
- **R23:** exact registration-number lookup on the doctors' unique index.
- **W01:** one schedule and doctor lookup followed by one appointment insert; index maintenance is fixed to the indexes touched by that row.
- **W02:** locate the earliest eligible booked in-clinic appointment through the booked-slot partial index, then update by primary key.
- **W03:** update one prescription using its unique appointment lookup; the write also maintains affected prescription indexes.
- **W05:** one doctor's booked appointments in one day via the partial `(doctor_id, slot_start)` index; runtime depends on that doctor's matching rows, not a whole-table scan.

### Expected to grow approximately with data volume (hypothesis)

- **R01:** verified doctor/specialization/city discovery uses indexes and `EXISTS`, but the number of qualifying doctors, clinics, and joined candidates can increase as those relations grow.
- **R08:** scans the appointments in the 2026 reporting range and groups by specialization/status; more qualifying appointments increase aggregation work.
- **R09:** processes the June completed-appointment range to calculate per-clinic waiting averages; work follows matching rows.
- **R10:** allergy GIN narrows patient candidates, but matching appointments, prescriptions, and medicine items still have to be joined and checked.
- **R12:** the date-range index narrows 2026 appointments, then monthly counts process all matching rows.
- **R13:** checks clinics against schedule clinic IDs; work follows the clinic and schedule populations (including the clinic scan), not the appointments table.
- **R14:** aggregates review and appointment rows to rank doctors; the broad input population can increase.
- **R15:** joins prescription items through prescriptions, appointments, and primary specializations; June items and joins drive the work.
- **R16:** reads appointments in a June window and aggregates fees by clinic; matching transactions drive the work.
- **R17:** scans completed appointments in the 2026 range, joins patients, and groups by age and blood group.
- **R18:** language GIN and city/schedule predicates narrow candidates, while doctor and schedule populations may grow.
- **R19:** the rewrite aggregates appointments once by doctor; `max(consult_ended_at)` covers all appointments while the June count is conditional, so total appointment rows still drive the grouped input.
- **R20:** processes completed appointments in June and sorts/groups them for the running total; work follows the month's matching rows.
- **R25:** scans completed appointments and associates primary specializations before grouping patient/specialization doctor counts.
- **W04:** the partial index locates unfinished appointments by `slot_end`, but update work and WAL/index changes grow with the number of eligible rows.

### Potentially disproportionate growth (hypothesis)

- **R22:** the prescribed query keeps `OFFSET 100000 LIMIT 25`. The current fixed offset traverses 100,000 preceding index entries; it is a scale risk because later pages require larger offsets, whose traversal grows with page depth. The fixed query's offset does not itself rise with table size, so disproportionate growth is not claimed without measurement. Keyset pagination is a possible future change only if page semantics and a stable last-seen ordering key are agreed.
- **R24:** the active-appointment self-join compares rows for the same doctor and slot. If appointment density or collision counts rise, candidate pair comparisons and output can grow faster than the underlying row count. This query is placed only here (not in the approximately proportional group); the seed plan's sequential scan does not establish how the join will behave at large scale.

These expectations do not report what actually happened at 20×. Actual measured growth ratios, query grouping, spills, and target outcomes remain **PENDING**.

## 5. What may break at scale and investigation method

After loading the large dataset, run the prescribed optimized workload and capture `EXPLAIN (ANALYZE, BUFFERS)` for slow or target-missing queries. Compare actual versus estimated rows, scan nodes, loops, shared hits/reads, temporary reads/writes, sort/hash spill details, and execution time with seed plans. Refresh statistics with `ANALYZE` as required by the project workflow. Check date predicates and index leading columns, join cardinality, OFFSET traversal, and rows touched by writes. For every change, retain before/after plans and re-check results; do not infer a successful fix from an index existing or from seed timings.

## 6. Storage analysis

The Phase 4 optimization report records the following seed measurements from its existing `akshattripathi` database. They are historical reported measurements, not a fresh CP5 measurement. The report's figures cover ordinary-table storage and indexes across the 11 Practo tables, not database-wide overhead such as unrelated objects or WAL.

| Measurement | Seed | Large dataset |
|---|---:|---:|
| Total database size | PENDING (not reported in Phase 4) | PENDING |
| Table storage (`pg_table_size`, 11 tables) | 58,302,464 bytes (55.60 MiB), as reported in Phase 4 | PENDING |
| Index storage (`pg_indexes_size`, 11 tables) | 78,389,248 bytes (74.76 MiB), as reported in Phase 4 | PENDING |
| Table plus index storage | 136,691,712 bytes (130.36 MiB), as reported in Phase 4 | PENDING |

The previously reported seed index storage is 1.34× table storage. After the large database is prepared, measure total database size and table/index sizes using consistent PostgreSQL size functions on the same scope, and report the actual values. Do not extrapolate storage linearly from the seed: indexes, TOAST, free space, and data distribution affect the result.

## 7. Architecture proposal for 100×

The following measured values provide seed-workload context for architectural choices; they are not partitioning, sharding, or replica benchmarks. In the optimized summary, R22 took **7.867 ms** with its fixed 100,000-row offset, R24 took **20.365 ms**, R19 took **21.123 ms**, R05 took **0.033 ms**, R04 took **0.043 ms**, R01 took **2.476 ms**, R14 took **17.745 ms**, R15 took **19.516 ms**, R17 took **34.336 ms**, R08 took **11.302 ms**, and R12 took **9.117 ms**. The Phase 4 report records R19 falling from **4,226.709 ms** to **21.123 ms** after replacing repeated correlated appointment scans with one grouped appointment aggregation; its cited first-run shared-buffer hits fell from **2,611,500** to **3,004**. These values show which access paths already matter on the seed workload; they do not establish large-scale behavior.

### Appointment partitioning

For a substantially larger deployment, evaluate **RANGE partitioning of `appointments` by `slot_start`**, with monthly partitions. The seed has 150,000 appointments, and range-driven queries already appear in the measured workload: R05 (0.033 ms), R08 (11.302 ms), R09 (2.129 ms), R12 (9.117 ms), R16 (2.020 ms), R17 (34.336 ms), R20 (1.172 ms), and R22 (7.867 ms). Those seed times alone do not prove partitioning will help; the architectural inference is that bounded time predicates on `slot_start` may prune unrelated months as history grows. R08/R09/R12/R16/R17/R20 and R05/R22 are representative candidates; W04 filters on `slot_end`, not the partition key, so it may still need to visit many partitions. Verify using bounded `slot_start` predicates and `EXPLAIN`; the plan should list only relevant child partitions or show runtime-pruned subplans. A predicate without the partition key may visit many/all partitions. The review DDL is in [`../sql/08_partitioning.sql`](../sql/08_partitioning.sql).

The verified seed CSV range is `slot_start` **2025-01-01 12:20:00+05:30** through **2026-07-15 21:45:00+05:30**, whereas `booked_at` is **2025-01-01 00:00:00+05:30** through **2026-06-30 23:54:45+05:30**. These are distinct timestamp ranges. The SQL example has monthly local-time bounds through July 2026 plus DEFAULT; its dates now cover the observed `slot_start` extrema. The database was unavailable during this audit, so these extrema were calculated from all 150,000 rows in `seed_data/appointments.csv`, not from a live query.

PostgreSQL requires a partitioned table's primary key or unique constraint to include every partition-key column. Thus a partitioned primary key must include `slot_start`, e.g. `(appointment_id, slot_start)`. That does **not** enforce global uniqueness of `appointment_id` by itself. Foreign keys from `prescriptions` and `doctor_reviews` that currently reference only `appointment_id` also need a deliberate key/reference redesign (for example, carry the partition key in the child relationship or retain a separately enforced global identifier registry). This trade-off must be resolved and validated before a production cutover. The SQL file is a review example only and does not change the existing table.

### Sharding comparison

- **City:** R01 measured 2.476 ms and R19 measured 21.123 ms on the seed; both include city-oriented discovery/reporting paths, which makes city locality attractive for those reads. But R04 (0.043 ms) and R05 (0.033 ms) represent patient history and doctor queue paths; a patient's appointments can span cities, so R04/R07/R10/R11/R17 and a doctor's R05 queue can become cross-shard or require duplicated lookup data. The seed timings are not a sharding test.
- **Doctor:** R02/R03/R05 and W01/W02/W04/W05 have doctor/schedule/slot access patterns; the measured R05 seed time is 0.033 ms. Doctor placement can keep a queue and slot writes local. Patient history across doctors (R04 measured 0.043 ms, plus R07/R10/R11/R17) becomes cross-shard, and city-wide R01/R19 discovery/reports require fan-out.
- **Patient:** R04's patient/status lookup (0.043 ms on seed), plus R07/R10/R11, supports patient locality and safety-history access. A doctor's queue/availability (R02/R03/R05, with R05 at 0.033 ms) then spans patient shards; city reports and doctor-wide aggregates also need fan-out.

No single shard key keeps all measured access patterns local. Choose based on the dominant transaction path, keep small reference data replicated where appropriate, and use coordinated fan-out/aggregation for cross-shard reports. These conclusions are architectural inference from query shapes and seed timings, not measured cross-shard latency; measure fan-out volume and consistency costs before choosing a key.

### Read replicas and caching

Measured seed examples show the potential read workload: R08 took 11.302 ms, R14 17.745 ms, R15 19.516 ms, R17 34.336 ms, R19 21.123 ms, R24 20.365 ms, and R12 9.117 ms. These reporting/analytics reads (R08/R09/R12/R14–R20/R24/R25) are replica candidates when stale reads are acceptable; R01/R02/R13/R18/R22 are also replica candidates subject to freshness needs. R08/R12/R14/R15/R17/R19 are candidates for cached or refreshed summary results if their refresh interval is acceptable. These are inferences from query type and measured seed cost, not proof of replica/cache benefit.

The slot picker R03, patient and doctor screens R04/R05/R07, sign-in R06, follow-up/safety R10/R11, and payment/support results R21–R23 should use the primary when freshness or authorization matters; R03 in particular must not rely on stale availability for booking decisions. All writes W01–W05 must go to the primary. R01 search can use a replica only if its freshness behavior is acceptable. Replicas may lag; define cache invalidation/freshness rules and do not cache away booking conflicts or authorization-sensitive patient details.

### Maintenance

Keep autovacuum active and monitor dead tuples and vacuum progress on the high-churn appointments table; tune per-table thresholds only after observing update/delete volume and vacuum behavior. Run `ANALYZE` after bulk loads and ensure statistics remain current. Archive old appointment history only under a retention policy and after considering prescription/review foreign keys, reporting needs, and restore requirements; detach/drop old partitions only after validation and backup. Consider summary tables/materialized views for stable, expensive aggregates (for example monthly counts and finance/quality summaries), with a documented refresh schedule and an acceptable staleness window.

## 8. Conclusion and remaining work

The schema, Phase 4 indexes, and seed measurements provide a baseline and a 100× design proposal. Readiness for 20× growth is **not yet proven**. The following Phase 5 work remains pending until faculty releases `large_data.zip`:

- [ ] Create a separate large-data database; load using the project schema/load workflow, apply `sql/05_indexes.sql`, then run `ANALYZE`.
- [ ] Run the optimized workload only (not the original 30 queries), with three measured runs per query and writes rolled back; save the prescribed large summary and raw plans.
- [ ] Fill all large-data timings, calculate large ÷ seed ratios, assign target outcomes, and update each query's measured growth classification.
- [ ] For target misses or other scale-specific failures, investigate using `EXPLAIN (ANALYZE, BUFFERS)`, apply justified fixes, verify results, and retain before/after large-data plans. All actual failures and fixes are currently **PENDING**.
- [ ] Measure total database size and table/index sizes on the large dataset using consistent scopes/functions; compare with the reported seed measurements. Large-data storage is **PENDING**.
- [ ] Reassess partition pruning and the architecture proposal against the measured large workload, then state readiness and remaining risks. Before/after large-data plans are **PENDING**.

# CP4 / Phase 5 — Scalability and Large-Data Results

| Field | Value |
|---|---|
| Team | T0035 |
| Database | `practo_cp4_large_t0035` (disposable local validation database) |
| PostgreSQL | 18.7 |
| Measured | 21 November 2026 |

**Status:** Large-data load and benchmark complete; all official mean-time targets pass. A scale-specific R24 regression was reduced and alternative plans were tested. Partitioning was tested on populated data. A temporary same-host asynchronous standby was used to measure replay lag; sharding and cache performance remain design analyses.

## 1. Scope and reproducibility

The teacher's `large_data.zip` remains at `/Users/akshattripathi/Desktop/large_data.zip`. It passed ZIP integrity validation and has SHA-256 `972006a41c99725febce3c56adbe9f6c6af34e1b0e83cb4e92c1569f6306ac15`. At benchmark time, the extracted files were at `/Users/akshattripathi/Desktop/large_data/`. Each archive member was hashed and matched that CP4 source byte-for-byte. On 21 November 2026, the already-extracted tree was moved into the required project-local `large_data/` directory and revalidated there: all headers match the seed files and all CSV rows parse. This relocation does not change the benchmarked dataset. `large_data/` remains ignored by Git; neither the archive nor CSV files are committed.

The run used the existing isolated PostgreSQL cluster in `.cp4_validation/pgdata`, on port 55441 and its private Unix socket. The database name was checked and found unused before creation. The schema in `sql/01_schema.sql` and all 19 indexes in `sql/05_indexes.sql` were applied. Index validation reported all 19 indexes valid and ready. `ANALYZE` ran after bulk load and after index creation. The database identity, row counts, load logs, index checks, and storage measurements are in `benchmarks/results/large/`.

The benchmark command was the existing runner with the optimized workload:

```sh
PGHOST="$PWD/.cp4_validation/socket" PGPORT=55441 PGUSER=akshattripathi \
  ./benchmarks/run_benchmark.sh practo_cp4_large_t0035 large 3 sql/06_optimized_queries.sql
```

Each read query was measured with `EXPLAIN (ANALYZE, BUFFERS)` three times. Each write query was measured inside `BEGIN` and `ROLLBACK`; no workload write was allowed to persist. `queries/workload_30.sql` was not changed or run against the large dataset. The final average in `summary.csv` is the arithmetic mean of the three `Execution Time` values in that query's raw plan. The validator independently checked all 30 IDs, raw timings, averages, target labels, and required evidence files; it passed.

The first benchmark invocation could not access the local socket from the restricted process context and was not treated as timing evidence. The benchmark was then run with local socket access and completed successfully.

## 2. Large dataset verification

| CSV/table | Source rows | Database rows | Result |
|---|---:|---:|---|
| cities | 10 | 10 | PASS |
| specializations | 15 | 15 | PASS |
| doctors | 60,000 | 60,000 | PASS |
| doctor_specializations | 74,000 | 74,000 | PASS |
| clinics | 30,000 | 30,000 | PASS |
| doctor_schedules | 609,747 | 609,747 | PASS |
| patients | 800,000 | 800,000 | PASS |
| appointments | 3,000,000 | 3,000,000 | PASS |
| prescriptions | 1,944,432 | 1,944,432 | PASS |
| prescription_items | 4,861,080 | 4,861,080 | PASS |
| doctor_reviews | 608,179 | 608,179 | PASS |

All four additional data checks passed: consultation type agrees with clinic presence, every in-clinic appointment matches a doctor's clinic schedule, prescriptions reference completed appointments, and each doctor has exactly one primary specialization. PostgreSQL constraints remained enabled during loading. See `benchmarks/results/large/row_counts.csv` and `load_validation.log`.

## 3. Large-data query targets

The target is evaluated against the **three-run mean**, per the faculty brief. `PASS` means mean strictly below the group's limit. All 30 queries have three raw executions; every mean passes. These outcomes do not imply every individual run was below its limit: W04 had one 2,405.404 ms run, while its mean was 945.381 ms against the 1,000 ms mean target.

| Query | Mean ms | Target | Outcome | Observed scan nodes (from raw plan) |
|---|---:|---:|---|---|
| R01 | 8.233 | <250 ms | PASS | Index Only Scan; Index Scan |
| R02 | 0.135 | <5 ms | PASS | Index Scan |
| R03 | 0.332 | <5 ms | PASS | Index Only Scan |
| R04 | 0.116 | <5 ms | PASS | Index Only Scan; Index Scan |
| R05 | 0.102 | <5 ms | PASS | Index Only Scan; Index Scan |
| R06 | 0.130 | <5 ms | PASS | Index Scan |
| R07 | 0.166 | <5 ms | PASS | Index Scan |
| R08 | 124.185 | <5,000 ms | PASS | Index Only Scan; Seq Scan |
| R09 | 76.855 | <5,000 ms | PASS | Index Scan |
| R10 | 684.276 | <5,000 ms | PASS | Bitmap Heap Scan; Bitmap Index Scan; Index Scan/Only Scan |
| R11 | 65.003 | <250 ms | PASS | Bitmap Heap Scan; Bitmap Index Scan; Index Scan/Only Scan |
| R12 | 90.526 | <5,000 ms | PASS | Index Only Scan |
| R13 | 14.150 | <250 ms | PASS | Seq Scan; Index Only Scan |
| R14 | 505.020 | <5,000 ms | PASS | Seq Scan |
| R15 | 366.255 | <5,000 ms | PASS | Seq Scan; Index Only Scan |
| R16 | 64.225 | <5,000 ms | PASS | Index Only Scan; Seq Scan |
| R17 | 691.990 | <5,000 ms | PASS | Index Only Scan; Seq Scan |
| R18 | 83.300 | <250 ms | PASS | Bitmap Heap Scan; Bitmap Index Scan; Seq Scan; Index Only Scan |
| R19 | 549.582 | <5,000 ms | PASS | Seq Scan; Index Only Scan |
| R20 | 29.396 | <5,000 ms | PASS | Index Only Scan |
| R21 | 0.146 | <250 ms | PASS | Index Only Scan |
| R22 | 8.945 | <250 ms | PASS | Index Only Scan |
| R23 | 0.124 | <5 ms | PASS | Index Scan |
| R24 | 562.748 | <5,000 ms | PASS | Index Only Scan |
| R25 | 356.415 | <5,000 ms | PASS | Index Only Scan; Seq Scan |
| W01 | 2.876 | <5 ms | PASS | Index Scan |
| W02 | 0.821 | <5 ms | PASS | Index Only Scan; Index Scan |
| W03 | 0.209 | <5 ms | PASS | Index Scan |
| W04 | 945.381 | <1,000 ms | PASS | Index Scan |
| W05 | 0.122 | <250 ms | PASS | Index Scan |

The complete per-query target mapping, limits, exact scan index names, and PASS/MISS calculations are in `benchmarks/results/large/target_analysis.csv`. Full plans (including loops, actual rows, buffers, and execution times) are `R01.txt` through `R25.txt` and `W01.txt` through `W05.txt`.

### Write-query rollback checks

The runner's SQL wrapper places every W01–W05 `EXPLAIN ANALYZE` inside `BEGIN` / `ROLLBACK`. After the runs, a separate read-only check compared the write targets with the original large CSV state. All five comparisons passed. The large source has no row for W01's appointment ID 90000001, no prescription for W03's appointment ID 18872, and no W05 matching doctor/day rows; those statements therefore affected zero rows in this particular dataset. W02 and W04 had eligible data and their post-run states matched source. This proves no changes persisted; it also identifies the three write cases whose update/insert behavior was not exercised against a matching row. Evidence: `rollback_evidence.csv` and `validate_large_write_rollback.py`.

## 4. Seed-to-large growth

The seed reference is `benchmarks/results/optimized/summary.csv`; it was checked against all 30 corresponding committed raw plan files, each containing five measured runs. The final large averages are compared with those optimized seed averages (not the stale values previously in this report). Ratios are `large mean / seed mean`; the CSV also gives percentage increase. A ratio below 1 means the observed large mean was lower in this run. These ratios are measurements across two database sizes and this hardware/cache state; they are not asymptotic complexity claims.

| Query | Seed mean ms | Large mean ms | Growth ratio |
|---|---:|---:|---:|
| R01 | 1.597 | 8.233 | 5.16x |
| R02 | 0.433 | 0.135 | 0.31x |
| R03 | 0.091 | 0.332 | 3.65x |
| R04 | 0.086 | 0.116 | 1.35x |
| R05 | 0.105 | 0.102 | 0.97x |
| R06 | 0.022 | 0.130 | 5.91x |
| R07 | 0.045 | 0.166 | 3.69x |
| R08 | 12.476 | 124.185 | 9.95x |
| R09 | 2.472 | 76.855 | 31.09x |
| R10 | 19.964 | 684.276 | 34.28x |
| R11 | 1.640 | 65.003 | 39.64x |
| R12 | 9.751 | 90.526 | 9.28x |
| R13 | 0.590 | 14.150 | 23.98x |
| R14 | 19.084 | 505.020 | 26.46x |
| R15 | 21.484 | 366.255 | 17.05x |
| R16 | 1.779 | 64.225 | 36.10x |
| R17 | 32.731 | 691.990 | 21.14x |
| R18 | 2.659 | 83.300 | 31.33x |
| R19 | 24.267 | 549.582 | 22.65x |
| R20 | 1.066 | 29.396 | 27.58x |
| R21 | 0.094 | 0.146 | 1.55x |
| R22 | 7.911 | 8.945 | 1.13x |
| R23 | 0.084 | 0.124 | 1.48x |
| R24 | 17.945 | 562.748 | 31.36x |
| R25 | 15.066 | 356.415 | 23.66x |
| W01 | 0.834 | 2.876 | 3.45x |
| W02 | 0.245 | 0.821 | 3.35x |
| W03 | 0.154 | 0.209 | 1.36x |
| W04 | 6.499 | 945.381 | 145.47x |
| W05 | 0.245 | 0.122 | 0.50x |

Most one-row/one-patient lookups remain sub-millisecond. Broad date reports and joins rise substantially but remain within their generous 5-second target. W04 is the main operational concern: the large workload update matched 6,239 rows, its mean is just under the 1-second target, and its three runs varied from 198.743 to 2,405.404 ms. The group target is technically met by the specified mean, but more repetitions on a production-like host would be needed to characterize tail latency. R22's fixed 100,000-row OFFSET remains a page-depth risk; this fixed workload measured 8.945 ms, so it did not miss its current interactive target.

Reproduce these values from `growth_analysis.csv`. `analyze_large_results.py` derives both analysis CSVs from the seed and final large summaries.

## 5. Scale-specific investigation and correction

### R24 duplicate active appointments

The initial large plan for R24 used a broad sequential scan/self-join pattern and repeated index probes. The raw three-run mean was 2,851.225 ms (from `summary_before_R24_fix.csv`); the plan returned 11,308 rows and reported approximately 7,075,753 shared-buffer hits plus 1,089,633 reads. The then-current CP3 version averaged 22.223 ms on seed data, making this a clear scale regression even though the analytics target was not exceeded. After the scale rewrite, the current SQL was separately measured five times on the indexed seed database: 17.945 ms average; raw plans and summary are in `benchmarks/results/optimized_r24_scale_fix_seed/`.

The rewrite in `sql/06_optimized_queries.sql` first groups active appointments by `(doctor_id, slot_start)` and retains groups with duplicates, then probes matching appointment rows through the doctor/slot indexes. On the large data, the three-run remeasurement averaged 562.748 ms (454.869–772.948 ms), about **5.07x faster** than the initial large run (80.3% lower mean). The new plan uses the active-doctor-slot index to form duplicate groups once and the doctor-slot covering index for matching rows. Raw before/after plans are `R24_before_fix.txt` and `R24.txt`; the isolated rerun record is in `large_r24_after/`.

`benchmark_console.log` is the initial full-workload run, before the R24 change. The final `summary.csv` and `R24.txt` use the separate three-run R24 remeasurement; the original full-run values remain available in `summary_before_R24_fix.csv` and `R24_before_fix.txt`.

Result preservation was checked with `EXCEPT ALL` in both directions. The original and candidate each returned 11,308 rows, and the multiset difference was zero. The check is recorded in `R24_candidate_test.log`. Against the current seed retiming, the final large mean is 31.36× higher. The rewrite materially reduces the large-data cost but does not make runtime scale-independent.

No other query exceeded its official mean target; no further index or SQL change was justified by this run. Sequential scans in R14/R15/R19 and a sequential scan of a small reference table in other plans are not by themselves defects: the broad relation/aggregate work can make a sequential scan cheaper. R10 (684.276 ms), R14 (505.020 ms), R17 (691.990 ms), R19 (549.582 ms), and W04 (945.381 ms) deserve monitoring as data grows; current evidence does not show they miss their specified mean targets.

### R24 follow-up plan and index experiments

The current plan's main work is the ordered scan and grouping of 2,703,682 active appointment entries. It removes 2,681,261 single-row groups and retains 11,178 duplicate slots; the current raw plan records 317,336 heap fetches in the index-only scan. The pair probes and final in-memory sort are smaller. PostgreSQL still visits heap pages for tuples whose visibility cannot be established from the visibility map, even for an index-only scan ([PostgreSQL index-only scans](https://www.postgresql.org/docs/18/indexes-index-only-scans.html)).

Two alternatives were tested read-only or transactionally on the same large database:

| Candidate | Measured result | Equivalence / storage | Decision |
|---|---|---|---|
| Aggregate IDs into arrays and enumerate pairs, using existing indexes | 957.188 ms in one `EXPLAIN ANALYZE`; plan added an incremental sort and still fetched 348,400 heap tuples | 11,308 output rows; `EXCEPT ALL` differences were zero both ways | Slower than the existing three-run mean; reject. |
| Same array rewrite with a temporary covering partial index `(doctor_id, slot_start, appointment_id) WHERE status <> 'CANCELLED'` | 507.462 ms in one run; 317,333 heap fetches remained | Temporary index was 105 MB and was rolled back; array rewrite's row multiset was already verified above | One run is not a matched improvement claim; added storage did not remove the visibility-fetch bottleneck. |
| Unchanged current R24 SQL with that temporary covering partial index | Three-run mean 452.481 ms (480.114, 439.559, 437.771); the candidate index served both pair probes and reduced their heap fetches from 7,717 to 3,857 | 11,308 rows each run; 105 MB index; transaction rolled back. Raw plans and timings are preserved. | Later two runs average 438.665 ms versus 457.648 ms for the earlier current-query runs 2–3 (about 4.1% lower), but cache and run ordering were not controlled. The test does not establish a reliable improvement worth the added index and write cost. |

The full candidate plans and equivalence output are `R24_alternative_test.log`, `R24_covering_index_test.log`, and `R24_partial_index_current_query_test.log`; their SQL is in the matching `*_test.sql` files. The three-run current-query candidate results are in `R24_partial_index_current_query_test.csv`. These tests did not change `sql/05_indexes.sql`, `sql/06_optimized_queries.sql`, or the persistent database. Each experimental index existed only inside a transaction that was rolled back. The evidence supports keeping the current rewrite and index set: R24 is below the 5,000 ms report target, the array SQL alternative was slower, and the covering index adds 105 MB while its apparent warm-run gain is small and confounded by cache state. Avoiding the full active-slot scan would require maintaining a duplicate-slot summary as appointments are inserted, moved, or cancelled; that adds write-path and correctness complexity for one report query and was not justified here.

## 6. Storage

The large database was measured after loading and applying the CP3 indexes, before adding the partition candidate. The ordinary-table and index scopes cover all 11 base tables. `partition_storage.csv` separately compares only the ordinary appointments relation with the leaves of the populated candidate; database size at this later point includes both sets and all other objects.

| Scope | Table bytes | Index bytes | Table + indexes |
|---|---:|---:|---:|
| All 11 ordinary base tables (pre-partition candidate) | 1,141,088,256 | 1,506,361,344 | 2,647,449,600 |
| Ordinary `appointments` relation | 441,933,824 | 1,021,247,488 | 1,463,181,312 |
| Populated partitioned appointment leaves | 440,287,232 | 1,306,935,296 | 1,747,222,528 |

The populated partition candidate's table-plus-index total is approximately **19.4% larger** than the ordinary appointment table's measured total. Its leaf data bytes are similar, while its index bytes are higher; the candidate includes the required composite partitioned primary key and the appointment indexes recreated from `sql/05_indexes.sql`. This is a real storage trade-off, not a projected saving. The database size after creating the candidate was 4,409,063,103 bytes. Raw measurements are `storage_measurements.csv`, `table_storage.csv`, `index_sizes.csv`, and `partition_storage.csv`.

## 7. Populated partitioning experiment

`sql/08_partitioning.sql` creates an isolated candidate table, not a replacement for `practo.appointments`. It RANGE partitions on `slot_start` into 19 monthly partitions from January 2025 through July 2026 and a DEFAULT partition, and recreates the ten appointment indexes from the CP3 index design. The existing three-million-row appointments relation was copied into this candidate and analyzed. All 3,000,000 candidate rows landed in the expected monthly partitions; the DEFAULT partition received none. Per-partition counts are in `partition_query_comparison.log`.

For the R05-shaped doctor/day queue, the ordinary and partitioned results had one row each and `EXCEPT ALL` differences of zero in both directions. Three raw `EXPLAIN ANALYZE` executions per table are in `partition_query_comparison.log`. Ordinary-table execution times were 0.009, 0.006, and 0.005 ms; partitioned-table times were 0.007, 0.005, and 0.005 ms. This tiny one-row query does not demonstrate a material speedup; planning and timer granularity dominate at this scale.

A second apples-to-apples check counted the June 2026 appointments through the ordinary parent and partitioned parent, three times each. Both access paths counted the same 167,952 rows. The ordinary table used a parallel index-only scan over the date index (24.785, 12.072, 12.884 ms; mean 16.580 ms); the partitioned table pruned to June and used a parallel sequential scan of that partition (19.633, 10.439, 9.833 ms; mean 13.302 ms). The observed mean was 19.8% lower on this run, with the first execution slower on both paths due to reads. Treat this as a limited single-month count result, not a universal partitioning speedup; raw plans are in `partition_month_comparison.log`.

The populated June 2026 pruning plan scanned only `appointments_partitioned_2026_06`, which contained 167,952 rows, and did not visit the other 18 non-default monthly partitions or DEFAULT. This is direct pruning evidence on populated data. Because the planner selected a sequential scan of that month, execution took 14.274 ms (3,005 shared blocks read); pruning reduced the scanned time range, but this experiment does not prove partitioning beats the best ordinary-table index plan for every workload. The captured plan is also isolated at `partition_pruning.txt`.

### Key and foreign-key limitation

PostgreSQL requires a partitioned primary/unique key to include the partition key. This candidate therefore uses `(appointment_id, slot_start)`. That does not enforce global uniqueness of `appointment_id` by itself. Existing `prescriptions.appointment_id` and `doctor_reviews.appointment_id` references cannot point to this composite key while retaining their current single-column shape. The experiment deliberately leaves those production relationships and the original table untouched. A production conversion needs a separately enforced global ID registry or a reviewed migration that carries the partition key into child references and related joins; dropping the foreign keys or weakening integrity is not acceptable. An ID-only lookup query also cannot identify a partition without the timestamp unless another lookup mechanism is retained.

The SQL and experiment are review evidence, not a production cutover. Monthly partition management must create future partitions ahead of incoming slots and alert on DEFAULT-partition rows.

## 8. Sharding, replicas, caching, and maintenance

These are architecture recommendations informed by this workload's measured large-data behavior. At this scale the database has 3,000,000 appointments, 60,000 doctors, 800,000 patients, and 10 cities. The measured report means include R10 at 684.276 ms, R14 at 505.020 ms, R19 at 549.582 ms, and R24 at 562.748 ms; these identify candidate workload classes, not guaranteed gains from distribution.

### Sharding options

- **City shard:** makes city search and clinic-oriented discovery such as R01 local, but patient histories and doctor queues can span cities. R04/R05 and prescription/safety joins become cross-shard when a patient's doctor or clinic is elsewhere. City-wide reports may still fan out if they compare regions.
- **Doctor shard:** makes doctor availability/queue and many appointment writes local (R02/R03/R05, W01/W02/W04/W05). Patient history, prescription views, and patient safety queries then fan out across doctors; city discovery and reporting also need aggregation across shards.
- **Patient shard:** makes patient history and patient-linked prescription/safety reads local (R04/R07/R10/R11). Doctor scheduling, queues, bookings, and doctor-wide reporting must fan out across patient shards.

| Candidate key | Local workload examples | Cross-shard cost / risk | Assessment |
|---|---|---|---|
| City | R01 clinic/doctor discovery and city-local reports | Only 10 city values; doctor schedules and video appointments may not have a clinic city, while patients can use providers outside their home city. City-wide aggregates still fan out. | Consider only if measured traffic is strongly city-local and per-city volume is balanced. City assignment for video appointments must be defined first. |
| Doctor | Doctor schedules, appointment-slot conflicts, queues, and W01/W02/W04/W05 appointment writes; R05 is 0.102 ms on the current 3M-row database | Patient history, allergy/prescription analysis (R04/R07/R10/R11), and multi-doctor care queries need patient routing or fan-out. | Best initial candidate if booking and doctor operations dominate. Co-locate schedules and appointments by `doctor_id`; retain patient identity as a lookup/reference and measure fan-out before rollout. |
| Patient | Patient appointment history, prescriptions, and safety lookups (R04/R07/R10/R11); R10 is currently 684.276 ms | Doctor availability, daily queues (R03/R05), double-booking checks (R24), and doctor-wide analytics span patient shards. | Choose only if patient-facing history/safety reads dominate and cross-doctor coordination can be handled. |

No single key localizes both patient-centered and doctor-centered flows. For a booking-heavy workload, doctor-based placement is the most direct starting hypothesis, not a proven speedup. The project has 10 city keys, 60,000 doctor keys and 800,000 patient keys, but no measured per-key skew or cross-shard request rate; profile those before choosing shard count or estimating gains. Small reference tables may be replicated if update and consistency rules are explicit.

### Read replica behavior measured on the isolated cluster

The CP4 cluster already had `wal_level=replica`, capacity for ten WAL senders and slots, and no active replica. A temporary physical standby was created with `pg_basebackup` in a separate scratch directory; no packages or persistent server configuration were changed. The standby streamed asynchronously over the local socket. To probe visibility lag, a separate disposable database received 50,000 rows with 512-byte payloads (25,600,000 payload bytes; database size 37 MB). Immediately after commit, `pg_stat_replication` reported 67.551 ms replay lag; the primary's target LSN was 6,089,968 bytes ahead of the replay LSN in that sample. A subsequent standby query observed all 50,000 rows and replayed beyond the target LSN. The raw primary/standby outputs and exact LSNs are in `replica_lag_primary.log`, `replica_lag_standby.log`, and `replica_lag_measurement.csv`; the repeatable probe SQL is `replica_lag_probe.sql`.

This is one same-host observation, not a lag guarantee or networked throughput experiment. The reported `replay_lag` is the measured time for recent WAL to be written, flushed, and replayed; PostgreSQL documents that it is not a prediction of catch-up time and becomes NULL after an idle standby has fully caught up ([`pg_stat_replication`](https://www.postgresql.org/docs/18/monitoring-stats.html#MONITORING-PG-STAT-REPLICATION-VIEW)). The scratch standby, probe database, and physical replication slot were stopped and removed after the test. Replicas are a plausible way to offload report traffic for R14/R15/R17/R19/R24/R25; they do not make an isolated query plan faster, and applications must check freshness before acting on results. R10 contains patient safety data, so replica routing also needs access controls and a freshness requirement.

### Caching design

The large measurements identify expensive read candidates: R10 684.276 ms, R14 505.020 ms, R15 366.255 ms, R17 691.990 ms, R19 549.582 ms, R24 562.748 ms, and R25 356.415 ms. For stable analytics, a database materialized view or report cache could expose an `as_of` watermark and an agreed refresh interval. R03 availability (0.332 ms) and booking/check-in/payment state must remain primary-consistent; caching them risks offering a slot that has already been booked. R10 is both sensitive and update-sensitive, so caching identifiable results is not recommended. R23's 0.124 ms lookup is too cheap to justify a cache on these measurements. No application cache was created: this repository has no application/cache layer, and the faculty disallows external caching as a Phase 4 query optimization. This design has no measured hit rate or speedup. Repeated PostgreSQL buffer-cache reads are not treated as an application-cache experiment.

### Maintenance

After bulk load, run `ANALYZE`; for ongoing service, monitor statistics and plan changes, dead tuples, autovacuum progress, and index growth. Appointments and prescriptions receive updates, so autovacuum health and write amplification matter. The R24 index-only scan's 317,336 heap fetches are a reason to monitor visibility-map coverage and vacuum progress, not evidence that a one-time manual vacuum will permanently eliminate heap access. Consider monthly archive/partition retention only after checking prescription/review relationships, reporting retention, backups, and restore procedures. Materialized summaries can help stable analytics if refresh cost and staleness are measured. No vacuum, archive, or summary-refresh experiment was part of this run; the separate replica-lag probe is described above.

## 9. Evidence index and remaining limitations

Key artifacts under `benchmarks/results/large/`:

- `summary.csv`, `R01.txt`–`R25.txt`, `W01.txt`–`W05.txt`: final 30-query measurements and raw plans.
- `summary_before_R24_fix.csv`, `R24_before_fix.txt`, `R24.txt`, and `large_r24_after/`: R24 large-data before/after evidence.
- `R24_alternative_test.sql` / `.log` and `R24_covering_index_test.sql` / `.log`: read-only query and transactional covering-index alternatives; the tested index was rolled back.
- `R24_partial_index_current_query_test.sql` / `.log` / `.csv`: three current-query runs with a transient covering index, rolled back after measurement.
- `index_write_overhead.log` / `.csv`: controlled session-temporary comparison of identical 3M-row tables with only the primary key versus the ten workload secondary indexes.
- `replica_lag_probe.sql`, `replica_lag_primary.log`, `replica_lag_standby.log`, and `replica_lag_measurement.csv`: temporary asynchronous physical-replica lag probe; the scratch standby, slot, and disposable database were removed after the test.
- `benchmarks/results/optimized_r24_scale_fix_seed/`: five-run seed measurement of the current R24 rewrite, used for the matched growth ratio.
- `R24_candidate_test.sql` / `.log`: result-equivalence comparison.
- `row_counts.csv`, `load_validation.log`, `load_data.log`, `schema_apply.log`, `index_application.log`, `index_validation.log`: load, integrity, and index checks.
- `rollback_evidence.csv`: post-benchmark write-state comparisons.
- `growth_analysis.csv`, `target_analysis.csv`: derived growth and target tables.
- `storage_measurements.csv`, `table_storage.csv`, `index_sizes.csv`, `partition_storage.csv`: storage evidence and scopes.
- `partition_population.log`, `partition_query_comparison.sql` / `.log`, `partition_month_comparison.sql` / `.log`, `partition_pruning.txt`, `partition_ddl_setup.log`: populated partition evidence.
- `dataset_metadata.json`, `seed_reference_validation.txt`: dataset and seed-source validation.

The large-data run, all 30 target averages, row counts, four integrity checks, and populated pruning are verified. The three no-match write cases are a workload-data limitation, W04 has substantial run-to-run variation, R24 still grows substantially relative to seed but remains below its target, partitioned foreign-key/global-ID migration remains unresolved by design, and sharding/cache benefits have not been experimentally measured. The replica lag result is one same-host sample. The controlled secondary-index test excludes WAL and production concurrency. These limits are stated rather than inferred away.

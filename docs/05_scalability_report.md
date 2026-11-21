# CP4 / Phase 5 — Scalability and Large-Data Results

| Field | Value |
|---|---|
| Team | T0035 |
| Database | `practo_cp4_large_t0035` (disposable local validation database) |
| PostgreSQL | 18.7 |
| Measured | 21 November 2026 |

**Status:** Large-data load and benchmark complete; all official mean-time targets pass. A genuine scale-specific regression was reduced and remeasured. Partitioning was tested on populated data. Sharding, replica lag, and cache performance remain design analyses, not experiments.

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

These are architecture recommendations informed by this workload's measured large-data behavior; no distributed cluster, replica, or cache was created, so no cross-node speedup or lag is claimed.

### Sharding options

- **City shard:** makes city search and clinic-oriented discovery such as R01 local, but patient histories and doctor queues can span cities. R04/R05 and prescription/safety joins become cross-shard when a patient's doctor or clinic is elsewhere. City-wide reports may still fan out if they compare regions.
- **Doctor shard:** makes doctor availability/queue and many appointment writes local (R02/R03/R05, W01/W02/W04/W05). Patient history, prescription views, and patient safety queries then fan out across doctors; city discovery and reporting also need aggregation across shards.
- **Patient shard:** makes patient history and patient-linked prescription/safety reads local (R04/R07/R10/R11). Doctor scheduling, queues, bookings, and doctor-wide reporting must fan out across patient shards.

No single key localizes both patient-centered and doctor-centered flows. The right choice depends on the dominant transaction and the operational cost of fan-out; measure cross-shard request rates and coordination latency before selecting a key. Small reference tables may be replicated if update and consistency rules are explicit.

### Read replicas and caching

The large measurements identify expensive read candidates: R10 684.276 ms, R14 505.020 ms, R15 366.255 ms, R17 691.990 ms, R19 549.582 ms, R24 562.748 ms, and R25 356.415 ms. Reporting queries can be routed to an asynchronous replica or served from refreshed summaries only if the acceptable staleness window is defined. This is an architectural recommendation, not an observed replica or cache result. Booking/availability, patient and doctor screens that drive an immediate action, payment state, and all W01–W05 writes need primary-consistent handling. Cache invalidation must never permit conflicting bookings or expose stale authorization-sensitive patient data.

### Maintenance

After bulk load, run `ANALYZE`; for ongoing service, monitor statistics and plan changes, dead tuples, autovacuum progress, and index growth. Appointments and prescriptions receive updates, so autovacuum health and write amplification matter. Consider monthly archive/partition retention only after checking prescription/review relationships, reporting retention, backups, and restore procedures. Materialized summaries can help stable analytics if refresh cost and staleness are measured. The current storage figures provide a baseline for that follow-up; no vacuum, archive, replica-lag, or refresh experiment was part of this run.

## 9. Evidence index and remaining limitations

Key artifacts under `benchmarks/results/large/`:

- `summary.csv`, `R01.txt`–`R25.txt`, `W01.txt`–`W05.txt`: final 30-query measurements and raw plans.
- `summary_before_R24_fix.csv`, `R24_before_fix.txt`, `R24.txt`, and `large_r24_after/`: R24 large-data before/after evidence.
- `benchmarks/results/optimized_r24_scale_fix_seed/`: five-run seed measurement of the current R24 rewrite, used for the matched growth ratio.
- `R24_candidate_test.sql` / `.log`: result-equivalence comparison.
- `row_counts.csv`, `load_validation.log`, `load_data.log`, `schema_apply.log`, `index_application.log`, `index_validation.log`: load, integrity, and index checks.
- `rollback_evidence.csv`: post-benchmark write-state comparisons.
- `growth_analysis.csv`, `target_analysis.csv`: derived growth and target tables.
- `storage_measurements.csv`, `table_storage.csv`, `index_sizes.csv`, `partition_storage.csv`: storage evidence and scopes.
- `partition_population.log`, `partition_query_comparison.sql` / `.log`, `partition_month_comparison.sql` / `.log`, `partition_pruning.txt`, `partition_ddl_setup.log`: populated partition evidence.
- `dataset_metadata.json`, `seed_reference_validation.txt`: dataset and seed-source validation.

The large-data run, all 30 target averages, row counts, four integrity checks, and populated pruning are verified. The three no-match write cases are a workload-data limitation, W04 has substantial run-to-run variation, R24 still grows substantially relative to seed, partitioned foreign-key/global-ID migration remains unresolved by design, and sharding/replica/cache benefits have not been experimentally measured. These limits are stated rather than inferred away.

# Phase 3: Baseline Query Timings

## 1. Purpose

This document records the baseline execution performance of the Practo Doctor Appointments database before applying the Phase 3 indexing optimizations. The same 30-query workload will be used for the later `after` benchmark so that performance can be compared.

## 2. Benchmark setup and method

| Item | Value |
|---|---|
| Database | `practo_db` |
| Schema | `practo` |
| Workload | `queries/workload_30.sql` |
| Benchmark phase | `before` |
| Query runs | 3 runs per query |
| Measurement | `EXPLAIN (ANALYZE, BUFFERS)` execution time |
| READ queries | R01–R25 (25 queries) |
| WRITE queries | W01–W05 (5 queries) |

Command used:

```bash
./benchmarks/run_benchmark.sh practo_db before
```

The individual run values below were extracted from the three `Execution Time` entries in each raw plan file under `benchmarks/results/before/`. The average is the arithmetic mean of Run 1, Run 2 and Run 3, rounded to three decimal places.

## 3. Baseline timings

All timings are in milliseconds (ms).

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---:|---:|---:|---:|---:|
| R01 | READ | 3.302 | 2.011 | 1.647 | 2.320 |
| R02 | READ | 0.283 | 0.265 | 0.245 | 0.264 |
| R03 | READ | 10.362 | 8.778 | 8.178 | 9.106 |
| R04 | READ | 6.275 | 6.369 | 6.575 | 6.406 |
| R05 | READ | 5.381 | 4.881 | 4.771 | 5.011 |
| R06 | READ | 0.023 | 0.020 | 0.020 | 0.021 |
| R07 | READ | 0.698 | 0.041 | 0.039 | 0.259 |
| R08 | READ | 19.146 | 18.886 | 18.628 | 18.887 |
| R09 | READ | 7.694 | 7.495 | 7.366 | 7.518 |
| R10 | READ | 22.761 | 16.476 | 16.331 | 18.523 |
| R11 | READ | 15.987 | 15.825 | 15.724 | 15.845 |
| R12 | READ | 22.416 | 21.783 | 21.942 | 22.047 |
| R13 | READ | 2.485 | 2.317 | 2.444 | 2.415 |
| R14 | READ | 17.308 | 17.263 | 17.548 | 17.373 |
| R15 | READ | 19.868 | 19.178 | 19.302 | 19.449 |
| R16 | READ | 8.936 | 8.838 | 8.711 | 8.828 |
| R17 | READ | 39.938 | 39.584 | 40.505 | 40.009 |
| R18 | READ | 4.037 | 3.950 | 3.668 | 3.885 |
| R19 | READ | 4417.225 | 4353.562 | 4331.229 | 4367.339 |
| R20 | READ | 8.073 | 7.606 | 7.564 | 7.748 |
| R21 | READ | 8.433 | 8.115 | 7.727 | 8.092 |
| R22 | READ | 32.642 | 31.659 | 31.947 | 32.083 |
| R23 | READ | 0.027 | 0.020 | 0.022 | 0.023 |
| R24 | READ | 20.710 | 19.726 | 20.375 | 20.270 |
| R25 | READ | 18.414 | 18.431 | 17.926 | 18.257 |
| W01 | WRITE | 0.578 | 0.499 | 0.492 | 0.523 |
| W02 | WRITE | 6.567 | 6.351 | 6.375 | 6.431 |
| W03 | WRITE | 0.152 | 0.121 | 0.116 | 0.130 |
| W04 | WRITE | 8.448 | 8.731 | 8.525 | 8.568 |
| W05 | WRITE | 6.558 | 6.489 | 6.426 | 6.491 |

## 4. Query-plan observations

The benchmark's `summary.csv` reports the scan nodes observed in each query's execution plan. These are reproduced below to make the baseline plan behavior visible alongside the timing results.

| SQL Query | Observed scan nodes |
|---|---|
| R01 | Seq Scan on doctor_specializations; Seq Scan on specializations; Index Scan using doctors_pkey on doctors; Index Scan using pk_doctor_schedules on doctor_schedules; Seq Scan on clinics |
| R02 | Index Scan using pk_doctor_schedules on doctor_schedules; Seq Scan on clinics |
| R03 | Index Scan using pk_doctor_schedules on doctor_schedules; Seq Scan on appointments |
| R04 | Seq Scan on appointments; Index Scan using doctors_pkey on doctors; Seq Scan on clinics |
| R05 | Seq Scan on appointments; Index Scan using patients_pkey on patients |
| R06 | Index Scan using patients_phone_key on patients |
| R07 | Index Scan using prescriptions_appointment_id_key on prescriptions; Index Scan using pk_prescription_items on prescription_items |
| R08 | Seq Scan on appointments; Seq Scan on doctor_specializations; Seq Scan on specializations |
| R09 | Seq Scan on appointments |
| R10 | Seq Scan on appointments; Seq Scan on patients; Index Scan using prescriptions_appointment_id_key on prescriptions; Index Scan using pk_prescription_items on prescription_items |
| R11 | Seq Scan on appointments; Seq Scan on prescriptions; Index Scan using appointments_pkey on appointments |
| R12 | Seq Scan on appointments |
| R13 | Seq Scan on clinics; Seq Scan on doctor_schedules |
| R14 | Seq Scan on appointments; Seq Scan on doctor_reviews |
| R15 | Seq Scan on prescription_items; Seq Scan on appointments; Seq Scan on prescriptions; Seq Scan on doctor_specializations; Seq Scan on specializations |
| R16 | Seq Scan on appointments; Seq Scan on clinics |
| R17 | Seq Scan on appointments; Seq Scan on patients |
| R18 | Seq Scan on doctor_schedules; Seq Scan on doctors; Seq Scan on clinics |
| R19 | Seq Scan on doctor_schedules; Seq Scan on clinics; Seq Scan on doctors; Seq Scan on appointments |
| R20 | Seq Scan on appointments |
| R21 | Seq Scan on appointments |
| R22 | Seq Scan on appointments |
| R23 | Index Scan using doctors_registration_no_key on doctors |
| R24 | Seq Scan on appointments |
| R25 | Seq Scan on appointments; Seq Scan on doctor_specializations |
| W01 | Index Scan using pk_doctor_schedules on doctor_schedules; Index Scan using doctors_pkey on doctors |
| W02 | Seq Scan on appointments; Index Scan using appointments_pkey on appointments |
| W03 | Index Scan using prescriptions_appointment_id_key on prescriptions |
| W04 | Seq Scan on appointments |
| W05 | Seq Scan on appointments |

### Key observations

- **R19 is the clear outlier:** its average execution time is 4367.339 ms (about 4.37 seconds), substantially higher than every other query.
- The next highest average times are R17 (40.009 ms) and R22 (32.083 ms).
- R12 (22.047 ms), R24 (20.270 ms), R15 (19.449 ms), R08 (18.887 ms), R10 (18.523 ms), and R25 (18.257 ms) are other relatively expensive READ queries in this baseline.
- R06 (0.021 ms) and R23 (0.023 ms) are the fastest READ queries in this measurement.
- The plans show sequential scans on tables including `appointments`, `doctor_specializations`, `specializations`, `clinics`, `patients`, and `doctor_reviews`, while several queries also use existing indexes.
- A sequential scan is not automatically a performance problem. Index changes should be selected after reviewing the SQL predicates, table sizes, selectivity, and full execution plans.

## 5. Baseline result files

- Consolidated timing summary: `benchmarks/results/before/summary.csv`
- Individual execution plans: `benchmarks/results/before/R01.txt` through `R25.txt` and `W01.txt` through `W05.txt`

## 6. Conclusion

The baseline benchmark completed for all 30 workload queries, with three measured runs per query. These measurements establish the reference performance before additional indexing changes. In the optimization phase, the same workload should be run with the `after` phase and compared against these baseline averages. No optimization or improvement is claimed in this baseline report.

# Final Project Audit — Practo DBMS

Audit date: 2026-11-21. This report distinguishes recorded artifacts from checks executed in the isolated validation databases.

Audit starting point: origin=https://github.com/SirTripathiJi/DE_Project_2026.git; branch=main; HEAD=dd2c209

| Checkpoint | Teacher marks | Verified status | Remaining limitation / evidence |
|---|---:|---|---|
| CP0 | — | PASS | No scored CP0 requirement remains in this local audit. |
| CP1 | 7 | PASS | No known missing CP1 requirement after the one-page and seed validations. |
| CP2 | 3 | PASS | No known missing CP2 timing artifact. |
| CP3 | 16 | PASS | R21/R22 literal tie-boundary membership remains undefined; controlled index-cost evidence excludes WAL and concurrency. |
| CP4 | 14 | PASS | Replica offload, caching and sharding gains are unmeasured; the one replay-lag probe used a same-host standby. |
| CP5 | Individual | INCOMPLETE | In-class individual analysis and instructor evaluation remain outstanding. |

## Independently checked evidence

- Seed CSV profile: 11/11 CSV row counts checked; total 599,382.
- PostgreSQL 18.7: fresh project-local seed schema/load passed; row-count and four cross-table checks are captured in `benchmarks/results/seed_validation/validation_run.txt`.
- CP2: every baseline query has 3 raw timings; summary averages reconcile to raw plans and the corrected report table.
- CP3: every optimized query has 5 raw timings; averages reconcile to raw plans; all 11 changed reads were compared on the seed validation databases; R13's NULL correction and deterministic tie-order handling are recorded.
- CP3: controlled secondary-index experiment used identical 3M-row temporary copies and 5,000 rolled-back updates; its WAL limitation is stated.
- CP3 storage: measured table/index/database bytes are recorded in `docs/04_optimization_report.md` and `docs/05_scalability_report.md`.
- CP4 partitioning: populated appointment data was partitioned and EXPLAIN shows pruning to the June 2026 partition; the experiment and storage comparison are recorded under `benchmarks/results/large/`.
- CP4 replication: one asynchronous same-host standby probe recorded `pg_stat_replication` lag and verified visibility of all 50,000 probe rows; the standby, slot and disposable probe database were removed.
- CP4: large artifacts passed validator.
- CP5: revision notes are preparation only; no individual assessment is claimed.

## Validation issues

No failures in the available CP0–CP4 repository checks.

## Outside this repository submission

CP5 is the separate in-class individual assessment and remains pending; it is not included in the CP0–CP4 /40 repository validation.

Marks are awarded by the instructor; this audit does not guarantee marks.

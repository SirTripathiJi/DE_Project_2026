#!/usr/bin/env python3
"""Validate CP4 large-data benchmark artifacts without inventing evidence."""

from __future__ import annotations

import argparse
import csv
import json
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "benchmarks" / "results" / "large"
EXPECTED_IDS = [f"R{i:02}" for i in range(1, 26)] + [f"W{i:02}" for i in range(1, 6)]
EXPECTED_DATASETS = {
    "cities.csv", "specializations.csv", "doctors.csv", "doctor_specializations.csv",
    "clinics.csv", "doctor_schedules.csv", "patients.csv", "appointments.csv",
    "prescriptions.csv", "prescription_items.csv", "doctor_reviews.csv",
}
TARGETS = {
    **{q: ("real-time", 5.0) for q in ("R02 R03 R04 R05 R06 R07 R23 W01 W02 W03").split()},
    **{q: ("interactive", 250.0) for q in ("R01 R11 R13 R18 R21 R22 W05").split()},
    **{q: ("reports", 5000.0) for q in ("R08 R09 R10 R12 R14 R15 R16 R17 R19 R20 R24 R25").split()},
    "W04": ("batch", 1000.0),
}
RAW_TIME = re.compile(r"Execution Time:\s*([0-9]+(?:\.[0-9]+)?)\s*ms")
REQUIRED_EVIDENCE = (
    "dataset_metadata.json",
    "row_counts.csv",
    "rollback_evidence.csv",
    "storage_measurements.csv",
    "partition_pruning.txt",
    "growth_analysis.csv",
    "target_analysis.csv",
)


def fail(message: str, errors: list[str]) -> None:
    errors.append(message)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--results", type=Path, default=RESULTS)
    parser.add_argument("--report", type=Path, default=ROOT / "docs" / "05_scalability_report.md")
    parser.add_argument("--workload", type=Path, default=ROOT / "sql" / "06_optimized_queries.sql")
    args = parser.parse_args()
    results = args.results
    errors: list[str] = []
    summary_path = results / "summary.csv"
    if not summary_path.is_file():
        print(f"FAIL: missing {summary_path}")
        return 1

    try:
        with summary_path.open(newline="", encoding="utf-8-sig") as handle:
            rows = list(csv.DictReader(handle))
    except (OSError, csv.Error) as exc:
        print(f"FAIL: cannot read summary CSV: {exc}")
        return 1
    ids = [row.get("query_id", "") for row in rows]
    if len(ids) != 30 or sorted(ids) != sorted(EXPECTED_IDS) or len(set(ids)) != 30:
        fail("summary must contain each of the 30 official IDs exactly once", errors)
    expected_types = {qid: ("WRITE" if qid.startswith("W") else "READ") for qid in EXPECTED_IDS}
    for row in rows:
        qid = row.get("query_id", "")
        if qid not in expected_types:
            continue
        if row.get("type") != expected_types[qid]:
            fail(f"{qid}: incorrect query type", errors)
        try:
            average = float(row["avg_ms"])
            if not math.isfinite(average) or average < 0:
                raise ValueError
        except (KeyError, TypeError, ValueError):
            fail(f"{qid}: invalid average timing", errors)
            continue
        raw_path = results / f"{qid}.txt"
        if not raw_path.is_file():
            fail(f"{qid}: missing raw plan file", errors)
            continue
        raw_text = raw_path.read_text(encoding="utf-8", errors="replace")
        if re.search(r"(?:^|\n)(?:ERROR|FATAL):", raw_text):
            fail(f"{qid}: raw plan contains a database error", errors)
        times = [float(value) for value in RAW_TIME.findall(raw_text)]
        if len(times) != 3 or any(not math.isfinite(value) or value < 0 for value in times):
            fail(f"{qid}: expected exactly three valid Execution Time measurements", errors)
        elif abs(sum(times) / 3 - average) > 0.00051:
            fail(f"{qid}: summary average does not match raw timings", errors)
        group, limit = TARGETS[qid]
        if average >= limit:
            print(f"TARGET MISS: {qid} {average:.3f} ms (target < {limit:g} ms; {group})")

    for filename in REQUIRED_EVIDENCE:
        evidence = results / filename
        if not evidence.is_file() or evidence.stat().st_size == 0:
            fail(f"missing or empty required evidence: {filename}", errors)
    metadata_path = results / "dataset_metadata.json"
    if metadata_path.is_file():
        try:
            metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
            counts = metadata["row_counts"]
            if (metadata.get("csv_files") != 11 or set(counts) != EXPECTED_DATASETS
                    or any(int(n) <= 0 for n in counts.values())):
                fail("dataset metadata must contain positive counts for all 11 expected CSVs", errors)
        except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError):
            fail("dataset_metadata.json is invalid or incomplete", errors)
    row_counts_path = results / "row_counts.csv"
    if row_counts_path.is_file() and metadata_path.is_file():
        try:
            metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
            expected_tables = {name.removesuffix(".csv"): int(count)
                               for name, count in metadata["row_counts"].items()}
            with row_counts_path.open(newline="", encoding="utf-8-sig") as handle:
                count_rows = list(csv.DictReader(handle))
            actual_tables = {row.get("table", ""): int(row.get("actual_rows", "")) for row in count_rows}
            declared_tables = {row.get("table", ""): int(row.get("expected_rows", "")) for row in count_rows}
            if set(actual_tables) != set(expected_tables) or actual_tables != expected_tables:
                fail("database row counts do not match the verified source CSV counts", errors)
            if declared_tables != expected_tables:
                fail("row_counts.csv expected counts do not match dataset metadata", errors)
        except (OSError, ValueError, KeyError, TypeError, csv.Error, json.JSONDecodeError):
            fail("row_counts.csv is invalid or incomplete", errors)
    rollback_path = results / "rollback_evidence.csv"
    if rollback_path.is_file():
        try:
            with rollback_path.open(newline="", encoding="utf-8-sig") as handle:
                rollback_rows = list(csv.DictReader(handle))
            rollback_by_id = {row.get("query_id", ""): row for row in rollback_rows}
            for qid in (f"W{i:02}" for i in range(1, 6)):
                row = rollback_by_id.get(qid)
                if not row or row.get("rolled_back", "").lower() != "true":
                    fail(f"{qid}: missing verified rollback record", errors)
                elif not row.get("before_fingerprint") or row.get("before_fingerprint") != row.get("after_fingerprint"):
                    fail(f"{qid}: write fingerprint changed across rollback", errors)
        except (OSError, csv.Error):
            fail("rollback_evidence.csv is invalid", errors)
    target_path = results / "target_analysis.csv"
    if target_path.is_file():
        try:
            with target_path.open(newline="", encoding="utf-8-sig") as handle:
                target_rows = list(csv.DictReader(handle))
            target_by_id = {row.get("query_id", ""): row for row in target_rows}
            if len(target_by_id) != 30 or set(target_by_id) != set(EXPECTED_IDS):
                fail("target_analysis.csv must contain every official query exactly once", errors)
            for qid, (group, limit) in TARGETS.items():
                row = target_by_id.get(qid)
                if not row:
                    continue
                try:
                    declared_limit = float(row.get("limit_ms", ""))
                except ValueError:
                    fail(f"{qid}: invalid limit in target_analysis.csv", errors)
                    continue
                if row.get("target_group") != group or declared_limit != limit:
                    fail(f"{qid}: incorrect performance target classification", errors)
                summary_row = next((entry for entry in rows if entry.get("query_id") == qid), None)
                if summary_row:
                    try:
                        average = float(summary_row["avg_ms"])
                        expected_status = "PASS" if average < limit else "MISS"
                        if row.get("result_status") != expected_status:
                            fail(f"{qid}: target status does not match the measured average", errors)
                    except (KeyError, ValueError):
                        pass
                if row.get("result_status") not in ("PASS", "MISS"):
                    fail(f"{qid}: target result must be PASS or MISS", errors)
                if row.get("result_status") == "MISS" and not row.get("explanation", "").strip():
                    fail(f"{qid}: target miss needs an explanation", errors)
        except (OSError, csv.Error):
            fail("target_analysis.csv is invalid", errors)
    growth_path = results / "growth_analysis.csv"
    seed_path = ROOT / "benchmarks" / "results" / "optimized" / "summary.csv"
    if growth_path.is_file() and seed_path.is_file():
        try:
            with growth_path.open(newline="", encoding="utf-8-sig") as handle:
                growth_rows = list(csv.DictReader(handle))
            with seed_path.open(newline="", encoding="utf-8-sig") as handle:
                seed_rows = {row.get("query_id", ""): float(row["avg_ms"]) for row in csv.DictReader(handle)}
            large_rows = {row.get("query_id", ""): float(row["avg_ms"]) for row in rows}
            growth_by_id = {row.get("query_id", ""): row for row in growth_rows}
            if set(growth_by_id) != set(EXPECTED_IDS):
                fail("growth_analysis.csv must contain all 30 query IDs", errors)
            for qid, row in growth_by_id.items():
                try:
                    seed_avg = float(row["seed_avg_ms"])
                    large_avg = float(row["large_avg_ms"])
                    ratio = float(row["growth_ratio"])
                    expected_ratio = large_rows[qid] / seed_rows[qid]
                    if (not math.isclose(seed_avg, seed_rows[qid], rel_tol=0, abs_tol=0.00051)
                            or not math.isclose(large_avg, large_rows[qid], rel_tol=0, abs_tol=0.00051)
                            or not math.isclose(ratio, expected_ratio, rel_tol=0.001, abs_tol=0.001)):
                        fail(f"{qid}: growth figures do not match seed and large summaries", errors)
                except (KeyError, TypeError, ValueError, ZeroDivisionError):
                    fail(f"{qid}: invalid growth figures", errors)
        except (OSError, ValueError, KeyError, TypeError, csv.Error):
            fail("growth_analysis.csv or optimized seed summary is invalid", errors)
    if not args.report.is_file():
        fail("scalability report is missing", errors)
    else:
        report = args.report.read_text(encoding="utf-8", errors="replace").lower()
        for section in ("growth", "storage", "partition", "sharding", "replica", "maintenance"):
            if section not in report:
                fail(f"report is missing required topic: {section}", errors)
    if not args.workload.is_file():
        fail("optimized workload SQL is missing", errors)
    else:
        workload_ids = re.findall(r"^--\s+@(R\d{2}|W\d{2})\b", args.workload.read_text(encoding="utf-8"), re.M)
        if sorted(workload_ids) != sorted(EXPECTED_IDS) or len(set(workload_ids)) != 30:
            fail("optimized workload markers do not match the 30 official query IDs", errors)

    if errors:
        for error in errors:
            print(f"FAIL: {error}")
        print(f"Validation failed with {len(errors)} issue(s).")
        return 1
    print("PASS: all 30 IDs, raw timings, averages, target classifications, and required evidence files validated.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Derive CP4 target and seed-growth tables from committed CSV evidence."""

import csv
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
LARGE = ROOT / "benchmarks/results/large"
TARGETS = {
    **{q: ("real-time", 5.0) for q in "R02 R03 R04 R05 R06 R07 R23 W01 W02 W03".split()},
    **{q: ("interactive", 250.0) for q in "R01 R11 R13 R18 R21 R22 W05".split()},
    **{q: ("reports", 5000.0) for q in "R08 R09 R10 R12 R14 R15 R16 R17 R19 R20 R24 R25".split()},
    "W04": ("batch", 1000.0),
}


def read_csv(path):
    with path.open(newline="", encoding="utf-8-sig") as f:
        return {row["query_id"]: row for row in csv.DictReader(f)}


def main():
    large = read_csv(LARGE / "summary.csv")
    seed = read_csv(ROOT / "benchmarks/results/optimized/summary.csv")
    required = set(TARGETS)
    if set(large) != required or set(seed) != required:
        raise SystemExit("seed and large summaries must each contain exactly R01-R25 and W01-W05")

    with (LARGE / "target_analysis.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["query_id", "target_group", "limit_ms", "avg_ms", "result_status", "scan_nodes", "plan_observation"])
        for qid in sorted(TARGETS):
            group, limit = TARGETS[qid]
            row = large[qid]
            avg = float(row["avg_ms"])
            scans = row.get("scan_nodes", "")
            plan_nodes = sorted({part.strip().split(" using ")[0] for part in scans.split(" | ") if part.strip()})
            detail = "Observed plan node types: " + (", ".join(plan_nodes) if plan_nodes else "not parsed")
            w.writerow([qid, group, f"{limit:.3f}", f"{avg:.3f}", "PASS" if avg < limit else "MISS", scans, detail])

    with (LARGE / "growth_analysis.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["query_id", "seed_avg_ms", "large_avg_ms", "growth_ratio", "growth_percent"])
        for qid in sorted(TARGETS):
            seed_avg = float(seed[qid]["avg_ms"])
            large_avg = float(large[qid]["avg_ms"])
            ratio = large_avg / seed_avg if seed_avg else float("inf")
            pct = (ratio - 1) * 100 if seed_avg else float("inf")
            w.writerow([qid, f"{seed_avg:.3f}", f"{large_avg:.3f}", f"{ratio:.6f}", f"{pct:.3f}"])
    print(f"Wrote target_analysis.csv and growth_analysis.csv for {len(required)} queries from measured summaries.")


if __name__ == "__main__":
    main()

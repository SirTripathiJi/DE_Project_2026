#!/usr/bin/env python3
"""Reconcile CP2/CP3 report timing cells with recorded raw EXPLAIN plans."""

from __future__ import annotations

import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IDS = [f"R{i:02}" for i in range(1, 26)] + [f"W{i:02}" for i in range(1, 6)]
TIME = re.compile(r"Execution Time:\s*([0-9]+(?:\.[0-9]+)?)\s*ms")
ROW = re.compile(r"^\| (R\d{2}|W\d{2}) \|.*$", re.MULTILINE)


def summaries(phase: str, runs: int) -> dict[str, tuple[list[float], float]]:
    folder = ROOT / "benchmarks/results" / phase
    with (folder / "summary.csv").open(newline="", encoding="utf-8-sig") as handle:
        summary = {row["query_id"]: float(row["avg_ms"]) for row in csv.DictReader(handle)}
    if set(summary) != set(IDS):
        raise ValueError(f"{phase}: summary must contain all 30 query IDs exactly once")
    values: dict[str, tuple[list[float], float]] = {}
    for qid in IDS:
        raw = (folder / f"{qid}.txt").read_text(encoding="utf-8")
        times = [float(value) for value in TIME.findall(raw)]
        if len(times) != runs:
            raise ValueError(f"{phase}/{qid}: expected {runs} timings, found {len(times)}")
        average = sum(times) / runs
        if abs(average - summary[qid]) > 0.00051:
            raise ValueError(f"{phase}/{qid}: summary average does not match raw plans")
        values[qid] = (times, average)
    return values


def update_baseline() -> None:
    path = ROOT / "docs/03_baseline_timings.md"
    content = path.read_text(encoding="utf-8")
    values = summaries("baseline", 3)

    def replace(match: re.Match[str]) -> str:
        cells = [cell.strip() for cell in match.group(0).strip().strip("|").split("|")]
        qid = cells[0]
        times, average = values[qid]
        for index, value in zip((3, 4, 5), times):
            cells[index] = f"{value:.3f}"
        cells[6] = f"{average:.3f}"
        return "| " + " | ".join(cells) + " |"

    content = ROW.sub(replace, content)
    content = content.replace("; an earlier path reference to `results/before/` was incorrect.", ".")
    ranked = sorted(((avg, qid) for qid, (_, avg) in values.items()), reverse=True)
    first, second, third = ranked[:3]
    content = re.sub(
        r"R19 is the slowest query at [\d,]+\.\d+ ms because its correlated subqueries repeatedly read appointments for doctors\. R17 \([\d,]+\.\d+ ms\) and R22 \([\d,]+\.\d+ ms\) are the next largest costs; R17 performs broad joins and grouping, while R22 traverses a deep OFFSET page\.",
        f"{first[1]} is the slowest query at {first[0]:,.3f} ms. {second[1]} ({second[0]:,.3f} ms) and {third[1]} ({third[0]:,.3f} ms) are the next largest costs. See their raw plans for the access paths and row counts.",
        content,
    )
    path.write_text(content, encoding="utf-8")


def update_optimization() -> None:
    path = ROOT / "docs/04_optimization_report.md"
    content = path.read_text(encoding="utf-8")
    baseline = summaries("baseline", 3)
    optimized = summaries("optimized", 5)
    faster = sum(baseline[qid][1] > optimized[qid][1] for qid in IDS)
    slower = sum(baseline[qid][1] < optimized[qid][1] for qid in IDS)
    same = len(IDS) - faster - slower
    content = re.sub(
        r"Using the average execution times in the saved summaries, [^.]+\.",
        f"Using the average execution times in the saved summaries, {faster} of 30 queries were faster, {slower} were slower, and {same} were unchanged at the recorded precision.",
        content,
        count=1,
    )
    content = re.sub(
        r"R19 improved from [\d,]+\.\d+ ms to [\d,]+\.\d+ ms \([\d.]+×\), the largest gain\.",
        f"R19 improved from {baseline['R19'][1]:,.3f} ms to {optimized['R19'][1]:,.3f} ms ({baseline['R19'][1]/optimized['R19'][1]:.2f}×), the largest gain.",
        content,
        count=1,
    )

    def replace(match: re.Match[str]) -> str:
        cells = [cell.strip() for cell in match.group(0).strip().strip("|").split("|")]
        qid = cells[0]
        before, after = baseline[qid][1], optimized[qid][1]
        ratio = before / after if after else float("inf")
        if before > after:
            description = f"{ratio:.2f}×; {(before-after)/before*100:.1f}% faster"
        elif before < after:
            description = f"{ratio:.2f}×; {(after-before)/before*100:.1f}% slower"
        else:
            description = "1.00×; unchanged at reported precision"
        cells[1] = f"{before:,.3f}"
        cells[2] = f"{after:,.3f}"
        cells[3] = description
        return "| " + " | ".join(cells) + " |"

    content = ROW.sub(replace, content)
    path.write_text(content, encoding="utf-8")


def main() -> None:
    update_baseline()
    update_optimization()
    print("Updated CP2/CP3 timing cells from raw EXPLAIN plans and verified summaries.")


if __name__ == "__main__":
    main()

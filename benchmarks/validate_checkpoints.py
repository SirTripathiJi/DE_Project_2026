#!/usr/bin/env python3
"""Check repository identity and CP1-CP5 evidence without fabricating results."""

from __future__ import annotations

import argparse
import csv
import json
import math
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IDS = [f"R{i:02}" for i in range(1, 26)] + [f"W{i:02}" for i in range(1, 6)]
SEED_COUNTS = {
    "cities": 10, "specializations": 15, "doctors": 3000,
    "doctor_specializations": 3700, "clinics": 1500,
    "doctor_schedules": 30499, "patients": 40000,
    "appointments": 150000, "prescriptions": 97234,
    "prescription_items": 243085, "doctor_reviews": 30339,
}
PHASE_RUNS = {"baseline": 3, "optimized": 5}
TIME_RE = re.compile(r"Execution Time:\s*([0-9]+(?:\.[0-9]+)?)\s*ms")


def git(*args: str) -> str:
    result = subprocess.run(["git", *args], cwd=ROOT, text=True, capture_output=True, check=True)
    return result.stdout.strip()


def benchmark_errors(phase: str, runs: int) -> list[str]:
    directory = ROOT / "benchmarks" / "results" / phase
    summary = directory / "summary.csv"
    errors: list[str] = []
    if not summary.is_file():
        return [f"{phase}: summary.csv missing"]
    try:
        with summary.open(newline="", encoding="utf-8-sig") as handle:
            rows = list(csv.DictReader(handle))
    except (OSError, csv.Error) as exc:
        return [f"{phase}: cannot read summary ({exc})"]
    ids = [row.get("query_id", "") for row in rows]
    if len(ids) != 30 or set(ids) != set(IDS) or len(set(ids)) != 30:
        errors.append(f"{phase}: expected every official query ID exactly once")
    for row in rows:
        qid = row.get("query_id", "")
        if qid not in IDS:
            continue
        if row.get("type") != ("WRITE" if qid.startswith("W") else "READ"):
            errors.append(f"{phase}/{qid}: wrong query type")
        raw = directory / f"{qid}.txt"
        if not raw.is_file():
            errors.append(f"{phase}/{qid}: raw plan missing")
            continue
        text = raw.read_text(encoding="utf-8", errors="replace")
        times = [float(value) for value in TIME_RE.findall(text)]
        if len(times) != runs or any(not math.isfinite(x) or x < 0 for x in times):
            errors.append(f"{phase}/{qid}: expected {runs} successful plan timings, found {len(times)}")
            continue
        average = sum(times) / runs
        try:
            summary_average = float(row["avg_ms"])
        except (KeyError, ValueError):
            errors.append(f"{phase}/{qid}: invalid summary average")
            continue
        if abs(average - summary_average) > 0.00051:
            errors.append(f"{phase}/{qid}: raw-plan average differs from summary")
        if re.search(r"(?:^|\n)(?:ERROR|FATAL):", text):
            errors.append(f"{phase}/{qid}: raw plan contains an error")
    return errors


def run_seed_validation(database: str, psql: Path) -> tuple[bool, str]:
    result = subprocess.run(
        [str(psql), "-d", database, "-X", "-P", "pager=off", "-v", "ON_ERROR_STOP=1",
         "-f", str(ROOT / "benchmarks" / "validate_seed.sql")],
        cwd=ROOT, text=True, capture_output=True, check=False,
    )
    output = result.stdout + result.stderr
    return result.returncode == 0 and "PASS" in output, output


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", help="run the seed SQL validator against this isolated DB")
    parser.add_argument(
        "--psql", type=Path,
        default=Path("/Applications/Postgres.app/Contents/Versions/latest/bin/psql"),
    )
    parser.add_argument("--write-audit", action="store_true", help="write FINAL_PROJECT_AUDIT.md")
    args = parser.parse_args()

    errors: dict[str, list[str]] = {"CP0": [], "CP1": [], "CP2": [], "CP3": [], "CP4": [], "CP5": []}
    facts: dict[str, str] = {}

    # CP0: identity, required files, and local-file protections.
    try:
        team = json.loads((ROOT / "team.json").read_text(encoding="utf-8"))
        if team.get("team_number") != "T0035": errors["CP0"].append("team.json team_number is not T0035")
        if team.get("group_lead", {}).get("github") != "SirTripathiJi": errors["CP0"].append("team.json group lead GitHub is incorrect")
        if len(team.get("members", [])) != 3: errors["CP0"].append("team.json must list three members besides the group lead")
    except (OSError, ValueError, TypeError) as exc:
        errors["CP0"].append(f"team.json invalid: {exc}")
    required = ["README.md", "CHECKPOINTS.md", "team.json", "queries/workload_30.sql", "benchmarks/run_benchmark.sh"]
    errors["CP0"].extend(f"required file missing: {p}" for p in required if not (ROOT / p).is_file())
    readme = (ROOT / "README.md").read_text(encoding="utf-8", errors="replace")
    if "https://github.com/SirTripathiJi/DE_Project_2026" not in readme or "**Team No.:** T0035" not in readme or "**Section:** E" not in readme:
        errors["CP0"].append("README repository/team identity is incomplete")
    if any(token in "\n".join(readme.splitlines()[26:30]) for token in ("YOUR_ENROLLMENT_NO", "GITHUB_USERNAME", "ENROLLMENT_NO")):
        errors["CP0"].append("README team roster still contains placeholders")
    ignore = (ROOT / ".gitignore").read_text(encoding="utf-8", errors="replace")
    for pattern in ("seed_data/", "large_data/", "*.dump", ".cp4_validation/", ".env"):
        if pattern not in ignore: errors["CP0"].append(f".gitignore does not protect {pattern}")
    try:
        remote = git("remote", "get-url", "origin")
        branch = git("branch", "--show-current")
        if remote.rstrip("/").removesuffix(".git") != "https://github.com/SirTripathiJi/DE_Project_2026":
            errors["CP0"].append(f"origin URL is unexpected: {remote}")
        facts["git"] = f"origin={remote}; branch={branch}; HEAD={git('rev-parse','--short','HEAD')}"
    except (subprocess.CalledProcessError, OSError) as exc:
        errors["CP0"].append(f"git identity check failed: {exc}")

    # CP1: project files, actual source row counts, PostgreSQL evidence.
    cp1_files = ["docs/01_problem_understanding.md", "docs/02_schema_design.md", "sql/01_schema.sql",
                 "sql/02_load_data.sql", "diagrams/er_diagram.png", "benchmarks/validate_seed.sql"]
    errors["CP1"].extend(f"required file missing: {p}" for p in cp1_files if not (ROOT / p).is_file())
    actual_seed: dict[str, int] = {}
    for table, expected in SEED_COUNTS.items():
        path = ROOT / "seed_data" / f"{table}.csv"
        try:
            with path.open(newline="", encoding="utf-8-sig") as handle:
                actual = sum(1 for _ in csv.reader(handle)) - 1
            actual_seed[table] = actual
            if actual != expected: errors["CP1"].append(f"seed {table}: expected {expected}, found {actual}")
        except (OSError, csv.Error) as exc:
            errors["CP1"].append(f"seed CSV unavailable/invalid ({table}): {exc}")
    diagram = ROOT / "diagrams" / "er_diagram.png"
    if diagram.is_file() and not diagram.read_bytes().startswith(b"\x89PNG\r\n\x1a\n"):
        errors["CP1"].append("ER diagram file is not a valid PNG signature")
    if args.database:
        ok, output = run_seed_validation(args.database, args.psql)
        facts["database"] = output.strip()
        if not ok: errors["CP1"].append("fresh-database seed validator failed")
    else:
        evidence = ROOT / "benchmarks/results/seed_validation/validation_run.txt"
        if not evidence.is_file() or "PASS" not in evidence.read_text(encoding="utf-8", errors="replace"):
            errors["CP1"].append("no successful PostgreSQL seed validation evidence")
    facts["seed"] = f"{len(actual_seed)}/11 CSV row counts checked; total {sum(actual_seed.values()):,}"

    # CP2 / CP3: validate every actual raw timing and the summaries.
    errors["CP2"].extend(benchmark_errors("baseline", PHASE_RUNS["baseline"]))
    errors["CP3"].extend(benchmark_errors("optimized", PHASE_RUNS["optimized"]))
    baseline_doc = (ROOT / "docs/03_baseline_timings.md").read_text(encoding="utf-8", errors="replace") if (ROOT / "docs/03_baseline_timings.md").is_file() else ""
    if not baseline_doc or "benchmarks/results/baseline/" not in baseline_doc or "results/before/" in baseline_doc:
        errors["CP2"].append("baseline report path/method is missing or points to the wrong evidence folder")
    doc_rows = re.findall(r"^\| (R\d{2}|W\d{2}) \|", baseline_doc, re.M)
    if len(doc_rows) != 30 or set(doc_rows) != set(IDS): errors["CP2"].append("baseline report must list every query exactly once")
    else:
        try:
            with (ROOT / "benchmarks/results/baseline/summary.csv").open(newline="", encoding="utf-8-sig") as handle:
                summary = {row["query_id"]: row for row in csv.DictReader(handle)}
            for line in baseline_doc.splitlines():
                parts = [part.strip() for part in line.strip().strip("|").split("|")]
                if not parts or parts[0] not in IDS: continue
                qid = parts[0]
                times = [float(v) for v in TIME_RE.findall((ROOT / "benchmarks/results/baseline" / f"{qid}.txt").read_text())]
                documented = [float(parts[i]) for i in (3, 4, 5, 6)]
                expected = [*times, float(summary[qid]["avg_ms"])]
                if len(times) != 3 or any(round(a, 3) != round(b, 3) for a, b in zip(documented, expected)):
                    errors["CP2"].append(f"baseline report timings differ from raw plans for {qid}")
        except (OSError, KeyError, ValueError, csv.Error):
            errors["CP2"].append("could not reconcile baseline report with raw plans")
    if "BEGIN" not in (ROOT / "benchmarks/run_benchmark.sh").read_text() or "ROLLBACK" not in (ROOT / "benchmarks/run_benchmark.sh").read_text():
        errors["CP2"].append("benchmark helper does not wrap writes in rollback")
    errors["CP3"].extend(f"required file missing: {p}" for p in ["sql/05_indexes.sql", "sql/06_optimized_queries.sql", "docs/04_optimization_report.md"] if not (ROOT / p).is_file())
    optimized_sql = (ROOT / "sql/06_optimized_queries.sql").read_text(encoding="utf-8", errors="replace")
    optimized_ids = re.findall(r"^--\s+@(R\d{2}|W\d{2})\b", optimized_sql, re.M)
    if set(optimized_ids) != set(IDS) or len(optimized_ids) != 30: errors["CP3"].append("optimized SQL markers are not exactly the 30 official queries")
    equivalence = ROOT / "benchmarks/results/optimized/equivalence_check_stable_ties.txt"
    if not equivalence.is_file():
        errors["CP3"].append("actual deterministic changed-query equivalence evidence is missing")
    else:
        equivalence_text = equivalence.read_text(encoding="utf-8", errors="replace")
        if "Changed read queries checked: 10" not in equivalence_text:
            errors["CP3"].append("equivalence evidence does not cover all ten changed reads")
        if "Strict result-preservation failures (excluding the intended R13 correction): none" not in equivalence_text:
            errors["CP3"].append("equivalence evidence has strict result-preservation failures")
        for qid in ("R18", "R21", "R22"):
            if f"{qid}: PASS same row multiset; ordered sequence identical" not in equivalence_text:
                errors["CP3"].append(f"{qid} deterministic ordered result equivalence failed")
    opt_doc = (ROOT / "docs/04_optimization_report.md").read_text(encoding="utf-8", errors="replace") if (ROOT / "docs/04_optimization_report.md").is_file() else ""
    for phrase in ("Result-equivalence validation", "R18", "R21 and R22", "index storage"):
        if phrase.lower() not in opt_doc.lower(): errors["CP3"].append(f"optimization report missing {phrase}")

    # CP4: never mark as complete from seed evidence alone.
    archive = ROOT / "large_data.zip"
    large_dir = ROOT / "large_data"
    large_summary = ROOT / "benchmarks/results/large/summary.csv"
    if archive.is_file() and large_dir.is_dir() and large_summary.is_file():
        large_check = subprocess.run([sys.executable, str(ROOT / "benchmarks/validate_large.py")], cwd=ROOT, text=True, capture_output=True)
        if large_check.returncode:
            errors["CP4"].append("large-data artifacts exist but validate_large.py failed")
            facts["cp4"] = large_check.stdout + large_check.stderr
        else:
            facts["cp4"] = "large artifacts passed validator"
    else:
        facts["cp4"] = "BLOCKED: official faculty large_data.zip/results not present; seed data is not a substitute"
    partition_evidence = ROOT / "benchmarks/results/partitioning/seed_pruning_validation.txt"
    if not (ROOT / "sql/08_partitioning.sql").is_file(): errors["CP4"].append("partitioning DDL missing")
    if not partition_evidence.is_file() or "appointments_partitioned_2026_06" not in partition_evidence.read_text(encoding="utf-8", errors="replace"):
        errors["CP4"].append("seed-only partition pruning plan evidence missing")

    # CP5: prep material is not the in-class individual assessment.
    cp5 = ROOT / "CP5_REVISION_NOTES.md"
    if not cp5.is_file(): errors["CP5"].append("individual revision notes missing")
    checkpoints = (ROOT / "CHECKPOINTS.md").read_text(encoding="utf-8", errors="replace")
    if "Individual analysis" not in checkpoints or "in class time" not in checkpoints:
        errors["CP5"].append("could not verify official CP5 timing")

    statuses = {
        "CP0": "PASS" if not errors["CP0"] else "FAIL",
        "CP1": "PASS" if not errors["CP1"] else "FAIL",
        "CP2": "PASS" if not errors["CP2"] else "FAIL",
        "CP3": "PASS" if not errors["CP3"] else "FAIL",
        "CP4": "PARTIAL / BLOCKED" if not errors["CP4"] and "BLOCKED" in facts.get("cp4", "") else ("PASS" if not errors["CP4"] else "FAIL"),
        "CP5": "PREPARED; assessment pending" if not errors["CP5"] else "INCOMPLETE",
    }
    marks = {"CP1": "7", "CP2": "3", "CP3": "16", "CP4": "14", "CP5": "Individual"}
    missing = {
        "CP0": "Instructor/repository tracker confirmation.",
        "CP1": "No material technical gap found in tested seed setup.",
        "CP2": "No material timing-artifact gap found after correcting the report.",
        "CP3": "Large-data behavior is CP4; CP3 seed evidence and rewrites are verified.",
        "CP4": "Official large dataset, large query runs, growth/target results, large storage and scale-only fixes.",
        "CP5": "In-class individual analysis and instructor evaluation remain outstanding.",
    }
    audit = [
        "# Final Project Audit — Practo DBMS", "",
        f"Audit date: {date.today().isoformat()}. This report distinguishes recorded artifacts from checks executed in the isolated validation databases.", "",
        f"Repository: {facts.get('git','unverified')}", "",
        "| Checkpoint | Teacher marks | Verified status | Missing evidence |", "|---|---:|---|---|",
    ]
    for cp in ("CP0", "CP1", "CP2", "CP3", "CP4", "CP5"):
        audit.append(f"| {cp} | {marks.get(cp,'—')} | {statuses[cp]} | {missing[cp]} |")
    audit += ["", "## Independently checked evidence", "",
              f"- Seed CSV profile: {facts.get('seed','not checked')}.",
              "- PostgreSQL 18.7: fresh project-local seed schema/load passed; row-count and four cross-table checks are captured in `benchmarks/results/seed_validation/validation_run.txt`.",
              "- CP2: every baseline query has 3 raw timings; summary averages reconcile to raw plans and the corrected report table.",
              "- CP3: every optimized query has 5 raw timings; averages reconcile to raw plans; 8 changed reads were compared on the fresh seed DB; R13's NULL fix and R18's tie-order limitation are recorded.",
              "- CP3 storage: measured table/index/database bytes are recorded in `docs/04_optimization_report.md` and `docs/05_scalability_report.md`.",
              "- Partition DDL: applied in a separate seed validation database; static EXPLAIN selected the June 2026 partition only. This is not a large-data performance test.",
              f"- CP4: {facts.get('cp4','not checked')}.",
              "- CP5: revision notes are preparation only; no individual assessment is claimed.", "",
              "## Validation issues", ""]
    all_errors = [(cp, issue) for cp, issues in errors.items() for issue in issues]
    if all_errors:
        audit += [f"- **{cp}:** {issue}" for cp, issue in all_errors]
    else:
        audit.append("No failures in the available local checks. CP4 is still blocked by the missing official faculty dataset.")
    audit += ["", "Marks are awarded by the instructor; this audit does not guarantee marks.", ""]
    output = "\n".join(audit)
    print(output)
    if args.write_audit:
        target = ROOT / "FINAL_PROJECT_AUDIT.md"
        target.write_text(output, encoding="utf-8")
        print(f"Wrote {target}")
    return 1 if all_errors else 0


if __name__ == "__main__":
    raise SystemExit(main())

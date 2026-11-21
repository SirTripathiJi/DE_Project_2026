#!/usr/bin/env python3
"""Compare rewritten read-query outputs and EXCEPT ALL results on PostgreSQL.

Use either one database for query-rewrite checks or two equivalent databases
to compare the unindexed workload with the indexed optimized workload:

    python benchmarks/validate_equivalence.py --baseline-database cp3_base \
        --optimized-database cp3_opt --output benchmarks/results/optimized/equivalence_check.txt

Rows are captured as CSV, counted as multisets, and SHA-256 checksums are
recorded. EXCEPT ALL counts are evaluated in the baseline database for each
rewritten query. R13 is an intentional correctness fix; all other row-set
differences fail validation, including LIMIT/OFFSET differences at ties.
"""

from __future__ import annotations

import argparse
import collections
import csv
import hashlib
import io
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PSQL = Path("/Applications/Postgres.app/Contents/Versions/latest/bin/psql")
MARKER = re.compile(r"^-- @(R\d{2}|W\d{2})\s*$", re.MULTILINE)


def read_queries(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    matches = list(MARKER.finditer(text))
    queries: dict[str, str] = {}
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        body = text[match.end():end]
        queries[match.group(1)] = "\n".join(
            line for line in body.splitlines() if not line.lstrip().startswith("--")
        ).strip().rstrip(";")
    return queries


def normalized(query: str) -> str:
    return re.sub(r"\s+", " ", query).strip().rstrip(";")


def comparison_reference(qid: str, query: str) -> str:
    """Give LIMIT/OFFSET queries a stable tie order for semantic comparison.

    The protected workload intentionally retains the instructor's original SQL.
    Its R21/R22 ORDER BY keys are non-unique, so the selected page at a tie
    boundary is not defined. appointment_id is the stable, unique tie-breaker
    already used by the optimized SQL; apply that ordering to the reference
    execution too, without changing predicates, projection, or page size.
    """
    if qid == "R18":
        return re.sub(
            r"ORDER\s+BY\s+d\.consultation_fee\b",
            "ORDER BY d.consultation_fee, d.doctor_id",
            query,
            flags=re.IGNORECASE,
            count=1,
        )
    if qid in {"R21", "R22"}:
        return re.sub(
            r"ORDER\s+BY\s+slot_start\s+DESC\b",
            "ORDER BY slot_start DESC, appointment_id ASC",
            query,
            flags=re.IGNORECASE,
            count=1,
        )
    return query


def psql_rows(psql: Path, database: str, query: str) -> list[tuple[str, ...]]:
    sql = "SET search_path TO practo;\n" + query + ";\n"
    process = subprocess.run(
        [str(psql), "-d", database, "-X", "-q", "-A", "--csv", "-t",
         "-v", "ON_ERROR_STOP=1"],
        input=sql, text=True, capture_output=True, env=os.environ.copy(), check=False,
    )
    if process.returncode:
        raise RuntimeError(process.stderr.strip() or f"psql failed for {database}")
    if not process.stdout:
        return []
    return [tuple(row) for row in csv.reader(io.StringIO(process.stdout))]


def except_all_counts(psql: Path, database: str, original: str, optimized: str) -> tuple[int, int]:
    statement = f"""
WITH original_result AS ({original}), optimized_result AS ({optimized})
SELECT 'original_minus_optimized', count(*)
FROM (SELECT * FROM original_result EXCEPT ALL SELECT * FROM optimized_result) delta
UNION ALL
SELECT 'optimized_minus_original', count(*)
FROM (SELECT * FROM optimized_result EXCEPT ALL SELECT * FROM original_result) delta;
"""
    rows = psql_rows(psql, database, statement)
    if len(rows) != 2:
        raise RuntimeError(f"EXCEPT ALL did not return two directional counts: {rows!r}")
    return int(rows[0][1]), int(rows[1][1])


def digest(rows: list[tuple[str, ...]], *, ordered: bool) -> str:
    values = rows if ordered else sorted(rows)
    payload = json.dumps(values, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("database", nargs="?", help="single database for rewrite-vs-original checks")
    parser.add_argument("--baseline-database", help="same seed rows without tuning indexes")
    parser.add_argument("--optimized-database", help="same seed rows with tuning indexes")
    parser.add_argument("--psql", type=Path, default=DEFAULT_PSQL)
    parser.add_argument("--output", type=Path, help="write evidence under the project root")
    args = parser.parse_args()

    if bool(args.baseline_database) != bool(args.optimized_database):
        parser.error("--baseline-database and --optimized-database must be supplied together")
    if not args.database and not args.baseline_database:
        parser.error("provide a database or a baseline/optimized database pair")

    original = read_queries(ROOT / "queries" / "workload_30.sql")
    optimized = read_queries(ROOT / "sql" / "06_optimized_queries.sql")
    changed = [qid for qid, query in original.items()
               if qid.startswith("R") and normalized(query) != normalized(optimized.get(qid, ""))]
    if not changed:
        parser.error("no changed read queries found")

    baseline_db = args.baseline_database or args.database
    optimized_db = args.optimized_database or args.database
    rows_out = [
        "CP3 rewritten-query result validation",
        f"Verified at (UTC): {datetime.now(timezone.utc).isoformat()}",
        f"Baseline database: {baseline_db}",
        f"Optimized database: {optimized_db}",
        "Method: execute the reference SQL on baseline DB and optimized SQL on indexed DB; compare ordered rows, row multisets, and SHA-256 checksums.",
        "For R18, the reference adds doctor_id after consultation_fee; for R21/R22, it adds appointment_id after slot_start. These unique tie-breakers make the intended order deterministic. They do not alter filters, selected columns, or page bounds; for R21/R22 they define which rows belong at a LIMIT/OFFSET tie boundary.",
        "EXCEPT ALL counts compare those same reference and optimized SQL statements on the baseline DB.",
        "R13 is an intentional NULL correctness correction. All other row-set differences are reported as failures.",
        "",
    ]
    failures: list[str] = []

    try:
        for qid in changed:
            reference = comparison_reference(qid, original[qid])
            after_query = optimized[qid]
            before = psql_rows(args.psql, baseline_db, reference)
            after = psql_rows(args.psql, optimized_db, optimized[qid])
            before_multiset = collections.Counter(before)
            after_multiset = collections.Counter(after)
            ordered_equal = before == after
            multiset_equal = before_multiset == after_multiset
            old_only = list((before_multiset - after_multiset).elements())
            new_only = list((after_multiset - before_multiset).elements())
            set_hash_before = digest(before, ordered=False)
            set_hash_after = digest(after, ordered=False)
            order_hash_before = digest(before, ordered=True)
            order_hash_after = digest(after, ordered=True)
            except_old, except_new = except_all_counts(
                args.psql, baseline_db, reference, after_query
            )

            if qid == "R13":
                passed = len(before) == 0 and len(after) == 292 and except_old == 0 and except_new == 292
                state = "PASS intentional NULL correction" if passed else "FAIL unexpected R13 correction results"
            else:
                passed = multiset_equal
                state = "PASS same row multiset" if passed else "FAIL result rows differ"
                if ordered_equal:
                    state += "; ordered sequence identical"
                elif multiset_equal:
                    state += "; only row order differs"

            rows_out.append(f"{qid}: {state}")
            rows_out.append(f"  row_count: original={len(before)} optimized={len(after)}")
            rows_out.append(f"  ordered_sha256: original={order_hash_before} optimized={order_hash_after}")
            rows_out.append(f"  multiset_sha256: original={set_hash_before} optimized={set_hash_after}")
            rows_out.append(f"  EXCEPT ALL on {baseline_db}: original_minus_optimized={except_old}, optimized_minus_original={except_new}")
            if old_only:
                rows_out.append(f"  original_only_sample: {old_only[:3]!r}")
            if new_only:
                rows_out.append(f"  optimized_only_sample: {new_only[:3]!r}")
            if not passed:
                failures.append(qid)
            rows_out.append("")

        rows_out.append(f"Changed read queries checked: {len(changed)}")
        rows_out.append(f"Strict result-preservation failures (excluding the intended R13 correction): {', '.join(failures) if failures else 'none'}")
    except (OSError, RuntimeError, csv.Error, ValueError) as exc:
        print(f"Equivalence check could not complete: {exc}", file=sys.stderr)
        return 2

    report = "\n".join(rows_out) + "\n"
    print(report, end="")
    if args.output:
        output = args.output.resolve()
        if not output.is_relative_to(ROOT):
            print("Refusing to write evidence outside the project directory.", file=sys.stderr)
            return 2
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(report, encoding="utf-8")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Compare large benchmark write targets after rollback with the source CSVs."""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import os
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
DATA = ROOT / "large_data"
PSQL = "/Applications/Postgres.app/Contents/Versions/latest/bin/psql"


def normalize_ts(value: str | None) -> str | None:
    if not value:
        return None
    return dt.datetime.fromisoformat(value.replace(" ", "T")).astimezone(dt.timezone.utc).isoformat()


def psql(database: str, query: str, host: str, port: str, user: str) -> str:
    result = subprocess.run(
        [PSQL, "-h", host, "-p", port, "-U", user, "-d", database,
         "-X", "-qAt", "-v", "ON_ERROR_STOP=1", "-c", query],
        check=True, capture_output=True, text=True, env=os.environ.copy(),
    )
    return result.stdout.strip()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("database")
    parser.add_argument("--host", required=True)
    parser.add_argument("--port", required=True)
    parser.add_argument("--user", required=True)
    parser.add_argument("--output", type=pathlib.Path,
                        default=ROOT / "benchmarks/results/large/rollback_evidence.csv")
    args = parser.parse_args()

    source_count = 0
    w01_present_source = False
    eligible_w02: list[dict[str, str]] = []
    w04_expected = 0
    w05_expected = 0
    with (DATA / "appointments.csv").open(newline="", encoding="utf-8-sig") as f:
        for r in csv.DictReader(f):
            source_count += 1
            w01_present_source |= r["appointment_id"] == "90000001"
            if (r["status"] == "BOOKED" and r["consult_type"] == "IN_CLINIC"
                    and "2026-07-01" <= r["slot_start"] < "2026-07-02"):
                eligible_w02.append(r)
            if (r["status"] in ("BOOKED", "CHECKED_IN")
                    and r["slot_end"] < "2026-07-02 00:00:00+05:30"
                    and not r["consult_ended_at"]):
                w04_expected += 1
            if (r["doctor_id"] == "504" and r["status"] == "BOOKED"
                    and "2026-07-03" <= r["slot_start"] < "2026-07-04"):
                w05_expected += 1
    w02_expected = []
    if eligible_w02:
        earliest = min(r["slot_start"] for r in eligible_w02)
        w02_expected = sorted(
            [[int(r["appointment_id"]), r["status"], normalize_ts(r["checked_in_at"])]
             for r in eligible_w02 if r["slot_start"] == earliest], key=lambda row: row[0]
        )

    source_prescription = None
    source_prescription_count = 0
    with (DATA / "prescriptions.csv").open(newline="", encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            if row["appointment_id"] == "18872":
                source_prescription = row
                source_prescription_count += 1
    if source_prescription_count > 1:
        raise RuntimeError(f"expected at most one source prescription for appointment 18872; found {source_prescription_count}")
    p = source_prescription
    w03_expected = ([p["notes"] or None, p["follow_up_date"] or None]
                    if p else None)

    actual_count = int(psql(args.database, "SELECT count(*) FROM practo.appointments", args.host, args.port, args.user))
    w01_id_count = int(psql(args.database, "SELECT count(*) FROM practo.appointments WHERE appointment_id=90000001", args.host, args.port, args.user))
    w02_sql = """SELECT COALESCE(json_agg(json_build_array(appointment_id,status,checked_in_at) ORDER BY appointment_id),'[]'::json)::text
FROM practo.appointments
WHERE status='BOOKED' AND consult_type='IN_CLINIC'
  AND slot_start=(SELECT min(slot_start) FROM practo.appointments
                  WHERE status='BOOKED' AND consult_type='IN_CLINIC'
                    AND slot_start >= '2026-07-01' AND slot_start < '2026-07-02')"""
    w02_actual_raw = psql(args.database, w02_sql, args.host, args.port, args.user)
    w02_actual = sorted(
        [[int(row[0]), row[1], normalize_ts(row[2])] for row in json.loads(w02_actual_raw)],
        key=lambda row: row[0],
    )
    w03_sql = """SELECT json_build_array(notes,follow_up_date::text)::text
FROM practo.prescriptions WHERE appointment_id=18872"""
    w03_actual_raw = psql(args.database, w03_sql, args.host, args.port, args.user)
    w03_actual = json.loads(w03_actual_raw) if w03_actual_raw else None
    w04_actual = int(psql(args.database, """SELECT count(*) FROM practo.appointments
WHERE status IN ('BOOKED','CHECKED_IN') AND slot_end < '2026-07-02 00:00:00+05:30'
  AND consult_ended_at IS NULL""", args.host, args.port, args.user))
    w05_actual = int(psql(args.database, """SELECT count(*) FROM practo.appointments
WHERE doctor_id=504 AND status='BOOKED'
  AND slot_start >= '2026-07-03' AND slot_start < '2026-07-04'""", args.host, args.port, args.user))

    checks = [
        ("W01", json.dumps([source_count, w01_present_source], separators=(",", ":")),
         json.dumps([actual_count, w01_id_count == 1], separators=(",", ":")),
         actual_count == source_count and w01_id_count == int(w01_present_source)),
        ("W02", json.dumps(w02_expected, separators=(",", ":")),
         json.dumps(w02_actual, separators=(",", ":")), w02_actual == w02_expected),
        ("W03", json.dumps(w03_expected, separators=(",", ":")),
         json.dumps(w03_actual, separators=(",", ":")), w03_actual == w03_expected),
        ("W04", str(w04_expected), str(w04_actual), w04_actual == w04_expected),
        ("W05", str(w05_expected), str(w05_actual), w05_actual == w05_expected),
    ]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["query_id", "rolled_back", "before_fingerprint", "after_fingerprint", "verification"])
        for qid, expected, actual, passed in checks:
            writer.writerow([qid, str(passed).lower(), expected, actual,
                             "source CSV state compared with post-benchmark database state"])
    for qid, expected, actual, passed in checks:
        print(f"{qid}: {'PASS' if passed else 'FAIL'}; before={expected if len(expected) < 200 else 'matching W02 state set'}; after={actual if len(actual) < 200 else 'matching W02 state set'}")
    if not all(item[3] for item in checks):
        return 1
    print(f"All five post-benchmark write-state comparisons passed. Evidence: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

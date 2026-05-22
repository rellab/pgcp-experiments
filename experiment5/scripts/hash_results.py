"""Compute content-only hashes of Experiment 5 artifacts.

Wall-time columns (`time_sec` in the per-level CSV, `wall_time_sec` in
the summary JSON) vary across runs and are excluded from the hash. The
remaining fields are bit-stable across CPython/Julia/Docker runs.
"""
from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
DATA  = HERE / "data"
RES   = HERE / "results"
PROC  = HERE / "processed"

INPUTS = [
    PROC / "campus_normalized.json",
    DATA / "campus_sensors.json",
    RES  / "campus_initial_triangulation.json",
    RES  / "campus_sweep_pk.csv",
]

OUT = RES / "RESULT_HASHES.txt"


def sha256_bytes(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def hash_file_raw(p: Path) -> str:
    return sha256_bytes(p.read_bytes())


def hash_bounds_csv_content(p: Path) -> str:
    """SHA-256 over campus_bounds.csv with the `time_sec` column dropped."""
    with p.open() as f:
        rdr = csv.reader(f)
        header = next(rdr)
        i_time = header.index("time_sec")
        keep_header = [h for j, h in enumerate(header) if j != i_time]
        rows = [
            [c for j, c in enumerate(row) if j != i_time]
            for row in rdr
        ]
    canonical = "\n".join([",".join(keep_header)] + [",".join(r) for r in rows])
    return sha256_bytes(canonical.encode("utf-8"))


def hash_summary_content(p: Path) -> str:
    """SHA-256 over campus_summary.json with `wall_time_sec` removed."""
    d = json.loads(p.read_text())
    d.pop("wall_time_sec", None)
    canonical = json.dumps(d, sort_keys=True, separators=(",", ":"))
    return sha256_bytes(canonical.encode("utf-8"))


def main() -> None:
    lines = []
    lines.append("# Experiment 5 — content hashes (excluding timing fields)")
    lines.append("")
    lines.append("## Raw-file SHA-256")
    for p in INPUTS:
        if not p.exists():
            lines.append(f"  MISSING  {p.relative_to(HERE)}")
            continue
        lines.append(f"  {hash_file_raw(p)}  {p.relative_to(HERE)}")
    lines.append("")
    lines.append("## Content SHA-256 (timing fields dropped)")
    cb = RES / "campus_bounds.csv"
    if cb.exists():
        lines.append(
            f"  {hash_bounds_csv_content(cb)}  "
            f"{cb.relative_to(HERE)}  (excludes 'time_sec' column)")
    cs = RES / "campus_summary.json"
    if cs.exists():
        lines.append(
            f"  {hash_summary_content(cs)}  "
            f"{cs.relative_to(HERE)}  (excludes 'wall_time_sec')")
    lines.append("")
    lines.append("## Analysis outputs — raw SHA-256 (no timing fields)")
    for p in (RES / "campus_importance.csv", RES / "campus_minsets.json"):
        if p.exists():
            lines.append(f"  {hash_file_raw(p)}  {p.relative_to(HERE)}")
        else:
            lines.append(f"  MISSING  {p.relative_to(HERE)}")
    text = "\n".join(lines) + "\n"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text)
    print(text, end="")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()

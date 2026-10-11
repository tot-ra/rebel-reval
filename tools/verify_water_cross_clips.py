#!/usr/bin/env python3
"""Verify WS-13c water-crossing one-shots, credits, and runtime binding.

Usage:
    python3 tools/verify_water_cross_clips.py
"""

from __future__ import annotations

import argparse
import csv
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WATER_DIR = ROOT / "sounds" / "water"
MANIFEST_CSV = WATER_DIR / "manifest.csv"
PASS_GD = ROOT / "scripts" / "map" / "view3d" / "underwater_pass.gd"
CREDITS_MD = ROOT / "CREDITS.md"
GENERATE_CREDITS = ROOT / "tools" / "generate_credits.py"
MIN_DURATION_SECONDS = 0.6
MAX_DURATION_SECONDS = 2.5
REQUIRED_PATHS = (
    "res://sounds/water/submerge.mp3",
    "res://sounds/water/emerge.mp3",
)


def probe_duration_seconds(path: Path) -> float:
    result = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            str(path),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return float(result.stdout.strip())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--water-dir", type=Path, default=WATER_DIR)
    args = parser.parse_args()
    water_dir: Path = args.water_dir
    manifest_path = water_dir / "manifest.csv"
    errors = 0

    if not manifest_path.is_file():
        print(f"ERROR: missing manifest {manifest_path}")
        return 1
    if not PASS_GD.is_file():
        print(f"ERROR: missing runtime binding {PASS_GD}")
        return 1
    text = PASS_GD.read_text(encoding="utf-8")
    for resource_path in REQUIRED_PATHS:
        if resource_path not in text:
            print(f"ERROR: underwater_pass.gd must reference {resource_path}")
            errors += 1

    credits_text = CREDITS_MD.read_text(encoding="utf-8") if CREDITS_MD.is_file() else ""
    generate_text = GENERATE_CREDITS.read_text(encoding="utf-8")
    if "sounds/water/manifest.csv" not in generate_text:
        print("ERROR: generate_credits.py must read sounds/water/manifest.csv")
        errors += 1

    with manifest_path.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        print("ERROR: water crossing manifest is empty")
        return 1

    expected_ids = {"water.submerge", "water.emerge"}
    found_ids = {str(row.get("clip_id") or "").strip() for row in rows}
    missing_ids = expected_ids - found_ids
    if missing_ids:
        print(f"ERROR: manifest missing clip_id(s): {', '.join(sorted(missing_ids))}")
        errors += 1

    for row_number, row in enumerate(rows, start=2):
        file_name = str(row.get("file") or "").strip()
        clip_id = row.get("clip_id") or f"row {row_number}"
        title = str(row.get("title") or "").strip()
        if not file_name:
            print(f"ERROR: manifest row {row_number} ({clip_id}) missing file field")
            errors += 1
            continue
        clip_path = water_dir / file_name
        if not clip_path.is_file():
            print(f"ERROR: missing clip {clip_path}")
            errors += 1
            continue
        import_path = Path(f"{clip_path}.import")
        if not import_path.is_file():
            print(f"ERROR: missing Godot import sidecar {import_path}")
            errors += 1
        if not title:
            print(f"ERROR: {clip_id} missing title")
            errors += 1
        elif title not in credits_text:
            print(f"ERROR: CREDITS.md must list {title}")
            errors += 1
        if not row.get("license"):
            print(f"ERROR: {clip_id} missing license")
            errors += 1
        if not row.get("page"):
            print(f"ERROR: {clip_id} missing attribution page")
            errors += 1
        try:
            duration = probe_duration_seconds(clip_path)
        except (OSError, subprocess.SubprocessError, ValueError) as exc:
            print(f"ERROR: could not probe {clip_path.name} duration: {exc}")
            errors += 1
            continue
        if duration < MIN_DURATION_SECONDS or duration > MAX_DURATION_SECONDS:
            print(
                f"ERROR: {clip_path.name} duration {duration:.2f}s "
                f"outside {MIN_DURATION_SECONDS}-{MAX_DURATION_SECONDS}s"
            )
            errors += 1

    if errors:
        print(f"water crossing audio verification failed with {errors} error(s)")
        return 1
    print(f"water crossing audio verification passed ({len(rows)} clip(s))")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Verify P0-124 weather ambient clips and Godot import sidecars.

Usage:
    python3 tools/verify_weather_audio_clips.py
"""

from __future__ import annotations

import argparse
import csv
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEATHER_DIR = ROOT / "sounds" / "weather"
MANIFEST_CSV = WEATHER_DIR / "manifest.csv"
ROOF_AUDIO_GD = ROOT / "scripts" / "map" / "view3d" / "sky_weather_roof_audio.gd"
MIN_DURATION_SECONDS = 30.0
MAX_DURATION_SECONDS = 60.0


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
    parser.add_argument("--weather-dir", type=Path, default=WEATHER_DIR)
    args = parser.parse_args()
    weather_dir: Path = args.weather_dir
    manifest_path = weather_dir / "manifest.csv"
    if not manifest_path.is_file():
        print(f"ERROR: missing manifest {manifest_path}")
        return 1
    if not ROOF_AUDIO_GD.is_file():
        print(f"ERROR: missing runtime binding {ROOF_AUDIO_GD}")
        return 1
    text = ROOF_AUDIO_GD.read_text(encoding="utf-8")
    if "res://sounds/weather/rain_roof.mp3" not in text:
        print("ERROR: sky_weather_roof_audio.gd must reference rain_roof.mp3")
        return 1

    errors = 0
    with manifest_path.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        print("ERROR: weather manifest is empty")
        return 1
    for row in rows:
        clip_path = weather_dir / row["file"]
        if not clip_path.is_file():
            print(f"ERROR: missing clip {clip_path}")
            errors += 1
            continue
        import_path = Path(f"{clip_path}.import")
        if not import_path.is_file():
            print(f"ERROR: missing Godot import sidecar {import_path}")
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
        license_text = row.get("license", "")
        if not license_text:
            print(f"ERROR: {row.get('clip_id', clip_path.name)} missing license")
            errors += 1
    if errors:
        print(f"weather audio verification failed with {errors} error(s)")
        return 1
    print(f"weather audio verification passed ({len(rows)} clip(s))")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

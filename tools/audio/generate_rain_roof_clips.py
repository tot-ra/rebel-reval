#!/usr/bin/env python3
"""Generate P0-124 interior rain-on-roof ambient loops.

Produces a deterministic, royalty-free muffled roof-drum loop for enclosed
interiors. The clip is synthesized in-house (no external field recording) so it
stays commercially usable without attribution requirements.

Usage:
    python3 tools/audio/generate_rain_roof_clips.py
    python3 tools/audio/generate_rain_roof_clips.py --dry-run
"""

from __future__ import annotations

import argparse
import csv
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WEATHER_DIR = ROOT / "sounds" / "weather"
OUTPUT_MP3 = WEATHER_DIR / "rain_roof.mp3"
MANIFEST_CSV = WEATHER_DIR / "manifest.csv"
DURATION_SECONDS = 48
SAMPLE_RATE = "44100"
AUDIO_BITRATE = "128k"
# Fixed lavfi seed keeps the loop reproducible across regenerations.
NOISE_SEED = 124073


def generate_clip(*, dry_run: bool) -> None:
    WEATHER_DIR.mkdir(parents=True, exist_ok=True)
    cmd = [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-f",
        "lavfi",
        "-i",
        f"anoisesrc=d={DURATION_SECONDS}:c=pink:a=0.22:seed={NOISE_SEED}",
        "-af",
        (
            "lowpass=f=1100,highpass=f=180,"
            "tremolo=5:0.28,"
            "acompressor=threshold=-22dB:ratio=3:attack=8:release=120,"
            "loudnorm=I=-22:TP=-2:LRA=9"
        ),
        "-t",
        str(DURATION_SECONDS),
        "-ar",
        SAMPLE_RATE,
        "-b:a",
        AUDIO_BITRATE,
        str(OUTPUT_MP3),
    ]
    if dry_run:
        print(" ".join(cmd))
        return
    subprocess.run(cmd, check=True)
    _write_manifest()


def _write_manifest() -> None:
    rows = [
        {
            "clip_id": "weather.rain_roof",
            "file": "rain_roof.mp3",
            "license": "AGPL-3.0-or-later (project author)",
            "source": "in-house ffmpeg synthesis (P0-124)",
            "notes": (
                f"48 s pink-noise roof-drum loop; lavfi seed {NOISE_SEED}; "
                "low-passed and tremolo-modulated for muffled thatch/shingle read"
            ),
        }
    ]
    with MANIFEST_CSV.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["clip_id", "file", "license", "source", "notes"],
        )
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    generate_clip(dry_run=args.dry_run)
    if not args.dry_run:
        print(f"wrote {OUTPUT_MP3.relative_to(ROOT)}")
        print(f"wrote {MANIFEST_CSV.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

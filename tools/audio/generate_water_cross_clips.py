#!/usr/bin/env python3
"""Generate WS-13c submerge and emerge one-shots.

Produces two deterministic, royalty-free water-crossing Foley clips for the
underwater camera pass. The clips are synthesized in-house (no external field
recording) so they stay commercially usable. Attribution still flows through
sounds/water/manifest.csv -> tools/generate_credits.py -> CREDITS.md.

Usage:
    python3 tools/audio/generate_water_cross_clips.py
    python3 tools/audio/generate_water_cross_clips.py --dry-run
"""

from __future__ import annotations

import argparse
import csv
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WATER_DIR = ROOT / "sounds" / "water"
MANIFEST_CSV = WATER_DIR / "manifest.csv"
SAMPLE_RATE = "44100"
AUDIO_BITRATE = "128k"

# Fixed lavfi seeds keep the one-shots reproducible across regenerations.
CLIPS = (
    {
        "clip_id": "water.submerge",
        "title": "Harbour submerge splash",
        "file": "submerge.mp3",
        "duration": 1.4,
        "seeds": (903101, 903102, 903103),
        "notes": (
            "Body-entry splash: brown-noise thump, pink mid burst, high droplet "
            "decay; lavfi seeds 903101-903103"
        ),
        "layers": (
            "anoisesrc=d={d}:c=brown:a=0.55:seed={s0},"
            "afade=t=in:st=0:d=0.008,afade=t=out:st=0.08:d=0.35,"
            "lowpass=f=420,highpass=f=40",
            "anoisesrc=d={d}:c=pink:a=0.35:seed={s1},"
            "afade=t=in:st=0:d=0.01,afade=t=out:st=0.12:d=0.9,"
            "bandpass=f=1200:width_type=h:w=1800",
            "anoisesrc=d={d}:c=white:a=0.12:seed={s2},"
            "afade=t=in:st=0.05:d=0.02,afade=t=out:st=0.25:d=1.1,"
            "highpass=f=2500,tremolo=f=18:d=0.7",
        ),
    },
    {
        "clip_id": "water.emerge",
        "title": "Harbour emerge splash",
        "file": "emerge.mp3",
        "duration": 1.1,
        "seeds": (903201, 903202, 903203),
        "notes": (
            "Surface-break splash: lighter thump, brighter mid burst, short "
            "droplet tail; lavfi seeds 903201-903203"
        ),
        "layers": (
            "anoisesrc=d={d}:c=brown:a=0.32:seed={s0},"
            "afade=t=in:st=0:d=0.006,afade=t=out:st=0.05:d=0.22,"
            "lowpass=f=620,highpass=f=80",
            "anoisesrc=d={d}:c=pink:a=0.38:seed={s1},"
            "afade=t=in:st=0:d=0.008,afade=t=out:st=0.08:d=0.7,"
            "bandpass=f=1800:width_type=h:w=2200",
            "anoisesrc=d={d}:c=white:a=0.16:seed={s2},"
            "afade=t=in:st=0.03:d=0.015,afade=t=out:st=0.18:d=0.85,"
            "highpass=f=3200,tremolo=f=22:d=0.65",
        ),
    },
)


def _layer_filter(spec: str, duration: float, seeds: tuple[int, int, int]) -> str:
    return spec.format(d=duration, s0=seeds[0], s1=seeds[1], s2=seeds[2])


def _clip_command(clip: dict) -> list[str]:
    duration = float(clip["duration"])
    seeds = clip["seeds"]
    layers = clip["layers"]
    cmd = [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
    ]
    for index in range(0, len(layers), 1):
        # Each tuple entry is one lavfi graph.
        cmd.extend(["-f", "lavfi", "-i", _layer_filter(layers[index], duration, seeds)])
    cmd.extend(
        [
            "-filter_complex",
            f"amix=inputs={len(layers)}:normalize=0,loudnorm=I=-18:TP=-2:LRA=8",
            "-t",
            str(duration),
            "-ar",
            SAMPLE_RATE,
            "-ac",
            "1",
            "-b:a",
            AUDIO_BITRATE,
            str(WATER_DIR / clip["file"]),
        ]
    )
    return cmd


def _write_manifest() -> None:
    rows = []
    for clip in CLIPS:
        rows.append(
            {
                "clip_id": clip["clip_id"],
                "title": clip["title"],
                "author": "project maintainer",
                "license": "AGPL-3.0-or-later (project author)",
                "page": "tools/audio/generate_water_cross_clips.py",
                "file": clip["file"],
                "notes": clip["notes"],
            }
        )
    WATER_DIR.mkdir(parents=True, exist_ok=True)
    with MANIFEST_CSV.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["clip_id", "title", "author", "license", "page", "file", "notes"],
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(rows)


def generate_clips(*, dry_run: bool) -> None:
    WATER_DIR.mkdir(parents=True, exist_ok=True)
    for clip in CLIPS:
        cmd = _clip_command(clip)
        if dry_run:
            print(" ".join(cmd))
            continue
        subprocess.run(cmd, check=True)
    if not dry_run:
        _write_manifest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    generate_clips(dry_run=args.dry_run)
    if not args.dry_run:
        print(f"wrote {MANIFEST_CSV.relative_to(ROOT)}")
        for clip in CLIPS:
            print(f"wrote {(WATER_DIR / clip['file']).relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

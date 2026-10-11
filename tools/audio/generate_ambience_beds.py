#!/usr/bin/env python3
"""Generate the R-1358 ambience bed loops and the open-air rain overlay.

Same approach as tools/audio/generate_rain_roof_clips.py (P0-124): deterministic
in-house ffmpeg synthesis, so the clips are commercially usable with no
attribution and no third-party licence to store. They are placeholder beds for
the ADR 0035 phase-2 pilot: the catalog addresses them by ID, so a licensed or
recorded replacement drops in without touching code.

Usage:
    python3 tools/audio/generate_ambience_beds.py
    python3 tools/audio/generate_ambience_beds.py --dry-run
"""

from __future__ import annotations

import argparse
import csv
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AMBIENCE_DIR = ROOT / "sounds" / "ambience"
WEATHER_DIR = ROOT / "sounds" / "weather"
DURATION_SECONDS = 48
SAMPLE_RATE = "44100"
AUDIO_BITRATE = "128k"

# Each clip: fixed lavfi seed, one or two noise sources, and a filter chain that
# shapes the noise into the layer we need. Seeds keep regeneration byte-stable.
CLIPS: list[dict[str, object]] = [
    {
        "clip_id": "ambience.lower_town_bed",
        "directory": AMBIENCE_DIR,
        "file": "lower_town_bed.mp3",
        "seed": 135801,
        # Street bed: a dark, slow-breathing hum that must sit under birds,
        # insects and spot sounds without masking dialogue.
        "inputs": ["anoisesrc=d=%d:c=brown:a=0.30:seed=%d"],
        "filters": (
            "lowpass=f=700,highpass=f=70,"
            "tremolo=0.2:0.22,"
            "acompressor=threshold=-24dB:ratio=3:attack=20:release=400,"
            "loudnorm=I=-28:TP=-3:LRA=7"
        ),
        "notes": (
            "48 s brown-noise Lower Town street hum; low-passed with a 0.2 Hz "
            "breath so it reads as distant town rather than wind"
        ),
    },
    {
        "clip_id": "ambience.forge_bed",
        "directory": AMBIENCE_DIR,
        "file": "forge_bed.mp3",
        "seed": 135802,
        # Forge bed: hearth rumble plus a bellows-paced crackle layer.
        "inputs": [
            "anoisesrc=d=%d:c=brown:a=0.34:seed=%d",
            "anoisesrc=d=%d:c=white:a=0.10:seed=%d",
        ],
        "filters": (
            "[0:a]lowpass=f=420,highpass=f=55,tremolo=0.28:0.35[hearth];"
            "[1:a]highpass=f=2600,lowpass=f=9000,tremolo=6.5:0.85,"
            "acompressor=threshold=-30dB:ratio=6:attack=1:release=60[crackle];"
            "[hearth][crackle]amix=inputs=2:weights=1 0.45:normalize=0,"
            "loudnorm=I=-26:TP=-3:LRA=8"
        ),
        "complex": True,
        "notes": (
            "48 s forge hearth bed: brown-noise fire rumble with a 0.28 Hz "
            "bellows swell, mixed with a gated white-noise crackle layer"
        ),
    },
    {
        "clip_id": "weather.rain_outdoor",
        "directory": WEATHER_DIR,
        "file": "rain_outdoor.mp3",
        # Offset from the forge bed, which consumes seed and seed + 1.
        "seed": 135810,
        # Open-air rain: brighter and flatter than the roof loop, which is
        # deliberately muffled for interiors.
        "inputs": ["anoisesrc=d=%d:c=pink:a=0.26:seed=%d"],
        "filters": (
            "highpass=f=300,lowpass=f=8000,"
            "tremolo=2.5:0.12,"
            "acompressor=threshold=-20dB:ratio=3:attack=5:release=90,"
            "loudnorm=I=-24:TP=-2:LRA=7"
        ),
        "notes": (
            "48 s open-air rain loop; pink noise high-passed so it reads as "
            "rain in the street, unlike the muffled rain_roof interior loop"
        ),
    },
]


def _command(clip: dict[str, object]) -> list[str]:
    cmd = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y"]
    seed = int(clip["seed"])
    for index, source in enumerate(clip["inputs"]):  # type: ignore[union-attr]
        cmd += ["-f", "lavfi", "-i", str(source) % (DURATION_SECONDS, seed + index)]
    flag = "-filter_complex" if clip.get("complex") else "-af"
    output: Path = clip["directory"] / str(clip["file"])  # type: ignore[operator]
    cmd += [
        flag,
        str(clip["filters"]),
        "-t",
        str(DURATION_SECONDS),
        "-ar",
        SAMPLE_RATE,
        "-b:a",
        AUDIO_BITRATE,
        str(output),
    ]
    return cmd


def generate(*, dry_run: bool) -> list[Path]:
    written: list[Path] = []
    for clip in CLIPS:
        directory: Path = clip["directory"]  # type: ignore[assignment]
        directory.mkdir(parents=True, exist_ok=True)
        cmd = _command(clip)
        if dry_run:
            print(" ".join(cmd))
            continue
        subprocess.run(cmd, check=True)
        written.append(directory / str(clip["file"]))
    if not dry_run:
        written += _write_manifests()
    return written


def _write_manifests() -> list[Path]:
    """One manifest per sounds/ subdirectory, matching the existing convention.

    The weather manifest already carries rain_roof, so its rows are merged
    instead of replaced.
    """
    written: list[Path] = []
    for directory in {clip["directory"] for clip in CLIPS}:
        manifest = directory / "manifest.csv"
        rows: dict[str, dict[str, str]] = {}
        if manifest.is_file():
            with manifest.open(encoding="utf-8", newline="") as handle:
                for row in csv.DictReader(handle):
                    rows[row["clip_id"]] = row
        for clip in CLIPS:
            if clip["directory"] is not directory:
                continue
            rows[str(clip["clip_id"])] = {
                "clip_id": str(clip["clip_id"]),
                "file": str(clip["file"]),
                "license": "AGPL-3.0-or-later (project author)",
                "source": "in-house ffmpeg synthesis (R-1358)",
                "notes": f"{clip['notes']}; lavfi seed {clip['seed']}",
            }
        with manifest.open("w", encoding="utf-8", newline="") as handle:
            # csv defaults to CRLF; the repo stores LF, so the file would read
            # back as modified after every regeneration.
            writer = csv.DictWriter(
                handle,
                fieldnames=["clip_id", "file", "license", "source", "notes"],
                lineterminator="\n",
            )
            writer.writeheader()
            for clip_id in sorted(rows):
                writer.writerow(rows[clip_id])
        written.append(manifest)
    return written


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    for path in generate(dry_run=args.dry_run):
        print(f"wrote {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

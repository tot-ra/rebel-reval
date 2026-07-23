#!/usr/bin/env python3
"""Process P0-122 raw bird recordings into engine-ready ambient clips (P0-123).

Reads ``sounds/birds/manifest.csv``, trims each take to the 15-90 s window when
needed, applies a light high-pass and loudness normalisation, and writes one
canonical ``call.mp3`` or ``song.mp3`` per catalog cue beside the raw source.

Usage:
    python3 tools/audio/process_bird_clips.py
    python3 tools/audio/process_bird_clips.py --birds-dir sounds/birds --dry-run
"""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AUDIO_TOOLS = ROOT / "tools" / "audio"
if str(AUDIO_TOOLS) not in sys.path:
    sys.path.insert(0, str(AUDIO_TOOLS))

from fetch_bird_songs import SONGBIRDS, SPECIES, parse_len_seconds  # noqa: E402

DEFAULT_LEN_RANGE = "15-90"
HIGH_PASS_HZ = 80
TARGET_LUFS = "-16"
TRUE_PEAK = "-1.5"
LRA = "11"
AUDIO_BITRATE = "128k"
SAMPLE_RATE = "44100"


def parse_len_range(text: str) -> tuple[int, int]:
    lo, hi = text.split("-", 1)
    return int(lo), int(hi)


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


def cue_kind_for(bird_id: str) -> str:
    return "song" if bird_id in SONGBIRDS else "call"


def cue_id_for(bird_id: str) -> str:
    return f"bird.{bird_id}.{cue_kind_for(bird_id)}"


def processed_path(birds_dir: Path, bird_id: str) -> Path:
    return birds_dir / bird_id / f"{cue_kind_for(bird_id)}.mp3"


def trim_window(duration: float, *, lo: int, hi: int) -> tuple[float, float]:
    """Return (start_seconds, output_duration_seconds) inside [lo, hi]."""
    if duration <= hi:
        if duration < lo:
            return 0.0, duration
        return 0.0, duration
    output = float(hi)
    start = max(0.0, (duration - output) / 2.0)
    return start, output


def process_clip(
    source: Path,
    dest: Path,
    *,
    lo: int,
    hi: int,
    dry_run: bool,
) -> dict[str, str | float]:
    duration = probe_duration_seconds(source)
    start, output_duration = trim_window(duration, lo=lo, hi=hi)
    if dry_run:
        return {
            "source": str(source),
            "processed": str(dest),
            "source_duration_s": duration,
            "processed_duration_s": output_duration,
            "trim_start_s": start,
        }

    dest.parent.mkdir(parents=True, exist_ok=True)
    filters = f"highpass=f={HIGH_PASS_HZ},loudnorm=I={TARGET_LUFS}:TP={TRUE_PEAK}:LRA={LRA}"
    cmd = [
        "ffmpeg",
        "-y",
        "-hide_banner",
        "-loglevel",
        "error",
        "-ss",
        f"{start:.3f}",
        "-t",
        f"{output_duration:.3f}",
        "-i",
        str(source),
        "-af",
        filters,
        "-ar",
        SAMPLE_RATE,
        "-b:a",
        AUDIO_BITRATE,
        str(dest),
    ]
    subprocess.run(cmd, check=True)
    processed_duration = probe_duration_seconds(dest)
    return {
        "source": str(source),
        "processed": str(dest),
        "source_duration_s": duration,
        "processed_duration_s": processed_duration,
        "trim_start_s": start,
    }


def load_manifest_rows(birds_dir: Path) -> dict[str, dict[str, str]]:
    manifest_path = birds_dir / "manifest.csv"
    if not manifest_path.is_file():
        raise FileNotFoundError(f"missing manifest: {manifest_path}")
    rows_by_bird: dict[str, dict[str, str]] = {}
    with open(manifest_path, newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            bird_id = row.get("bird_id", "")
            if bird_id in SPECIES and bird_id not in rows_by_bird:
                rows_by_bird[bird_id] = row
    missing = sorted(set(SPECIES) - set(rows_by_bird))
    if missing:
        raise ValueError(f"manifest missing species: {', '.join(missing)}")
    return rows_by_bird


def process_all(
    birds_dir: Path,
    *,
    len_range: str = DEFAULT_LEN_RANGE,
    dry_run: bool = False,
) -> list[dict[str, str | float]]:
    lo, hi = parse_len_range(len_range)
    rows_by_bird = load_manifest_rows(birds_dir)
    processed_rows: list[dict[str, str | float]] = []

    for bird_id in SPECIES:
        row = rows_by_bird[bird_id]
        source = Path(row["file"])
        if not source.is_file():
            raise FileNotFoundError(f"{bird_id}: missing source clip {source}")
        dest = processed_path(birds_dir, bird_id)
        stats = process_clip(source, dest, lo=lo, hi=hi, dry_run=dry_run)
        length_secs = float(stats["processed_duration_s"])
        if length_secs < lo or length_secs > hi + 0.25:
            raise ValueError(
                f"{bird_id}: processed length {length_secs:.2f}s outside {lo}-{hi}s"
            )
        processed_rows.append(
            {
                "cue": cue_id_for(bird_id),
                "bird_id": bird_id,
                "kind": cue_kind_for(bird_id),
                "source_file": str(source),
                "processed_file": str(dest),
                "source_xc_id": row.get("xc_id", ""),
                "license": row.get("license", ""),
                "recordist": row.get("recordist", ""),
                "page": row.get("page", ""),
                "source_duration_s": stats["source_duration_s"],
                "processed_duration_s": length_secs,
                "trim_start_s": stats["trim_start_s"],
            }
        )
        print(
            f"* {cue_id_for(bird_id)}: {source.name} -> {dest.name} "
            f"({stats['source_duration_s']:.1f}s -> {length_secs:.1f}s)",
            flush=True,
        )

    if not dry_run:
        manifest_out = birds_dir / "processed_manifest.csv"
        fieldnames = [
            "cue",
            "bird_id",
            "kind",
            "source_file",
            "processed_file",
            "source_xc_id",
            "license",
            "recordist",
            "page",
            "source_duration_s",
            "processed_duration_s",
            "trim_start_s",
        ]
        with open(manifest_out, "w", newline="", encoding="utf-8") as fh:
            writer = csv.DictWriter(fh, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(processed_rows)
        summary = {
            "len_range": len_range,
            "high_pass_hz": HIGH_PASS_HZ,
            "target_lufs": TARGET_LUFS,
            "clip_count": len(processed_rows),
        }
        (birds_dir / "processed_manifest.json").write_text(
            json.dumps(summary, indent=2) + "\n",
            encoding="utf-8",
        )
        print(f"\nProcessed manifest: {manifest_out} ({len(processed_rows)} cues)")

    return processed_rows


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--birds-dir", type=Path, default=ROOT / "sounds" / "birds")
    ap.add_argument("--len", dest="len_range", default=DEFAULT_LEN_RANGE)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    try:
        process_all(args.birds_dir, len_range=args.len_range, dry_run=args.dry_run)
    except (FileNotFoundError, ValueError, subprocess.CalledProcessError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

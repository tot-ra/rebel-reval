#!/usr/bin/env python3
"""Bake WS-13c/R-915 submerge and emerge one-shots from CC0 field recordings.

Why: the first WS-13c pass used lavfi noise so the cue contract could ship
without an external recordist. Those clips read as filtered hiss, not water.
This rebake trims public-domain harbour-scale splashes and keeps the same
runtime filenames, loudness, and attribution pipeline.

Usage:
    python3 tools/audio/generate_water_cross_clips.py
    python3 tools/audio/generate_water_cross_clips.py --dry-run
"""

from __future__ import annotations

import argparse
import csv
import subprocess
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WATER_DIR = ROOT / "sounds" / "water"
SOURCE_DIR = WATER_DIR / "source"
MANIFEST_CSV = WATER_DIR / "manifest.csv"
SAMPLE_RATE = "44100"
AUDIO_BITRATE = "128k"
USER_AGENT = "rebel-reval/r915-water-cross-clips"

# Freesound HQ previews are the same public fetch path as curated bird audio.
# Original 24-bit masters need a logged-in download; the preview is enough for
# a 128 kbps mono one-shot and keeps regeneration offline once cached.
CLIPS = (
    {
        "clip_id": "water.submerge",
        "title": "Harbour submerge splash",
        "file": "submerge.mp3",
        "author": "blaukreuz",
        "license": "https://creativecommons.org/publicdomain/zero/1.0/",
        "page": "https://freesound.org/people/blaukreuz/sounds/195877/",
        "source_file": "195877_blaukreuz_harbor_jump-hq.mp3",
        "source_url": "https://cdn.freesound.org/previews/195/195877_623488-hq.mp3",
        "start": 12.12,
        "duration": 1.40,
        "fade_in": 0.012,
        "fade_out": 0.22,
        "notes": (
            "Body-entry from CC0 Brela harbour jetty jump FS 195877; "
            "trim 12.12s + 1.40s, 50 Hz high-pass, loudnorm -18 LUFS"
        ),
    },
    {
        "clip_id": "water.emerge",
        "title": "Harbour emerge splash",
        "file": "emerge.mp3",
        "author": "morganveilleux",
        "license": "https://creativecommons.org/publicdomain/zero/1.0/",
        "page": "https://freesound.org/people/morganveilleux/sounds/389987/",
        "source_file": "389987_morganveilleux_coming_out-hq.mp3",
        "source_url": "https://cdn.freesound.org/previews/389/389987_6987210-hq.mp3",
        "start": 0.05,
        "duration": 1.10,
        "fade_in": 0.010,
        "fade_out": 0.18,
        "notes": (
            "Surface-break from CC0 water-lift FS 389987; "
            "trim 0.05s + 1.10s, 50 Hz high-pass, loudnorm -18 LUFS"
        ),
    },
)


def _download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        dest.write_bytes(response.read())


def _ensure_source(clip: dict, *, dry_run: bool) -> Path:
    dest = SOURCE_DIR / clip["source_file"]
    if dest.is_file() and dest.stat().st_size > 1024:
        return dest
    if dry_run:
        return dest
    _download(clip["source_url"], dest)
    if dest.stat().st_size < 1024:
        dest.unlink(missing_ok=True)
        raise RuntimeError(f"download too small: {clip['source_url']}")
    return dest


def _clip_command(clip: dict, source: Path) -> list[str]:
    duration = float(clip["duration"])
    fade_out_start = max(0.0, duration - float(clip["fade_out"]))
    filt = (
        f"highpass=f=50,"
        f"afade=t=in:st=0:d={clip['fade_in']},"
        f"afade=t=out:st={fade_out_start}:d={clip['fade_out']},"
        "loudnorm=I=-18:TP=-2:LRA=8"
    )
    return [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-i",
        str(source),
        "-ss",
        str(clip["start"]),
        "-t",
        str(duration),
        "-af",
        filt,
        "-ar",
        SAMPLE_RATE,
        "-ac",
        "1",
        "-b:a",
        AUDIO_BITRATE,
        str(WATER_DIR / clip["file"]),
    ]


def _write_manifest() -> None:
    rows = []
    for clip in CLIPS:
        rows.append(
            {
                "clip_id": clip["clip_id"],
                "title": clip["title"],
                "author": clip["author"],
                "license": clip["license"],
                "page": clip["page"],
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
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    ignore = SOURCE_DIR / ".gdignore"
    if not ignore.is_file():
        ignore.write_text(
            "# Raw Freesound HQ previews. Runtime uses the trimmed mp3s in the parent folder.\n",
            encoding="utf-8",
        )
    for clip in CLIPS:
        source = _ensure_source(clip, dry_run=dry_run)
        cmd = _clip_command(clip, source)
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

#!/usr/bin/env python3
"""Bake the R-2179 exterior and roof rain beds from Freesound field recordings.

The current files use synthesized noise with periodic tremolo, which can read as
mechanical pulsing. This builder uses steady field-recording excerpts instead,
then joins each 48-second loop with a short equal-power seam. HQ previews are
cached in build/audio_sources/ and pinned by SHA-256 for reproducible rebuilds.

Usage:
    python3 tools/audio/generate_weather_rain_loops.py
    python3 tools/audio/generate_weather_rain_loops.py --clip outdoor --dry-run
    python3 tools/audio/generate_weather_rain_loops.py --print-sources
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import subprocess
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CACHE_DIR = ROOT / "build" / "audio_sources"
WEATHER_DIR = ROOT / "sounds" / "weather"
MANIFEST = WEATHER_DIR / "manifest.csv"
SAMPLE_RATE = "44100"
AUDIO_BITRATE = "128k"
LOOP_SECONDS = 48.0
SEAM_SECONDS = 3.0
USER_AGENT = "rebel-reval/r2179-weather-rain-loops"

CLIPS: dict[str, dict[str, object]] = {
    "outdoor": {
        "clip_id": "weather.rain_outdoor",
        "title": "Light rain in a quiet coastal suburb",
        "author": "Andron827",
        "license": "https://creativecommons.org/publicdomain/zero/1.0/",
        "page": "https://freesound.org/people/Andron827/sounds/142936/",
        "url": "https://cdn.freesound.org/previews/142/142936_1504845-hq.mp3",
        "sha256": "058e6a736227cf49963fb787994008ec6cb5f375d9a0c759ec19456e6cb166bf",
        "start": 5.0,
        "lufs": -24,
        "file": "rain_outdoor.mp3",
    },
    "roof": {
        "clip_id": "weather.rain_roof",
        "title": "Rain interior wooden house roof",
        "author": "marsal.oido",
        "license": "https://creativecommons.org/licenses/by/4.0/",
        "page": "https://freesound.org/people/marsal.oido/sounds/415848/",
        "url": "https://cdn.freesound.org/previews/415/415848_2058991-hq.mp3",
        "sha256": "2ec505014f9d28ec87c07a4eb288961423894d17882104d7ba6f0761026eb49e",
        "start": 106.0,
        "lufs": -22,
        "file": "rain_roof.mp3",
    },
}


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _ensure_source(clip: dict[str, object]) -> Path:
    url = str(clip["url"])
    source = CACHE_DIR / Path(url).name
    if not source.is_file():
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=600) as response:
            source.write_bytes(response.read())
    digest = _sha256(source)
    if digest != clip["sha256"]:
        raise RuntimeError(f"sha256 mismatch for {source.name}: {digest}")
    return source


def _notes(clip: dict[str, object]) -> str:
    excerpt_end = float(clip["start"]) + LOOP_SECONDS + SEAM_SECONDS
    return (
        f"R-2179 {LOOP_SECONDS:.0f} s field-recording loop from Freesound HQ preview; "
        f"excerpt {float(clip['start']):.0f}-{excerpt_end:.0f} s with "
        f"{SEAM_SECONDS:.0f} s equal-power loop seam; 45 Hz high-pass; "
        f"loudnorm {clip['lufs']} LUFS; preview sha256 {clip['sha256']}"
    )


def _loop_command(clip: dict[str, object], source: Path, output: Path) -> list[str]:
    start = float(clip["start"])
    seam_end = start + LOOP_SECONDS + SEAM_SECONDS
    body_end = start + LOOP_SECONDS
    head_end = start + SEAM_SECONDS
    # Reuse the recorded continuation at the seam instead of crossfading two
    # unrelated points; the long body remains free of the old periodic flutter.
    graph = (
        "[0:a]highpass=f=45,asplit=3[a][b][c];"
        f"[a]atrim={start}:{head_end},asetpts=PTS-STARTPTS,"
        f"afade=t=in:d={SEAM_SECONDS}:curve=qsin[head];"
        f"[b]atrim={body_end}:{seam_end},asetpts=PTS-STARTPTS,"
        f"afade=t=out:d={SEAM_SECONDS}:curve=qsin[tail];"
        "[head][tail]amix=inputs=2:normalize=0[seam];"
        f"[c]atrim={head_end}:{body_end},asetpts=PTS-STARTPTS[body];"
        "[seam][body]concat=n=2:v=0:a=1,"
        f"loudnorm=I={clip['lufs']}:TP=-2:LRA=11[out]"
    )
    return [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-i",
        str(source),
        "-filter_complex",
        graph,
        "-map",
        "[out]",
        "-ar",
        SAMPLE_RATE,
        "-ac",
        "2",
        "-b:a",
        AUDIO_BITRATE,
        str(output),
    ]


def _write_manifest(selected: list[dict[str, object]]) -> None:
    rows: dict[str, dict[str, str]] = {}
    if MANIFEST.is_file():
        with MANIFEST.open(encoding="utf-8", newline="") as handle:
            for row in csv.DictReader(handle):
                rows[row["clip_id"]] = row
    for clip in selected:
        rows[str(clip["clip_id"])] = {
            "clip_id": str(clip["clip_id"]),
            "title": str(clip["title"]),
            "author": str(clip["author"]),
            "license": str(clip["license"]),
            "page": str(clip["page"]),
            "file": str(clip["file"]),
            "notes": _notes(clip),
        }
    fields = ["clip_id", "title", "author", "license", "page", "file", "notes"]
    with MANIFEST.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        for clip_id in sorted(rows):
            writer.writerow(rows[clip_id])


def _source_rows(selected: list[dict[str, object]]) -> list[list[str]]:
    rows = []
    for clip in selected:
        output = WEATHER_DIR / str(clip["file"])
        output_hash = _sha256(output) if output.is_file() else "missing"
        rows.append(
            [
                str(clip["clip_id"]).replace("weather.", "sounds.weather."),
                f"sounds/weather/{clip['file']}",
                str(clip["author"]),
                "Freesound HQ preview / tools/audio/generate_weather_rain_loops.py",
                f"{clip['page']} {clip['url']} output-sha256:{output_hash}",
                "n/a",
                str(clip["license"]),
                f"{_notes(clip)}; stereo 44.1 kHz 128 kbps; source excerpt pinned by SHA-256.",
                "approved - R-2179 maintainer request 2026-10-16",
            ]
        )
    return rows


def generate(*, selected: list[dict[str, object]], dry_run: bool) -> list[Path]:
    written: list[Path] = []
    for clip in selected:
        source = CACHE_DIR / Path(str(clip["url"])).name
        if not dry_run:
            source = _ensure_source(clip)
        output = WEATHER_DIR / str(clip["file"])
        command = _loop_command(clip, source, output)
        if dry_run:
            print(" ".join(command))
            continue
        WEATHER_DIR.mkdir(parents=True, exist_ok=True)
        subprocess.run(command, check=True)
        written.append(output)
    if not dry_run:
        _write_manifest(selected)
    return written


def main(default_clip: str = "all", argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--clip", choices=("all", "outdoor", "roof"), default=default_clip)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--print-sources", action="store_true")
    args = parser.parse_args(argv)
    selected = list(CLIPS.values()) if args.clip == "all" else [CLIPS[args.clip]]
    if args.print_sources:
        csv.writer(sys.stdout, lineterminator="\n").writerows(_source_rows(selected))
        return 0
    for path in generate(selected=selected, dry_run=args.dry_run):
        print(f"wrote {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Bake R-1550 sea surf and wind ambience loops from CC0 field recordings.

Why: the AmbienceController sea and wind layers crossfade three loops each by
wind strength (calm/moderate/storm surf, light/strong/storm wind). These are
real recordings, not lavfi noise: synthesised surf has no wave rhythm and reads
as hiss.

Each loop is a fixed excerpt of a public Freesound HQ preview (offsets are
constants, picked as the steadiest window by 1 s RMS), high-passed, loudness
normalised and made seamless by mixing the 3 s that follow the excerpt into its
head with an equal-power crossfade, so the end flows back into the start.

Previews are cached under build/audio_sources/ (gitignored: several exceed the
2 MiB storage cap for sounds/) and verified by sha256, so regeneration is
reproducible offline once cached.

Usage:
    python3 tools/audio/generate_sea_wind_beds.py
    python3 tools/audio/generate_sea_wind_beds.py --print-sources
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
SAMPLE_RATE = "44100"
AUDIO_BITRATE = "128k"
USER_AGENT = "rebel-reval/r1550-sea-wind-beds"
CC0 = "https://creativecommons.org/publicdomain/zero/1.0/"
LOOP_SECONDS = 52.0
SEAM_SECONDS = 3.0

CLIPS = (
    {
        "dir": "sea",
        "clip_id": "sea.calm",
        "lufs": -24,
        "title": "Calm sea, small waves on shingle",
        "file": "sea_calm.mp3",
        "author": "timsc",
        "fs_id": 367479,
        "page": "https://freesound.org/people/timsc/sounds/367479/",
        "url": "https://cdn.freesound.org/previews/367/367479_266678-hq.mp3",
        "sha256": "7cfb4b480c979ed909731afa8485fe9ef205a7fb63e2ea43af3b303935c92645",
        "start": 24.0,
    },
    {
        "dir": "sea",
        "clip_id": "sea.moderate",
        "lufs": -21,
        "title": "Moderate surf on shingle and rock",
        "file": "sea_moderate.mp3",
        "author": "leesparey",
        "fs_id": 653395,
        "page": "https://freesound.org/people/leesparey/sounds/653395/",
        "url": "https://cdn.freesound.org/previews/653/653395_4893432-hq.mp3",
        "sha256": "79ff7af2cae7dc596641e5a9617a8b7b70abe2076639d7d95c448c70938c35f2",
        "start": 639.0,
    },
    {
        "dir": "sea",
        "clip_id": "sea.storm",
        "lufs": -18,
        "title": "Storm waves breaking on a beach",
        "file": "sea_storm.mp3",
        "author": "chris_dagorne",
        "fs_id": 426076,
        "page": "https://freesound.org/people/chris_dagorne/sounds/426076/",
        "url": "https://cdn.freesound.org/previews/426/426076_3380363-hq.mp3",
        "sha256": "931332ae6d38cc03cf3fd794c05996b94f4cbe68713e28afd6f23f446507be3b",
        "start": 12.0,
    },
    {
        "dir": "wind",
        "clip_id": "wind.light",
        "lufs": -27,
        "title": "Light wind through pines",
        "file": "wind_light.mp3",
        "author": "kvgarlic",
        "fs_id": 184277,
        "page": "https://freesound.org/people/kvgarlic/sounds/184277/",
        "url": "https://cdn.freesound.org/previews/184/184277_1050391-hq.mp3",
        "sha256": "5f09cf202979897db2301d1dad2f60c8b07599e97103a59437b5626e665b18ff",
        "start": 42.0,
    },
    {
        "dir": "wind",
        "clip_id": "wind.strong",
        "lufs": -22,
        "title": "Strong wind in a tree",
        "file": "wind_strong.mp3",
        "author": "felix.blume",
        "fs_id": 187756,
        "page": "https://freesound.org/people/felix.blume/sounds/187756/",
        "url": "https://cdn.freesound.org/previews/187/187756_1661766-hq.mp3",
        "sha256": "160a58e58253654b8081a7e059e760596abe3542ce404dacf5b771abc9034490",
        "start": 13.0,
    },
    {
        "dir": "wind",
        "clip_id": "wind.storm",
        "lufs": -18,
        "title": "Howling storm wind",
        "file": "wind_storm.mp3",
        "author": "DBlover",
        "fs_id": 505999,
        "page": "https://freesound.org/people/DBlover/sounds/505999/",
        "url": "https://cdn.freesound.org/previews/505/505999_7846219-hq.mp3",
        "sha256": "2047bf1c4fdffdea4f01614118dc1b9cc210eda634dd7ed78c026a499c9eb3dd",
        "start": 147.0,
    },
)


def _notes(clip: dict) -> str:
    return (
        f"R-1550 seamless {LOOP_SECONDS:.0f} s loop from CC0 FS {clip['fs_id']}; "
        f"excerpt {clip['start']:.0f}s + {LOOP_SECONDS + SEAM_SECONDS:.0f}s, "
        f"{SEAM_SECONDS:.0f} s equal-power seam, 40 Hz high-pass, "
        f"loudnorm {clip['lufs']} LUFS"
    )


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _ensure_source(clip: dict) -> Path:
    dest = CACHE_DIR / Path(clip["url"]).name
    if not dest.is_file():
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        request = urllib.request.Request(clip["url"], headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=600) as response:
            dest.write_bytes(response.read())
    digest = _sha256(dest)
    if digest != clip["sha256"]:
        raise RuntimeError(f"sha256 mismatch for {dest.name}: {digest}")
    return dest


def _loop_command(clip: dict, source: Path, out: Path) -> list[str]:
    start = float(clip["start"])
    body_end = start + LOOP_SECONDS
    seam_end = body_end + SEAM_SECONDS
    head_end = start + SEAM_SECONDS
    # head: first SEAM seconds faded in; tail: the SEAM seconds after the loop
    # end, faded out and laid over the head. Playback of the loop end therefore
    # continues straight into the recording that really followed it.
    graph = (
        "[0:a]highpass=f=40,asplit=3[a][b][c];"
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
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        "-i", str(source),
        "-filter_complex", graph,
        "-map", "[out]",
        "-ar", SAMPLE_RATE, "-ac", "2", "-b:a", AUDIO_BITRATE,
        str(out),
    ]


def _write_manifests() -> None:
    fields = ["clip_id", "title", "author", "license", "page", "file", "notes"]
    for directory in sorted({clip["dir"] for clip in CLIPS}):
        path = ROOT / "sounds" / directory / "manifest.csv"
        with path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
            writer.writeheader()
            for clip in CLIPS:
                if clip["dir"] != directory:
                    continue
                writer.writerow(
                    {
                        "clip_id": clip["clip_id"],
                        "title": clip["title"],
                        "author": clip["author"],
                        "license": CC0,
                        "page": clip["page"],
                        "file": clip["file"],
                        "notes": _notes(clip),
                    }
                )


def _source_rows() -> list[list[str]]:
    rows = []
    for clip in CLIPS:
        path = ROOT / "sounds" / clip["dir"] / clip["file"]
        digest = _sha256(path) if path.is_file() else "missing"
        rows.append(
            [
                f"sounds.{clip['clip_id']}",
                f"sounds/{clip['dir']}/{clip['file']}",
                clip["author"],
                "Freesound HQ preview / tools/audio/generate_sea_wind_beds.py",
                f"{clip['page']} sha256:{digest}",
                str(clip["fs_id"]),
                "CC0 1.0",
                f"{_notes(clip)}; stereo 44.1 kHz 128 kbps; preview sha256 {clip['sha256']}.",
                "approved - R-1550 CC0 field recording (maintainer request 2026-10-10)",
            ]
        )
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--print-sources", action="store_true", help="print assets/SOURCES.csv rows"
    )
    args = parser.parse_args()
    if args.print_sources:
        writer = csv.writer(sys.stdout, lineterminator="\n")
        writer.writerows(_source_rows())
        return
    for clip in CLIPS:
        source = _ensure_source(clip)
        out = ROOT / "sounds" / clip["dir"] / clip["file"]
        out.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(_loop_command(clip, source, out), check=True)
        print(f"wrote {out.relative_to(ROOT)}")
    _write_manifests()


if __name__ == "__main__":
    main()

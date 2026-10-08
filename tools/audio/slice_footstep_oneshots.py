#!/usr/bin/env python3
"""Slice single-step footstep one-shots out of the two existing walk-cycle clips.

Why this exists (R-1382): the ADR 0035 phase-2 catalog pointed
sfx.footstep.wood.walk and sfx.footstep.mud.walk at `sounds/walk_wood.mp3`
(5.04 s) and `sounds/walking_on_mud_stable_audio_3.mp3` (7.99 s). Both are
continuous *walk cycles*, not one-shots, so FootstepAudio played a whole
multi-second cycle per foot plant and several of them overlapped. This tool
cuts those cycles into one impact per file so a foot plant can play exactly one
step.

Same approach as tools/audio/generate_ambience_beds.py (P0-124, R-1358):
deterministic in-house ffmpeg processing of material the project already owns,
so the output is commercially usable with no new third-party licence. The cut
offsets below are hand-picked constants, not runtime onset detection, so
regenerating is byte-stable.

Every slice is peak-normalised to the same ceiling, so a pool does not jump in
level between variations, and exported mono: the catalog plays these through
AudioStreamPlayer3D, and a baked stereo image fights positional panning.

Usage:
    python3 tools/audio/slice_footstep_oneshots.py
    python3 tools/audio/slice_footstep_oneshots.py --dry-run
"""

from __future__ import annotations

import argparse
import csv
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOUNDS_DIR = ROOT / "sounds"
OUT_DIR = SOUNDS_DIR / "footsteps"
WOOD_SOURCE = SOUNDS_DIR / "walk_wood.mp3"
MUD_SOURCE = SOUNDS_DIR / "walking_on_mud_stable_audio_3.mp3"

SAMPLE_RATE = "44100"
# docs/ASSET_STORAGE_POLICY.md: new runtime cues ship as 128 kbps CBR MP3.
AUDIO_BITRATE = "128k"
# Variations are matched on RMS, not peak: a pool normalised by peak still
# jumps in perceived loudness between steps, because the impacts differ in
# length and density. The peak ceiling then caps the gain so a layered pool
# cannot clip.
TARGET_RMS_DB = -18.0
# Measured on the PCM before encoding. MP3 overshoots the input peak by ~2.5 dB
# on these transients, so the ceiling keeps headroom for that too.
PEAK_CEILING_DB = -6.0
FADE_IN_SECONDS = 0.005

LICENSE = "AGPL-3.0-or-later (project author)"

# Cut table. Offsets were read off a 10 ms RMS envelope of each source and each
# one lands just before a single heel impact, with the window ending before the
# next step starts. `fade_out` hides the cut and the source's own floor noise.
#
# The wood cycle has five cleanly separated impacts. The mud cycle is a much
# denser, continuous squelch; only four of its steps are isolated enough to cut,
# which is why that pool is smaller.
SLICES: list[dict[str, object]] = [
    {
        "clip_id": "footstep.wood_walk_01",
        "file": "wood_walk_01.mp3",
        "source": WOOD_SOURCE,
        "start": 0.420,
        "duration": 0.240,
        "fade_out": 0.060,
    },
    {
        "clip_id": "footstep.wood_walk_02",
        "file": "wood_walk_02.mp3",
        "source": WOOD_SOURCE,
        "start": 1.100,
        "duration": 0.220,
        "fade_out": 0.060,
    },
    {
        "clip_id": "footstep.wood_walk_03",
        "file": "wood_walk_03.mp3",
        "source": WOOD_SOURCE,
        "start": 1.835,
        "duration": 0.240,
        "fade_out": 0.060,
    },
    {
        "clip_id": "footstep.wood_walk_04",
        "file": "wood_walk_04.mp3",
        "source": WOOD_SOURCE,
        "start": 2.555,
        "duration": 0.240,
        "fade_out": 0.060,
    },
    {
        "clip_id": "footstep.wood_walk_05",
        "file": "wood_walk_05.mp3",
        "source": WOOD_SOURCE,
        "start": 3.375,
        "duration": 0.260,
        "fade_out": 0.060,
    },
    {
        "clip_id": "footstep.mud_walk_01",
        "file": "mud_walk_01.mp3",
        "source": MUD_SOURCE,
        "start": 1.745,
        "duration": 0.175,
        "fade_out": 0.050,
    },
    {
        "clip_id": "footstep.mud_walk_02",
        "file": "mud_walk_02.mp3",
        "source": MUD_SOURCE,
        "start": 2.565,
        "duration": 0.175,
        "fade_out": 0.050,
    },
    {
        "clip_id": "footstep.mud_walk_03",
        "file": "mud_walk_03.mp3",
        "source": MUD_SOURCE,
        "start": 4.800,
        "duration": 0.145,
        "fade_out": 0.045,
    },
    {
        "clip_id": "footstep.mud_walk_04",
        "file": "mud_walk_04.mp3",
        "source": MUD_SOURCE,
        "start": 7.230,
        "duration": 0.115,
        "fade_out": 0.040,
    },
]

MAX_VOLUME_RE = re.compile(r"max_volume:\s*(-?\d+(?:\.\d+)?)\s*dB")
MEAN_VOLUME_RE = re.compile(r"mean_volume:\s*(-?\d+(?:\.\d+)?)\s*dB")


def _trim_filters(clip: dict[str, object]) -> str:
    """Cut inside the filter graph rather than with -ss.

    `-ss` before -i depends on the MPEG frame grid, and `-ss` after -i discards
    frames *after* filtering, which silently defeats afade (the fade-out would
    be timed against the full clip and the kept region comes out silent).
    atrim + a PTS reset is exact and independent of seek behaviour.
    """
    return "atrim=start=%.3f:duration=%.3f,asetpts=PTS-STARTPTS" % (
        float(clip["start"]),
        float(clip["duration"]),
    )


def _cut_args(clip: dict[str, object]) -> list[str]:
    return ["-i", str(clip["source"]), "-ac", "1"]


def _gain_db(clip: dict[str, object]) -> float:
    """RMS-matching gain for one cut, capped so the peak stays under the ceiling."""
    cmd = ["ffmpeg", "-hide_banner", "-nostats", "-y", *_cut_args(clip)]
    cmd += ["-af", _trim_filters(clip) + ",volumedetect", "-f", "null", "-"]
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    peak = MAX_VOLUME_RE.search(result.stderr)
    mean = MEAN_VOLUME_RE.search(result.stderr)
    if peak is None or mean is None:
        raise RuntimeError(f"ffmpeg volumedetect gave no levels for {clip['clip_id']}")
    return min(
        TARGET_RMS_DB - float(mean.group(1)),
        PEAK_CEILING_DB - float(peak.group(1)),
    )


def _encode_command(clip: dict[str, object], gain_db: float) -> list[str]:
    duration = float(clip["duration"])
    fade_out = float(clip["fade_out"])
    chain = ",".join(
        [
            _trim_filters(clip),
            f"volume={gain_db:.2f}dB",
            f"afade=t=in:st=0:d={FADE_IN_SECONDS}",
            f"afade=t=out:st={duration - fade_out:.3f}:d={fade_out:.3f}",
        ]
    )
    return [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        *_cut_args(clip),
        "-af",
        chain,
        "-ar",
        SAMPLE_RATE,
        "-b:a",
        AUDIO_BITRATE,
        str(OUT_DIR / str(clip["file"])),
    ]


def _notes(clip: dict[str, object]) -> str:
    return (
        "R-1382 single-step one-shot cut from %s at %.3f s, %.0f ms, mono, "
        "RMS-matched to %.0f dBFS under a %.0f dBFS peak ceiling; the source is a "
        "continuous walk cycle and must never be played as a one-shot itself"
        % (
            clip["source"].name,  # type: ignore[union-attr]
            float(clip["start"]),
            float(clip["duration"]) * 1000.0,
            TARGET_RMS_DB,
            PEAK_CEILING_DB,
        )
    )


def slice_all(*, dry_run: bool) -> list[Path]:
    for source in {WOOD_SOURCE, MUD_SOURCE}:
        if not source.is_file():
            raise FileNotFoundError(f"missing source clip: {source}")
    written: list[Path] = []
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for clip in SLICES:
        if dry_run:
            # Peak measurement needs a decode pass, so show the cut instead of a
            # gain that would differ from the real run.
            print("%s -> %s" % (_trim_filters(clip), OUT_DIR / str(clip["file"])))
            continue
        gain_db = _gain_db(clip)
        subprocess.run(_encode_command(clip, gain_db), check=True)
        written.append(OUT_DIR / str(clip["file"]))
    if not dry_run:
        written.append(_write_manifest())
    return written


def _write_manifest() -> Path:
    path = OUT_DIR / "manifest.csv"
    with path.open("w", encoding="utf-8", newline="") as handle:
        # csv defaults to CRLF; the repo stores LF, so the file would read back
        # as modified after every regeneration.
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(["clip_id", "file", "license", "source", "notes"])
        for clip in SLICES:
            writer.writerow(
                [
                    clip["clip_id"],
                    clip["file"],
                    LICENSE,
                    "in-house ffmpeg slice of %s (R-1382)"
                    % clip["source"].name,  # type: ignore[union-attr]
                    _notes(clip),
                ]
            )
    return path


def sources_rows() -> list[list[str]]:
    """assets/SOURCES.csv rows for the slices, in the shipped column order.

    Printed by --print-sources so the provenance rows are generated from the
    same cut table rather than retyped.
    """
    parents = {
        WOOD_SOURCE: "sounds.walk.wood",
        MUD_SOURCE: "sounds.walking.on.mud.stable.audio.3",
    }
    rows: list[list[str]] = []
    for clip in SLICES:
        source: Path = clip["source"]  # type: ignore[assignment]
        asset_id = "sounds.footsteps." + str(clip["file"]).removesuffix(".mp3")
        rows.append(
            [
                asset_id,
                "sounds/footsteps/%s" % clip["file"],
                "project maintainer",
                "in-house ffmpeg slice (tools/audio/slice_footstep_oneshots.py)",
                "tools/audio/slice_footstep_oneshots.py",
                "n/a",
                LICENSE,
                "%s. Derived from approved source %s." % (_notes(clip), parents[source]),
                "approved - in-house slice of approved source",
            ]
        )
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="print the cuts, write nothing")
    parser.add_argument(
        "--print-sources",
        action="store_true",
        help="print assets/SOURCES.csv rows for the slices and exit",
    )
    args = parser.parse_args()
    if args.print_sources:
        writer = csv.writer(sys.stdout)
        for row in sources_rows():
            writer.writerow(row)
        return 0
    for path in slice_all(dry_run=args.dry_run):
        print(path.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

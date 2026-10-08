#!/usr/bin/env python3
"""Synthesise footstep one-shots for the surfaces that have no recording yet.

Why this exists (R-1383): ADR 0035 phase 2 shipped only two pools, wood and
mud, and let SurfaceResolver borrow them for the other four surfaces. The
borrowed material is audible as a defect - walking world_saaremaa knocked like
a plank on its beaches and squelched like a swamp on its meadows - so the
stand-in chains were removed. This tool gives stone, grass, gravel/sand and
shallow water a pool of the right material instead.

Same approach as tools/audio/generate_ambience_beds.py (P0-124, R-1358):
deterministic in-house ffmpeg synthesis, so the clips are commercially usable
with no attribution and no third-party licence to store. They remain
placeholders: the catalog addresses them by ID, so a licensed or recorded
replacement drops in without touching code.

Each clip is one noise burst (two layers for water) shaped by a material filter
chain and a percussive envelope, then RMS-matched to the same target as the
sliced wood and mud one-shots so a pool does not jump in level between
variations and surfaces do not jump in level between maps. Mono on purpose: the
catalog plays these through AudioStreamPlayer3D and a baked stereo image fights
positional panning.

Usage:
    python3 tools/audio/generate_footstep_oneshots.py
    python3 tools/audio/generate_footstep_oneshots.py --dry-run
    python3 tools/audio/generate_footstep_oneshots.py --print-sources
"""

from __future__ import annotations

import argparse
import csv
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "sounds" / "footsteps"

SAMPLE_RATE = "44100"
# docs/ASSET_STORAGE_POLICY.md: new runtime cues ship as 128 kbps CBR MP3.
AUDIO_BITRATE = "128k"
# Matches tools/audio/slice_footstep_oneshots.py so the synthesised pools sit at
# the same loudness as the sliced wood and mud pools.
TARGET_RMS_DB = -18.0
PEAK_CEILING_DB = -6.0
FADE_IN_SECONDS = 0.004

LICENSE = "AGPL-3.0-or-later (project author)"

# Material voices. `attack` is the envelope's rise, `body` the point where the
# exponential decay starts; everything after it is tail. Short attacks read as
# a hard heel strike, longer ones as a sole brushing through cover.
#
# Frequencies come from the acoustics of the real surface: a flagstone returns a
# bright, fast transient with a mid ring; grass is band-limited rustle with no
# low end; gravel is a dense granular crunch (modelled with a fast tremolo that
# chops the noise into grains); a puddle is a bright splash over a low slap of
# displaced water, which is why it is the one two-layer voice.
VOICES: dict[str, dict[str, object]] = {
    "stone": {
        "inputs": ["anoisesrc=d=%(duration).3f:c=white:a=0.9:seed=%(seed)d"],
        "chain": (
            "highpass=f=380,lowpass=f=7000,"
            "equalizer=f=%(tone)d:width_type=q:w=1.0:g=5,"
            "acompressor=threshold=-18dB:ratio=4:attack=1:release=40"
        ),
        "attack": 0.003,
        "body": 0.014,
        "tones": [1500, 1750, 1300, 1950],
        "durations": [0.130, 0.145, 0.120, 0.150],
    },
    "grass": {
        "inputs": ["anoisesrc=d=%(duration).3f:c=white:a=0.8:seed=%(seed)d"],
        # Rustle, not impact: the tremolo breaks the noise into blade contacts
        # and the high-pass removes any body so it cannot read as soil.
        "chain": (
            "highpass=f=%(tone)d,lowpass=f=9000,"
            "tremolo=f=72:d=0.45,"
            "acompressor=threshold=-22dB:ratio=3:attack=4:release=90"
        ),
        "attack": 0.022,
        "body": 0.055,
        "tones": [1200, 1450, 1050, 1600],
        "durations": [0.185, 0.200, 0.170, 0.210],
    },
    "gravel": {
        # Sand and gravel share this surface in the six-surface first cut.
        "inputs": ["anoisesrc=d=%(duration).3f:c=white:a=0.85:seed=%(seed)d"],
        "chain": (
            "highpass=f=600,lowpass=f=%(tone)d,"
            "tremolo=f=46:d=0.9,"
            "acompressor=threshold=-20dB:ratio=5:attack=1:release=50"
        ),
        "attack": 0.004,
        "body": 0.030,
        "tones": [9000, 10500, 8000, 11000],
        "durations": [0.155, 0.170, 0.140, 0.180],
    },
    "water_shallow": {
        "inputs": [
            "anoisesrc=d=%(duration).3f:c=white:a=0.85:seed=%(seed)d",
            "anoisesrc=d=%(duration).3f:c=brown:a=0.9:seed=%(seed2)d",
        ],
        # [0] spray, [1] the low slap of displaced water under it.
        "chain": (
            "[0:a]highpass=f=%(tone)d,lowpass=f=11000,"
            "afade=t=in:st=0:d=0.004,afade=t=out:st=0.020:d=%(spray_tail).3f:curve=exp[spray];"
            "[1:a]lowpass=f=320,"
            "afade=t=in:st=0:d=0.006,afade=t=out:st=0.010:d=0.090:curve=exp[slap];"
            "[spray][slap]amix=inputs=2:weights=1 0.55:normalize=0"
        ),
        "attack": 0.004,
        "body": 0.022,
        "tones": [700, 850, 600, 950],
        "durations": [0.240, 0.260, 0.215, 0.275],
    },
}

# Seeds are fixed so regeneration is byte-stable. Each voice gets its own block
# of 10 so adding a fifth variation cannot collide with the next voice.
SEED_BASE: dict[str, int] = {
    "stone": 138300,
    "grass": 138310,
    "gravel": 138320,
    "water_shallow": 138330,
}

MAX_VOLUME_RE = re.compile(r"max_volume:\s*(-?\d+(?:\.\d+)?)\s*dB")
MEAN_VOLUME_RE = re.compile(r"mean_volume:\s*(-?\d+(?:\.\d+)?)\s*dB")


def clips() -> list[dict[str, object]]:
    """One record per output file, expanded from the voice table."""
    out: list[dict[str, object]] = []
    for surface, voice in VOICES.items():
        durations: list[float] = voice["durations"]  # type: ignore[assignment]
        tones: list[int] = voice["tones"]  # type: ignore[assignment]
        for index, duration in enumerate(durations):
            out.append(
                {
                    "surface": surface,
                    "file": "%s_walk_%02d.mp3" % (surface, index + 1),
                    "clip_id": "footstep.%s_walk_%02d" % (surface, index + 1),
                    "duration": duration,
                    "tone": tones[index],
                    "seed": SEED_BASE[surface] + index * 2,
                    "seed2": SEED_BASE[surface] + index * 2 + 1,
                    "voice": voice,
                }
            )
    return out


def _substitutions(clip: dict[str, object]) -> dict[str, object]:
    duration = float(clip["duration"])
    voice: dict[str, object] = clip["voice"]  # type: ignore[assignment]
    return {
        "duration": duration,
        "seed": clip["seed"],
        "seed2": clip["seed2"],
        "tone": clip["tone"],
        # The spray layer decays over whatever is left after its own attack.
        "spray_tail": max(duration - 0.020, 0.040),
    }


def _input_args(clip: dict[str, object]) -> list[str]:
    voice: dict[str, object] = clip["voice"]  # type: ignore[assignment]
    subs = _substitutions(clip)
    args: list[str] = []
    for descriptor in voice["inputs"]:  # type: ignore[union-attr]
        args += ["-f", "lavfi", "-i", str(descriptor) % subs]
    return args


def _envelope(clip: dict[str, object]) -> str:
    """Percussive attack plus an exponential decay to the end of the clip.

    One `afade=out` with curve=exp rather than a linear fade: a linear tail on a
    140 ms impact is heard as a gate closing, an exponential one as a surface
    ringing out.
    """
    voice: dict[str, object] = clip["voice"]  # type: ignore[assignment]
    duration = float(clip["duration"])
    body = float(voice["body"])  # type: ignore[arg-type]
    return "afade=t=in:st=0:d=%.3f:curve=qsin,afade=t=out:st=%.3f:d=%.3f:curve=exp" % (
        max(float(voice["attack"]), FADE_IN_SECONDS),  # type: ignore[arg-type]
        body,
        duration - body,
    )


def _graph(clip: dict[str, object], gain_db: float | None) -> str:
    voice: dict[str, object] = clip["voice"]  # type: ignore[assignment]
    chain = str(voice["chain"]) % _substitutions(clip)
    parts = [chain, _envelope(clip)]
    if gain_db is None:
        parts.append("volumedetect")
    else:
        # Gain to the RMS target, then limit instead of backing the gain off to
        # fit the peak: a synthesised impact has a far higher crest factor than
        # the sliced wood and mud steps, so a peak-capped gain would leave these
        # pools ~5 dB quieter and the player would hear the level drop when
        # crossing from a plank onto cobbles.
        parts.append("volume=%.2fdB" % gain_db)
        parts.append(
            "alimiter=level_in=1:level_out=1:limit=%.4f:attack=0.1:release=20:level=disabled"
            % (10.0 ** (PEAK_CEILING_DB / 20.0))
        )
    return ",".join(parts)


def _ffmpeg(clip: dict[str, object], gain_db: float | None, target: Path | None) -> list[str]:
    """One command for both passes.

    A single input uses -af; the two-layer water voice needs -filter_complex,
    and that flag also accepts the single-chain form, so the graph is built once
    either way.
    """
    cmd = ["ffmpeg", "-hide_banner", "-nostats", "-y", *_input_args(clip)]
    cmd += ["-filter_complex", _graph(clip, gain_db), "-ac", "1"]
    if target is None:
        cmd += ["-f", "null", "-"]
    else:
        cmd += ["-ar", SAMPLE_RATE, "-b:a", AUDIO_BITRATE, str(target)]
    return cmd


def _gain_db(clip: dict[str, object]) -> float:
    """RMS-matching gain. The limiter in the encode graph holds the peak."""
    result = subprocess.run(
        _ffmpeg(clip, None, None), capture_output=True, text=True, check=True
    )
    mean = MEAN_VOLUME_RE.search(result.stderr)
    if mean is None:
        raise RuntimeError(f"ffmpeg volumedetect gave no levels for {clip['clip_id']}")
    return TARGET_RMS_DB - float(mean.group(1))


def _notes(clip: dict[str, object]) -> str:
    voice: dict[str, object] = clip["voice"]  # type: ignore[assignment]
    layers = len(voice["inputs"])  # type: ignore[arg-type]
    return (
        "R-1383 synthesised %s footstep one-shot, %.0f ms, mono, %d noise "
        "layer(s), lavfi seed %d, RMS-matched to %.0f dBFS under a %.0f dBFS "
        "peak ceiling; placeholder for a recorded or licensed pool, addressed "
        "by catalog ID sfx.footstep.%s.walk"
        % (
            clip["surface"],
            float(clip["duration"]) * 1000.0,
            layers,
            int(clip["seed"]),  # type: ignore[arg-type]
            TARGET_RMS_DB,
            PEAK_CEILING_DB,
            clip["surface"],
        )
    )


def generate(*, dry_run: bool) -> list[Path]:
    written: list[Path] = []
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for clip in clips():
        target = OUT_DIR / str(clip["file"])
        if dry_run:
            # The gain needs a measurement pass, so show the graph instead of a
            # number that would differ from the real run.
            print("%s -> %s" % (_graph(clip, None), target))
            continue
        subprocess.run(_ffmpeg(clip, _gain_db(clip), target), check=True, capture_output=True)
        written.append(target)
    return written


def sources_rows() -> list[list[str]]:
    """assets/SOURCES.csv rows, in the shipped column order."""
    rows: list[list[str]] = []
    for clip in clips():
        rows.append(
            [
                "sounds.footsteps." + str(clip["file"]).removesuffix(".mp3"),
                "sounds/footsteps/%s" % clip["file"],
                "project maintainer",
                "in-house ffmpeg synthesis (tools/audio/generate_footstep_oneshots.py)",
                "tools/audio/generate_footstep_oneshots.py",
                str(clip["seed"]),
                LICENSE,
                _notes(clip) + ".",
                "approved - R-1383 in-house footstep synthesis",
            ]
        )
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="print the graphs, write nothing")
    parser.add_argument(
        "--print-sources",
        action="store_true",
        help="print assets/SOURCES.csv rows for the clips and exit",
    )
    args = parser.parse_args()
    if args.print_sources:
        writer = csv.writer(sys.stdout)
        writer.writerows(sources_rows())
        return 0
    for path in generate(dry_run=args.dry_run):
        print(path.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

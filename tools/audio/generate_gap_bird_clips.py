#!/usr/bin/env python3
"""Generate P0-122b maintainer-recorded gap calls for species without commercial takes.

After P0-122c found no CC0/BY/BY-SA Baltic clips for ``great_cormorant`` or
``white_tailed_eagle``, this script produces deterministic in-house call loops
with ffmpeg (no external field recording). Clips are tagged ``source: maintainer``
in ``curated_bird_recordings.json`` and should be replaced by real Baltic field
takes when **P0-122e** lands.

Usage:
    python3 tools/audio/generate_gap_bird_clips.py
    python3 tools/audio/generate_gap_bird_clips.py --dry-run
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BIRDS_DIR = ROOT / "sounds" / "birds"
SAMPLE_RATE = "44100"
AUDIO_BITRATE = "128k"

GAP_CLIPS: dict[str, dict[str, object]] = {
    "great_cormorant": {
        "recording_id": "122b01",
        "duration": 24,
        "grunts": [
            (1.0, 270),
            (4.6, 285),
            (8.4, 300),
            (12.2, 290),
            (16.0, 305),
            (20.1, 275),
        ],
    },
    "white_tailed_eagle": {
        "recording_id": "122b02",
        "duration": 21,
        "mews": [
            (1.5, 880, 620),
            (6.8, 920, 650),
            (11.9, 860, 600),
            (16.7, 900, 640),
        ],
    },
}


def _ffmpeg_exists() -> bool:
    return shutil.which("ffmpeg") is not None


def _run_ffmpeg(cmd: list[str], *, dry_run: bool) -> None:
    if dry_run:
        print(" ".join(cmd))
        return
    subprocess.run(cmd, check=True)


def _cormorant_filter(grunts: list[tuple[float, int]], duration: int) -> str:
    chains: list[str] = []
    labels: list[str] = ["[0:a]"]
    for index, (start, _frequency) in enumerate(grunts):
        input_index = index + 1
        chains.append(
            f"[{input_index}:a]volume=0.42,afade=t=out:st=0.22:d=0.18,"
            f"adelay={int(start * 1000)}|{int(start * 1000)}[g{index}]"
        )
        labels.append(f"[g{index}]")
    mix = "".join(labels)
    chains.append(
        f"{mix}amix=inputs={len(labels)}:duration=longest:dropout_transition=0,"
        "highpass=f=110,lowpass=f=900,"
        "loudnorm=I=-16:TP=-1.5:LRA=11"
    )
    return ";".join(chains)


def _eagle_filter(mews: list[tuple[float, int, int]], duration: int) -> str:
    chains: list[str] = []
    labels: list[str] = ["[0:a]"]
    input_index = 1
    for call_index, (start, _start_hz, _end_hz) in enumerate(mews):
        chains.append(
            f"[{input_index}:a]volume=0.38,afade=t=out:st=0.35:d=0.2,"
            f"adelay={int(start * 1000)}|{int(start * 1000)}[m{call_index}a]"
        )
        input_index += 1
        chains.append(
            f"[{input_index}:a]volume=0.22,afade=t=out:st=0.35:d=0.2,"
            f"adelay={int(start * 1000)}|{int(start * 1000)}[m{call_index}b]"
        )
        input_index += 1
        chains.append(
            f"[m{call_index}a][m{call_index}b]amix=inputs=2:duration=longest[m{call_index}]"
        )
        labels.append(f"[m{call_index}]")
    mix = "".join(labels)
    chains.append(
        f"{mix}amix=inputs={len(labels)}:duration=longest:dropout_transition=0,"
        "highpass=f=350,lowpass=f=2200,"
        "loudnorm=I=-16:TP=-1.5:LRA=11"
    )
    return ";".join(chains)


def _generate_cormorant(output: Path, *, dry_run: bool) -> None:
    spec = GAP_CLIPS["great_cormorant"]
    grunts: list[tuple[float, int]] = spec["grunts"]  # type: ignore[assignment]
    duration = int(spec["duration"])
    cmd = [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-f",
        "lavfi",
        "-i",
        f"anullsrc=channel_layout=mono:sample_rate={SAMPLE_RATE}:duration={duration}",
    ]
    for _, frequency in grunts:
        cmd.extend(
            [
                "-f",
                "lavfi",
                "-i",
                f"sine=frequency={frequency}:duration=0.45:sample_rate={SAMPLE_RATE}",
            ]
        )
    cmd.extend(
        [
            "-filter_complex",
            _cormorant_filter(grunts, duration),
            "-t",
            str(duration),
            "-ar",
            SAMPLE_RATE,
            "-b:a",
            AUDIO_BITRATE,
            str(output),
        ]
    )
    _run_ffmpeg(cmd, dry_run=dry_run)


def _generate_eagle(output: Path, *, dry_run: bool) -> None:
    spec = GAP_CLIPS["white_tailed_eagle"]
    mews: list[tuple[float, int, int]] = spec["mews"]  # type: ignore[assignment]
    duration = int(spec["duration"])
    cmd = [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-f",
        "lavfi",
        "-i",
        f"anullsrc=channel_layout=mono:sample_rate={SAMPLE_RATE}:duration={duration}",
    ]
    for _, start_hz, end_hz in mews:
        cmd.extend(
            [
                "-f",
                "lavfi",
                "-i",
                (
                    f"sine=frequency={start_hz}:duration=0.55:sample_rate={SAMPLE_RATE}"
                ),
            ]
        )
        cmd.extend(
            [
                "-f",
                "lavfi",
                "-i",
                (
                    f"sine=frequency={end_hz}:duration=0.55:sample_rate={SAMPLE_RATE}"
                ),
            ]
        )
    cmd.extend(
        [
            "-filter_complex",
            _eagle_filter(mews, duration),
            "-t",
            str(duration),
            "-ar",
            SAMPLE_RATE,
            "-b:a",
            AUDIO_BITRATE,
            str(output),
        ]
    )
    _run_ffmpeg(cmd, dry_run=dry_run)


def generate_all(*, dry_run: bool) -> list[Path]:
    if not dry_run and not _ffmpeg_exists():
        raise RuntimeError("ffmpeg is required to generate gap bird clips")

    outputs: list[Path] = []
    for bird_id, spec in GAP_CLIPS.items():
        recording_id = str(spec["recording_id"])
        out_dir = BIRDS_DIR / bird_id
        output = out_dir / f"{bird_id}_MR{recording_id}.mp3"
        outputs.append(output)
        if dry_run:
            print(f"* {bird_id} -> {output.relative_to(ROOT)}")
            continue
        out_dir.mkdir(parents=True, exist_ok=True)
        if bird_id == "great_cormorant":
            _generate_cormorant(output, dry_run=False)
        else:
            _generate_eagle(output, dry_run=False)
        print(f"wrote {output.relative_to(ROOT)}")
    return outputs


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    try:
        generate_all(dry_run=args.dry_run)
    except (RuntimeError, subprocess.CalledProcessError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Recompress runtime audio that exceeds the P0-182 bitrate or size caps.

Lossy MP3 outliers are rewritten in place at the sounds_lossy encode target
(128 kbps CBR, 44.1 kHz) without loudness filters so later bird-clip processing
can still read the same takes. Requires ffmpeg. PCM WAV/FLAC is left untouched.

Usage:
    python3 tools/optimize_runtime_audio.py
    python3 tools/optimize_runtime_audio.py --dry-run
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import verify_runtime_audio_budget as budget  # noqa: E402

MANIFEST_PATH = ROOT / "docs" / "data" / "runtime_audio_budget.json"
SAMPLE_RATE = "44100"


def _ffmpeg() -> str:
    binary = shutil.which("ffmpeg")
    if binary is None:
        raise SystemExit("ffmpeg is required to recompress runtime audio")
    return binary


def _target_kbps(rel: str, manifest: dict) -> str:
    if rel.startswith("music/"):
        bps = int(manifest["budget"]["music"]["encode_target_bps"])
    else:
        bps = int(manifest["budget"]["sounds_lossy"]["encode_target_bps"])
    return f"{bps // 1000}k"


def optimize_file(path: Path, *, ffmpeg: str, bitrate: str, dry_run: bool) -> None:
    if dry_run:
        return
    with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as handle:
        dest = Path(handle.name)
    cmd = [
        ffmpeg,
        "-y",
        "-hide_banner",
        "-loglevel",
        "error",
        "-i",
        str(path),
        "-ar",
        SAMPLE_RATE,
        "-c:a",
        "libmp3lame",
        "-b:a",
        bitrate,
        str(dest),
    ]
    subprocess.run(cmd, check=True)
    shutil.move(str(dest), str(path))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--manifest", type=Path, default=MANIFEST_PATH)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)

    manifest_path = args.manifest if args.manifest.is_absolute() else args.root / args.manifest
    manifest, read_errors = budget.load_manifest(manifest_path)
    if read_errors:
        print("\n".join(read_errors), file=sys.stderr)
        return 1

    errors = budget.validate(root=args.root, manifest_path=manifest_path)
    over = [line.split(":", 1)[0] for line in errors if ": " in line and "missing" not in line]
    unique = []
    seen: set[str] = set()
    for rel in over:
        if rel in seen:
            continue
        seen.add(rel)
        unique.append(rel)

    if not unique:
        print("runtime audio already inside budget")
        return 0

    ffmpeg = _ffmpeg()
    rewritten = []
    skipped = []
    for rel in unique:
        path = args.root / rel
        if path.suffix.lower() != ".mp3":
            skipped.append(rel)
            continue
        bitrate = _target_kbps(rel, manifest)
        before = path.stat().st_size
        optimize_file(path, ffmpeg=ffmpeg, bitrate=bitrate, dry_run=args.dry_run)
        after = before if args.dry_run else path.stat().st_size
        rewritten.append({"path": rel, "bytes_before": before, "bytes_after": after})
        action = "would recompress" if args.dry_run else "recompressed"
        print(f"{action} {rel}: {before} -> {after}")

    if skipped:
        print("skipped non-mp3 outliers:", file=sys.stderr)
        for rel in skipped:
            print(f"  - {rel}", file=sys.stderr)
        return 1 if not args.dry_run else 0

    print(json.dumps({"rewritten": rewritten}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

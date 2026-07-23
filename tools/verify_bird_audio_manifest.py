#!/usr/bin/env python3
"""Verify the P0-122 bird-audio manifest and downloaded clips.

Checks that every runtime bird species in tools/audio/fetch_bird_songs.py has at
least one on-disk recording whose manifest row carries a commercial-friendly
license (CC0 / CC BY / CC BY-SA) and a length inside the configured window.

Usage:
    python3 tools/verify_bird_audio_manifest.py
    python3 tools/verify_bird_audio_manifest.py --birds-dir sounds/birds
"""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIO_TOOLS = ROOT / "tools" / "audio"
if str(AUDIO_TOOLS) not in sys.path:
    sys.path.insert(0, str(AUDIO_TOOLS))

from fetch_bird_songs import (  # noqa: E402
    SPECIES,
    is_commercial_license,
    parse_len_seconds,
)

DEFAULT_LEN_RANGE = "15-90"


def parse_len_range(text: str) -> tuple[int, int]:
    lo, hi = text.split("-", 1)
    return int(lo), int(hi)


def verify(
    birds_dir: Path,
    *,
    len_range: str = DEFAULT_LEN_RANGE,
) -> list[str]:
    errors: list[str] = []
    manifest_path = birds_dir / "manifest.csv"
    if not manifest_path.is_file():
        return [f"missing manifest: {manifest_path}"]

    lo, hi = parse_len_range(len_range)
    rows_by_bird: dict[str, list[dict[str, str]]] = {bird_id: [] for bird_id in SPECIES}
    with open(manifest_path, newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            bird_id = row.get("bird_id", "")
            if bird_id in rows_by_bird:
                rows_by_bird[bird_id].append(row)

    for bird_id in SPECIES:
        species_rows = rows_by_bird[bird_id]
        if not species_rows:
            errors.append(f"{bird_id}: no manifest row")
            continue

        valid = False
        for row in species_rows:
            lic = row.get("license", "")
            if not is_commercial_license(lic):
                errors.append(
                    f"{bird_id}: non-commercial or blocked license {lic!r} (XC{row.get('xc_id', '')})"
                )
                continue

            length_secs = parse_len_seconds(row.get("length", ""))
            if length_secs < 0:
                errors.append(f"{bird_id}: unparseable length {row.get('length', '')!r}")
                continue
            if length_secs < lo or length_secs > hi:
                errors.append(
                    f"{bird_id}: length {length_secs}s outside {lo}-{hi}s (XC{row.get('xc_id', '')})"
                )
                continue

            file_path = Path(row.get("file", ""))
            if not file_path.is_file():
                errors.append(f"{bird_id}: missing file {file_path}")
                continue

            valid = True
            break

        if not valid and not any(
            f.startswith(f"{bird_id}:") for f in errors if bird_id in f
        ):
            errors.append(f"{bird_id}: no valid commercial clip in range")

    return errors


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--birds-dir", type=Path, default=ROOT / "sounds" / "birds")
    ap.add_argument("--len", dest="len_range", default=DEFAULT_LEN_RANGE)
    args = ap.parse_args()

    errors = verify(args.birds_dir, len_range=args.len_range)
    if errors:
        print("bird audio manifest verification failed:")
        for error in errors:
            print(f"  - {error}")
        return 1

    manifest_path = args.birds_dir / "manifest.csv"
    print(
        f"bird audio manifest verification passed "
        f"({len(SPECIES)} species; manifest {manifest_path})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

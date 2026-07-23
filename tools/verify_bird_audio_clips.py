#!/usr/bin/env python3
"""Verify P0-123 processed bird clips resolve every catalog cue.

Checks that each ``song.cue`` in ``map_view_bird_species.gd`` maps to an on-disk
processed ``.mp3`` with a Godot ``.import`` sidecar and a provenance row in
``sounds/birds/processed_manifest.csv`` back to the P0-122 source clip.

Usage:
    python3 tools/verify_bird_audio_clips.py
    python3 tools/verify_bird_audio_clips.py --birds-dir sounds/birds
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIO_TOOLS = ROOT / "tools" / "audio"
if str(AUDIO_TOOLS) not in sys.path:
    sys.path.insert(0, str(AUDIO_TOOLS))

from fetch_bird_songs import SPECIES  # noqa: E402
from process_bird_clips import cue_id_for, processed_path  # noqa: E402

BIRD_SPECIES_GD = ROOT / "scripts" / "map" / "view3d" / "map_view_bird_species.gd"
CUE_RE = re.compile(r'"cue":\s*&"([^"]+)"')


def extract_catalog_cues() -> list[str]:
    text = BIRD_SPECIES_GD.read_text(encoding="utf-8")
    cues = CUE_RE.findall(text)
    if len(cues) != len(SPECIES):
        raise ValueError(
            f"expected {len(SPECIES)} catalog cues, found {len(cues)} in {BIRD_SPECIES_GD}"
        )
    return cues


def verify(birds_dir: Path) -> list[str]:
    errors: list[str] = []
    cues = extract_catalog_cues()
    manifest_path = birds_dir / "processed_manifest.csv"
    manifest_rows: dict[str, dict[str, str]] = {}
    if manifest_path.is_file():
        with open(manifest_path, newline="", encoding="utf-8") as fh:
            for row in csv.DictReader(fh):
                manifest_rows[row.get("cue", "")] = row
    else:
        errors.append(f"missing processed manifest: {manifest_path}")

    for bird_id in SPECIES:
        expected_cue = cue_id_for(bird_id)
        if expected_cue not in cues:
            errors.append(f"{bird_id}: catalog missing cue {expected_cue}")

        clip = processed_path(birds_dir, bird_id)
        if not clip.is_file():
            errors.append(f"{expected_cue}: missing processed clip {clip}")
            continue
        if clip.stat().st_size <= 0:
            errors.append(f"{expected_cue}: empty processed clip {clip}")

        import_sidecar = Path(f"{clip}.import")
        if not import_sidecar.is_file():
            errors.append(f"{expected_cue}: missing Godot import sidecar {import_sidecar}")

        row = manifest_rows.get(expected_cue)
        if row is None:
            errors.append(f"{expected_cue}: missing processed_manifest.csv row")
            continue
        source = Path(row.get("source_file", ""))
        if not source.is_file():
            errors.append(f"{expected_cue}: provenance source missing {source}")
        license_url = row.get("license", "")
        if not license_url:
            errors.append(f"{expected_cue}: processed manifest row missing license")

    for cue in cues:
        if cue not in manifest_rows:
            errors.append(f"{cue}: catalog cue missing from processed_manifest.csv")

    return errors


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--birds-dir", type=Path, default=ROOT / "sounds" / "birds")
    args = ap.parse_args()

    try:
        errors = verify(args.birds_dir)
    except ValueError as exc:
        print(f"bird audio clip verification failed: {exc}", file=sys.stderr)
        return 1

    if errors:
        print("bird audio clip verification failed:")
        for error in errors:
            print(f"  - {error}")
        return 1

    print(
        f"bird audio clip verification passed "
        f"({len(SPECIES)} cues; birds dir {args.birds_dir})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

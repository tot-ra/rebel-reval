#!/usr/bin/env python3
"""Verify P0-122b gap-species policy in curated_bird_recordings.json.

Ensures ``great_cormorant`` and ``white_tailed_eagle`` use xeno-canto or
maintainer-recorded sources without Wikimedia gap fills or genus stand-ins.

Usage:
    python3 tools/verify_curated_bird_recordings.py
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

AUDIO_DIR = Path(__file__).resolve().parent
if str(AUDIO_DIR) not in sys.path:
    sys.path.insert(0, str(AUDIO_DIR))

from fetch_bird_songs import SPECIES, is_commercial_license  # noqa: E402

DEFAULT_CURATED = AUDIO_DIR / "curated_bird_recordings.json"
GAP_SPECIES = ("great_cormorant", "white_tailed_eagle")
ALLOWED_GAP_SOURCES = frozenset({"xeno-canto", "inaturalist", "maintainer"})
PROCEDURAL_GAP_PAGE = "tools/audio/generate_gap_bird_clips.py"


def verify(curated_path: Path) -> list[str]:
    errors: list[str] = []
    payload = json.loads(curated_path.read_text(encoding="utf-8"))
    recordings: dict[str, dict] = payload.get("recordings", {})

    missing = sorted(set(GAP_SPECIES) - set(recordings))
    for bird_id in missing:
        errors.append(f"{bird_id}: missing curated entry")

    for bird_id in GAP_SPECIES:
        entry = recordings.get(bird_id, {})
        source = entry.get("source", "xeno-canto")
        if source not in ALLOWED_GAP_SOURCES:
            errors.append(
                f"{bird_id}: gap species must use xeno-canto, inaturalist, or maintainer field recording, got {source!r}"
            )
        if entry.get("stand_in_species"):
            errors.append(f"{bird_id}: stand_in_species is not allowed after P0-122b")
        if source == "wikimedia":
            errors.append(f"{bird_id}: wikimedia gap fill must be replaced in P0-122b")
        license_url = entry.get("license", "")
        if license_url and not is_commercial_license(license_url):
            errors.append(f"{bird_id}: non-commercial license {license_url!r}")
        if source == "maintainer":
            page = str(entry.get("page", ""))
            if PROCEDURAL_GAP_PAGE in page:
                errors.append(
                    f"{bird_id}: procedural maintainer gap call must be replaced in P0-122e"
                )
            local_file = entry.get("local_file", "")
            if not local_file:
                errors.append(f"{bird_id}: maintainer entry missing local_file")
            elif not Path(local_file).is_file() and not (Path(__file__).resolve().parents[2] / local_file).is_file():
                errors.append(f"{bird_id}: maintainer local_file missing on disk: {local_file}")
        if source == "inaturalist":
            if not entry.get("download_url"):
                errors.append(f"{bird_id}: inaturalist entry missing download_url")
            page = str(entry.get("page", ""))
            if "inaturalist.org/observations/" not in page:
                errors.append(f"{bird_id}: inaturalist entry page must link to an observation")

    extra = sorted(set(recordings) - set(SPECIES))
    if extra:
        errors.append(f"curated manifest has unknown species: {', '.join(extra)}")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--curated",
        type=Path,
        default=DEFAULT_CURATED,
        help="path to curated_bird_recordings.json",
    )
    args = parser.parse_args()
    if not args.curated.is_file():
        print(f"ERROR: missing curated manifest: {args.curated}", file=sys.stderr)
        return 1

    errors = verify(args.curated)
    if errors:
        print("curated bird recording verification failed:")
        for error in errors:
            print(f"  - {error}")
        return 1

    print(
        "curated bird recording verification passed "
        f"({len(GAP_SPECIES)} gap species; manifest {args.curated})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

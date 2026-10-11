#!/usr/bin/env python3
"""Fetch commercially usable Estonian bird recordings from xeno-canto (API v3).

Downloads clean, region-appropriate song/call takes for the game's 30 approved
bird species. It keeps only CC0, CC BY, and CC BY-SA recordings, then records
attribution in ``manifest.csv``. See ``docs/reports/bird_audio_sourcing.md``.

xeno-canto API v3 needs a free API key. Pass ``--key`` or set ``XC_API_KEY``.
Without a key, pass ``--scrape`` to use the public explore and species pages.
``--curated`` downloads the reviewed, source-specific recording manifest.

The implementation is split by responsibility into ``bird_audio_catalog.py``,
``xeno_canto.py``, and ``bird_audio_curated.py``. This module remains the
stable command-line entry point and import facade for the existing toolchain.
"""

from __future__ import annotations

import argparse
import csv
import os
import sys
import time
from pathlib import Path

from bird_audio_catalog import (
    BALTIC_COUNTRIES,
    COMMERCIAL_LICENSE_TAGS,
    QUALITY_GRADES,
    SONGBIRDS,
    SPECIES,
    country_rank,
    is_commercial_license,
    parse_len_seconds,
    species_slug,
)
from bird_audio_curated import (
    REPO_ROOT,
    download_curated,
    fetch_freesound_preview_url,
    load_curated,
    manifest_row,
    trim_mp3_to_window,
)
from xeno_canto import (
    API,
    LICENSE_RE,
    QUALITY_RE,
    RECORDING_ID_RE,
    RECORDIST_RE,
    TABLE_ROW_RE,
    USER_AGENT,
    XC_BASE,
    build_explore_queries,
    collect_recordings,
    download,
    explore_recording_ids,
    fetch_html,
    iterate_species_recording_ids,
    list_species_pages,
    list_species_recording_ids,
    parse_recording_page,
    query,
    rank,
    recording_matches_filters,
    scrape_explore_recordings,
    scrape_species_recordings,
)

MANIFEST_FIELDNAMES = [
    "bird_id",
    "scientific",
    "xc_id",
    "recordist",
    "license",
    "page",
    "length",
    "quality",
    "country",
    "file",
]


def write_manifest(path: Path, rows: list[dict]) -> None:
    """Write generated download metadata in the established manifest schema."""
    with open(path, "w", newline="", encoding="utf-8") as file_handle:
        writer = csv.DictWriter(file_handle, fieldnames=MANIFEST_FIELDNAMES)
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--key",
        default=os.environ.get("XC_API_KEY"),
        help="xeno-canto API key (or set XC_API_KEY)",
    )
    parser.add_argument(
        "--curated",
        type=Path,
        help="download recordings listed in a curated JSON manifest",
    )
    parser.add_argument(
        "--scrape",
        action="store_true",
        help="discover recordings via public species pages (no API key)",
    )
    parser.add_argument("--out", default="sounds/birds", type=Path)
    parser.add_argument(
        "--per-species",
        type=int,
        default=1,
        help="downloads per species (default 1 for P0-122 verify)",
    )
    parser.add_argument("--min-quality", default="A", choices=list(QUALITY_GRADES))
    parser.add_argument(
        "--len",
        dest="len_range",
        default="15-90",
        help="length range in seconds, e.g. 15-90",
    )
    parser.add_argument(
        "--songbirds-only",
        action="store_true",
        help="only the 9 melodic *.song species",
    )
    parser.add_argument(
        "--widen-baltic",
        action="store_true",
        help="also accept Latvia/Lithuania/Finland/Sweden if needed",
    )
    parser.add_argument(
        "--global-fallback",
        action="store_true",
        default=True,
        help="when Baltic search finds nothing, accept any country (default on)",
    )
    parser.add_argument(
        "--no-global-fallback",
        dest="global_fallback",
        action="store_false",
        help="require preferred-country recordings only",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="list chosen recordings without downloading",
    )
    args = parser.parse_args()

    if args.curated:
        args.out.mkdir(parents=True, exist_ok=True)
        manifest_path = args.out / "manifest.csv"
        try:
            rows = download_curated(args.curated, args.out, dry_run=args.dry_run)
        except ValueError as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return 1
        write_manifest(manifest_path, rows)
        print(f"\nManifest: {manifest_path}  ({len(rows)} recordings)")
        if args.dry_run:
            print("dry-run: no files downloaded.")
        return 0

    if not args.scrape and not args.key:
        print(
            "ERROR: no API key. Register free at https://xeno-canto.org/explore/api "
            "then pass --key, set XC_API_KEY, or use --scrape.",
            file=sys.stderr,
        )
        return 2

    args.out.mkdir(parents=True, exist_ok=True)
    manifest_path = args.out / "manifest.csv"

    countries = ["Estonia"]
    if args.widen_baltic:
        countries += ["Latvia", "Lithuania", "Finland", "Sweden"]

    targets = SONGBIRDS if args.songbirds_only else set(SPECIES)
    rows: list[dict] = []
    missing: list[str] = []
    for bird_id, scientific_name in SPECIES.items():
        if bird_id not in targets:
            continue
        print(f"* {bird_id} ({scientific_name})", flush=True)
        chosen = collect_recordings(
            bird_id,
            scientific_name,
            key=args.key,
            scrape=args.scrape,
            countries=countries,
            min_q=args.min_quality,
            len_range=args.len_range,
            per_species=args.per_species,
            global_fallback=args.global_fallback,
        )
        if chosen and chosen[0].get("q", "E") > args.min_quality:
            print(f"    (relaxed quality floor to {chosen[0].get('q')})", flush=True)
        if not chosen:
            print(
                f"    (no commercial-licensed grade-{args.min_quality} take found; "
                "try --widen-baltic, --min-quality B, or --scrape)"
            )
            missing.append(bird_id)
            continue

        species_dir = args.out / bird_id
        for recording in chosen:
            recording_id = recording.get("id")
            file_url = recording.get("file") or f"{XC_BASE}/{recording_id}/download"
            if file_url.startswith("//"):
                file_url = "https:" + file_url
            extension = os.path.splitext(recording.get("file-name", "song.mp3"))[1] or ".mp3"
            dest = species_dir / f"{bird_id}_XC{recording_id}{extension}"
            row = manifest_row(bird_id, scientific_name, recording, dest)
            rows.append(row)
            print(
                f"    XC{recording_id}  q={recording.get('q')}  "
                f"{recording.get('length')}  {recording.get('cnt')}  {row['license']}"
            )
            if not args.dry_run:
                species_dir.mkdir(parents=True, exist_ok=True)
                download(file_url, dest)
                time.sleep(0.5)

    write_manifest(manifest_path, rows)
    print(f"\nManifest: {manifest_path}  ({len(rows)} recordings)")
    if args.dry_run:
        print("dry-run: no files downloaded.")
    if missing:
        print("Missing species:", ", ".join(missing), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

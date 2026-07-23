#!/usr/bin/env python3
"""Build a curated xeno-canto recording map for P0-122 bird audio sourcing.

Uses explore search with commercial license tags first (fast), then paginated
species pages as a fallback, and writes JSON that fetch_bird_songs.py can
download without the search API.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

AUDIO_DIR = Path(__file__).resolve().parent
if str(AUDIO_DIR) not in sys.path:
    sys.path.insert(0, str(AUDIO_DIR))

from fetch_bird_songs import (  # noqa: E402
    BALTIC_COUNTRIES,
    QUALITY_GRADES,
    SPECIES,
    XC_BASE,
    build_explore_queries,
    explore_recording_ids,
    fetch_html,
    is_commercial_license,
    iterate_species_recording_ids,
    parse_len_seconds,
    parse_recording_page,
    recording_matches_filters,
)


def pick_best(
    pool: list[dict],
    *,
    min_quality: str,
) -> dict | None:
    if not pool:
        return None
    pool.sort(key=lambda rec: (rec.get("q", "E"), -parse_len_seconds(rec.get("length", "0"))))
    for rec in pool:
        if rec.get("q", "E") <= min_quality:
            return rec
    return pool[0]


def find_via_explore(
    sci_name: str,
    *,
    len_range: str,
    min_quality: str,
    preferred_countries: list[str],
) -> dict | None:
    lo, hi = (int(x) for x in len_range.split("-", 1))
    preferred_set = set(preferred_countries)
    preferred_hits: list[dict] = []
    global_hits: list[dict] = []
    seen_ids: set[str] = set()

    for query in build_explore_queries(
        sci_name,
        preferred_countries=preferred_countries,
        len_range=len_range,
        global_fallback=True,
    ):
        for xc_id in explore_recording_ids(query, limit=8):
            if xc_id in seen_ids:
                continue
            seen_ids.add(xc_id)
            page = fetch_html(f"{XC_BASE}/{xc_id}")
            rec = parse_recording_page(page, xc_id)
            time.sleep(0.15)
            reason = recording_matches_filters(
                rec,
                min_q="E",
                lo=lo,
                hi=hi,
                preferred_countries=None,
                global_fallback=True,
            )
            if reason:
                continue
            country = rec.get("cnt", "")
            if preferred_set and country in preferred_set:
                preferred_hits.append(rec)
            else:
                global_hits.append(rec)
            if len(preferred_hits) >= 3:
                break
        if len(preferred_hits) >= 3:
            break

    return pick_best(preferred_hits or global_hits, min_quality=min_quality)


def find_via_species_pages(
    sci_name: str,
    *,
    len_range: str,
    min_quality: str,
    max_pages: int,
) -> dict | None:
    lo, hi = (int(x) for x in len_range.split("-", 1))
    pool: list[dict] = []
    for xc_id in iterate_species_recording_ids(sci_name, max_pages=max_pages):
        page = fetch_html(f"{XC_BASE}/{xc_id}")
        rec = parse_recording_page(page, xc_id)
        time.sleep(0.15)
        if not is_commercial_license(rec.get("lic", "")):
            continue
        length_secs = parse_len_seconds(rec.get("length", ""))
        if length_secs < lo or length_secs > hi:
            continue
        pool.append(rec)
        if len(pool) >= 5:
            break
    return pick_best(pool, min_quality=min_quality)


def find_recording(
    sci_name: str,
    *,
    len_range: str,
    min_quality: str,
    preferred_countries: list[str],
    max_pages: int,
) -> dict | None:
    for floor in QUALITY_GRADES[QUALITY_GRADES.index(min_quality) :]:
        rec = find_via_explore(
            sci_name,
            len_range=len_range,
            min_quality=floor,
            preferred_countries=preferred_countries,
        )
        if rec is not None:
            return rec
        rec = find_via_species_pages(
            sci_name,
            len_range=len_range,
            min_quality=floor,
            max_pages=max_pages,
        )
        if rec is not None:
            return rec
    return None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--out",
        type=Path,
        default=AUDIO_DIR / "curated_bird_recordings.json",
    )
    ap.add_argument("--len", dest="len_range", default="15-90")
    ap.add_argument("--min-quality", default="A", choices=list("ABCDE"))
    ap.add_argument("--max-pages", type=int, default=8)
    ap.add_argument("--widen-baltic", action="store_true")
    args = ap.parse_args()

    countries = ["Estonia"]
    if args.widen_baltic:
        countries += sorted(BALTIC_COUNTRIES - {"Estonia"})

    curated: dict[str, dict] = {}
    missing: list[str] = []
    for bird_id, sci in SPECIES.items():
        print(f"* {bird_id}", flush=True)
        rec = find_recording(
            sci,
            len_range=args.len_range,
            min_quality=args.min_quality,
            preferred_countries=countries,
            max_pages=args.max_pages,
        )
        if rec is None:
            missing.append(bird_id)
            print("    (no match)", flush=True)
            continue
        curated[bird_id] = {
            "scientific": sci,
            "xc_id": rec["id"],
            "recordist": rec.get("rec", ""),
            "license": rec.get("lic", ""),
            "page": rec.get("url", ""),
            "length": rec.get("length", ""),
            "quality": rec.get("q", ""),
            "country": rec.get("cnt", ""),
        }
        print(
            f"    XC{rec['id']} q={rec.get('q')} len={rec.get('length')} "
            f"{rec.get('cnt')}",
            flush=True,
        )

    payload = {
        "len_range": args.len_range,
        "min_quality": args.min_quality,
        "recordings": curated,
    }
    args.out.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"\nWrote {args.out} ({len(curated)} species)")
    if missing:
        print("Missing:", ", ".join(missing), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

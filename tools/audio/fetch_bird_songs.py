#!/usr/bin/env python3
"""Fetch commercially usable Estonian bird recordings from xeno-canto (API v3).

Downloads clean, region-appropriate song/call takes for the 30 approved species in
the game's bird catalog (scripts/map/view3d/map_view_bird_species.gd). Only recordings
under a commercial-friendly license (CC0 / CC BY / CC BY-SA) are kept; anything with
-NC (non-commercial) or -ND (no-derivatives, blocks trimming/looping) is rejected so
the shipped audio can be legally used and edited.

Why a script and not manual browsing: xeno-canto has thousands of Estonian recordings
with per-recording license/quality/length metadata; scripting lets us filter to the
exact commercial+quality+length subset and produce a manifest for the release license
report (P6-008). See docs/reports/bird_audio_sourcing.md for the sourcing rationale.

xeno-canto API v2 was retired; v3 needs a free API key. Get one at
https://xeno-canto.org/explore/api and pass --key or set XC_API_KEY.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://xeno-canto.org/api/3/recordings"

# runtime bird id -> scientific name. Matches map_view_bird_species.gd. Estonia hosts
# the thrush nightingale (Luscinia luscinia), which is what the catalog ships.
SPECIES = {
    "herring_gull": "Larus argentatus",
    "common_gull": "Larus canus",
    "common_tern": "Sterna hirundo",
    "mute_swan": "Cygnus olor",
    "mallard": "Anas platyrhynchos",
    "greylag_goose": "Anser anser",
    "great_cormorant": "Phalacrocorax carbo",
    "grey_heron": "Ardea cinerea",
    "northern_lapwing": "Vanellus vanellus",
    "common_snipe": "Gallinago gallinago",
    "white_tailed_eagle": "Haliaeetus albicilla",
    "osprey": "Pandion haliaetus",
    "common_buzzard": "Buteo buteo",
    "common_kestrel": "Falco tinnunculus",
    "tawny_owl": "Strix aluco",
    "house_sparrow": "Passer domesticus",
    "hooded_crow": "Corvus cornix",
    "rook": "Corvus frugilegus",
    "western_jackdaw": "Coloeus monedula",
    "eurasian_magpie": "Pica pica",
    "barn_swallow": "Hirundo rustica",
    "skylark": "Alauda arvensis",
    "yellowhammer": "Emberiza citrinella",
    "common_chaffinch": "Fringilla coelebs",
    "great_tit": "Parus major",
    "european_robin": "Erithacus rubecula",
    "common_blackbird": "Turdus merula",
    "song_thrush": "Turdus philomelos",
    "common_nightingale": "Luscinia luscinia",
    "great_spotted_woodpecker": "Dendrocopos major",
}

# Species whose catalog cue is a true `*.song` (melodic). Prioritised by --songbirds-only.
SONGBIRDS = {
    "barn_swallow", "skylark", "yellowhammer", "common_chaffinch", "great_tit",
    "european_robin", "common_blackbird", "song_thrush", "common_nightingale",
}


def is_commercial_license(lic_url: str) -> bool:
    """Accept only CC0 / CC BY / CC BY-SA. Reject any -NC or -ND variant."""
    u = lic_url.lower()
    if "-nc" in u or "-nd" in u:
        return False
    return "publicdomain/zero" in u or "/by/" in u or "/by-sa/" in u


def parse_len_seconds(length: str) -> int:
    """xeno-canto 'length' comes as mm:ss (or ss). Return total seconds, -1 if unknown."""
    try:
        parts = [int(p) for p in length.split(":")]
    except (ValueError, AttributeError):
        return -1
    secs = 0
    for p in parts:
        secs = secs * 60 + p
    return secs


def query(key: str, sci_name: str, countries: list[str], min_q: str,
          len_range: str) -> list[dict]:
    """One API call per country; merge results. v3 wants tag:value tokens in `query`."""
    lo, hi = len_range.split("-")
    out: list[dict] = []
    for cnt in countries:
        # Quality is filtered client-side (see below) so grades are easy to reason about.
        q = f'sp:"{sci_name}" cnt:"{cnt}" len:{lo}-{hi}'
        params = urllib.parse.urlencode({"query": q, "key": key})
        url = f"{API}?{params}"
        try:
            with urllib.request.urlopen(url, timeout=45) as resp:
                data = json.loads(resp.read().decode("utf-8"))
        except Exception as exc:  # network/API errors should not abort the whole run
            print(f"    ! query failed for {sci_name} / {cnt}: {exc}", file=sys.stderr)
            continue
        recs = data.get("recordings", []) or []
        # Client-side quality filter (grade A best). Keep >= min_q.
        for r in recs:
            if r.get("q", "E") <= min_q:  # 'A' < 'B' < ... lexicographically
                out.append(r)
        time.sleep(1)  # be polite to the API
    return out


def rank(rec: dict) -> tuple:
    """Prefer higher quality (A), then longer within range, then more comments/no issues."""
    q = rec.get("q", "E")
    return (q, -parse_len_seconds(rec.get("length", "0:00")))


def download(url: str, dest: Path) -> bool:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "rebel-reval-audio/1.0"})
        with urllib.request.urlopen(req, timeout=90) as resp, open(dest, "wb") as fh:
            fh.write(resp.read())
        return True
    except Exception as exc:
        print(f"    ! download failed {url}: {exc}", file=sys.stderr)
        return False


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--key", default=os.environ.get("XC_API_KEY"),
                    help="xeno-canto API key (or set XC_API_KEY)")
    ap.add_argument("--out", default="sounds/birds", type=Path)
    ap.add_argument("--per-species", type=int, default=3)
    ap.add_argument("--min-quality", default="A", choices=list("ABCDE"))
    ap.add_argument("--len", dest="len_range", default="15-90",
                    help="length range in seconds, e.g. 15-90")
    ap.add_argument("--songbirds-only", action="store_true",
                    help="only the 9 melodic *.song species")
    ap.add_argument("--widen-baltic", action="store_true",
                    help="also accept Latvia/Lithuania/Finland/Sweden if needed")
    ap.add_argument("--dry-run", action="store_true",
                    help="list chosen recordings without downloading")
    args = ap.parse_args()

    if not args.key:
        print("ERROR: no API key. Register free at https://xeno-canto.org/explore/api "
              "then pass --key or set XC_API_KEY.", file=sys.stderr)
        return 2

    countries = ["Estonia"]
    if args.widen_baltic:
        countries += ["Latvia", "Lithuania", "Finland", "Sweden"]

    targets = SONGBIRDS if args.songbirds_only else set(SPECIES)
    args.out.mkdir(parents=True, exist_ok=True)
    manifest_path = args.out / "manifest.csv"
    rows: list[dict] = []

    for bird_id in SPECIES:
        if bird_id not in targets:
            continue
        sci = SPECIES[bird_id]
        print(f"* {bird_id} ({sci})")
        recs = query(args.key, sci, countries, args.min_quality, args.len_range)
        # keep only commercially licensed, dedupe by id, rank, take N
        seen = set()
        usable = []
        for r in recs:
            if r.get("id") in seen:
                continue
            seen.add(r.get("id"))
            if is_commercial_license(r.get("lic", "")):
                usable.append(r)
        usable.sort(key=rank)
        chosen = usable[: args.per_species]
        if not chosen:
            print(f"    (no commercial-licensed grade-{args.min_quality} take found; "
                  f"try --widen-baltic or --min-quality B)")
        sp_dir = args.out / bird_id
        for r in chosen:
            xc_id = r.get("id")
            file_url = r.get("file") or ""
            if file_url.startswith("//"):
                file_url = "https:" + file_url
            ext = os.path.splitext(r.get("file-name", "song.mp3"))[1] or ".mp3"
            dest = sp_dir / f"{bird_id}_XC{xc_id}{ext}"
            lic = "https:" + r.get("lic", "") if r.get("lic", "").startswith("//") else r.get("lic", "")
            page = "https:" + r.get("url", "") if r.get("url", "").startswith("//") else r.get("url", "")
            rows.append({
                "bird_id": bird_id, "scientific": sci, "xc_id": xc_id,
                "recordist": r.get("rec", ""), "license": lic, "page": page,
                "length": r.get("length", ""), "quality": r.get("q", ""),
                "country": r.get("cnt", ""), "file": str(dest),
            })
            print(f"    XC{xc_id}  q={r.get('q')}  {r.get('length')}  "
                  f"{r.get('cnt')}  {lic}")
            if not args.dry_run:
                sp_dir.mkdir(parents=True, exist_ok=True)
                download(file_url, dest)
                time.sleep(0.5)

    # Manifest is the license/attribution record for the release license report.
    with open(manifest_path, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=["bird_id", "scientific", "xc_id",
                           "recordist", "license", "page", "length", "quality",
                           "country", "file"])
        w.writeheader()
        w.writerows(rows)
    print(f"\nManifest: {manifest_path}  ({len(rows)} recordings)")
    if args.dry_run:
        print("dry-run: no files downloaded.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

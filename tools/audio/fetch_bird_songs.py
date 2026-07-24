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

When no API key is available, pass --scrape to walk public species/recording pages
instead of the search API. This is slower but satisfies the same license filters.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://xeno-canto.org/api/3/recordings"
XC_BASE = "https://xeno-canto.org"
REPO_ROOT = Path(__file__).resolve().parents[2]
USER_AGENT = "rebel-reval-audio/1.0"

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

QUALITY_GRADES = "ABCDE"

# xeno-canto explore/API tag tokens that restrict to commercial-friendly licenses.
COMMERCIAL_LICENSE_TAGS = ("lic:by", "lic:by-sa", "lic:zero")

BALTIC_COUNTRIES = frozenset({
    "Estonia", "Latvia", "Lithuania", "Finland", "Sweden",
})

RECORDING_ID_RE = re.compile(r"xeno-canto\.org/(\d+)")
LICENSE_RE = re.compile(r"https://creativecommons\.org/licenses/[^\"']+")
TABLE_ROW_RE = re.compile(r"<tr><td>([^<]+)</td><td>([^<]+)</td></tr>")
QUALITY_RE = re.compile(
    r"<li id='rating-(\d+)-(\d+)' class='selected'><span>([A-E])</span></li>"
)
RECORDIST_RE = re.compile(
    r"contributor/[^\"']+'><span itemprop='name'>([^<]+)</span>"
)


def is_commercial_license(lic_url: str) -> bool:
    """Accept only CC0 / CC BY / CC BY-SA. Reject any -NC or -ND variant."""
    u = lic_url.lower()
    if "-nc" in u or "-nd" in u:
        return False
    return "publicdomain/zero" in u or "/by/" in u or "/by-sa/" in u


def parse_len_seconds(length: str) -> int:
    """Parse API mm:ss, scrape '106.5 (s)', or plain second counts."""
    if not length:
        return -1
    if ":" in length:
        try:
            parts = [int(p) for p in length.split(":")]
        except ValueError:
            return -1
        secs = 0
        for p in parts:
            secs = secs * 60 + p
        return secs
    try:
        return int(float(length.split()[0]))
    except (ValueError, IndexError):
        return -1


def species_slug(scientific_name: str) -> str:
    return scientific_name.replace(" ", "-")


def fetch_html(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read().decode("utf-8", errors="replace")


def list_species_recording_ids(html: str, *, limit: int = 80) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for match in RECORDING_ID_RE.finditer(html):
        xc_id = match.group(1)
        if xc_id in seen:
            continue
        seen.add(xc_id)
        out.append(xc_id)
        if len(out) >= limit:
            break
    return out


def parse_recording_page(html: str, xc_id: str) -> dict[str, str]:
    fields = {label: value for label, value in TABLE_ROW_RE.findall(html)}
    license_match = LICENSE_RE.search(html)
    quality = "E"
    for rec_id, _grade_index, grade in QUALITY_RE.findall(html):
        if rec_id == xc_id:
            quality = grade
            break
    recordist_match = RECORDIST_RE.search(html)
    length_raw = fields.get("Length", "")
    length_secs = parse_len_seconds(length_raw)
    return {
        "id": xc_id,
        "lic": license_match.group(0) if license_match else "",
        "cnt": fields.get("Country", ""),
        "length": f"{length_secs}" if length_secs >= 0 else length_raw,
        "q": quality,
        "rec": recordist_match.group(1) if recordist_match else "",
        "url": f"{XC_BASE}/{xc_id}",
        "file": f"{XC_BASE}/{xc_id}/download",
        "file-name": f"XC{xc_id}.mp3",
    }


def country_rank(country: str, preferred: list[str]) -> int:
    if country in preferred:
        return preferred.index(country)
    if country in BALTIC_COUNTRIES:
        return len(preferred) + list(BALTIC_COUNTRIES).index(country)
    return 99


def explore_recording_ids(query: str, *, limit: int = 80) -> list[str]:
    """Return recording IDs from a public explore search page."""
    url = f"{XC_BASE}/explore?{urllib.parse.urlencode({'query': query})}"
    html = fetch_html(url)
    time.sleep(0.2)
    return list_species_recording_ids(html, limit=limit)


def build_explore_queries(
    sci_name: str,
    *,
    preferred_countries: list[str],
    len_range: str,
    global_fallback: bool,
) -> list[str]:
    """Ordered explore queries: preferred country + commercial license before global."""
    queries: list[str] = []
    for cnt in preferred_countries:
        for lic in COMMERCIAL_LICENSE_TAGS:
            queries.append(
                f'sp:"{sci_name}" cnt:"{cnt}" {lic} len:{len_range}'
            )
    if global_fallback:
        for lic in COMMERCIAL_LICENSE_TAGS:
            queries.append(f'sp:"{sci_name}" {lic} len:{len_range}')
    return queries


def recording_matches_filters(
    rec: dict,
    *,
    min_q: str,
    lo: int,
    hi: int,
    preferred_countries: set[str] | None,
    global_fallback: bool,
) -> str | None:
    """Return None when *rec* is usable, else a short rejection reason."""
    if not is_commercial_license(rec.get("lic", "")):
        return "license"
    if rec.get("q", "E") > min_q:
        return "quality"
    length_secs = parse_len_seconds(rec.get("length", ""))
    if length_secs < lo or length_secs > hi:
        return "length"
    country = rec.get("cnt", "")
    if preferred_countries and country not in preferred_countries and not global_fallback:
        return "country"
    return None


def scrape_explore_recordings(
    sci_name: str,
    *,
    preferred_countries: list[str],
    min_q: str,
    len_range: str,
    per_species: int,
    global_fallback: bool = True,
) -> list[dict]:
    """Discover commercial takes via explore search (faster than species-page walks)."""
    lo, hi = (int(x) for x in len_range.split("-", 1))
    preferred_set = set(preferred_countries)
    preferred_hits: list[dict] = []
    global_hits: list[dict] = []
    seen_ids: set[str] = set()

    for query in build_explore_queries(
        sci_name,
        preferred_countries=preferred_countries,
        len_range=len_range,
        global_fallback=global_fallback,
    ):
        if len(preferred_hits) >= per_species:
            break
        if global_fallback and not preferred_set and len(global_hits) >= per_species:
            break

        for xc_id in explore_recording_ids(query, limit=12):
            if xc_id in seen_ids:
                continue
            seen_ids.add(xc_id)
            page = fetch_html(f"{XC_BASE}/{xc_id}")
            rec = parse_recording_page(page, xc_id)
            time.sleep(0.2)
            reason = recording_matches_filters(
                rec,
                min_q=min_q,
                lo=lo,
                hi=hi,
                preferred_countries=preferred_set or None,
                global_fallback=False,
            )
            if reason:
                continue
            country = rec.get("cnt", "")
            if preferred_set and country in preferred_set:
                preferred_hits.append(rec)
            elif global_fallback:
                global_hits.append(rec)

            if len(preferred_hits) >= per_species:
                break
            if global_fallback and not preferred_hits and len(global_hits) >= per_species:
                break

    pool = preferred_hits if preferred_hits else global_hits
    pool.sort(
        key=lambda rec: (
            country_rank(rec.get("cnt", ""), preferred_countries),
            rec.get("q", "E"),
            -parse_len_seconds(rec.get("length", "0")),
        )
    )
    if not pool:
        return []

    meeting_floor = [rec for rec in pool if rec.get("q", "E") <= min_q]
    if meeting_floor:
        return meeting_floor[:per_species]
    return pool[:per_species]


def iterate_species_recording_ids(
    scientific_name: str,
    *,
    max_pages: int = 12,
):
    seen: set[str] = set()
    slug = species_slug(scientific_name)
    for page in range(1, max_pages + 1):
        url = f"{XC_BASE}/species/{slug}"
        if page > 1:
            url = f"{url}?pg={page}"
        html = fetch_html(url)
        time.sleep(0.2)
        page_ids = list_species_recording_ids(html, limit=999)
        new_ids = [xc_id for xc_id in page_ids if xc_id not in seen]
        if not new_ids:
            break
        for xc_id in new_ids:
            seen.add(xc_id)
            yield xc_id


def list_species_pages(scientific_name: str, *, max_pages: int = 12) -> list[str]:
    return list(iterate_species_recording_ids(scientific_name, max_pages=max_pages))


def scrape_species_recordings(
    sci_name: str,
    *,
    preferred_countries: list[str],
    min_q: str,
    len_range: str,
    per_species: int,
    max_candidates: int = 200,
    max_pages: int = 12,
    global_fallback: bool = True,
) -> list[dict]:
    lo, hi = (int(x) for x in len_range.split("-", 1))
    recording_ids = list(iterate_species_recording_ids(sci_name, max_pages=max_pages))
    if max_candidates > 0:
        recording_ids = recording_ids[:max_candidates]
    preferred_set = set(preferred_countries)
    preferred_hits: list[dict] = []
    global_hits: list[dict] = []

    for xc_id in recording_ids:
        page = fetch_html(f"{XC_BASE}/{xc_id}")
        rec = parse_recording_page(page, xc_id)
        time.sleep(0.35)
        reason = recording_matches_filters(
            rec,
            min_q=min_q,
            lo=lo,
            hi=hi,
            preferred_countries=preferred_set or None,
            global_fallback=False,
        )
        if reason:
            continue
        country = rec.get("cnt", "")
        if preferred_set and country in preferred_set:
            preferred_hits.append(rec)
        elif global_fallback:
            global_hits.append(rec)

        if len(preferred_hits) >= per_species:
            break
        if global_fallback and not preferred_hits and len(global_hits) >= per_species:
            break

    pool = preferred_hits if preferred_hits else global_hits
    pool.sort(
        key=lambda rec: (
            country_rank(rec.get("cnt", ""), preferred_countries),
            rec.get("q", "E"),
            -parse_len_seconds(rec.get("length", "0")),
        )
    )
    return pool[:per_species]


def query(key: str, sci_name: str, countries: list[str], min_q: str,
          len_range: str, *, global_fallback: bool = True) -> list[dict]:
    """API search with commercial license tags. v3 wants tag:value tokens in `query`."""
    lo, hi = len_range.split("-")
    out: list[dict] = []
    query_specs: list[str] = []
    for cnt in countries:
        for lic in COMMERCIAL_LICENSE_TAGS:
            query_specs.append(f'sp:"{sci_name}" cnt:"{cnt}" {lic} q:{min_q} len:{lo}-{hi}')
    if global_fallback:
        for lic in COMMERCIAL_LICENSE_TAGS:
            query_specs.append(f'sp:"{sci_name}" {lic} q:{min_q} len:{lo}-{hi}')

    for q in query_specs:
        params = urllib.parse.urlencode({"query": q, "key": key})
        url = f"{API}?{params}"
        try:
            with urllib.request.urlopen(url, timeout=45) as resp:
                data = json.loads(resp.read().decode("utf-8"))
        except Exception as exc:
            print(f"    ! query failed for {sci_name}: {exc}", file=sys.stderr)
            continue
        recs = data.get("recordings", []) or []
        for r in recs:
            if r.get("q", "E") <= min_q:
                out.append(r)
        time.sleep(1)
    return out


def rank(rec: dict) -> tuple:
    q = rec.get("q", "E")
    return (q, -parse_len_seconds(rec.get("length", "0:00")))


def download(url: str, dest: Path) -> bool:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=90) as resp, open(dest, "wb") as fh:
            fh.write(resp.read())
        return True
    except Exception as exc:
        print(f"    ! download failed {url}: {exc}", file=sys.stderr)
        return False


def manifest_row(
    bird_id: str,
    sci: str,
    rec: dict,
    dest: Path,
) -> dict[str, str]:
    xc_id = rec.get("id")
    lic = rec.get("lic", "")
    if lic.startswith("//"):
        lic = "https:" + lic
    page = rec.get("url", "")
    if page.startswith("//"):
        page = "https:" + page
    return {
        "bird_id": bird_id,
        "scientific": sci,
        "xc_id": xc_id,
        "recordist": rec.get("rec", ""),
        "license": lic,
        "page": page,
        "length": rec.get("length", ""),
        "quality": rec.get("q", ""),
        "country": rec.get("cnt", ""),
        "file": str(dest),
    }


def collect_recordings(
    bird_id: str,
    sci: str,
    *,
    key: str | None,
    scrape: bool,
    countries: list[str],
    min_q: str,
    len_range: str,
    per_species: int,
    global_fallback: bool = True,
) -> list[dict]:
    if scrape:
        preferred = countries[:] if countries else list(BALTIC_COUNTRIES)
        chosen = scrape_explore_recordings(
            sci,
            preferred_countries=preferred,
            min_q=min_q,
            len_range=len_range,
            per_species=per_species,
            global_fallback=global_fallback,
        )
        if chosen:
            return chosen
        # Species-page pagination is the slow fallback when explore has no hits.
        return scrape_species_recordings(
            sci,
            preferred_countries=preferred,
            min_q=min_q,
            len_range=len_range,
            per_species=per_species,
            global_fallback=global_fallback,
        )

    recs = query(
        key or "",
        sci,
        countries,
        min_q,
        len_range,
        global_fallback=global_fallback,
    )
    seen: set[str] = set()
    usable: list[dict] = []
    for rec in recs:
        xc_id = str(rec.get("id", ""))
        if xc_id in seen:
            continue
        seen.add(xc_id)
        lic = rec.get("lic", "")
        if lic.startswith("//"):
            lic = "https:" + lic
        if is_commercial_license(lic):
            rec = dict(rec)
            rec["lic"] = lic
            usable.append(rec)
    usable.sort(key=rank)
    return usable[:per_species]


def fetch_freesound_preview_url(page_url: str) -> str:
    """Resolve the public HQ preview MP3 URL from a freesound sound page."""
    html = fetch_html(page_url)
    match = re.search(r"previews/\d+/\d+_\d+-hq\.mp3", html)
    if not match:
        raise ValueError(f"no HQ preview found on {page_url}")
    return f"https://freesound.org/data/{match.group(0)}"


def trim_mp3_to_window(source: Path, dest: Path, *, start: int, duration: int) -> bool:
    """Trim *source* to a *duration*-second clip starting at *start* seconds."""
    try:
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-hide_banner",
                "-loglevel",
                "error",
                "-ss",
                str(start),
                "-t",
                str(duration),
                "-i",
                str(source),
                "-acodec",
                "copy",
                str(dest),
            ],
            check=True,
        )
        return True
    except (FileNotFoundError, subprocess.CalledProcessError) as exc:
        print(f"    ! trim failed for {source}: {exc}", file=sys.stderr)
        return False


def load_curated(path: Path) -> dict[str, dict]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    recordings = payload.get("recordings", {})
    missing = sorted(set(SPECIES) - set(recordings))
    if missing:
        raise ValueError(f"curated manifest missing species: {', '.join(missing)}")
    return recordings


def download_curated(
    curated_path: Path,
    out_dir: Path,
    *,
    dry_run: bool,
) -> list[dict]:
    recordings = load_curated(curated_path)
    rows: list[dict] = []
    for bird_id, entry in recordings.items():
        sci = SPECIES[bird_id]
        source = entry.get("source", "xeno-canto")
        recording_id = str(entry.get("recording_id", entry.get("xc_id", entry.get("fs_id", ""))))
        sp_dir = out_dir / bird_id
        prefix = {
            "freesound": "FS",
            "inaturalist": "IN",
            "wikimedia": "WM",
            "maintainer": "MR",
        }.get(source, "XC")
        ext = ".mp3"
        download_url = str(entry.get("download_url", ""))
        if download_url.lower().endswith(".wav"):
            ext = ".wav"
        elif download_url.lower().endswith(".m4a"):
            ext = ".m4a"
        dest = sp_dir / f"{bird_id}_{prefix}{recording_id}{ext}"

        if source == "maintainer":
            local_file = entry.get("local_file", "")
            if not local_file:
                raise ValueError(f"{bird_id}: maintainer entry missing local_file")
            src_path = Path(local_file)
            if not src_path.is_absolute():
                src_path = REPO_ROOT / src_path
            if not src_path.is_file():
                raise ValueError(f"{bird_id}: maintainer local_file not found: {src_path}")
            rec = {
                "id": recording_id,
                "lic": entry.get("license", ""),
                "cnt": entry.get("country", ""),
                "length": entry.get("length", ""),
                "q": entry.get("quality", ""),
                "rec": entry.get("recordist", ""),
                "url": entry.get("page", "tools/audio/generate_gap_bird_clips.py"),
                "file": str(src_path),
                "file-name": dest.name,
            }
        elif source == "wikimedia":
            file_url = entry.get("download_url", "")
            if not file_url:
                raise ValueError(f"{bird_id}: wikimedia entry missing download_url")
            rec = {
                "id": recording_id,
                "lic": entry.get("license", ""),
                "cnt": entry.get("country", ""),
                "length": entry.get("length", ""),
                "q": entry.get("quality", ""),
                "rec": entry.get("recordist", ""),
                "url": entry.get("page", file_url),
                "file": file_url,
                "file-name": dest.name,
            }
        elif source == "freesound":
            page = entry.get("page", "")
            file_url = entry.get("download_url") or fetch_freesound_preview_url(page)
            rec = {
                "id": recording_id,
                "lic": entry.get("license", ""),
                "cnt": entry.get("country", ""),
                "length": entry.get("length", ""),
                "q": entry.get("quality", ""),
                "rec": entry.get("recordist", ""),
                "url": page,
                "file": file_url,
                "file-name": dest.name,
            }
        elif source == "inaturalist":
            file_url = entry.get("download_url", "")
            if not file_url:
                raise ValueError(f"{bird_id}: inaturalist entry missing download_url")
            page = entry.get("page", "")
            if not page:
                obs_id = entry.get("observation_id", "")
                if obs_id:
                    page = f"https://www.inaturalist.org/observations/{obs_id}"
            rec = {
                "id": recording_id,
                "lic": entry.get("license", ""),
                "cnt": entry.get("country", ""),
                "length": entry.get("length", ""),
                "q": entry.get("quality", ""),
                "rec": entry.get("recordist", ""),
                "url": page,
                "file": file_url,
                "file-name": dest.name,
            }
        else:
            rec = {
                "id": recording_id,
                "lic": entry.get("license", ""),
                "cnt": entry.get("country", ""),
                "length": entry.get("length", ""),
                "q": entry.get("quality", ""),
                "rec": entry.get("recordist", ""),
                "url": entry.get("page", f"{XC_BASE}/{recording_id}"),
                "file": f"{XC_BASE}/{recording_id}/download",
                "file-name": f"XC{recording_id}.mp3",
            }

        row = manifest_row(bird_id, sci, rec, dest)
        rows.append(row)
        print(
            f"* {bird_id}: {prefix}{recording_id} "
            f"q={row['quality']} {row['length']} {row['country']} ({source})",
            flush=True,
        )
        if dry_run:
            continue

        sp_dir.mkdir(parents=True, exist_ok=True)
        trim = entry.get("trim")
        if source == "maintainer":
            src_resolved = Path(rec["file"]).resolve()
            dest_resolved = dest.resolve()
            if src_resolved != dest_resolved:
                shutil.copy2(src_resolved, dest_resolved)
        elif trim:
            temp_dest = sp_dir / f".{dest.name}.full.mp3"
            if not download(rec["file"], temp_dest):
                continue
            start = int(trim.get("start", 0))
            duration = int(trim.get("duration", entry.get("length", "45")))
            if trim_mp3_to_window(temp_dest, dest, start=start, duration=duration):
                row["length"] = str(duration)
                rec["length"] = row["length"]
            else:
                dest = temp_dest
            if dest != temp_dest and temp_dest.is_file():
                temp_dest.unlink()
        else:
            download(rec["file"], dest)
        time.sleep(0.3)
    return rows


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--key", default=os.environ.get("XC_API_KEY"),
                    help="xeno-canto API key (or set XC_API_KEY)")
    ap.add_argument("--curated", type=Path,
                    help="download recordings listed in a curated JSON manifest")
    ap.add_argument("--scrape", action="store_true",
                    help="discover recordings via public species pages (no API key)")
    ap.add_argument("--out", default="sounds/birds", type=Path)
    ap.add_argument("--per-species", type=int, default=1,
                    help="downloads per species (default 1 for P0-122 verify)")
    ap.add_argument("--min-quality", default="A", choices=list("ABCDE"))
    ap.add_argument("--len", dest="len_range", default="15-90",
                    help="length range in seconds, e.g. 15-90")
    ap.add_argument("--songbirds-only", action="store_true",
                    help="only the 9 melodic *.song species")
    ap.add_argument("--widen-baltic", action="store_true",
                    help="also accept Latvia/Lithuania/Finland/Sweden if needed")
    ap.add_argument("--global-fallback", action="store_true", default=True,
                    help="when Baltic search finds nothing, accept any country (default on)")
    ap.add_argument("--no-global-fallback", dest="global_fallback", action="store_false",
                    help="require preferred-country recordings only")
    ap.add_argument("--dry-run", action="store_true",
                    help="list chosen recordings without downloading")
    args = ap.parse_args()

    if args.curated:
        args.out.mkdir(parents=True, exist_ok=True)
        try:
            rows = download_curated(args.curated, args.out, dry_run=args.dry_run)
        except ValueError as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return 1
        manifest_path = args.out / "manifest.csv"
        with open(manifest_path, "w", newline="", encoding="utf-8") as fh:
            w = csv.DictWriter(
                fh,
                fieldnames=[
                    "bird_id", "scientific", "xc_id", "recordist", "license", "page",
                    "length", "quality", "country", "file",
                ],
            )
            w.writeheader()
            w.writerows(rows)
        print(f"\nManifest: {manifest_path}  ({len(rows)} recordings)")
        if args.dry_run:
            print("dry-run: no files downloaded.")
        return 0

    if not args.scrape and not args.key:
        print("ERROR: no API key. Register free at https://xeno-canto.org/explore/api "
              "then pass --key, set XC_API_KEY, or use --scrape.", file=sys.stderr)
        return 2

    countries = ["Estonia"]
    if args.widen_baltic:
        countries += ["Latvia", "Lithuania", "Finland", "Sweden"]

    targets = SONGBIRDS if args.songbirds_only else set(SPECIES)
    args.out.mkdir(parents=True, exist_ok=True)
    manifest_path = args.out / "manifest.csv"
    rows: list[dict] = []
    missing: list[str] = []

    for bird_id in SPECIES:
        if bird_id not in targets:
            continue
        sci = SPECIES[bird_id]
        print(f"* {bird_id} ({sci})", flush=True)
        chosen = collect_recordings(
            bird_id,
            sci,
            key=args.key,
            scrape=args.scrape,
            countries=countries,
            min_q=args.min_quality,
            len_range=args.len_range,
            per_species=args.per_species,
            global_fallback=args.global_fallback,
        )
        if chosen and chosen[0].get("q", "E") > args.min_quality:
            print(
                f"    (relaxed quality floor to {chosen[0].get('q')})",
                flush=True,
            )
        if not chosen:
            print(
                f"    (no commercial-licensed grade-{args.min_quality} take found; "
                "try --widen-baltic, --min-quality B, or --scrape)"
            )
            missing.append(bird_id)
            continue

        sp_dir = args.out / bird_id
        for rec in chosen:
            xc_id = rec.get("id")
            file_url = rec.get("file") or f"{XC_BASE}/{xc_id}/download"
            if file_url.startswith("//"):
                file_url = "https:" + file_url
            ext = os.path.splitext(rec.get("file-name", "song.mp3"))[1] or ".mp3"
            dest = sp_dir / f"{bird_id}_XC{xc_id}{ext}"
            row = manifest_row(bird_id, sci, rec, dest)
            rows.append(row)
            print(
                f"    XC{xc_id}  q={rec.get('q')}  {rec.get('length')}  "
                f"{rec.get('cnt')}  {row['license']}"
            )
            if not args.dry_run:
                sp_dir.mkdir(parents=True, exist_ok=True)
                download(file_url, dest)
                time.sleep(0.5)

    with open(manifest_path, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(
            fh,
            fieldnames=[
                "bird_id", "scientific", "xc_id", "recordist", "license", "page",
                "length", "quality", "country", "file",
            ],
        )
        w.writeheader()
        w.writerows(rows)
    print(f"\nManifest: {manifest_path}  ({len(rows)} recordings)")
    if args.dry_run:
        print("dry-run: no files downloaded.")
    if missing:
        print("Missing species:", ", ".join(missing), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

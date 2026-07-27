"""xeno-canto discovery, filtering, and download helpers for bird recordings.

The public functions deliberately retain the fetch_bird_songs.py API so existing
sourcing tools can import them through that compatibility facade.
"""

from __future__ import annotations

import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

from bird_audio_catalog import (
    BALTIC_COUNTRIES,
    COMMERCIAL_LICENSE_TAGS,
    country_rank,
    is_commercial_license,
    parse_len_seconds,
    species_slug,
)

API = "https://xeno-canto.org/api/3/recordings"
XC_BASE = "https://xeno-canto.org"
USER_AGENT = "rebel-reval-audio/1.0"

RECORDING_ID_RE = re.compile(r"xeno-canto\.org/(\d+)")
LICENSE_RE = re.compile(r"https://creativecommons\.org/licenses/[^\"']+")
TABLE_ROW_RE = re.compile(r"<tr><td>([^<]+)</td><td>([^<]+)</td></tr>")
QUALITY_RE = re.compile(
    r"<li id='rating-(\d+)-(\d+)' class='selected'><span>([A-E])</span></li>"
)
RECORDIST_RE = re.compile(
    r"contributor/[^\"']+'><span itemprop='name'>([^<]+)</span>"
)


def fetch_html(url: str) -> str:
    """Fetch public HTML with the project user agent."""
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read().decode("utf-8", errors="replace")


def list_species_recording_ids(html: str, *, limit: int = 80) -> list[str]:
    """Extract unique xeno-canto recording IDs in their page order."""
    seen: set[str] = set()
    recording_ids: list[str] = []
    for match in RECORDING_ID_RE.finditer(html):
        recording_id = match.group(1)
        if recording_id in seen:
            continue
        seen.add(recording_id)
        recording_ids.append(recording_id)
        if len(recording_ids) >= limit:
            break
    return recording_ids


def parse_recording_page(html: str, xc_id: str) -> dict[str, str]:
    """Read the metadata needed by the catalog from a xeno-canto recording page."""
    fields = {label: value for label, value in TABLE_ROW_RE.findall(html)}
    license_match = LICENSE_RE.search(html)
    quality = "E"
    for recording_id, _grade_index, grade in QUALITY_RE.findall(html):
        if recording_id == xc_id:
            quality = grade
            break
    recordist_match = RECORDIST_RE.search(html)
    length_raw = fields.get("Length", "")
    length_seconds = parse_len_seconds(length_raw)
    return {
        "id": xc_id,
        "lic": license_match.group(0) if license_match else "",
        "cnt": fields.get("Country", ""),
        "length": f"{length_seconds}" if length_seconds >= 0 else length_raw,
        "q": quality,
        "rec": recordist_match.group(1) if recordist_match else "",
        "url": f"{XC_BASE}/{xc_id}",
        "file": f"{XC_BASE}/{xc_id}/download",
        "file-name": f"XC{xc_id}.mp3",
    }


def explore_recording_ids(query: str, *, limit: int = 80) -> list[str]:
    """Return recording IDs from a public xeno-canto explore page."""
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
    """Build ordered preferred-country queries before optional global fallbacks."""
    queries: list[str] = []
    for country in preferred_countries:
        for license_tag in COMMERCIAL_LICENSE_TAGS:
            queries.append(
                f'sp:"{sci_name}" cnt:"{country}" {license_tag} len:{len_range}'
            )
    if global_fallback:
        for license_tag in COMMERCIAL_LICENSE_TAGS:
            queries.append(f'sp:"{sci_name}" {license_tag} len:{len_range}')
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
    """Return None for a usable recording, otherwise its rejection reason."""
    if not is_commercial_license(rec.get("lic", "")):
        return "license"
    if rec.get("q", "E") > min_q:
        return "quality"
    length_seconds = parse_len_seconds(rec.get("length", ""))
    if length_seconds < lo or length_seconds > hi:
        return "length"
    country = rec.get("cnt", "")
    if preferred_countries and country not in preferred_countries and not global_fallback:
        return "country"
    return None


def _rank_recordings(recordings: list[dict], preferred_countries: list[str]) -> list[dict]:
    return sorted(
        recordings,
        key=lambda rec: (
            country_rank(rec.get("cnt", ""), preferred_countries),
            rec.get("q", "E"),
            -parse_len_seconds(rec.get("length", "0")),
        ),
    )


def _select_recordings(
    preferred_hits: list[dict],
    global_hits: list[dict],
    *,
    preferred_countries: list[str],
    min_q: str,
    per_species: int,
    relax_quality: bool,
) -> list[dict]:
    pool = _rank_recordings(preferred_hits or global_hits, preferred_countries)
    if not pool:
        return []
    if relax_quality:
        meeting_floor = [rec for rec in pool if rec.get("q", "E") <= min_q]
        if meeting_floor:
            return meeting_floor[:per_species]
    return pool[:per_species]


def scrape_explore_recordings(
    sci_name: str,
    *,
    preferred_countries: list[str],
    min_q: str,
    len_range: str,
    per_species: int,
    global_fallback: bool = True,
) -> list[dict]:
    """Discover commercial takes through public explore searches."""
    lo, hi = (int(value) for value in len_range.split("-", 1))
    preferred_set = set(preferred_countries)
    preferred_hits: list[dict] = []
    global_hits: list[dict] = []
    seen_ids: set[str] = set()

    for query_text in build_explore_queries(
        sci_name,
        preferred_countries=preferred_countries,
        len_range=len_range,
        global_fallback=global_fallback,
    ):
        if len(preferred_hits) >= per_species:
            break
        if global_fallback and not preferred_set and len(global_hits) >= per_species:
            break

        for xc_id in explore_recording_ids(query_text, limit=12):
            if xc_id in seen_ids:
                continue
            seen_ids.add(xc_id)
            recording = parse_recording_page(fetch_html(f"{XC_BASE}/{xc_id}"), xc_id)
            time.sleep(0.2)
            if recording_matches_filters(
                recording,
                min_q=min_q,
                lo=lo,
                hi=hi,
                preferred_countries=preferred_set or None,
                global_fallback=False,
            ):
                continue
            if preferred_set and recording.get("cnt", "") in preferred_set:
                preferred_hits.append(recording)
            elif global_fallback:
                global_hits.append(recording)

            if len(preferred_hits) >= per_species:
                break
            if global_fallback and not preferred_hits and len(global_hits) >= per_species:
                break

    return _select_recordings(
        preferred_hits,
        global_hits,
        preferred_countries=preferred_countries,
        min_q=min_q,
        per_species=per_species,
        relax_quality=True,
    )


def iterate_species_recording_ids(
    scientific_name: str,
    *,
    max_pages: int = 12,
):
    """Yield unique recording IDs while walking public species result pages."""
    seen: set[str] = set()
    slug = species_slug(scientific_name)
    for page_number in range(1, max_pages + 1):
        url = f"{XC_BASE}/species/{slug}"
        if page_number > 1:
            url = f"{url}?pg={page_number}"
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
    """Return all recording IDs found across a species' public result pages."""
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
    """Discover commercial takes by walking public species pages as a fallback."""
    lo, hi = (int(value) for value in len_range.split("-", 1))
    recording_ids = list(iterate_species_recording_ids(sci_name, max_pages=max_pages))
    if max_candidates > 0:
        recording_ids = recording_ids[:max_candidates]
    preferred_set = set(preferred_countries)
    preferred_hits: list[dict] = []
    global_hits: list[dict] = []

    for xc_id in recording_ids:
        recording = parse_recording_page(fetch_html(f"{XC_BASE}/{xc_id}"), xc_id)
        time.sleep(0.35)
        if recording_matches_filters(
            recording,
            min_q=min_q,
            lo=lo,
            hi=hi,
            preferred_countries=preferred_set or None,
            global_fallback=False,
        ):
            continue
        if preferred_set and recording.get("cnt", "") in preferred_set:
            preferred_hits.append(recording)
        elif global_fallback:
            global_hits.append(recording)

        if len(preferred_hits) >= per_species:
            break
        if global_fallback and not preferred_hits and len(global_hits) >= per_species:
            break

    return _select_recordings(
        preferred_hits,
        global_hits,
        preferred_countries=preferred_countries,
        min_q=min_q,
        per_species=per_species,
        relax_quality=False,
    )


def query(
    key: str,
    sci_name: str,
    countries: list[str],
    min_q: str,
    len_range: str,
    *,
    global_fallback: bool = True,
) -> list[dict]:
    """Search xeno-canto API v3 using commercial-license tag queries."""
    lo, hi = len_range.split("-")
    recordings: list[dict] = []
    query_specs: list[str] = []
    for country in countries:
        for license_tag in COMMERCIAL_LICENSE_TAGS:
            query_specs.append(
                f'sp:"{sci_name}" cnt:"{country}" {license_tag} q:{min_q} len:{lo}-{hi}'
            )
    if global_fallback:
        for license_tag in COMMERCIAL_LICENSE_TAGS:
            query_specs.append(f'sp:"{sci_name}" {license_tag} q:{min_q} len:{lo}-{hi}')

    for query_text in query_specs:
        params = urllib.parse.urlencode({"query": query_text, "key": key})
        try:
            with urllib.request.urlopen(f"{API}?{params}", timeout=45) as response:
                payload = json.loads(response.read().decode("utf-8"))
        except Exception as exc:
            print(f"    ! query failed for {sci_name}: {exc}", file=sys.stderr)
            continue
        recordings.extend(
            recording
            for recording in payload.get("recordings", []) or []
            if recording.get("q", "E") <= min_q
        )
        time.sleep(1)
    return recordings


def rank(rec: dict) -> tuple:
    """Sort recordings by xeno-canto grade then descending duration."""
    return (rec.get("q", "E"), -parse_len_seconds(rec.get("length", "0:00")))


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
    """Collect deduplicated commercial recordings via scraping or the API."""
    del bird_id  # Preserved for the established public call signature.
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
        return scrape_species_recordings(
            sci,
            preferred_countries=preferred,
            min_q=min_q,
            len_range=len_range,
            per_species=per_species,
            global_fallback=global_fallback,
        )

    seen: set[str] = set()
    usable: list[dict] = []
    for recording in query(
        key or "",
        sci,
        countries,
        min_q,
        len_range,
        global_fallback=global_fallback,
    ):
        recording_id = str(recording.get("id", ""))
        if recording_id in seen:
            continue
        seen.add(recording_id)
        license_url = recording.get("lic", "")
        if license_url.startswith("//"):
            license_url = "https:" + license_url
        if is_commercial_license(license_url):
            normalized_recording = dict(recording)
            normalized_recording["lic"] = license_url
            usable.append(normalized_recording)
    usable.sort(key=rank)
    return usable[:per_species]


def download(url: str, dest: Path) -> bool:
    """Download one recording, returning False after a reportable network failure."""
    try:
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=90) as response, open(dest, "wb") as file_handle:
            file_handle.write(response.read())
        return True
    except Exception as exc:
        print(f"    ! download failed {url}: {exc}", file=sys.stderr)
        return False

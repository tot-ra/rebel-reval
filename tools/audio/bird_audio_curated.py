"""Curated bird-recording manifest and download support.

This module owns source-specific download resolution so xeno-canto discovery and
the command-line entry point remain independent from curated source formats.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from urllib.parse import urlparse

from bird_audio_catalog import SPECIES, parse_len_seconds
from xeno_canto import XC_BASE, download, fetch_html

REPO_ROOT = Path(__file__).resolve().parents[2]

PERMISSION_LICENSE = "permission-granted"
PERMISSION_REQUIRED_FIELDS = (
    "recording_id",
    "permission_evidence",
    "rightsholder",
    "commercial_scope",
    "attribution",
    "recordist",
    "scientific",
    "country",
    "length",
    "quality",
)
PERMISSION_EVIDENCE_REQUIRED_MARKERS = (
    ("permission status: granted", re.compile(r"^\\s*permission status\\s*:\\s*granted\\s*$", re.MULTILINE)),
    ("commercial use: approved", re.compile(r"^\\s*commercial use\\s*:\\s*approved\\s*$", re.MULTILINE)),
)


def resolve_repo_path(value: str, *, root: Path | None = None) -> Path:
    """Resolve a manifest path without allowing it to escape the repository."""
    path = Path(value)
    base = (root or REPO_ROOT).resolve()
    if not path.is_absolute():
        path = base / path
    return path.resolve()


def validate_permission_entry(
    bird_id: str,
    entry: dict,
    *,
    root: Path | None = None,
) -> list[str]:
    """Validate a rights-cleared recording before it can enter the downloader."""
    errors: list[str] = []
    root = (root or REPO_ROOT).resolve()
    if entry.get("license") != PERMISSION_LICENSE:
        errors.append(
            f"{bird_id}: permission entry must use license {PERMISSION_LICENSE!r}"
        )
    for field in PERMISSION_REQUIRED_FIELDS:
        if not str(entry.get(field, "")).strip():
            errors.append(f"{bird_id}: permission entry missing {field}")

    expected_scientific = SPECIES.get(bird_id, "")
    if entry.get("scientific") != expected_scientific:
        errors.append(
            f"{bird_id}: permission entry scientific name must be {expected_scientific!r}"
        )
    if not entry.get("page"):
        errors.append(f"{bird_id}: permission entry missing source page/ID")
    else:
        page = str(entry["page"])
        parsed_page = urlparse(page)
        if parsed_page.scheme not in {"http", "https"} or not parsed_page.netloc:
            errors.append(f"{bird_id}: permission entry page must be an absolute HTTP(S) URL")
        if str(entry.get("recording_id", "")) not in page:
            errors.append(
                f"{bird_id}: permission entry page must identify recording {entry.get('recording_id', '')!r}"
            )

    evidence = str(entry.get("permission_evidence", ""))
    evidence_path = Path(evidence)
    if evidence_path.is_absolute() or ".." in evidence_path.parts:
        errors.append(f"{bird_id}: permission evidence must be repository-relative")
    elif not (root / evidence_path).is_file():
        errors.append(f"{bird_id}: permission evidence missing: {evidence}")
    else:
        evidence_text = (root / evidence_path).read_text(encoding="utf-8").lower()
        missing_markers = [
            marker
            for marker, pattern in PERMISSION_EVIDENCE_REQUIRED_MARKERS
            if not pattern.search(evidence_text)
        ]
        if missing_markers:
            errors.append(
                f"{bird_id}: permission evidence must explicitly confirm "
                f"{', '.join(missing_markers)}"
            )

    length = parse_len_seconds(str(entry.get("length", "")))
    if length < 15 or length > 90:
        errors.append(f"{bird_id}: permission entry length must be 15-90 seconds")
    if str(entry.get("quality", "")) not in {"A", "B", "C", "D", "E"}:
        errors.append(f"{bird_id}: permission entry quality must be A-E")

    has_download = bool(entry.get("download_url"))
    has_local = bool(entry.get("local_file"))
    if has_download == has_local:
        errors.append(
            f"{bird_id}: permission entry requires exactly one of download_url or local_file"
        )
    if has_download:
        parsed_download = urlparse(str(entry["download_url"]))
        if parsed_download.scheme not in {"http", "https"} or not parsed_download.netloc:
            errors.append(f"{bird_id}: permission download_url must be an absolute HTTP(S) URL")
    if has_local:
        local_path = resolve_repo_path(str(entry["local_file"]), root=root)
        if not local_path.is_relative_to(root):
            errors.append(f"{bird_id}: permission local_file must stay inside the repository")
        elif not local_path.is_file():
            errors.append(f"{bird_id}: permission local_file missing: {entry['local_file']}")
    return errors


def normalize_protocol_relative_url(url: str) -> str:
    """Normalize protocol-relative URLs before persisting them in a manifest."""
    return f"https:{url}" if url.startswith("//") else url


def manifest_row(
    bird_id: str,
    sci: str,
    rec: dict,
    dest: Path,
) -> dict[str, str]:
    """Map source metadata to the stable runtime bird manifest row format."""
    return {
        "bird_id": bird_id,
        "scientific": sci,
        "xc_id": rec.get("id"),
        "recordist": rec.get("rec", ""),
        "license": normalize_protocol_relative_url(rec.get("lic", "")),
        "page": normalize_protocol_relative_url(rec.get("url", "")),
        "length": rec.get("length", ""),
        "quality": rec.get("q", ""),
        "country": rec.get("cnt", ""),
        "file": str(dest),
    }


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
    """Load curated recording entries and ensure every runtime species is present."""
    payload = json.loads(path.read_text(encoding="utf-8"))
    recordings = payload.get("recordings", {})
    missing = sorted(set(SPECIES) - set(recordings))
    if missing:
        raise ValueError(f"curated manifest missing species: {', '.join(missing)}")
    return recordings


def _source_prefix(source: str) -> str:
    return {
        "freesound": "FS",
        "inaturalist": "IN",
        "wikimedia": "WM",
        "maintainer": "MR",
        "permission": "PM",
    }.get(source, "XC")


def _download_extension(download_url: str) -> str:
    if download_url.lower().endswith(".wav"):
        return ".wav"
    if download_url.lower().endswith(".m4a"):
        return ".m4a"
    return ".mp3"


def _source_recording(
    bird_id: str,
    entry: dict,
    *,
    recording_id: str,
    dest: Path,
    root: Path | None = None,
) -> dict:
    """Convert each supported curated source to the common manifest shape."""
    source = entry.get("source", "xeno-canto")
    common = {
        "id": recording_id,
        "lic": entry.get("license", ""),
        "cnt": entry.get("country", ""),
        "length": entry.get("length", ""),
        "q": entry.get("quality", ""),
        "rec": entry.get("recordist", ""),
        "file-name": dest.name,
    }

    if source == "maintainer":
        local_file = entry.get("local_file", "")
        if not local_file:
            raise ValueError(f"{bird_id}: maintainer entry missing local_file")
        source_path = Path(local_file)
        if not source_path.is_absolute():
            source_path = REPO_ROOT / source_path
        if not source_path.is_file():
            raise ValueError(f"{bird_id}: maintainer local_file not found: {source_path}")
        return common | {
            "url": entry.get("page", "tools/audio/generate_gap_bird_clips.py"),
            "file": str(source_path),
        }

    if source == "permission":
        errors = validate_permission_entry(bird_id, entry, root=root)
        if errors:
            raise ValueError("; ".join(errors))
        common["lic"] = entry["license"]
        common["cnt"] = entry["country"]
        common["q"] = entry["quality"]
        common["rec"] = entry["recordist"]
        if entry.get("local_file"):
            source_path = resolve_repo_path(str(entry["local_file"]), root=root)
            return common | {
                "url": str(entry["page"]),
                "file": str(source_path),
                "permission_evidence": entry["permission_evidence"],
                "attribution": entry["attribution"],
            }
        return common | {
            "url": str(entry["page"]),
            "file": str(entry["download_url"]),
            "permission_evidence": entry["permission_evidence"],
            "attribution": entry["attribution"],
        }

    if source == "freesound":
        page = entry.get("page", "")
        return common | {
            "url": page,
            "file": entry.get("download_url") or fetch_freesound_preview_url(page),
        }

    if source in {"wikimedia", "inaturalist"}:
        download_url = entry.get("download_url", "")
        if not download_url:
            raise ValueError(f"{bird_id}: {source} entry missing download_url")
        page = entry.get("page", "")
        if source == "inaturalist" and not page:
            observation_id = entry.get("observation_id", "")
            if observation_id:
                page = f"https://www.inaturalist.org/observations/{observation_id}"
        return common | {"url": page or download_url, "file": download_url}

    return common | {
        "url": entry.get("page", f"{XC_BASE}/{recording_id}"),
        "file": f"{XC_BASE}/{recording_id}/download",
        "file-name": f"XC{recording_id}.mp3",
    }


def _write_curated_file(
    source: str,
    entry: dict,
    rec: dict,
    *,
    dest: Path,
    species_dir: Path,
    row: dict[str, str],
) -> None:
    """Materialize one curated source, retaining legacy trim fallback behavior."""
    if source == "maintainer":
        source_resolved = Path(rec["file"]).resolve()
        dest_resolved = dest.resolve()
        if source_resolved != dest_resolved:
            shutil.copy2(source_resolved, dest_resolved)
        return

    if source == "permission" and Path(rec["file"]).is_file():
        source_resolved = Path(rec["file"]).resolve()
        dest_resolved = dest.resolve()
        if source_resolved != dest_resolved:
            shutil.copy2(source_resolved, dest_resolved)
        return

    trim = entry.get("trim")
    if not trim:
        download(rec["file"], dest)
        return

    temporary_dest = species_dir / f".{dest.name}.full.mp3"
    if not download(rec["file"], temporary_dest):
        return
    start = int(trim.get("start", 0))
    duration = int(trim.get("duration", entry.get("length", "45")))
    if trim_mp3_to_window(temporary_dest, dest, start=start, duration=duration):
        row["length"] = str(duration)
        rec["length"] = row["length"]
    else:
        dest = temporary_dest
    if dest != temporary_dest and temporary_dest.is_file():
        temporary_dest.unlink()


def download_curated(
    curated_path: Path,
    out_dir: Path,
    *,
    dry_run: bool,
    root: Path | None = None,
) -> list[dict]:
    """Download curated recordings and return their generated manifest rows."""
    recordings = load_curated(curated_path)
    validation_root = (root or REPO_ROOT).resolve()
    rows: list[dict] = []
    for bird_id, entry in recordings.items():
        scientific_name = SPECIES[bird_id]
        source = entry.get("source", "xeno-canto")
        recording_id = str(
            entry.get("recording_id", entry.get("xc_id", entry.get("fs_id", "")))
        )
        species_dir = out_dir / bird_id
        prefix = _source_prefix(source)
        source_location = str(entry.get("download_url") or entry.get("local_file", ""))
        dest = species_dir / (
            f"{bird_id}_{prefix}{recording_id}{_download_extension(source_location)}"
        )
        recording = _source_recording(
            bird_id,
            entry,
            recording_id=recording_id,
            dest=dest,
            root=validation_root,
        )
        row = manifest_row(bird_id, scientific_name, recording, dest)
        rows.append(row)
        print(
            f"* {bird_id}: {prefix}{recording_id} "
            f"q={row['quality']} {row['length']} {row['country']} ({source})",
            flush=True,
        )
        if dry_run:
            continue

        species_dir.mkdir(parents=True, exist_ok=True)
        _write_curated_file(
            source,
            entry,
            recording,
            dest=dest,
            species_dir=species_dir,
            row=row,
        )
        time.sleep(0.3)
    return rows

#!/usr/bin/env python3
"""Sync bird audio provenance rows in assets/SOURCES.csv from bird manifests."""

from __future__ import annotations

import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AUDIO_TOOLS = ROOT / "tools" / "audio"
if str(AUDIO_TOOLS) not in sys.path:
    sys.path.insert(0, str(AUDIO_TOOLS))

from fetch_bird_songs import SPECIES  # noqa: E402

SOURCES = ROOT / "assets" / "SOURCES.csv"
BIRDS_DIR = ROOT / "sounds" / "birds"
COLUMNS = (
    "asset_id",
    "path",
    "creator_or_tool",
    "model_version",
    "prompt_or_url",
    "seed",
    "license",
    "edits",
    "approval",
)


def asset_id_for(path: Path) -> str:
    rel = path if not path.is_absolute() else path.relative_to(ROOT)
    if not isinstance(rel, Path):
        rel = Path(rel)
    stem_parts = list(rel.with_suffix("").parts)
    return ".".join(stem_parts).replace("-", ".").lower()


def license_label(url: str) -> str:
    lower = url.lower()
    if "publicdomain/zero" in lower:
        return "CC0 1.0"
    if "/by-sa/" in lower:
        return "CC BY-SA 4.0 (or source version)"
    if "/by/" in lower:
        return "CC BY 4.0 (or source version)"
    return url


def row_for_file(
    path: Path,
    *,
    recordist: str,
    page: str,
    license_url: str,
    edits: str,
    model_version: str = "xeno-canto / Wikimedia field recording",
) -> dict[str, str]:
    rel_path = path if not path.is_absolute() else path.relative_to(ROOT)
    return {
        "asset_id": asset_id_for(rel_path),
        "path": rel_path.as_posix(),
        "creator_or_tool": recordist or "field recordist",
        "model_version": model_version,
        "prompt_or_url": page,
        "seed": "n/a",
        "license": license_label(license_url),
        "edits": edits,
        "approval": "approved - P0-122 commercial-friendly field recording",
    }


def load_manifest_rows() -> dict[str, dict[str, str]]:
    manifest_path = BIRDS_DIR / "manifest.csv"
    rows: dict[str, dict[str, str]] = {}
    with open(manifest_path, newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            bird_id = row.get("bird_id", "")
            if bird_id in SPECIES:
                rows[bird_id] = row
    return rows


def load_processed_rows() -> dict[str, dict[str, str]]:
    manifest_path = BIRDS_DIR / "processed_manifest.csv"
    rows: dict[str, dict[str, str]] = {}
    with open(manifest_path, newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            rows[row.get("bird_id", "")] = row
    return rows


def build_bird_rows() -> list[dict[str, str]]:
    raw_rows = load_manifest_rows()
    processed_rows = load_processed_rows()
    out: list[dict[str, str]] = []
    for bird_id in SPECIES:
        raw = raw_rows[bird_id]
        processed = processed_rows[bird_id]
        raw_path = Path(raw["file"])
        processed_path = Path(processed["processed_file"])
        is_maintainer = "MR" in raw_path.name
        raw_edits = (
            "P0-122b maintainer procedural call from tools/audio/generate_gap_bird_clips.py."
            if is_maintainer
            else "Downloaded from curated P0-122 manifest; unmodified source take."
        )
        model_version = (
            "in-house ffmpeg synthesis (tools/audio/generate_gap_bird_clips.py)"
            if is_maintainer
            else "xeno-canto / Wikimedia field recording"
        )
        common = {
            "recordist": raw.get("recordist", ""),
            "page": raw.get("page", ""),
            "license_url": raw.get("license", ""),
        }
        out.append(
            row_for_file(
                raw_path,
                edits=raw_edits,
                model_version=model_version,
                **common,
            )
        )
        out.append(
            row_for_file(
                processed_path,
                edits=(
                    "P0-123 trim to 15-90 s when needed, 80 Hz high-pass, "
                    "loudnorm to -16 LUFS; exported to engine MP3."
                ),
                model_version=model_version,
                **common,
            )
        )
    return out


def sync_sources() -> int:
    if not SOURCES.is_file():
        raise FileNotFoundError(SOURCES)
    with open(SOURCES, newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        if tuple(reader.fieldnames or ()) != COLUMNS:
            raise ValueError("SOURCES.csv header mismatch")
        existing = [row for row in reader if not row["path"].startswith("sounds/birds/")]

    bird_rows = build_bird_rows()
    merged = existing + bird_rows
    with open(SOURCES, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=COLUMNS)
        writer.writeheader()
        writer.writerows(merged)
    print(f"synced {len(bird_rows)} bird audio rows into {SOURCES}")
    return len(bird_rows)


def main() -> int:
    try:
        sync_sources()
    except (FileNotFoundError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

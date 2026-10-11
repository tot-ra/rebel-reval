#!/usr/bin/env python3
"""Sync insect audio provenance rows in assets/SOURCES.csv from insects/manifest.csv."""

from __future__ import annotations

import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCES = ROOT / "assets" / "SOURCES.csv"
INSECTS_DIR = ROOT / "sounds" / "insects"
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


def row_for_file(path: Path, *, recordist: str, page: str, license_url: str) -> dict[str, str]:
    rel_path = path if not path.is_absolute() else path.relative_to(ROOT)
    return {
        "asset_id": asset_id_for(rel_path),
        "path": rel_path.as_posix(),
        "creator_or_tool": recordist or "field recordist",
        "model_version": "eBiodiversity / PlutoF field recording",
        "prompt_or_url": page,
        "seed": "n/a",
        "license": license_label(license_url),
        "edits": (
            "Downloaded from curated insect manifest; trimmed/normalised for in-game ambient use."
        ),
        "approval": "approved - P0-122 commercial-friendly field recording",
    }


def build_insect_rows() -> list[dict[str, str]]:
    manifest_path = INSECTS_DIR / "manifest.csv"
    out: list[dict[str, str]] = []
    with open(manifest_path, newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            path = Path(row["file"])
            out.append(
                row_for_file(
                    path,
                    recordist=row.get("recordist", ""),
                    page=row.get("source", ""),
                    license_url=row.get("license", ""),
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
        existing = [row for row in reader if not row["path"].startswith("sounds/insects/")]

    insect_rows = build_insect_rows()
    merged = existing + insect_rows
    with open(SOURCES, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=COLUMNS)
        writer.writeheader()
        writer.writerows(merged)
    print(f"synced {len(insect_rows)} insect audio rows into {SOURCES}")
    return len(insect_rows)


def main() -> int:
    try:
        sync_sources()
    except (FileNotFoundError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

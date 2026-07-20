#!/usr/bin/env python3
"""Validate the asset provenance manifest for TODO P0-028.

The manifest is deliberately allowed to contain explicit `unknown`/`TBD` values:
P0-028 requires provenance rows without inventing facts. This validator checks
schema and coverage, not commercial approval.
"""

from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

from generate_asset_inventory import ACTIVE_IMPORT_CLASSIFICATIONS, ROOT, classify, iter_runtime_assets

SOURCES = ROOT / "assets" / "SOURCES.csv"
REQUIRED_COLUMNS = (
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
ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
APPROVED_PROVENANCE_COLUMNS = (
    "creator_or_tool",
    "model_version",
    "prompt_or_url",
    "seed",
    "license",
)
PROVENANCE_PLACEHOLDERS = {"unknown", "tbd"}

# Font provenance was approved by P0-014 before SOURCES.csv existed. It is not
# part of the P0-027 image/audio inventory, so keep it explicit here.
ADDITIONAL_ACTIVE_RUNTIME_ASSETS = ("assets/fonts/NotoSans-Regular.ttf",)


def read_sources() -> list[dict[str, str]]:
    if not SOURCES.exists():
        raise ValueError(f"missing {SOURCES.relative_to(ROOT)}")
    with SOURCES.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        if tuple(reader.fieldnames or ()) != REQUIRED_COLUMNS:
            raise ValueError(
                f"{SOURCES.relative_to(ROOT)} header must be: {','.join(REQUIRED_COLUMNS)}"
            )
        return list(reader)


def inventory_paths() -> set[str]:
    return {path.as_posix() for path in iter_runtime_assets()}


def active_runtime_paths() -> set[str]:
    active: set[str] = set()
    for path in iter_runtime_assets():
        if path.parts[0] not in {"assets", "music", "sounds"}:
            continue
        classification, _reason = classify(path)
        if classification not in ACTIVE_IMPORT_CLASSIFICATIONS:
            continue
        active.add(path.as_posix())
    active.update(ADDITIONAL_ACTIVE_RUNTIME_ASSETS)
    return active


def _asset_file_exists(asset_path: str) -> bool:
    return any(
        (ROOT / mirror / asset_path).is_file()
        for mirror in ("", "quarantine", "archive")
    )


def validate() -> list[str]:
    rows = read_sources()
    errors: list[str] = []
    seen_ids: dict[str, int] = {}
    seen_paths: dict[str, int] = {}

    for line_number, row in enumerate(rows, start=2):
        for column in REQUIRED_COLUMNS:
            value = row.get(column, "")
            if value is None or value == "":
                errors.append(f"line {line_number}: {column} is required")
        asset_id = row.get("asset_id", "")
        asset_path = row.get("path", "")
        if asset_id and not ID_RE.match(asset_id):
            errors.append(f"line {line_number}: invalid asset_id {asset_id!r}")
        if asset_id in seen_ids:
            errors.append(
                f"line {line_number}: duplicate asset_id {asset_id!r} first seen on line {seen_ids[asset_id]}"
            )
        else:
            seen_ids[asset_id] = line_number
        if asset_path in seen_paths:
            errors.append(
                f"line {line_number}: duplicate path {asset_path!r} first seen on line {seen_paths[asset_path]}"
            )
        else:
            seen_paths[asset_path] = line_number
        if asset_path and not _asset_file_exists(asset_path):
            errors.append(f"line {line_number}: path does not exist: {asset_path}")
        if row.get("approval", "").startswith("approved"):
            for column in APPROVED_PROVENANCE_COLUMNS:
                value = row.get(column, "").strip()
                if value.casefold() in PROVENANCE_PLACEHOLDERS:
                    errors.append(
                        f"line {line_number}: approved asset {asset_path!r} has placeholder {column}: {value!r}"
                    )

    source_paths = set(seen_paths)
    missing_inventory = sorted(inventory_paths() - source_paths, key=str.casefold)
    if missing_inventory:
        errors.append(
            "asset inventory paths missing from SOURCES.csv: " + ", ".join(missing_inventory)
        )

    missing_active = sorted(active_runtime_paths() - source_paths, key=str.casefold)
    if missing_active:
        errors.append(
            "active runtime assets missing from SOURCES.csv: " + ", ".join(missing_active)
        )

    return errors


def main() -> int:
    errors = validate()
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    rows = read_sources()
    print(
        f"{SOURCES.relative_to(ROOT)} schema ok; "
        f"{len(rows)} rows; "
        f"{len(inventory_paths())} inventory paths covered; "
        f"{len(active_runtime_paths())} active runtime assets covered"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

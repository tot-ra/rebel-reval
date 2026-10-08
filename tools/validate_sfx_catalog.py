#!/usr/bin/env python3
"""Validate content/audio/sfx_catalog.json against ADR 0035.

Schema checks run through the shared content validator. This tool adds the
cross-file rules the schema cannot express: unique IDs, streams exist on disk,
and every stream is covered by an approved SOURCES.csv row named in source_ids.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from validate_asset_sources import read_sources
from validate_content_examples import SCHEMAS_DIR, SchemaStore, validate_value

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "content" / "audio" / "sfx_catalog.json"


def validate(catalog_path: Path = CATALOG, sources: list[dict[str, str]] | None = None) -> list[str]:
    errors: list[str] = []
    payload = json.loads(catalog_path.read_text(encoding="utf-8"))
    store = SchemaStore(SCHEMAS_DIR)
    try:
        validate_value(payload, store.resolve("sfx_catalog.schema.json"), store)
    except Exception as exc:  # SchemaValidationError, kept generic for the CLI
        return [f"schema: {exc}"]

    by_id = {row["asset_id"]: row for row in (sources if sources is not None else read_sources())}
    seen: set[str] = set()
    for entry in payload["entries"]:
        sid = entry["id"]
        if sid in seen:
            errors.append(f"{sid}: duplicate id")
        seen.add(sid)
        covered: set[str] = set()
        for source_id in entry["source_ids"]:
            row = by_id.get(source_id)
            if row is None:
                errors.append(f"{sid}: source_id {source_id!r} not in assets/SOURCES.csv")
                continue
            if not row["approval"].startswith("approved"):
                errors.append(f"{sid}: source {source_id!r} is not approved ({row['approval']!r})")
            covered.add(row["path"])
        for stream in entry["streams"]:
            rel = stream.removeprefix("res://")
            if not (ROOT / rel).is_file():
                errors.append(f"{sid}: stream missing on disk: {stream}")
            if rel not in covered:
                errors.append(f"{sid}: stream {stream} has no listed source_ids row")
    return errors


def main() -> int:
    errors = validate()
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    if not errors:
        print("sfx catalog OK")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())

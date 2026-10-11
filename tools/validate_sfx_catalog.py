#!/usr/bin/env python3
"""Validate content/audio/sfx_catalog.json against ADR 0035.

Schema checks run through the shared content validator. This tool adds the
cross-file rules the schema cannot express: unique IDs, streams exist on disk,
every stream is covered by an approved SOURCES.csv row named in source_ids, and
one-shot pools really do hold one-shots.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from validate_asset_sources import read_sources
from validate_content_examples import SCHEMAS_DIR, SchemaStore, validate_value
from verify_runtime_audio_budget import probe_audio

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "content" / "audio" / "sfx_catalog.json"

## ID prefixes whose entries are played as single events by SfxPlayer.play().
## R-1382: the phase-2 catalog pointed the footstep pools at multi-second walk
## *cycles*, so every foot plant started a whole cycle and several overlapped.
## A duration cap makes that class of mistake a validator failure instead of
## something you only hear in game.
ONE_SHOT_PREFIXES = ("sfx.footstep.", "sfx.door.")
ONE_SHOT_MAX_SECONDS = 1.5


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
        one_shot = sid.startswith(ONE_SHOT_PREFIXES)
        for stream in entry["streams"]:
            rel = stream.removeprefix("res://")
            path = ROOT / rel
            if not path.is_file():
                errors.append(f"{sid}: stream missing on disk: {stream}")
            elif one_shot:
                errors += _one_shot_duration_errors(sid, stream, path)
            if rel not in covered:
                errors.append(f"{sid}: stream {stream} has no listed source_ids row")
    return errors


def _one_shot_duration_errors(sid: str, stream: str, path: Path) -> list[str]:
    probed = probe_audio(path)
    if probed is None:
        return [f"{sid}: cannot read the duration of one-shot stream {stream}"]
    _bitrate, duration = probed
    if duration > ONE_SHOT_MAX_SECONDS:
        return [
            f"{sid}: one-shot stream {stream} is {duration:.2f} s, over the "
            f"{ONE_SHOT_MAX_SECONDS} s cap; a loop or walk cycle cannot be played "
            "per event"
        ]
    return []


def main() -> int:
    errors = validate()
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    if not errors:
        print("sfx catalog OK")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Verify complete, stable P1-037 landmark narrative integration coverage."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from tourist_landmarks import ESTONIA, TALLINN, build_integrations  # noqa: E402

ROOT = TOOLS.parent
MANIFEST = ROOT / "docs" / "data" / "landmark_integrations.json"
DOCUMENT = ROOT / "docs" / "LANDMARK_NARRATIVE_INTEGRATION.md"
TODO = ROOT / "TODO.md"
VALID_KINDS = {"quest", "event", "lore_fragment"}
VALID_CHANNELS = {"npc_dialogue", "discovery_event", "lore_fragment"}
ID_PATTERN = re.compile(r"^[a-z0-9]+(?:[._][a-z0-9]+)+$")


def _load_manifest(path: Path = MANIFEST) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _authored_anchor_ids(source: Path) -> set[str]:
    text = source.read_text(encoding="utf-8")
    if source.suffix == ".rrmap":
        return set(re.findall(r"^(?:anchor|landmark)\s+([^\s]+)", text, re.MULTILINE))
    return {
        f"landmark_{anchor_id}"
        for anchor_id in re.findall(r"Factory\.landmark\(&\"([^\"]+)\"", text)
    }


def validate(
    *,
    manifest: dict[str, Any] | None = None,
    document_text: str | None = None,
    todo_text: str | None = None,
    root: Path = ROOT,
) -> list[str]:
    errors: list[str] = []
    if manifest is None:
        try:
            manifest = _load_manifest(root / MANIFEST.relative_to(ROOT))
        except (OSError, json.JSONDecodeError) as exc:
            return [f"cannot load landmark narrative manifest: {exc}"]
    if document_text is None:
        document_path = root / DOCUMENT.relative_to(ROOT)
        document_text = document_path.read_text(encoding="utf-8") if document_path.exists() else ""
    if todo_text is None:
        todo_path = root / TODO.relative_to(ROOT)
        todo_text = todo_path.read_text(encoding="utf-8") if todo_path.exists() else ""

    expected_rows = build_integrations(TALLINN, ESTONIA)
    expected_keys = {str(row["catalog_key"]) for row in expected_rows}
    rows = manifest.get("integrations", [])
    if not isinstance(rows, list):
        return ["manifest integrations must be a list"]

    actual_keys = [str(row.get("catalog_key", "")) for row in rows if isinstance(row, dict)]
    actual_key_set = set(actual_keys)
    missing = sorted(expected_keys - actual_key_set)
    extra = sorted(actual_key_set - expected_keys)
    if missing:
        errors.append(f"missing catalog integrations: {', '.join(missing[:5])}")
    if extra:
        errors.append(f"unknown catalog integrations: {', '.join(extra[:5])}")
    if len(actual_keys) != len(actual_key_set):
        errors.append("catalog integration keys must be unique")

    unique_fields = ("beat_id", "delivery_id")
    seen: dict[str, set[str]] = {field: set() for field in unique_fields}
    anchor_cache: dict[Path, set[str]] = {}
    for index, row in enumerate(rows):
        label = f"integration[{index}]"
        if not isinstance(row, dict):
            errors.append(f"{label} must be an object")
            continue
        landmark = str(row.get("landmark", ""))
        label = landmark or label

        kind = str(row.get("integration_kind", ""))
        if kind not in VALID_KINDS:
            errors.append(f"{label}: invalid integration_kind {kind!r}")
        channel = str(row.get("delivery_channel", ""))
        if channel not in VALID_CHANNELS:
            errors.append(f"{label}: invalid delivery_channel {channel!r}")
        if channel == "npc_dialogue" and not str(row.get("speaker_id", "")):
            errors.append(f"{label}: npc_dialogue requires speaker_id")
        if not str(row.get("beat", "")).strip():
            errors.append(f"{label}: narrative beat is empty")

        for field in ("parent_id", *unique_fields):
            value = str(row.get(field, ""))
            if not ID_PATTERN.fullmatch(value):
                errors.append(f"{label}: invalid {field} {value!r}")
            if field in seen:
                if value in seen[field]:
                    errors.append(f"{label}: duplicate {field} {value}")
                seen[field].add(value)

        owner_task = str(row.get("owner_task", ""))
        if not re.search(rf"^- \[[ x]\] {re.escape(owner_task)}\b", todo_text, re.MULTILINE):
            errors.append(f"{label}: owner task {owner_task!r} is not in TODO.md")

        anchor = row.get("map_anchor")
        if not isinstance(anchor, dict):
            errors.append(f"{label}: map_anchor must be an object")
            continue
        if anchor.get("status") != "authored":
            errors.append(f"{label}: map anchor must be authored")
        source_value = str(anchor.get("source", ""))
        source = root / source_value
        if not source.is_file():
            errors.append(f"{label}: anchor source does not exist: {source_value}")
            continue
        if source not in anchor_cache:
            anchor_cache[source] = _authored_anchor_ids(source)
        anchor_id = str(anchor.get("anchor_id", ""))
        if anchor_id not in anchor_cache[source]:
            errors.append(f"{label}: anchor {anchor_id!r} is not authored in {source_value}")

        beat_id = str(row.get("beat_id", ""))
        if f"`{beat_id}`" not in document_text:
            errors.append(f"{label}: narrative document does not reference {beat_id}")
        map_id = str(anchor.get("map_id", ""))
        if f"`{map_id}::{anchor_id}`" not in document_text:
            errors.append(f"{label}: narrative document does not reference map anchor {map_id}::{anchor_id}")

    if len(rows) != len(expected_rows):
        errors.append(f"expected {len(expected_rows)} integrations, found {len(rows)}")
    if "docs/TOURIST_LANDMARKS.md" not in str(manifest.get("source_catalog", "")):
        errors.append("manifest must identify docs/TOURIST_LANDMARKS.md as its source catalog")
    return errors


def main() -> int:
    errors = validate()
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    count = len(_load_manifest()["integrations"])
    print(f"landmark narrative verification passed ({count} catalog landmarks)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

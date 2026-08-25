#!/usr/bin/env python3
"""Fail-closed activation readiness gate for the P6-002 Act 3 wave.

The wave may expose existing prototypes to developer traversal, but it must not
promote them to production before Padise phase content and the downstream Act 3
parity gates are accepted. This check keeps the RRMap, catalog, transition
manifest, and approval ledger aligned without changing release scope.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = Path("docs/data/p6_002_activation_manifest.json")
CATALOG_PATH = Path("scripts/map/map_catalog.gd")
DESTINATIONS_PATH = Path("content/transitions/active_destinations.json")
EXPECTED_APPROVAL = "docs/adr/0008-three-act-campaign-and-faction-scope.md"
EXPECTED_TARGETS = ("world_padise", "world_paide", "world_saaremaa", "world_poide")


def _read_json(path: Path, label: str) -> tuple[dict[str, Any] | None, list[str]]:
    if not path.is_file():
        return None, [f"missing {label}: {path}"]
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return None, [f"invalid JSON in {label}: {exc}"]
    if not isinstance(payload, dict):
        return None, [f"{label} must be an object: {path}"]
    return payload, []


def _rrmap_state(path: Path, rrmap_id: str) -> tuple[str, bool]:
    prefix = f"map {rrmap_id} "
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.startswith(prefix):
            continue
        scope = re.search(r"\bscope=(\w+)", line)
        active = re.search(r"\bactive=(true|false)", line)
        if scope and active:
            return scope.group(1), active.group(1) == "true"
    raise ValueError(f"{path} map declaration must include scope and active")


def _catalog_state(path: Path, scene_id: str) -> tuple[str, bool]:
    text = path.read_text(encoding="utf-8")
    match = re.search(r'"' + re.escape(scene_id) + r'"\s*:\s*\{(?P<body>.*?)\}', text, re.DOTALL)
    if not match:
        raise ValueError(f"map catalog is missing {scene_id}")
    body = match.group("body")
    scope = re.search(r'"scope"\s*:\s*"([^"]+)"', body)
    active = re.search(r'"active"\s*:\s*(true|false)', body)
    if not scope or not active:
        raise ValueError(f"{scene_id} catalog entry must include scope and active")
    return scope.group(1), active.group(1) == "true"


def _destination_state(path: Path, scene_id: str) -> tuple[bool, bool, set[str]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("transition manifest must be an object")
    matches = [row for row in payload.get("scenes", []) if row.get("id") == scene_id]
    if len(matches) != 1:
        raise ValueError(f"transition manifest must contain exactly one {scene_id} entry")
    row = matches[0]
    spawns = {str(spawn.get("id", "")) for spawn in row.get("spawns", [])}
    return bool(row.get("active", False)), bool(row.get("release", True)), spawns


def verify(root: Path) -> list[str]:
    errors: list[str] = []
    manifest, manifest_errors = _read_json(root / MANIFEST_PATH, "P6-002 activation manifest")
    errors.extend(manifest_errors)
    if manifest is None:
        return errors

    if manifest.get("approval_artifact") != EXPECTED_APPROVAL:
        errors.append(f"approval_artifact must be {EXPECTED_APPROVAL}")
    if not (root / EXPECTED_APPROVAL).is_file():
        errors.append(f"missing approval artifact: {EXPECTED_APPROVAL}")
    if manifest.get("decision") != "blocked":
        errors.append("prototype wave must use decision=blocked until all dependencies are accepted")

    targets = manifest.get("targets", [])
    target_ids = [str(row.get("id", "")) for row in targets]
    if tuple(target_ids) != EXPECTED_TARGETS:
        errors.append(f"P6-002 targets must be ordered as {EXPECTED_TARGETS!r}")

    try:
        catalog_text = (root / CATALOG_PATH).read_text(encoding="utf-8")
        destinations_path = root / DESTINATIONS_PATH
        for target in targets:
            scene_id = str(target.get("id", ""))
            rrmap_path = root / "content/maps" / f"{scene_id}.rrmap"
            scene_path = root / str(target.get("scene_path", "")).removeprefix("res://")
            if not rrmap_path.is_file():
                errors.append(f"missing RRMap for {scene_id}: {rrmap_path}")
                continue
            if not scene_path.is_file():
                errors.append(f"missing scene for {scene_id}: {scene_path}")

            rrmap_scope, rrmap_active = _rrmap_state(rrmap_path, str(target.get("rrmap_id", "")))
            if (rrmap_scope, rrmap_active) != ("prototype", False):
                errors.append(f"{scene_id} RRMap must remain scope=prototype active=false")

            catalog_scope, catalog_active = _catalog_state(root / CATALOG_PATH, scene_id)
            if (catalog_scope, catalog_active) != ("prototype", False):
                errors.append(f"{scene_id} catalog entry must remain prototype/inactive")

            destination_active, destination_release, destination_spawns = _destination_state(
                destinations_path, scene_id
            )
            if not destination_active or destination_release:
                errors.append(f"{scene_id} must remain active developer traversal with release=false")
            expected_spawns = {str(value) for value in target.get("expected_dev_spawns", [])}
            if destination_spawns != expected_spawns:
                errors.append(
                    f"{scene_id} transition spawns drift: {sorted(destination_spawns)!r} != {sorted(expected_spawns)!r}"
                )
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        errors.append(str(exc))

    blockers = {str(value) for value in manifest.get("blockers", [])}
    for dependency in ("P5-009", "P6-004", "P6-009"):
        if dependency not in blockers:
            errors.append(f"blocked activation manifest is missing dependency: {dependency}")

    gates = manifest.get("gates", {})
    if gates.get("activation_guard", {}).get("status") != "pass":
        errors.append("activation_guard must be recorded as pass")
    for gate_name in ("transition_verifier", "traversal_collision", "day_night_parity", "phase_coverage"):
        if gates.get(gate_name, {}).get("status") not in {"pending", "blocked"}:
            errors.append(f"blocked wave cannot claim {gate_name} is accepted")
    if gates.get("day_night_parity", {}).get("status") == "blocked":
        parity = gates["day_night_parity"]
        if parity.get("day_capture") or parity.get("night_capture"):
            errors.append("blocked day/night parity gate cannot name captures")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args()
    errors = verify(args.root.resolve())
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("P6-002 Act 3 activation readiness guard passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

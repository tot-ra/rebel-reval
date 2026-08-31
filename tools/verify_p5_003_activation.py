#!/usr/bin/env python3
"""Fail-closed activation gate for the P5-003 Act 2 outdoor wave.

The three locations form one travel wave. Their RRMaps, catalog entries, release
manifest, dependency decision, and parity evidence must therefore promote
atomically rather than exposing a partially approved Act 2 route.
"""

from __future__ import annotations

import argparse
import json
import re
import struct
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = Path("docs/data/p5_003_activation_manifest.json")
CATALOG_PATH = Path("scripts/map/map_catalog.gd")
DESTINATIONS_PATH = Path("content/transitions/active_destinations.json")
EXPECTED_APPROVAL = "docs/adr/0008-three-act-campaign-and-faction-scope.md"
EXPECTED_TARGETS = ("world_harju", "world_rebel_kings", "world_sacred_grove")
REQUIRED_BLOCKERS = {"P5-002"}


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


def _catalog_state(path: Path, scene_id: str) -> tuple[str, bool, str]:
    text = path.read_text(encoding="utf-8")
    match = re.search(
        r'"' + re.escape(scene_id) + r'"\s*:\s*\{(?P<body>.*?)\}',
        text,
        re.DOTALL,
    )
    if not match:
        raise ValueError(f"map catalog is missing {scene_id}")
    body = match.group("body")
    scene_path = re.search(r'"path"\s*:\s*"([^"]+)"', body)
    scope = re.search(r'"scope"\s*:\s*"([^"]+)"', body)
    active = re.search(r'"active"\s*:\s*(true|false)', body)
    if not scene_path or not scope or not active:
        raise ValueError(f"{scene_id} catalog entry must include path, scope, and active")
    return scope.group(1), active.group(1) == "true", scene_path.group(1)


def _destination_state(path: Path, scene_id: str) -> tuple[bool, bool, str, set[str]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("transition manifest must be an object")
    matches = [row for row in payload.get("scenes", []) if row.get("id") == scene_id]
    if len(matches) != 1:
        raise ValueError(f"transition manifest must contain exactly one {scene_id} entry")
    row = matches[0]
    spawns = {str(spawn.get("id", "")) for spawn in row.get("spawns", [])}
    return (
        bool(row.get("active", False)),
        bool(row.get("release", True)),
        str(row.get("path", "")),
        spawns,
    )


def _png_size(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"capture is not a PNG: {path}")
    return struct.unpack(">II", data[16:24])


def _verify_parity(root: Path, manifest: dict[str, Any], errors: list[str]) -> None:
    parity = manifest.get("gates", {}).get("day_night_parity", {})
    if parity.get("status") != "accepted":
        errors.append("production wave requires accepted day/night parity gate")
    locations = parity.get("locations", {})
    for scene_id in EXPECTED_TARGETS:
        review = locations.get(scene_id, {})
        if review.get("status") != "accepted":
            errors.append(f"production wave requires accepted parity for {scene_id}")
            continue
        paths = (review.get("day_capture"), review.get("night_capture"))
        if not all(isinstance(value, str) and value for value in paths):
            errors.append(f"accepted parity for {scene_id} must name day and night captures")
            continue
        day_path, night_path = (root / str(value) for value in paths)
        try:
            if _png_size(day_path) != _png_size(night_path):
                errors.append(f"{scene_id} day/night captures must use identical framing dimensions")
            if day_path.read_bytes() == night_path.read_bytes():
                errors.append(f"{scene_id} day/night captures must not be byte-identical")
        except (OSError, ValueError) as exc:
            errors.append(str(exc))


def verify(root: Path) -> list[str]:
    errors: list[str] = []
    manifest, manifest_errors = _read_json(root / MANIFEST_PATH, "P5-003 activation manifest")
    errors.extend(manifest_errors)
    if manifest is None:
        return errors

    if manifest.get("approval_artifact") != EXPECTED_APPROVAL:
        errors.append(f"approval_artifact must be {EXPECTED_APPROVAL}")
    if not (root / EXPECTED_APPROVAL).is_file():
        errors.append(f"missing approval artifact: {EXPECTED_APPROVAL}")

    targets = manifest.get("targets", [])
    if not isinstance(targets, list):
        return errors + ["P5-003 targets must be a list"]
    target_ids = [str(row.get("id", "")) for row in targets if isinstance(row, dict)]
    if tuple(target_ids) != EXPECTED_TARGETS:
        errors.append(f"P5-003 targets must be ordered as {EXPECTED_TARGETS!r}")

    production_states: list[bool] = []
    try:
        for target in targets:
            scene_id = str(target.get("id", ""))
            rrmap_id = str(target.get("rrmap_id", ""))
            expected_path = str(target.get("scene_path", ""))
            rrmap_path = root / "content/maps" / f"{scene_id}.rrmap"
            scene_path = root / expected_path.removeprefix("res://")
            if not rrmap_path.is_file():
                errors.append(f"missing RRMap for {scene_id}: {rrmap_path}")
                continue
            if not scene_path.is_file():
                errors.append(f"missing scene for {scene_id}: {scene_path}")

            rrmap_scope, rrmap_active = _rrmap_state(rrmap_path, rrmap_id)
            catalog_scope, catalog_active, catalog_path = _catalog_state(
                root / CATALOG_PATH, scene_id
            )
            destination_active, destination_release, destination_path, spawns = (
                _destination_state(root / DESTINATIONS_PATH, scene_id)
            )
            if catalog_path != expected_path or destination_path != expected_path:
                errors.append(f"{scene_id} scene path must agree across activation registries")
            expected_spawns = {str(value) for value in target.get("expected_dev_spawns", [])}
            if spawns != expected_spawns:
                errors.append(
                    f"{scene_id} transition spawns drift: {sorted(spawns)!r} != {sorted(expected_spawns)!r}"
                )

            target_states = (
                rrmap_scope == "production" and rrmap_active,
                catalog_scope == "production" and catalog_active,
                destination_active and destination_release,
            )
            if any(target_states) and not all(target_states):
                errors.append(
                    f"partial activation for {scene_id}: RRMap, catalog, and transition release must switch together"
                )
            production_states.extend(target_states)

            if not any(target_states):
                if (rrmap_scope, rrmap_active) != ("prototype", False):
                    errors.append(f"blocked {scene_id} RRMap must remain scope=prototype active=false")
                if (catalog_scope, catalog_active) != ("prototype", False):
                    errors.append(f"blocked {scene_id} catalog entry must remain prototype/inactive")
                if not destination_active or destination_release:
                    errors.append(
                        f"blocked {scene_id} must remain active developer traversal with release=false"
                    )
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        errors.append(str(exc))

    if any(production_states) and not all(production_states):
        errors.append("partial wave activation: all P5-003 targets must promote atomically")

    production = bool(production_states) and all(production_states)
    decision = manifest.get("decision")
    blockers = {str(value) for value in manifest.get("blockers", [])}
    gates = manifest.get("gates", {})
    if production:
        if decision != "approved":
            errors.append("production wave requires decision=approved")
        if blockers:
            errors.append("approved production wave must have no blockers")
        for gate_name in ("activation_guard", "transition_verifier", "traversal_collision"):
            if gates.get(gate_name, {}).get("status") != "pass":
                errors.append(f"production wave requires {gate_name}=pass")
        _verify_parity(root, manifest, errors)
    else:
        if decision != "blocked":
            errors.append("inactive P5-003 wave must use decision=blocked")
        missing = sorted(REQUIRED_BLOCKERS - blockers)
        for dependency in missing:
            errors.append(f"blocked activation manifest is missing dependency: {dependency}")
        for gate_name in ("transition_verifier", "traversal_collision", "day_night_parity"):
            if gates.get(gate_name, {}).get("status") not in {"pending", "blocked"}:
                errors.append(f"blocked wave cannot claim {gate_name} is accepted")
        parity_locations = gates.get("day_night_parity", {}).get("locations", {})
        if set(parity_locations) != set(EXPECTED_TARGETS):
            errors.append("blocked parity ledger must contain exactly the three P5-003 targets")
        for scene_id, review in parity_locations.items():
            if review.get("status") == "accepted":
                errors.append(f"blocked wave cannot claim accepted parity for {scene_id}")
            if review.get("day_capture") or review.get("night_capture"):
                errors.append(f"blocked parity for {scene_id} cannot name captures")

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
    print("P5-003 world activation wave readiness guard passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Validate final declarative-map inventory, plan, scene wiring, and capture coverage."""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

from verify_map_conversion_plan import (
    PLAN,
    SCENE_INVENTORY,
    TODO,
    parse_inventory,
    parse_plan,
    validate_map_conversion_plan,
)

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "content" / "map_audit_manifest.json"
REGISTRY = ROOT / "scripts" / "map" / "map_audit_registry.gd"
DEFINITION_ROOT = ROOT / "scripts" / "map" / "definitions"
SCENE_DEFINITION = re.compile(r'preload\("res://(?P<path>scripts/map/(?:definitions/[^"\n]+|smithy_courtyard_definition\.gd))"\)')
VALID_DISPOSITIONS = frozenset({"convert", "retain", "archive-prototype"})


@dataclass(frozen=True)
class ValidationError:
    message: str


def load_manifest(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _duplicates(values: list[str]) -> list[str]:
    return sorted(value for value, count in Counter(values).items() if count > 1)


def _format(values: set[str] | list[str]) -> str:
    return ", ".join(f"`{value}`" for value in sorted(values))


def _resolves(root: Path, value: str) -> bool:
    return (root / value.removeprefix("res://")).is_file()


def _declarative_scene_links(root: Path) -> dict[str, str]:
    links: dict[str, str] = {}
    for scene_path in root.rglob("*.tscn"):
        if any(part in {".git", ".godot"} for part in scene_path.parts):
            continue
        scene_text = scene_path.read_text(encoding="utf-8")
        script_match = re.search(r'path="res://(?P<script>[^"\n]+\.gd)"', scene_text)
        if script_match is None:
            continue
        script_path = root / script_match.group("script")
        if not script_path.is_file():
            continue
        definition_match = SCENE_DEFINITION.search(script_path.read_text(encoding="utf-8"))
        if definition_match:
            links[scene_path.relative_to(root).as_posix()] = definition_match.group("path")
    return links


def _definition_packages(root: Path) -> set[str]:
    packages: set[str] = set()
    for path in DEFINITION_ROOT.relative_to(ROOT).glob("**/*.gd"):
        absolute = root / path
        if not absolute.is_file():
            continue
        text = absolute.read_text(encoding="utf-8")
        is_package = path.stem.endswith(("_definition", "_definitions"))
        if is_package and "MapDefinition" in text and ("static func create(" in text or "static func all(" in text):
            packages.add(path.as_posix())
    # The original authoring spike deliberately lives beside the shared map modules.
    packages.add("scripts/map/smithy_courtyard_definition.gd")
    return packages


def validate_map_audit(
    *,
    root: Path,
    manifest_path: Path,
    plan_path: Path,
    inventory_path: Path,
    todo_path: Path,
    require_captures: bool = True,
) -> list[ValidationError]:
    errors = [ValidationError(error.message) for error in validate_map_conversion_plan(
        root=root,
        plan_path=plan_path,
        inventory_path=inventory_path,
        todo_path=todo_path,
    )]

    try:
        payload = load_manifest(manifest_path)
    except (OSError, json.JSONDecodeError) as exc:
        return errors + [ValidationError(f"cannot load map audit manifest: {exc}")]

    rows = payload.get("maps")
    capture = payload.get("capture")
    if not isinstance(rows, list) or not rows:
        return errors + [ValidationError("map audit manifest needs a non-empty maps array")]
    if not isinstance(capture, dict):
        return errors + [ValidationError("map audit manifest needs capture policy")]

    required_fields = {
        "id", "location_name", "scene", "definition", "factory", "disposition",
        "capture", "mandatory_anchors", "mandatory_transitions",
    }
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            errors.append(ValidationError(f"maps[{index}] must be an object"))
            continue
        missing = required_fields - set(row)
        if missing:
            errors.append(ValidationError(f"maps[{index}] missing fields: {', '.join(sorted(missing))}"))
            continue
        if row["disposition"] not in VALID_DISPOSITIONS:
            errors.append(ValidationError(f"invalid audit disposition `{row['disposition']}` for `{row['id']}`"))
        for field in ("id", "location_name", "scene", "definition", "factory", "capture"):
            if not isinstance(row[field], str) or not row[field].strip():
                errors.append(ValidationError(f"maps[{index}].{field} must be a non-empty string"))
        for field in ("mandatory_anchors", "mandatory_transitions"):
            if not isinstance(row[field], list) or not all(isinstance(value, str) and value for value in row[field]):
                errors.append(ValidationError(f"maps[{index}].{field} must be an array of IDs"))
            elif _duplicates(row[field]):
                errors.append(ValidationError(f"duplicate {field} for `{row['id']}`: {_format(_duplicates(row[field]))}"))

    valid_rows = [row for row in rows if isinstance(row, dict) and required_fields <= set(row)]
    for field in ("id", "scene", "capture"):
        duplicates = _duplicates([str(row[field]) for row in valid_rows])
        if duplicates:
            errors.append(ValidationError(f"duplicate map audit {field} entries: {_format(duplicates)}"))

    inventory_scenes = set(parse_inventory(inventory_path))
    index_rows, _ = parse_plan(plan_path)
    plan_by_scene = {row.scene: row for row in index_rows}
    manifest_by_scene = {row["scene"]: row for row in valid_rows}
    manifest_definitions = {row["definition"] for row in valid_rows}

    for row in valid_rows:
        map_id = row["id"]
        for field in ("scene", "definition"):
            if not _resolves(root, row[field]):
                errors.append(ValidationError(f"stale {field} `{row[field]}` for `{map_id}`"))
        if row["scene"] not in inventory_scenes:
            errors.append(ValidationError(f"audit scene missing from scene inventory: `{row['scene']}`"))
        plan_row = plan_by_scene.get(row["scene"])
        if plan_row is None:
            errors.append(ValidationError(f"audit scene missing from conversion plan: `{row['scene']}`"))
        elif row["disposition"] != "archive-prototype" and plan_row.status != row["disposition"]:
            errors.append(ValidationError(
                f"disposition mismatch for `{row['scene']}`: plan `{plan_row.status}`, audit `{row['disposition']}`"
            ))
        elif row["disposition"] == "convert" and f"`{row['definition']}`" != plan_row.target:
            errors.append(ValidationError(f"definition target mismatch for converted scene `{row['scene']}`"))

        capture_path = root / str(capture.get("directory", "")) / row["capture"]
        if require_captures and (not capture_path.is_file() or capture_path.stat().st_size == 0):
            errors.append(ValidationError(f"missing visual capture for `{map_id}`: `{capture_path.relative_to(root)}`"))

    for field in ("viewport_px", "panel_world_px"):
        value = capture.get(field)
        if not isinstance(value, list) or len(value) != 2 or not all(isinstance(item, int) and item > 0 for item in value):
            errors.append(ValidationError(f"capture.{field} must contain two positive integers"))
    if not isinstance(capture.get("world_scale"), (int, float)) or capture.get("world_scale", 0) <= 0:
        errors.append(ValidationError("capture.world_scale must be positive"))
    if capture.get("legend") is not True:
        errors.append(ValidationError("capture.legend must be true"))

    declarative_links = _declarative_scene_links(root)
    missing_scene_rows = set(declarative_links) - set(manifest_by_scene)
    if missing_scene_rows:
        errors.append(ValidationError("declarative scenes missing audit entries: " + _format(missing_scene_rows)))
    for scene, definition in declarative_links.items():
        row = manifest_by_scene.get(scene)
        if row is not None and row["definition"] != definition:
            errors.append(ValidationError(
                f"scene `{scene}` loads `{definition}` but audit declares `{row['definition']}`"
            ))

    expected_converted = {
        row.scene for row in index_rows
        if row.status == "convert" and row.role in {"level", "map", "event"}
    }
    actual_converted = {row["scene"] for row in valid_rows if row["disposition"] == "convert"}
    if expected_converted != actual_converted:
        missing = expected_converted - actual_converted
        stale = actual_converted - expected_converted
        if missing:
            errors.append(ValidationError("converted plan scenes missing audit entries: " + _format(missing)))
        if stale:
            errors.append(ValidationError("stale converted audit entries: " + _format(stale)))

    packages = _definition_packages(root)
    missing_packages = packages - manifest_definitions
    stale_packages = manifest_definitions - packages
    if missing_packages:
        errors.append(ValidationError("definition packages missing audit entries: " + _format(missing_packages)))
    if stale_packages:
        errors.append(ValidationError("stale definition packages in audit: " + _format(stale_packages)))

    registry_path = root / REGISTRY.relative_to(ROOT)
    if not registry_path.is_file():
        errors.append(ValidationError(f"map audit registry is missing: `{registry_path.relative_to(root)}`"))
    else:
        registry_text = registry_path.read_text(encoding="utf-8")
        for definition in sorted(manifest_definitions):
            if f'res://{definition}' not in registry_text:
                errors.append(ValidationError(f"definition missing from executable registry: `{definition}`"))

    # Converted scene shells must use the shared assembly/Y-sort policy and cannot
    # regain a legacy diamond TileMap dependency through either .tscn or scene script.
    for scene in sorted(expected_converted):
        scene_path = root / scene
        text = scene_path.read_text(encoding="utf-8") if scene_path.is_file() else ""
        if 'name="Actors"' not in text or "y_sort_enabled = true" not in text:
            errors.append(ValidationError(f"converted scene lacks shared Actors Y-sort root: `{scene}`"))
        script_match = re.search(r'path="res://(?P<script>[^"\n]+\.gd)"', text)
        script_text = ""
        if script_match and (root / script_match.group("script")).is_file():
            script_text = (root / script_match.group("script")).read_text(encoding="utf-8")
        if "MapSceneBootstrap.assemble" not in script_text:
            errors.append(ValidationError(f"converted scene does not use MapSceneBootstrap: `{scene}`"))
        combined = text + "\n" + script_text
        if re.search(r"\b(?:TileMap|TileSet|diamond_isometric)\b", combined, re.IGNORECASE):
            errors.append(ValidationError(f"legacy diamond TileMap dependency in converted scene: `{scene}`"))

    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--manifest", type=Path, default=MANIFEST)
    parser.add_argument("--plan", type=Path, default=PLAN)
    parser.add_argument("--inventory", type=Path, default=SCENE_INVENTORY)
    parser.add_argument("--todo", type=Path, default=TODO)
    parser.add_argument("--skip-captures", action="store_true")
    args = parser.parse_args(argv)

    errors = validate_map_audit(
        root=args.root,
        manifest_path=args.manifest,
        plan_path=args.plan,
        inventory_path=args.inventory,
        todo_path=args.todo,
        require_captures=not args.skip_captures,
    )
    if errors:
        print("map audit verification failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error.message}", file=sys.stderr)
        return 1

    count = len(load_manifest(args.manifest)["maps"])
    print(f"map audit verification passed ({count} declarative maps)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

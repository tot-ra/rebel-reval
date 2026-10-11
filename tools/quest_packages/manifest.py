"""Load and validate quest package manifests and branch maps."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from validate_content_examples import SCHEMAS_DIR, SchemaStore, SchemaValidationError, validate_value

ROOT = Path(__file__).resolve().parents[2]
PACKAGES_ROOT = ROOT / "content" / "packages"
LANDMARK_MANIFEST = ROOT / "docs" / "data" / "landmark_integrations.json"
PACKAGE_SCHEMA = "quest_package.schema.json"


@dataclass(frozen=True)
class QuestPackage:
    root: Path
    manifest: dict[str, Any]
    branch_map: dict[str, Any]


def discover_packages(root: Path | None = None) -> list[Path]:
    packages_root = (root or PACKAGES_ROOT).resolve()
    if not packages_root.exists():
        return []
    discovered: list[Path] = []
    for package_json in sorted(packages_root.glob("*/package.json"), key=lambda path: path.as_posix().casefold()):
        discovered.append(package_json.parent)
    return discovered


def _load_json(path: Path) -> Any:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def load_package(package_dir: Path) -> QuestPackage:
    package_dir = package_dir.resolve()
    manifest_path = package_dir / "package.json"
    manifest = _load_json(manifest_path)
    if not isinstance(manifest, dict):
        raise ValueError(f"{manifest_path}: top-level JSON value must be an object")
    branch_map_path = package_dir / str(manifest["branch_map"])
    branch_map = _load_json(branch_map_path)
    if not isinstance(branch_map, dict):
        raise ValueError(f"{branch_map_path}: top-level JSON value must be an object")
    return QuestPackage(root=package_dir, manifest=manifest, branch_map=branch_map)


def package_content_paths(package: QuestPackage) -> list[Path]:
    paths = [package.root / str(package.manifest["quest"])]
    for relative in package.manifest.get("dialogue", []):
        paths.append(package.root / str(relative))
    for relative in package.manifest.get("support", []):
        paths.append((package.root / str(relative)).resolve())
    return paths


def package_content_dirs(package: QuestPackage) -> list[Path]:
    dirs: list[Path] = []
    seen: set[Path] = set()
    for path in package_content_paths(package):
        parent = path.parent.resolve()
        if parent not in seen:
            seen.add(parent)
            dirs.append(parent)
    return dirs


def _known_landmark_beats(manifest: dict[str, Any]) -> set[str]:
    integrations = manifest.get("integrations", [])
    if not isinstance(integrations, list):
        return set()
    beats: set[str] = set()
    for row in integrations:
        if not isinstance(row, dict):
            continue
        beat_id = row.get("beat_id")
        if isinstance(beat_id, str):
            beats.add(beat_id)
    return beats


def _validate_manifest_schema(manifest: dict[str, Any]) -> list[str]:
    store = SchemaStore(SCHEMAS_DIR)
    try:
        validate_value(manifest, store.resolve(PACKAGE_SCHEMA), store)
    except SchemaValidationError as exc:
        return [str(exc)]
    return []


def validate_package(package: QuestPackage, *, landmark_manifest: dict[str, Any] | None = None) -> list[str]:
    errors = _validate_manifest_schema(package.manifest)
    manifest = package.manifest
    branch_map = package.branch_map

    quest_path = package.root / str(manifest["quest"])
    if not quest_path.exists():
        errors.append(f"{quest_path}: quest file is missing")
    else:
        quest_record = _load_json(quest_path)
        quest_id = quest_record.get("id") if isinstance(quest_record, dict) else None
        branch_quest_id = branch_map.get("quest_id")
        if quest_id and branch_quest_id != quest_id:
            errors.append(
                f"{package.root / str(manifest['branch_map'])}: quest_id {branch_quest_id!r} "
                f"does not match quest record id {quest_id!r}"
            )

    branch_map_path = package.root / str(manifest["branch_map"])
    if not branch_map_path.exists():
        errors.append(f"{branch_map_path}: branch map file is missing")

    for relative in manifest.get("dialogue", []):
        dialogue_path = package.root / str(relative)
        if not dialogue_path.exists():
            errors.append(f"{dialogue_path}: dialogue file is missing")

    for relative in manifest.get("support", []):
        support_path = (package.root / str(relative)).resolve()
        if not support_path.exists():
            errors.append(f"{support_path}: support file is missing")

    bindings = manifest.get("bindings", {})
    landmark_beats = bindings.get("landmark_beats", []) if isinstance(bindings, dict) else []
    if not landmark_beats:
        errors.append(f"{package.root / 'package.json'}: bindings.landmark_beats must list at least one beat")

    landmark_manifest = landmark_manifest or _load_json(LANDMARK_MANIFEST)
    known_beats = _known_landmark_beats(landmark_manifest)
    for beat_id in landmark_beats:
        if beat_id not in known_beats:
            errors.append(f"{package.root / 'package.json'}: unknown landmark beat {beat_id!r}")

    branches = branch_map.get("branches", [])
    if not isinstance(branches, list) or not branches:
        errors.append(f"{branch_map_path}: branches must contain at least one traversal branch")

    return errors


def load_branch_map(package: QuestPackage) -> dict[str, Any]:
    return package.branch_map

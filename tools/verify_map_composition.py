#!/usr/bin/env python3
"""Verify P1-036 map composition audit thresholds and enforced registry maps."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
THRESHOLDS = ROOT / "docs" / "data" / "map_composition_thresholds.json"
AUDIT_MANIFEST = ROOT / "content" / "map_audit_manifest.json"
LOWER_TOWN_OWNERSHIP = ROOT / "docs" / "data" / "lower_town_authoring_contract.json"
REGISTRY = ROOT / "scripts" / "map" / "map_blueprint_registry.gd"
DOSSIER = ROOT / "docs" / "HISTORICAL_AUDIT.md"
TODO = ROOT / "TODO.md"


def resolve_godot() -> Path | None:
    override = os.environ.get("GODOT_BIN")
    if override:
        path = Path(override)
        if path.is_file():
            return path
    found = shutil.which("godot") or shutil.which("godot4")
    if found:
        return Path(found)
    mac_default = Path("/Applications/Godot.app/Contents/MacOS/Godot")
    if mac_default.is_file():
        return mac_default
    return None


def parse_registry_ids(text: str) -> list[str]:
    import re

    return re.findall(r'"id"\s*:\s*&"([a-z][a-z0-9_.]*)"', text)


def p1_036_complete(todo_text: str) -> bool:
    import re

    return bool(re.search(r"^- \[x\] P1-036\b", todo_text, re.MULTILINE))


def _load_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"could not parse {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ValueError(f"{path}: top-level JSON value must be an object")
    return value


def validate_threshold_contract() -> list[str]:
    errors: list[str] = []
    if not THRESHOLDS.is_file():
        return [f"missing thresholds file: {THRESHOLDS}"]
    try:
        payload = _load_json(THRESHOLDS)
    except ValueError as exc:
        return [str(exc)]
    maps: dict = payload.get("maps", {})
    if not maps:
        errors.append("thresholds file has no map cards")
    try:
        registry_ids = parse_registry_ids(REGISTRY.read_text(encoding="utf-8"))
    except OSError as exc:
        return [f"could not read map registry: {exc}"]
    missing = sorted(set(registry_ids) - set(maps))
    extra = sorted(set(maps) - set(registry_ids))
    if missing:
        errors.append("registry maps missing threshold cards: " + ", ".join(missing))
    if extra:
        errors.append("threshold cards absent from registry: " + ", ".join(extra))
    for map_id, card in maps.items():
        if not isinstance(card, dict):
            errors.append(f"{map_id}: threshold card must be an object")
            continue
        if card.get("enforce", True) is False:
            continue
        if card.get("interior"):
            if not card.get("surface_shares"):
                errors.append(f"{map_id}: interior map needs surface_shares")
            if not card.get("open_floor_pct"):
                errors.append(f"{map_id}: interior map needs open_floor_pct")
        elif not card.get("surface_shares"):
            errors.append(f"{map_id}: outdoor map needs surface_shares")

    errors.extend(validate_lower_town_enforcement())
    return errors


def validate_lower_town_enforcement() -> list[str]:
    """Require an explicit gate and ownership source for the playable slice."""
    errors: list[str] = []
    try:
        thresholds = _load_json(THRESHOLDS)
        manifest = _load_json(AUDIT_MANIFEST)
        ownership = _load_json(LOWER_TOWN_OWNERSHIP)
    except ValueError as exc:
        return [str(exc)]

    card = thresholds.get("maps", {}).get("lower_town_slice")
    if not isinstance(card, dict):
        return ["lower_town_slice: missing threshold card"]
    if card.get("enforce") is not True or card.get("enforcement_state") != "enforced":
        errors.append("lower_town_slice: composition gate must be explicitly enforced")
    if card.get("ownership_contract") != "docs/data/lower_town_authoring_contract.json":
        errors.append("lower_town_slice: threshold card must name its ownership contract")
    if not card.get("source_refs") or not {"H04-H05", "H09-H10"}.issubset(card["source_refs"]):
        errors.append("lower_town_slice: H04-H05 and H09-H10 source refs are required")

    rows = [row for row in manifest.get("maps", []) if row.get("id") == "lower_town_slice"]
    if len(rows) != 1:
        errors.append("lower_town_slice: audit manifest must contain exactly one map row")
        return errors
    enforcement = rows[0].get("composition_enforcement", {})
    expected = {
        "state": "enforced",
        "thresholds": "docs/data/map_composition_thresholds.json#maps.lower_town_slice",
        "ownership": "docs/data/lower_town_authoring_contract.json",
        "open_region_exclusions": "ownership.open_regions[].exclude_from_unowned_empty_region",
    }
    for key, value in expected.items():
        if enforcement.get(key) != value:
            errors.append(f"lower_town_slice: manifest composition_enforcement.{key} must be {value!r}")

    if ownership.get("map_id") != "lower_town_slice":
        errors.append("lower_town_slice: ownership contract has the wrong map_id")
    open_regions = ownership.get("open_regions", [])
    if not open_regions:
        errors.append("lower_town_slice: ownership contract must list intentional open regions")
    for region in open_regions:
        region_id = region.get("id", "<unnamed>")
        if not region.get("bounds_cells"):
            errors.append(f"lower_town_slice: open region {region_id} needs bounds_cells")
        if not region.get("reason"):
            errors.append(f"lower_town_slice: open region {region_id} needs an exclusion reason")
        if region.get("exclude_from_unowned_empty_region") is not True:
            errors.append(
                f"lower_town_slice: open region {region_id} must explicitly opt out of the empty-region metric"
            )
    return errors


def run_godot_audit() -> tuple[int, str]:
    godot = resolve_godot()
    if godot is None:
        return 1, "Godot binary not found; set GODOT_BIN or install Godot 4.7"
    result = subprocess.run(
        [
            str(godot),
            "--headless",
            "--path",
            str(ROOT),
            "--script",
            "tools/audit_map_composition.gd",
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    output = (result.stdout or "") + (result.stderr or "")
    return result.returncode, output


def main() -> int:
    errors = validate_threshold_contract()
    if errors:
        print("map composition verification failed:")
        for error in errors:
            print(f"  - {error}")
        return 1

    code, output = run_godot_audit()
    if code != 0:
        print("map composition audit failed:")
        print(output)
        return 1

    enforced = sum(
        1
        for card in json.loads(THRESHOLDS.read_text(encoding="utf-8"))["maps"].values()
        if card.get("enforce", True)
    )
    print(
        f"map composition verification passed ({enforced} enforced map(s); "
        f"thresholds={THRESHOLDS.relative_to(ROOT)})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

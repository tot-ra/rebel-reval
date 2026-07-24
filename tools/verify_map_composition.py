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


def validate_threshold_contract() -> list[str]:
    errors: list[str] = []
    if not THRESHOLDS.is_file():
        return [f"missing thresholds file: {THRESHOLDS}"]
    payload = json.loads(THRESHOLDS.read_text(encoding="utf-8"))
    maps: dict = payload.get("maps", {})
    if not maps:
        errors.append("thresholds file has no map cards")
    registry_ids = parse_registry_ids(REGISTRY.read_text(encoding="utf-8"))
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

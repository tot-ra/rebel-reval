#!/usr/bin/env python3
"""Repository accessibility checklist verifier for P3-007.

Usage:
    python3 tools/report_accessibility_checklist.py
    python3 tools/report_accessibility_checklist.py --check
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "docs" / "data" / "accessibility_checklist.json"

REQUIRED_FILES = [
    "scripts/settings/gameplay_accessibility_settings.gd",
    "scripts/settings/dialogue_settings.gd",
    "scripts/settings/input_binding_settings.gd",
    "scripts/ui/game_settings_overlay.gd",
    "scripts/ui/controls_overlay.gd",
    "scripts/ui/ui_focus_theme.gd",
    "scripts/player/player_action_input.gd",
    "scripts/map/view3d/map_view_runtime_camera.gd",
    "tests/godot/test_gameplay_accessibility_settings.gd",
    "tests/godot/test_input_bindings.gd",
    "tests/godot/test_game_settings_overlay.gd",
]

REQUIRED_GAMEPLAY_FIELDS = [
    "guard_mode",
    "screenshake_enabled",
    "reduced_flashing",
    "enhanced_focus_contrast",
]

REQUIRED_DIALOGUE_FIELDS = [
    "text_scale",
    "text_speed",
    "subtitle_background",
    "high_contrast",
    "reduced_motion",
]


def load_manifest() -> dict:
    return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))


def verify_files() -> list[str]:
    failures: list[str] = []
    for relative in REQUIRED_FILES:
        path = ROOT / relative
        if not path.is_file():
            failures.append(f"missing required file: {relative}")
    return failures


def verify_manifest_contract(manifest: dict) -> list[str]:
    failures: list[str] = []
    required = manifest.get("required_options")
    if not isinstance(required, list) or not required:
        failures.append("manifest required_options must be a non-empty list")
        required = []
    else:
        for index, option in enumerate(required):
            if not isinstance(option, str) or not option.strip():
                failures.append(
                    f"manifest required_options[{index}] must be a non-empty string"
                )
    for option in [
        "remapping",
        "guard_hold_toggle",
        "text_speed",
        "scalable_text",
        "subtitle_background",
        "focus_contrast",
        "screen_shake",
        "reduced_flashing",
    ]:
        if option not in required:
            failures.append(f"missing required option: {option}")
    if len(manifest.get("supported_resolutions", [])) < 2:
        failures.append("manifest must list at least two supported resolutions")
    if "keyboard_mouse" not in manifest.get("input_methods", []):
        failures.append("manifest must list keyboard_mouse input method")
    if "gamepad" not in manifest.get("input_methods", []):
        failures.append("manifest must list gamepad input method")
    return failures


def verify_model_fields() -> list[str]:
    failures: list[str] = []
    gameplay = (ROOT / "scripts/settings/gameplay_accessibility_settings.gd").read_text(
        encoding="utf-8"
    )
    for field in REQUIRED_GAMEPLAY_FIELDS:
        if f"var {field}" not in gameplay:
            failures.append(f"gameplay accessibility model missing field: {field}")
    dialogue = (ROOT / "scripts/settings/dialogue_settings.gd").read_text(encoding="utf-8")
    for field in REQUIRED_DIALOGUE_FIELDS:
        if f"var {field}" not in dialogue:
            failures.append(f"dialogue accessibility model missing field: {field}")
    overlay = (ROOT / "scripts/ui/game_settings_overlay.gd").read_text(encoding="utf-8")
    if "controls_requested" not in overlay:
        failures.append("settings overlay must expose remap controls entry point")
    if "Remap controls" not in overlay:
        failures.append("settings overlay must expose remap controls button")
    return failures


def run_check() -> tuple[bool, list[str]]:
    failures: list[str] = []
    if not MANIFEST_PATH.is_file():
        return False, [f"missing manifest: {MANIFEST_PATH.relative_to(ROOT)}"]
    manifest = load_manifest()
    failures.extend(verify_files())
    failures.extend(verify_manifest_contract(manifest))
    failures.extend(verify_model_fields())
    return not failures, failures


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Verify slice accessibility checklist")
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit 1 when checklist verification fails",
    )
    args = parser.parse_args(argv)
    passed, failures = run_check()
    if passed:
        print("accessibility checklist: PASS")
        return 0
    print("accessibility checklist: FAIL")
    for failure in failures:
        print(f"  - {failure}")
    return 1 if args.check else 0


if __name__ == "__main__":
    sys.exit(main())

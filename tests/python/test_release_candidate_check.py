#!/usr/bin/env python3
"""Tests for the release-candidate verification scaffold."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from release_candidate_check import (  # noqa: E402
    check_accessibility,
    check_ci,
    check_license,
    check_platform,
    check_provenance,
    main,
    run_checks,
)


class ReleaseCandidateCheckTest(unittest.TestCase):
    def test_license_passes_with_agpl_markers(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / "LICENSE").write_text(
                "\n".join(
                    [
                        "GNU AFFERO GENERAL PUBLIC LICENSE",
                        "Version 3, 19 November 2007",
                        "Copyright (C) 2007 Free Software Foundation, Inc.",
                    ]
                ),
                encoding="utf-8",
            )

            result = check_license(root)

            self.assertTrue(result.passed)
            self.assertEqual(result.name, "License Report")

    def test_license_fails_when_missing(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            result = check_license(Path(temp_dir))
            self.assertFalse(result.passed)

    def test_provenance_requires_manifest_and_validator(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / "assets").mkdir()
            (root / "assets" / "SOURCES.csv").write_text("path,source\n", encoding="utf-8")
            (root / "tools").mkdir()
            (root / "tools" / "validate_asset_sources.py").write_text("# stub\n", encoding="utf-8")

            result = check_provenance(root)

            self.assertTrue(result.passed)

    def test_accessibility_checks_implemented_baseline_files(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / "project.godot").write_text(
                "\n".join(
                    [
                        "[autoload]",
                        'UserSettings="*res://scripts/settings/user_settings.gd"',
                        "",
                        "[display]",
                        "window/size/viewport_width=1920",
                        "window/size/viewport_height=1080",
                        "",
                        "[input]",
                        "interact={}",
                    ]
                ),
                encoding="utf-8",
            )
            settings_dir = root / "scripts" / "settings"
            settings_dir.mkdir(parents=True)
            (settings_dir / "user_settings.gd").write_text(
                "func rebind_action(action, event, device):\n\tpass\n",
                encoding="utf-8",
            )
            ui_dir = root / "scripts" / "ui"
            ui_dir.mkdir(parents=True)
            (ui_dir / "controls_overlay.gd").write_text("extends Control\n", encoding="utf-8")
            tests_dir = root / "tests" / "godot"
            tests_dir.mkdir(parents=True)
            (tests_dir / "test_input_bindings.gd").write_text("extends RefCounted\n", encoding="utf-8")
            docs_dir = root / "docs" / "data"
            docs_dir.mkdir(parents=True)
            (docs_dir / "accessibility_checklist.json").write_text(
                json.dumps(
                    {
                        "required_options": [
                            "remapping",
                            "guard_hold_toggle",
                            "text_speed",
                            "scalable_text",
                            "subtitle_background",
                            "focus_contrast",
                            "screen_shake",
                            "reduced_flashing",
                        ],
                        "supported_resolutions": [{"width": 1280, "height": 720}],
                        "input_methods": ["keyboard_mouse", "gamepad"],
                    }
                ),
                encoding="utf-8",
            )
            (settings_dir / "gameplay_accessibility_settings.gd").write_text(
                "\n".join(
                    [
                        "var guard_mode",
                        "var screenshake_enabled",
                        "var reduced_flashing",
                        "var enhanced_focus_contrast",
                    ]
                ),
                encoding="utf-8",
            )
            (settings_dir / "dialogue_settings.gd").write_text(
                "\n".join(
                    [
                        "var text_scale",
                        "var text_speed",
                        "var subtitle_background",
                        "var high_contrast",
                        "var reduced_motion",
                    ]
                ),
                encoding="utf-8",
            )
            (ui_dir / "game_settings_overlay.gd").write_text(
                'signal controls_requested\nbutton_text = "Remap controls"\n',
                encoding="utf-8",
            )
            (root / "tools").mkdir(parents=True)
            (root / "tools" / "report_accessibility_checklist.py").write_text("# stub\n", encoding="utf-8")
            (tests_dir / "test_gameplay_accessibility_settings.gd").write_text(
                "extends RefCounted\n", encoding="utf-8"
            )
            (tests_dir / "test_game_settings_overlay.gd").write_text("extends RefCounted\n", encoding="utf-8")
            (ui_dir / "ui_focus_theme.gd").write_text("extends RefCounted\n", encoding="utf-8")
            (root / "scripts" / "player" / "player_action_input.gd").parent.mkdir(
                parents=True, exist_ok=True
            )
            (root / "scripts" / "player" / "player_action_input.gd").write_text(
                "extends RefCounted\n", encoding="utf-8"
            )
            (root / "scripts" / "map" / "view3d" / "map_view_runtime_camera.gd").parent.mkdir(
                parents=True, exist_ok=True
            )
            (root / "scripts" / "map" / "view3d" / "map_view_runtime_camera.gd").write_text(
                "extends RefCounted\n", encoding="utf-8"
            )
            (settings_dir / "input_binding_settings.gd").write_text("extends RefCounted\n", encoding="utf-8")

            result = check_accessibility(root)

            self.assertTrue(result.passed)

    def test_platform_checks_export_preset_contract(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / ".godot-version").write_text("4.7\n", encoding="utf-8")
            (root / "export_presets.cfg").write_text(
                "\n".join(
                    [
                        'platform="macOS"',
                        'binary_format/architecture="universal"',
                    ]
                ),
                encoding="utf-8",
            )

            result = check_platform(root)

            self.assertTrue(result.passed)

    def test_ci_checks_workflow_and_runner_scripts(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            workflow_dir = root / ".github" / "workflows"
            workflow_dir.mkdir(parents=True)
            (workflow_dir / "ci.yml").write_text(
                "\n".join(
                    [
                        "validate-and-smoke:",
                        "  steps:",
                        "    - run: tools/run_godot_checked.sh clean-import",
                        "    - run: tools/run_godot_checked.sh main-scene",
                    ]
                ),
                encoding="utf-8",
            )
            tools_dir = root / "tools"
            tools_dir.mkdir()
            (tools_dir / "run_godot_checked.sh").write_text("#!/bin/sh\n", encoding="utf-8")
            (tools_dir / "restore_lfs_assets.sh").write_text("#!/bin/sh\n", encoding="utf-8")

            result = check_ci(root)

            self.assertTrue(result.passed)

    def test_main_passes_on_repository_root(self) -> None:
        self.assertEqual(main([]), 0)

    def test_run_checks_all_pass_on_repository_root(self) -> None:
        results = run_checks()
        self.assertTrue(results)
        self.assertTrue(all(result.passed for result in results))


if __name__ == "__main__":
    unittest.main()

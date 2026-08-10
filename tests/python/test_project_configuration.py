#!/usr/bin/env python3
"""Smoke tests for the repository's core Godot project configuration."""

from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PROJECT_FILE = ROOT / "project.godot"
VERSION_FILE = ROOT / ".godot-version"


class ProjectConfigurationTest(unittest.TestCase):
    def test_godot_version_pin_matches_project_features(self) -> None:
        version = VERSION_FILE.read_text(encoding="utf-8").strip()
        project = PROJECT_FILE.read_text(encoding="utf-8")
        feature_match = re.search(
            r'^config/features=PackedStringArray\("([^"]+)"',
            project,
            flags=re.MULTILINE,
        )

        self.assertTrue(version, ".godot-version must not be empty")
        self.assertIsNotNone(feature_match, "project.godot must declare config/features")
        self.assertEqual(version, feature_match.group(1))

    def test_declared_main_scene_uid_resolves_to_existing_scene(self) -> None:
        project = PROJECT_FILE.read_text(encoding="utf-8")
        main_scene_match = re.search(
            r'^run/main_scene="([^"]+)"', project, flags=re.MULTILINE
        )

        self.assertIsNotNone(main_scene_match, "project.godot must declare run/main_scene")
        main_scene_uid = main_scene_match.group(1)
        scene_paths = []
        for scene_path in ROOT.rglob("*.tscn"):
            if ".git" in scene_path.parts or ".godot" in scene_path.parts:
                continue
            scene_text = scene_path.read_text(encoding="utf-8", errors="ignore")
            scene_header = scene_text.splitlines()[0] if scene_text else ""
            if scene_header.startswith("[gd_scene ") and f'uid="{main_scene_uid}"' in scene_header:
                scene_paths.append(scene_path)

        self.assertEqual(
            len(scene_paths),
            1,
            f"main scene UID {main_scene_uid} must resolve to exactly one .tscn",
        )
        self.assertTrue(scene_paths[0].is_file())


if __name__ == "__main__":
    unittest.main()

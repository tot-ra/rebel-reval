#!/usr/bin/env python3
"""Smoke tests for the repository's core Godot project configuration."""

from __future__ import annotations

import re
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PROJECT_FILE = ROOT / "project.godot"
VERSION_FILE = ROOT / ".godot-version"


def _scene_paths_for_uid(root: Path, scene_uid: str) -> list[Path]:
    scene_paths = []
    for scene_path in root.rglob("*.tscn"):
        if any(part in scene_path.parts for part in (".git", ".godot", ".worktrees")):
            continue
        scene_text = scene_path.read_text(encoding="utf-8", errors="ignore")
        scene_header = scene_text.splitlines()[0] if scene_text else ""
        if scene_header.startswith("[gd_scene ") and f'uid="{scene_uid}"' in scene_header:
            scene_paths.append(scene_path)
    return scene_paths


def _resolve_main_scene_path(root: Path, project_text: str) -> Path:
    main_scene_match = re.search(
        r'^run/main_scene="([^"]+)"', project_text, flags=re.MULTILINE
    )
    if main_scene_match is None:
        raise AssertionError("project.godot must declare run/main_scene")

    main_scene_uid = main_scene_match.group(1)
    scene_paths = _scene_paths_for_uid(root, main_scene_uid)
    if len(scene_paths) != 1:
        raise AssertionError(
            f"main scene UID {main_scene_uid} must resolve to exactly one .tscn"
        )
    return scene_paths[0]


def _assert_main_scene_matches_path(
    root: Path, project_text: str, expected_path: Path
) -> Path:
    scene_path = _resolve_main_scene_path(root, project_text)
    if scene_path != expected_path:
        raise AssertionError(
            f"main scene UID resolves to {scene_path}, expected {expected_path}"
        )
    return scene_path


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
        scene_path = _assert_main_scene_matches_path(
            ROOT, project, ROOT / "scenes/menu/main_menu.tscn"
        )

        self.assertTrue(scene_path.is_file())

    def test_main_scene_uid_must_match_expected_path(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            fixture_root = Path(temp_dir)
            (fixture_root / "main.tscn").write_text(
                '[gd_scene load_steps=1 format=3 uid="uid://main"]\n',
                encoding="utf-8",
            )
            (fixture_root / "other.tscn").write_text(
                '[gd_scene load_steps=1 format=3 uid="uid://other"]\n',
                encoding="utf-8",
            )
            project = 'run/main_scene="uid://other"\n'

            with self.assertRaisesRegex(AssertionError, "expected"):
                _assert_main_scene_matches_path(
                    fixture_root, project, fixture_root / "main.tscn"
                )

    def test_duplicate_main_scene_uid_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            fixture_root = Path(temp_dir)
            scene_header = '[gd_scene load_steps=1 format=3 uid="uid://main"]\n'
            (fixture_root / "main.tscn").write_text(scene_header, encoding="utf-8")
            (fixture_root / "duplicate.tscn").write_text(scene_header, encoding="utf-8")

            scene_paths = _scene_paths_for_uid(fixture_root, "uid://main")

        self.assertEqual(
            len(scene_paths),
            2,
            "duplicate main-scene UIDs must not be treated as a unique resolution",
        )


if __name__ == "__main__":
    unittest.main()

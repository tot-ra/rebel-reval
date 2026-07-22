#!/usr/bin/env python3
"""Tests for P4-018 / P1-038 quest package generation."""

from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import generate_quest_package_tests as generator  # noqa: E402
from quest_packages import load_package, render_godot_test, validate_package  # noqa: E402

PACKAGE_DIR = ROOT / "content" / "packages" / "act1_south_quarter_probe"


class QuestPackageGeneratorTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.package = load_package(PACKAGE_DIR)

    def test_example_package_validates(self) -> None:
        self.assertEqual(validate_package(self.package), [])

    def test_generated_godot_test_is_checked_in(self) -> None:
        expected = render_godot_test(self.package)
        output_path = generator.test_output_path(self.package)
        self.assertTrue(output_path.exists(), f"missing generated test: {output_path}")
        self.assertEqual(output_path.read_text(encoding="utf-8"), expected)

    def test_generator_check_passes(self) -> None:
        self.assertEqual(generator.main(["--check"]), 0)

    def test_missing_landmark_beat_binding_fails_validation(self) -> None:
        mutated = copy.deepcopy(self.package.manifest)
        mutated["bindings"]["landmark_beats"] = []
        broken = copy.copy(self.package)
        broken = type(self.package)(root=self.package.root, manifest=mutated, branch_map=self.package.branch_map)
        errors = validate_package(broken)
        self.assertTrue(any("landmark_beats must list at least one beat" in error for error in errors))

    def test_unknown_landmark_beat_fails_validation(self) -> None:
        mutated = copy.deepcopy(self.package.manifest)
        mutated["bindings"]["landmark_beats"] = ["beat.landmark.tallinn.missing_probe"]
        broken = type(self.package)(root=self.package.root, manifest=mutated, branch_map=self.package.branch_map)
        errors = validate_package(broken)
        self.assertTrue(any("unknown landmark beat" in error for error in errors))


if __name__ == "__main__":
    unittest.main()

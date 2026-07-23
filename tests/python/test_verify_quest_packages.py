#!/usr/bin/env python3
"""Tests for tools/verify_quest_packages.py."""

from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import verify_quest_packages as verifier  # noqa: E402
from quest_packages import load_package, validate_package  # noqa: E402

PACKAGE_DIR = ROOT / "content" / "packages" / "act1_south_quarter_probe"


class VerifyQuestPackagesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.package = load_package(PACKAGE_DIR)

    def test_example_package_validates(self) -> None:
        self.assertEqual(validate_package(self.package), [])

    def test_strict_mode_passes_on_current_corpus(self) -> None:
        self.assertEqual(verifier.main([]), 0)

    def test_skip_failing_passes_on_current_corpus(self) -> None:
        self.assertEqual(verifier.main(["--skip-failing"]), 0)

    def test_strict_mode_fails_on_validation_error(self) -> None:
        import tempfile

        with tempfile.TemporaryDirectory() as tmp_dir:
            broken_pkg = Path(tmp_dir) / "broken_package"
            broken_pkg.mkdir()
            (broken_pkg / "package.json").write_text(
                (
                    '{"type": "quest_package", "id": "package.broken", "schema_version": 1, '
                    '"title": "Broken Package", "quest": "content/quest.json", '
                    '"branch_map": "branch_map.json", '
                    '"bindings": {"landmark_beats": ["beat.landmark.tallinn.missing_probe"], '
                    '"map_anchors": [{"map_id": "south_quarter", "anchor_id": "karja_approach"}]}, '
                    '"source_notes": [{"confidence": "invented", "summary": "test fixture", '
                    '"citations": ["TODO.md"]}]}'
                ),
                encoding="utf-8",
            )
            (broken_pkg / "branch_map.json").write_text(
                '{"quest_id": "quest.broken", "branches": [{"id": "probe", "transitions": []}]}',
                encoding="utf-8",
            )

            with patch("verify_quest_packages.discover_packages", return_value=[broken_pkg]):
                self.assertEqual(verifier.main([]), 1)

    def test_skip_failing_continues_after_validation_error(self) -> None:
        import tempfile

        with tempfile.TemporaryDirectory() as tmp_dir:
            broken_pkg = Path(tmp_dir) / "broken_package"
            broken_pkg.mkdir()
            (broken_pkg / "package.json").write_text(
                (
                    '{"type": "quest_package", "id": "package.broken", "schema_version": 1, '
                    '"title": "Broken Package", "quest": "content/quest.json", '
                    '"branch_map": "branch_map.json", '
                    '"bindings": {"landmark_beats": ["beat.landmark.tallinn.missing_probe"], '
                    '"map_anchors": [{"map_id": "south_quarter", "anchor_id": "karja_approach"}]}, '
                    '"source_notes": [{"confidence": "invented", "summary": "test fixture", '
                    '"citations": ["TODO.md"]}]}'
                ),
                encoding="utf-8",
            )
            (broken_pkg / "branch_map.json").write_text(
                '{"quest_id": "quest.broken", "branches": [{"id": "probe", "transitions": []}]}',
                encoding="utf-8",
            )

            with patch(
                "verify_quest_packages.discover_packages",
                return_value=[broken_pkg, PACKAGE_DIR],
            ):
                validated, skipped, errors = verifier.validate_all(
                    [broken_pkg, PACKAGE_DIR],
                    skip_failing=True,
                )

            self.assertEqual(errors, [])
            self.assertIn("broken_package", skipped)
            self.assertEqual(validated, 1)

    def test_skip_failing_continues_after_load_error(self) -> None:
        import tempfile

        with tempfile.TemporaryDirectory() as tmp_dir:
            corrupt_pkg = Path(tmp_dir) / "corrupt_package"
            corrupt_pkg.mkdir()
            (corrupt_pkg / "package.json").write_text(
                '{"id": "package.corrupt", "name": "Corrupt Package"}',
                encoding="utf-8",
            )

            with patch(
                "verify_quest_packages.discover_packages",
                return_value=[corrupt_pkg, PACKAGE_DIR],
            ):
                validated, skipped, errors = verifier.validate_all(
                    [corrupt_pkg, PACKAGE_DIR],
                    skip_failing=True,
                )

            self.assertEqual(errors, [])
            self.assertIn("corrupt_package", skipped)
            self.assertEqual(validated, 1)

    def test_missing_landmark_beat_binding_fails_validation(self) -> None:
        mutated = copy.deepcopy(self.package.manifest)
        mutated["bindings"]["landmark_beats"] = []
        broken = type(self.package)(
            root=self.package.root,
            manifest=mutated,
            branch_map=self.package.branch_map,
        )
        errors = validate_package(broken)
        self.assertTrue(any("landmark_beats must list at least one beat" in error for error in errors))


if __name__ == "__main__":
    unittest.main()

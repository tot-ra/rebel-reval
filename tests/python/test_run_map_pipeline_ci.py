#!/usr/bin/env python3
"""Guards map-pipeline CI filters against stems that match no Godot test file."""

from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tools" / "run_map_pipeline_ci.sh"
TEST_DIR = ROOT / "tests" / "godot"
_RUN_TESTS_RE = re.compile(r"""run_tests\s+([A-Za-z0-9_-]+)""")


class RunMapPipelineCiTest(unittest.TestCase):
    def test_every_run_tests_filter_matches_a_godot_test_file(self) -> None:
        text = SCRIPT.read_text(encoding="utf-8")
        filters = _RUN_TESTS_RE.findall(text)
        self.assertGreaterEqual(len(filters), 6, "expected parser/compiler/parity/routes/persistence filters")
        missing: list[str] = []
        for raw in filters:
            stem = raw if raw.startswith("test_") else f"test_{raw}"
            path = TEST_DIR / f"{stem}.gd"
            if not path.is_file():
                missing.append(f"{raw} -> {path.relative_to(ROOT)}")
        self.assertEqual(missing, [], "run_tests filter must be an existing tests/godot stem")

    def test_parity_and_routes_use_the_slice_and_hardening_stems(self) -> None:
        text = SCRIPT.read_text(encoding="utf-8")
        self.assertIn("run_tests test_lower_town_slice_map", text)
        self.assertIn("run_tests test_map_pipeline_hardening", text)
        self.assertNotIn("run_tests lower_town_slice_map", text)
        self.assertNotIn("run_tests map_pipeline_hardening", text)


if __name__ == "__main__":
    unittest.main()

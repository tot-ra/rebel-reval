#!/usr/bin/env python3
"""Contract tests for the repository smoke-test helper."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SMOKE_HELPER = ROOT / "test_commands.sh"
PERFORMANCE_HELPER = ROOT / "tools" / "run_performance_report.sh"


class TestCommandsSmokeHelperTest(unittest.TestCase):
    def test_invalid_explicit_godot_binary_fails_before_smoke(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            env = os.environ.copy()
            env["GODOT_BIN"] = str(Path(temp_dir) / "missing-godot")
            completed = subprocess.run(
                ["bash", str(SMOKE_HELPER)],
                cwd=ROOT,
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("GODOT_BIN is not an executable Godot binary", completed.stderr)
        self.assertNotIn("Playable-room smoke scene was not found", completed.stderr)
        self.assertEqual(completed.stdout, "")

    def test_performance_report_rejects_extra_argument_before_running_godot(self) -> None:
        completed = subprocess.run(
            ["bash", str(PERFORMANCE_HELPER), "report.json", "--quick", "unexpected"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(completed.returncode, 2)
        self.assertIn("Usage:", completed.stderr)
        self.assertEqual(completed.stdout, "")


if __name__ == "__main__":
    unittest.main()

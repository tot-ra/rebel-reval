#!/usr/bin/env python3
"""Contract tests for the clean-checkout Lower Town load gate."""

from __future__ import annotations

import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
GATE = ROOT / "tools" / "verify_clean_checkout_load.sh"
CHECKED_RUNNER = ROOT / "tools" / "run_godot_checked.sh"
RESTORE_LFS = ROOT / "tools" / "restore_lfs_assets.sh"
WORKFLOW = ROOT / ".github" / "workflows" / "ci.yml"
REPORT = ROOT / "docs" / "reports" / "p0_101_clean_checkout_load_gate.md"


class VerifyCleanCheckoutLoadTest(unittest.TestCase):
    def test_gate_exists_and_is_executable(self) -> None:
        self.assertTrue(GATE.is_file())
        self.assertTrue(GATE.stat().st_mode & stat.S_IXUSR)

    def test_gate_uses_detached_checkout_import_and_focused_load(self) -> None:
        text = GATE.read_text(encoding="utf-8")
        for required in (
            "worktree add --detach",
            "restore_lfs_assets.sh\" runtime",
            "--editor --import --quit",
            "--require-test-summary clean-checkout-mapview",
            "test_lower_town_slice_map",
            "test_map_view_3d_core",
            "test_map_view_3d_mesh",
            "test_map_view_3d_runtime",
            "run_godot_checked.sh",
        ):
            self.assertIn(required, text)
        self.assertIn("worktree remove --force", text)

    def test_gate_keeps_runtime_helpers_and_workflow_contract_stable(self) -> None:
        self.assertTrue(CHECKED_RUNNER.is_file())
        self.assertTrue(RESTORE_LFS.is_file())
        workflow = WORKFLOW.read_text(encoding="utf-8")
        self.assertIn("tools/verify_clean_checkout_load.sh", workflow)
        self.assertIn("Clean-checkout Lower Town parser and MapView3D load gate", workflow)

    def test_gate_failure_cleanup_does_not_touch_repository_files(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            marker = Path(temp_dir) / "marker"
            marker.write_text("keep", encoding="utf-8")
            env = os.environ.copy()
            env.update(
                {
                    "GODOT_BIN": "/definitely/missing/godot",
                    "GODOT_LOG_DIR": str(Path(temp_dir) / "logs"),
                }
            )
            completed = subprocess.run(
                ["bash", str(GATE)],
                cwd=ROOT,
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(completed.returncode, 0)
            self.assertTrue(marker.exists())
            self.assertIn("Clean-checkout load gate failed", completed.stderr)
            self.assertNotIn("git worktree", completed.stderr.lower())

    def test_checked_runner_requires_non_empty_summary(self) -> None:
        text = CHECKED_RUNNER.read_text(encoding="utf-8")
        self.assertIn("--require-test-summary", text)
        self.assertIn("CLEAN_TEST_SUMMARY", text)
        self.assertIn("Resource file not found", text)
        self.assertIn("Failed loading resource", text)

    def test_report_documents_gate_command_and_ci_reference(self) -> None:
        self.assertTrue(REPORT.is_file(), "missing gate report")
        text = REPORT.read_text(encoding="utf-8")
        for required in (
            "tools/verify_clean_checkout_load.sh",
            "Clean-checkout Lower Town parser and MapView3D load gate",
            "test_lower_town_slice_map",
            "test_map_view_3d_core",
            "test_map_view_3d_mesh",
            "test_map_view_3d_runtime",
        ):
            self.assertIn(required, text)

    def test_checked_runner_rejects_parse_error_without_touching_repo(self) -> None:
        godot_bin = os.environ.get("GODOT_BIN", "godot")
        if (
            subprocess.run(["bash", "-lc", f"command -v {godot_bin} >/dev/null"], check=False).returncode
            != 0
            and not Path(godot_bin).is_file()
        ):
            self.skipTest("Godot binary not available for parse-error probe")

        marker = ROOT / "tests" / "python" / "test_verify_clean_checkout_load.py"
        before_mtime = marker.stat().st_mtime_ns

        with tempfile.TemporaryDirectory() as temp_dir:
            project_dir = Path(temp_dir) / "probe"
            project_dir.mkdir()
            (project_dir / "project.godot").write_text(
                "config_version=5\n\n[application]\nconfig/name=\"probe\"\n",
                encoding="utf-8",
            )
            bad_script = project_dir / "bad.gd"
            bad_script.write_text("func broken( -> void:\n\tpass\n", encoding="utf-8")
            env = os.environ.copy()
            env["GODOT_LOG_DIR"] = str(Path(temp_dir) / "logs")
            completed = subprocess.run(
                [
                    "bash",
                    str(CHECKED_RUNNER),
                    "parse-error-probe",
                    "--",
                    godot_bin,
                    "--headless",
                    "--path",
                    str(project_dir),
                    "--script",
                    str(bad_script),
                ],
                cwd=ROOT,
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )

        self.assertNotEqual(completed.returncode, 0)
        combined = f"{completed.stdout}\n{completed.stderr}"
        self.assertRegex(combined, r"(SCRIPT ERROR|Parse Error)")
        self.assertEqual(marker.stat().st_mtime_ns, before_mtime)


if __name__ == "__main__":
    unittest.main()

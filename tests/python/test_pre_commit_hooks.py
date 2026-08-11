#!/usr/bin/env python3
"""Contract tests for repository-owned on-commit lint/test hooks."""

from __future__ import annotations

import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / "tools" / "run_pre_commit_checks.sh"
INSTALLER = ROOT / "tools" / "install_git_hooks.sh"
HOOK_SRC = ROOT / "tools" / "git-hooks" / "pre-commit"
PRE_COMMIT_CONFIG = ROOT / ".pre-commit-config.yaml"


class PreCommitHooksTest(unittest.TestCase):
    def test_hook_scripts_exist_and_are_executable_bits_set(self) -> None:
        for path in (RUNNER, INSTALLER, HOOK_SRC):
            self.assertTrue(path.is_file(), f"missing {path.relative_to(ROOT)}")
            mode = path.stat().st_mode
            self.assertTrue(
                mode & stat.S_IXUSR,
                f"{path.relative_to(ROOT)} must be executable",
            )

    def test_pre_commit_config_points_at_repo_runner(self) -> None:
        text = PRE_COMMIT_CONFIG.read_text(encoding="utf-8")
        self.assertIn("tools/run_pre_commit_checks.sh staged", text)
        self.assertIn("id: gdlint", text)
        self.assertNotIn("id: gdformat", text)

    def test_runner_skips_when_requested(self) -> None:
        env = os.environ.copy()
        env["SKIP_PRE_COMMIT"] = "1"
        completed = subprocess.run(
            ["bash", str(RUNNER), "staged"],
            cwd=ROOT,
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertIn("SKIP_PRE_COMMIT=1", completed.stdout)

    def test_runner_accepts_empty_staged_set(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo = Path(temp_dir)
            subprocess.run(["git", "init"], cwd=repo, check=True, capture_output=True)
            subprocess.run(
                ["git", "config", "user.email", "test@example.com"],
                cwd=repo,
                check=True,
                capture_output=True,
            )
            subprocess.run(
                ["git", "config", "user.name", "Test"],
                cwd=repo,
                check=True,
                capture_output=True,
            )
            # Copy only the runner into a tiny fixture repo and invoke it there so
            # an empty index proves the staged-empty early exit without touching
            # the dirty shared worktree index.
            tools_dir = repo / "tools"
            tools_dir.mkdir()
            runner_copy = tools_dir / "run_pre_commit_checks.sh"
            runner_copy.write_text(RUNNER.read_text(encoding="utf-8"), encoding="utf-8")
            runner_copy.chmod(0o755)

            completed = subprocess.run(
                ["bash", str(runner_copy), "staged"],
                cwd=repo,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            self.assertIn("No staged files", completed.stdout)


if __name__ == "__main__":
    unittest.main()

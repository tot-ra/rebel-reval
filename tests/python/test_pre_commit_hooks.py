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
_GIT_ENV_LEAKS = (
    "GIT_DIR",
    "GIT_WORK_TREE",
    "GIT_INDEX_FILE",
    "GIT_OBJECT_DIRECTORY",
    "GIT_ALTERNATE_OBJECT_DIRECTORIES",
    "GIT_COMMON_DIR",
    "GIT_PREFIX",
)


def _clean_git_env() -> dict[str, str]:
    # `git commit --only` exports GIT_INDEX_FILE into the hook. Fixture repos
    # must not inherit that index or they try to read objects from the parent
    # commit and fail with "unable to read <oid>".
    env = os.environ.copy()
    for key in _GIT_ENV_LEAKS:
        env.pop(key, None)
    return env


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
                env=_clean_git_env(),
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            self.assertIn("No staged files", completed.stdout)

    def test_runner_fires_seam_continuity_gate_on_staged_map_change(self) -> None:
        # R-1117: a staged seam-gate input must invoke the seam form-continuity tool.
        # A fake GODOT_BIN records its arguments so no real engine is needed; the
        # runner's exit code is irrelevant because sibling gates have no fixtures.
        with tempfile.TemporaryDirectory() as temp_dir:
            repo = Path(temp_dir)
            fixture_env = _clean_git_env()
            for args in (
                ["git", "init"],
                ["git", "config", "user.email", "test@example.com"],
                ["git", "config", "user.name", "Test"],
            ):
                subprocess.run(
                    args, cwd=repo, env=fixture_env, check=True, capture_output=True,
                )
            tools_dir = repo / "tools"
            tools_dir.mkdir()
            runner_copy = tools_dir / "run_pre_commit_checks.sh"
            runner_copy.write_text(RUNNER.read_text(encoding="utf-8"), encoding="utf-8")
            runner_copy.chmod(0o755)
            # The mandatory index gate runs before path-selected sibling gates.
            (tools_dir / "verify_import_sidecars.py").write_text(
                (ROOT / "tools" / "verify_import_sidecars.py").read_text(encoding="utf-8"),
                encoding="utf-8",
            )
            # The runner imports this helper before the map gates run.
            helper_dir = repo / "tests" / "python"
            helper_dir.mkdir(parents=True)
            (helper_dir / "test_magic_budget.py").write_text(
                (ROOT / "tests" / "python" / "test_magic_budget.py").read_text(encoding="utf-8"),
                encoding="utf-8",
            )
            log = repo / "godot_calls.log"
            fake = repo / "fake_godot.sh"
            fake.write_text(f'#!/usr/bin/env bash\necho "$@" >> "{log}"\n', encoding="utf-8")
            fake.chmod(0o755)
            # Staging a map would also trigger sibling gates that need their own
            # fixtures, so stage the budget (same trigger list) and assert the map
            # triggers textually below.
            budget = repo / "docs" / "data" / "seam_continuity_budget.json"
            budget.parent.mkdir(parents=True)
            budget.write_text("{}\n", encoding="utf-8")
            subprocess.run(
                ["git", "add", "docs/data/seam_continuity_budget.json"],
                cwd=repo,
                env=fixture_env,
                check=True,
                capture_output=True,
            )
            env = _clean_git_env()
            env["GODOT_BIN"] = str(fake)
            completed = subprocess.run(
                ["bash", str(runner_copy), "staged"],
                cwd=repo,
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            calls = log.read_text(encoding="utf-8") if log.exists() else ""
            self.assertIn("tools/verify_seam_continuity.gd", calls, completed.stdout + completed.stderr)
            runner_text = RUNNER.read_text(encoding="utf-8")
            block = runner_text[runner_text.index("R-1117 / UF-08") :]
            self.assertIn('any_staged_path "content/maps"', block.split("then", 1)[0])

    def test_clean_git_env_strips_commit_only_index(self) -> None:
        previous = os.environ.get("GIT_INDEX_FILE")
        os.environ["GIT_INDEX_FILE"] = "/tmp/fake-commit-only-index"
        try:
            env = _clean_git_env()
            self.assertNotIn("GIT_INDEX_FILE", env)
            self.assertNotIn("GIT_DIR", env)
        finally:
            if previous is None:
                os.environ.pop("GIT_INDEX_FILE", None)
            else:
                os.environ["GIT_INDEX_FILE"] = previous

    def test_runner_rejects_unignored_class_name_under_build_tmp_guard(self) -> None:
        # Why: R-925's guard runs before the empty-staged exit. Prove it in a
        # fixture repo so a dirty shared worktree and live build/ stay untouched.
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
            tools_dir = repo / "tools"
            tools_dir.mkdir()
            runner_copy = tools_dir / "run_pre_commit_checks.sh"
            runner_copy.write_text(RUNNER.read_text(encoding="utf-8"), encoding="utf-8")
            runner_copy.chmod(0o755)

            planted = repo / "build" / "tmp_guard" / "tmp_guard_scratch.gd"
            planted.parent.mkdir(parents=True)
            planted.write_text(
                "class_name TmpGuardScratch\nextends Node\n",
                encoding="utf-8",
            )

            env = _clean_git_env()
            failed = subprocess.run(
                ["bash", str(runner_copy), "staged"],
                cwd=repo,
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            failed_text = failed.stdout + failed.stderr
            self.assertNotEqual(failed.returncode, 0, failed_text)
            self.assertIn("CLASS CACHE GUARD", failed_text)
            self.assertIn("build/tmp_guard/tmp_guard_scratch.gd", failed_text)

            (planted.parent / ".gdignore").write_text("", encoding="utf-8")
            self.assertFalse(
                (repo / "build" / ".gdignore").exists(),
                "folder .gdignore must clear the guard without ignoring all of build/",
            )
            passed = subprocess.run(
                ["bash", str(runner_copy), "staged"],
                cwd=repo,
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            passed_text = passed.stdout + passed.stderr
            self.assertEqual(passed.returncode, 0, passed_text)
            self.assertIn("No staged files", passed.stdout)
            self.assertNotIn("CLASS CACHE GUARD", passed_text)

    def test_runner_rejects_broken_import_pairs_even_on_deletion_only_commit(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo = Path(temp_dir)
            env = _clean_git_env()
            env.pop("SKIP_PRE_COMMIT", None)

            def git(*args: str) -> None:
                subprocess.run(
                    ["git", *args], cwd=repo, env=env, check=True, capture_output=True,
                )

            git("init")
            git("config", "user.email", "test@example.com")
            git("config", "user.name", "Test")
            tools = repo / "tools"
            tools.mkdir()
            runner = tools / "run_pre_commit_checks.sh"
            runner.write_text(RUNNER.read_text(encoding="utf-8"), encoding="utf-8")
            (tools / "verify_import_sidecars.py").write_text(
                (ROOT / "tools/verify_import_sidecars.py").read_text(encoding="utf-8"),
                encoding="utf-8",
            )
            # Enough context for the runner's always-imported path selector;
            # no heavyweight content/budget fixture is needed for media paths.
            helper = repo / "tests/python/test_magic_budget.py"
            helper.parent.mkdir(parents=True)
            helper.write_text(
                "def magic_budget_paths_trigger(paths):\n    return False\n",
                encoding="utf-8",
            )
            (repo / "tests/__init__.py").touch()
            (repo / "tests/python/__init__.py").touch()

            def run(mode: str = "staged") -> subprocess.CompletedProcess:
                return subprocess.run(
                    ["bash", str(runner), mode], cwd=repo, env=env,
                    capture_output=True, text=True, check=False,
                )

            source = repo / "sky.png"
            sidecar = repo / "sky.png.import"
            source.write_bytes(b"fixture")
            sidecar.write_text("fixture", encoding="utf-8")
            git("add", "sky.png")
            failed = run()
            self.assertEqual(failed.returncode, 1, failed.stdout + failed.stderr)
            self.assertIn("missing import sidecar", failed.stderr)
            git("add", "sky.png.import")
            passed = run()
            self.assertEqual(passed.returncode, 0, passed.stdout + passed.stderr)
            self.assertIn("Godot import sidecar pairs", passed.stdout)
            git("-c", "core.hooksPath=/dev/null", "commit", "-m", "Fixture pair")
            git("rm", "sky.png")
            failed = run()
            self.assertEqual(failed.returncode, 1, failed.stdout + failed.stderr)
            self.assertIn("orphan import sidecar", failed.stderr)
            self.assertNotIn("No staged files", failed.stdout)
            failed_all = run("all")
            self.assertEqual(failed_all.returncode, 1)
            self.assertIn("orphan import sidecar", failed_all.stderr)
            git("rm", "sky.png.import")
            passed = run()
            self.assertEqual(passed.returncode, 0, passed.stdout + passed.stderr)
            self.assertIn("Import sidecar check passed", passed.stdout)

    def test_runner_rejects_unknown_mode(self) -> None:
        completed = subprocess.run(
            ["bash", str(RUNNER), "unexpected"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 2, completed.stderr)
        self.assertIn("Usage:", completed.stderr)
        self.assertEqual(completed.stdout, "")

    def test_runner_documents_path_aware_python_and_godot_resolution(self) -> None:
        text = RUNNER.read_text(encoding="utf-8")
        for required in (
            "tests.python.test_pre_commit_hooks",
            "tests.python.test_project_configuration",
            "tests.python.test_campaign_save_fixtures",
            "tests.python.test_verify_clean_checkout_load",
            "content/demo",
            "GODOT_BIN",
            "/Applications/Godot.app/Contents/MacOS/Godot",
            "path-aware Python unit tests",
            "focused Godot tests",
            "queue_python_module_for_path",
            "verify_asset_lint.py",
            "live-inventory modules",
        ):
            self.assertIn(required, text)


if __name__ == "__main__":
    unittest.main()

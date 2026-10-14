"""Staged-tree behavior for the pre-commit documentation runner."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
sys.path.insert(0, str(TOOLS))
import docs_index  # noqa: E402


class CheckStagedDocsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.env = os.environ.copy()
        for key in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_OBJECT_DIRECTORY", "GIT_COMMON_DIR"):
            self.env.pop(key, None)
        for args in (
            ["git", "init", "-q"],
            ["git", "config", "user.name", "Fixture"],
            ["git", "config", "user.email", "fixture@example.com"],
        ):
            subprocess.run(args, cwd=self.root, env=self.env, check=True, capture_output=True)

        tools_dir = self.root / "tools"
        tools_dir.mkdir()
        shutil.copy2(TOOLS / "check_staged_docs.py", tools_dir)
        for relative in (
            "docs_index.py",
            "generate_active_docs_report.py",
            "active_docs_report_common.py",
            "active_docs_report_checks.py",
            "active_docs_report_links.py",
            "active_docs_report_fixtures.py",
        ):
            shutil.copy2(TOOLS / relative, tools_dir / relative)

        # docs_index requires its configured index pages. Link all of them
        # directly from README so the fixture stays intentionally tiny.
        root_links = []
        for index, _scope in docs_index.INDEXES:
            index_path = self.root / index
            index_path.parent.mkdir(parents=True, exist_ok=True)
            index_path.write_text(f"# {Path(index).stem.title()}\n", encoding="utf-8")
            root_links.append(f"[{index}]({index})")
        (self.root / "README.md").write_text(
            "# Fixture\n\n" + "\n".join(root_links) + "\n[Canon](docs/CANON.md)\n[Agent guide](AGENTS.md)\n[Tasks](TODO.md)\n",
            encoding="utf-8",
        )
        (self.root / "AGENTS.md").write_text("# Agent guide\n", encoding="utf-8")
        (self.root / "TODO.md").write_text("# Tasks\n", encoding="utf-8")
        (self.root / "docs/CANON.md").write_text("# Canon\n", encoding="utf-8")
        subprocess.run(["git", "add", "--all"], cwd=self.root, env=self.env, check=True, capture_output=True)

        subprocess.run([sys.executable, "tools/docs_index.py"], cwd=self.root, env=self.env, check=True, capture_output=True)
        subprocess.run(["git", "add", "--all"], cwd=self.root, env=self.env, check=True, capture_output=True)
        subprocess.run(
            [sys.executable, "tools/generate_active_docs_report.py"],
            cwd=self.root,
            env=self.env,
            check=True,
            capture_output=True,
        )
        subprocess.run(["git", "add", "--all"], cwd=self.root, env=self.env, check=True, capture_output=True)
        # The report's excluded inventory includes the generated report once
        # that Markdown file is tracked, so regenerate after the first add.
        subprocess.run(
            [sys.executable, "tools/generate_active_docs_report.py"],
            cwd=self.root,
            env=self.env,
            check=True,
            capture_output=True,
        )
        subprocess.run(["git", "add", "--all"], cwd=self.root, env=self.env, check=True, capture_output=True)
        subprocess.run([sys.executable, "tools/docs_index.py"], cwd=self.root, env=self.env, check=True, capture_output=True)
        subprocess.run(["git", "add", "--all"], cwd=self.root, env=self.env, check=True, capture_output=True)

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def run_check(self, *checks: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, "tools/check_staged_docs.py", "--root", str(self.root), *checks],
            cwd=ROOT,
            env=self.env,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_untracked_markdown_is_ignored_but_staged_broken_link_fails(self) -> None:
        (self.root / "docs" / "untracked-orphan.md").write_text("# Local note\n", encoding="utf-8")
        passed = self.run_check("active", "index")
        self.assertEqual(passed.returncode, 0, passed.stdout + passed.stderr)

        canon = self.root / "docs" / "CANON.md"
        canon.write_text(canon.read_text(encoding="utf-8") + "\n[Unstaged broken link](missing-worktree-target.md)\n", encoding="utf-8")
        passed = self.run_check("active")
        self.assertEqual(passed.returncode, 0, passed.stdout + passed.stderr)

        readme = self.root / "README.md"
        readme.write_text(readme.read_text(encoding="utf-8") + "\n[Broken](missing-staged-target.md)\n", encoding="utf-8")
        subprocess.run(["git", "add", "README.md"], cwd=self.root, env=self.env, check=True, capture_output=True)
        failed = self.run_check("active")
        self.assertNotEqual(failed.returncode, 0, failed.stdout + failed.stderr)
        self.assertIn("active Markdown docs contain 1 issue(s)", failed.stdout + failed.stderr)


if __name__ == "__main__":
    unittest.main()

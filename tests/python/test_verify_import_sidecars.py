"""Fixture coverage for the index-only Godot import metadata gate (R-1453)."""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from tools.verify_import_sidecars import IMPORTABLE_SUFFIXES, validate_paths

ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tools" / "verify_import_sidecars.py"


def clean_git_env() -> dict[str, str]:
    env = os.environ.copy()
    for key in (
        "GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_OBJECT_DIRECTORY",
        "GIT_ALTERNATE_OBJECT_DIRECTORIES", "GIT_COMMON_DIR", "GIT_PREFIX",
    ):
        env.pop(key, None)
    return env


class ImportSidecarPathsTest(unittest.TestCase):
    def test_complete_pairs_for_every_known_format(self) -> None:
        for suffix in IMPORTABLE_SUFFIXES:
            with self.subTest(suffix=suffix):
                source = "assets/source" + suffix
                self.assertEqual(validate_paths([source, source + ".import"]), [])

    def test_missing_sidecar_case_unicode_and_spaces(self) -> None:
        source = "assets/Õhtu sky.PNG"
        self.assertEqual(validate_paths([source]), [f"missing import sidecar: {source}.import"])

    def test_ancestor_gdignore_skips_only_its_subtree(self) -> None:
        self.assertEqual(validate_paths([
            "docs/.gdignore", "docs/evidence/nested/plate.png", "docs_other/plate.png",
        ]), ["missing import sidecar: docs_other/plate.png.import"])

    def test_root_gdignore_skips_missing_but_not_orphan(self) -> None:
        self.assertEqual(validate_paths([
            ".gdignore", "assets/source.png", "assets/gone.png.import",
        ]), ["orphan import sidecar: assets/gone.png.import (source not in Git index)"])

    def test_orphan_for_unknown_format_and_ignored_dir(self) -> None:
        self.assertEqual(validate_paths([
            "docs/.gdignore", "docs/gone.custom.import",
        ]), ["orphan import sidecar: docs/gone.custom.import (source not in Git index)"])

    def test_native_resources_and_csv_manifests_need_no_sidecar(self) -> None:
        self.assertEqual(validate_paths([
            "project.godot", "assets/SOURCES.csv", "content/table.json",
            "scene.tscn", "material.tres", "script.gd", "shader.gdshader", "script.gd.uid",
        ]), [])

    def test_deterministic_unique_diagnostics(self) -> None:
        paths = ["z.png", "a.png", "a.png"]
        self.assertEqual(validate_paths(paths), validate_paths(reversed(paths)))
        self.assertEqual(len(validate_paths(paths)), 2)


class ImportSidecarIndexTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.env = clean_git_env()
        self.git("init")

    def git(self, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            ["git", *args], cwd=self.repo, env=self.env,
            capture_output=True, text=True, check=True,
        )

    def write(self, name: str, text: str = "fixture") -> None:
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def check(self) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, str(CHECKER), "--root", str(self.repo)],
            env=self.env, capture_output=True, text=True, check=False,
        )

    def test_untracked_local_counterpart_does_not_satisfy_index(self) -> None:
        self.write("assets/sky.png")
        self.write("assets/sky.png.import")
        self.git("add", "assets/sky.png")
        self.assertEqual(self.check().returncode, 1)
        self.git("add", "assets/sky.png.import")
        self.assertEqual(self.check().returncode, 0)
        self.git("rm", "--cached", "-f", "assets/sky.png")
        result = self.check()
        self.assertEqual(result.returncode, 1)
        self.assertIn("orphan import sidecar", result.stderr)
        self.assertTrue((self.repo / "assets/sky.png").is_file())

    def test_indexed_ignore_not_worktree_ignore(self) -> None:
        self.write("docs/nested/sky.png")
        self.write("docs/.gdignore", "")
        self.git("add", "docs/nested/sky.png")
        self.assertEqual(self.check().returncode, 1)
        self.git("add", "docs/.gdignore")
        (self.repo / "docs/.gdignore").unlink()
        self.assertEqual(self.check().returncode, 0)

    def test_untracked_or_worktree_deleted_media_is_not_index_inventory(self) -> None:
        self.write("untracked.png")
        self.write("sky.png")
        self.write("sky.png.import")
        self.git("add", "sky.png", "sky.png.import")
        (self.repo / "sky.png").unlink()
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("passed", result.stdout)

    def test_index_preserves_non_ascii_and_newline_paths(self) -> None:
        source = "assets/Õhtu sky\nplate.png"
        self.write(source)
        self.write(source + ".import")
        self.git("add", ".")
        # Sanitize inherited Git variables for direct function calls as well.
        result = subprocess.run(
            [sys.executable, "-c", (
                "from pathlib import Path; from tools.verify_import_sidecars import tracked_paths; "
                "import sys; print(len(tracked_paths(Path(sys.argv[1]))))"
            ), str(self.repo)], cwd=ROOT, env=self.env,
            capture_output=True, text=True, check=True,
        )
        self.assertEqual(result.stdout.strip(), "2")
        self.assertEqual(self.check().returncode, 0)

    def test_non_repository_reports_operational_failure(self) -> None:
        with tempfile.TemporaryDirectory() as other:
            result = subprocess.run(
                [sys.executable, str(CHECKER), "--root", other],
                env=self.env, capture_output=True, text=True, check=False,
            )
        self.assertEqual(result.returncode, 2)
        self.assertIn("could not read Git index", result.stderr)


if __name__ == "__main__":
    unittest.main()

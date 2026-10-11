"""Tests for tools/docs_index.py: generated index blocks and README reachability."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import docs_index  # noqa: E402


class DocsIndexTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        subprocess.run(["git", "init", "-q"], cwd=self.root, check=True)
        self._patches = [
            mock.patch.object(docs_index, "ROOT", self.root),
            mock.patch.object(
                docs_index,
                "INDEXES",
                [("docs/README.md", "docs"), ("docs/sub/README.md", "docs/sub")],
            ),
        ]
        for patch in self._patches:
            patch.start()

    def tearDown(self) -> None:
        for patch in self._patches:
            patch.stop()
        self._tmp.cleanup()

    def write(self, rel: str, text: str) -> None:
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def run_tool(self, *args: str) -> int:
        with mock.patch.object(sys, "argv", ["docs_index.py", *args]):
            with mock.patch("builtins.print"):
                return docs_index.main()

    def test_orphan_fails_check_until_indexed(self) -> None:
        self.write("README.md", "# Root\n\n[hub](docs/README.md)\n")
        self.write("docs/README.md", "# Hub\n")
        self.write("docs/sub/README.md", "# Sub\n")
        self.write("docs/sub/feature.md", "# Feature page\n")
        self.write("docs/manual.md", "# Manual\n")

        self.assertEqual(self.run_tool("--check"), 1)
        self.assertEqual(self.run_tool(), 0)
        self.assertEqual(self.run_tool("--check"), 0)

        hub = (self.root / "docs/README.md").read_text(encoding="utf-8")
        self.assertIn("[Manual](manual.md)", hub)
        self.assertIn("[Sub](sub/README.md)", hub)
        self.assertNotIn("feature.md", hub, "nested index owns its own files")
        sub = (self.root / "docs/sub/README.md").read_text(encoding="utf-8")
        self.assertIn("[Feature page](feature.md)", sub)

    def test_manual_links_are_not_repeated(self) -> None:
        self.write("README.md", "[hub](docs/)\n")
        self.write("docs/README.md", "# Hub\n\n[Linked by hand](./manual.md)\n")
        self.write("docs/sub/README.md", "# Sub\n")
        self.write("docs/manual.md", "no heading here\n")

        self.assertEqual(self.run_tool(), 0)
        hub = (self.root / "docs/README.md").read_text(encoding="utf-8")
        self.assertEqual(hub.count("manual.md"), 1)

    def test_title_falls_back_to_file_name(self) -> None:
        self.write("docs/old_town_well.md", "plain text\n")
        self.assertEqual(docs_index.title_of("docs/old_town_well.md"), "Old Town Well")
        self.write("docs/h2.md", "## Second level\n")
        self.assertEqual(docs_index.title_of("docs/h2.md"), "Second level")


if __name__ == "__main__":
    unittest.main()

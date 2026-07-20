#!/usr/bin/env python3
"""Tests for active Markdown document discovery."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from active_docs_report_common import collect_active_docs  # noqa: E402


class ActiveDocsReportCommonTest(unittest.TestCase):
    def test_generated_hidden_cache_markdown_is_not_discovered(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / "docs" / ".pytest_cache").mkdir(parents=True)
            root_cache_doc = root / ".pytest_cache" / "README.md"
            root_cache_doc.parent.mkdir()
            root_cache_doc.write_text("# Generated pytest cache\n", encoding="utf-8")
            docs_cache_doc = root / "docs" / ".pytest_cache" / "README.md"
            docs_cache_doc.write_text("# Generated pytest cache\n", encoding="utf-8")
            tool_cache_doc = root / "docs" / "__pycache__" / "README.md"
            tool_cache_doc.parent.mkdir()
            tool_cache_doc.write_text("# Generated Python cache\n", encoding="utf-8")
            active_doc = root / "docs" / "guide.md"
            active_doc.write_text("# Active guide\n", encoding="utf-8")

            active_docs, excluded_docs = collect_active_docs(root)

            self.assertIn(active_doc, active_docs)
            self.assertNotIn(root_cache_doc, active_docs)
            self.assertNotIn(root_cache_doc, excluded_docs)
            self.assertNotIn(docs_cache_doc, active_docs)
            self.assertNotIn(docs_cache_doc, excluded_docs)
            self.assertNotIn(tool_cache_doc, active_docs)
            self.assertNotIn(tool_cache_doc, excluded_docs)


if __name__ == "__main__":
    unittest.main()

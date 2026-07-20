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

from active_docs_report_checks import check_missing_references  # noqa: E402
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

    def test_missing_reference_check_only_matches_explicit_placeholders(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            docs = root / "docs"
            docs.mkdir()
            policy = docs / "policy.md"
            policy.write_text(
                "# Policy\n\n"
                "A temporary file must not replace the missing source.\n",
                encoding="utf-8",
            )
            draft = docs / "draft.md"
            draft.write_text("# Draft\n\n- Evidence: source needed.\n", encoding="utf-8")

            issues = check_missing_references([policy, draft], root)

            self.assertEqual(len(issues), 1)
            self.assertEqual(issues[0].path, "docs/draft.md")
            self.assertEqual(issues[0].code, "MISSING_REFERENCE")


if __name__ == "__main__":
    unittest.main()

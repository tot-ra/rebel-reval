#!/usr/bin/env python3
"""Tests for TODO.md priority summary regeneration."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from update_todo_counts import build_table, rewrite_table, scan_todo  # noqa: E402


class UpdateTodoCountsTest(unittest.TestCase):
    def test_scan_counts_open_done_and_suffix_task_ids(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            todo = Path(temp_dir) / "TODO.md"
            todo.write_text(
                "\n".join(
                    [
                        "# TODO",
                        "",
                        "<!-- Quick-reference counts updated on every structural change -->",
                        "| Priority | Open | Done | Notes |",
                        "|----------|-----:|-----:|-------|",
                        "| P0 |  ~1 |  ~1 | stale |",
                        "",
                        "- [x] D-004a | deps: none | deliverable: demo follow-up | verify: passes",
                        "- [ ] P0-070 | deps: P0-078 | deliverable: storage migration | verify: passes",
                        "- [x] P1-031a | deps: P1-031 | deliverable: map click travel | verify: passes",
                        "- [ ] P3-011 | deps: P1-030 | deliverable: hardware target | verify: passes",
                    ]
                ),
                encoding="utf-8",
            )

            counts = scan_todo(todo)

            self.assertEqual(counts["D"].done_count, 1)
            self.assertEqual(counts["P0"].open_count, 1)
            self.assertEqual(counts["P1"].done_count, 1)
            self.assertEqual(counts["P"].open_count, 1)

    def test_rewrite_table_preserves_task_rows(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            todo = Path(temp_dir) / "TODO.md"
            task_row = (
                "- [ ] P0-999 | deps: none | deliverable: sample | verify: sample"
            )
            todo.write_text(
                "\n".join(
                    [
                        "# TODO",
                        "",
                        "<!-- Quick-reference counts updated on every structural change -->",
                        "| Priority | Open | Done | Notes |",
                        "|----------|-----:|-----:|-------|",
                        "| P0 |  ~9 |  ~9 | stale |",
                        "",
                        task_row,
                        "",
                        "## Notes",
                        "unchanged",
                    ]
                ),
                encoding="utf-8",
            )

            table = build_table(scan_todo(todo))
            self.assertTrue(rewrite_table(todo, table))

            updated = todo.read_text(encoding="utf-8")
            self.assertIn(task_row, updated)
            self.assertIn("## Notes", updated)
            self.assertIn("unchanged", updated)
            self.assertIn("<!-- Quick-reference counts", updated)


if __name__ == "__main__":
    unittest.main()

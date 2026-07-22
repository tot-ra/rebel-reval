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

from update_todo_counts import Counters, build_table, rewrite_table, scan_todo  # noqa: E402


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
            self.assertEqual(counts["P3"].open_count, 1)

    def test_scan_buckets_suffix_task_ids_into_act_bands(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            todo = Path(temp_dir) / "TODO.md"
            todo.write_text(
                "\n".join(
                    [
                        "# TODO",
                        "",
                        "- [ ] P4-027a | deps: P4-027 | deliverable: tower slice | verify: passes",
                        "- [x] P5-008 | deps: none | deliverable: enemy archetypes | verify: passes",
                        "- [ ] P6-001 | deps: P5-010 | deliverable: act 3 design | verify: passes",
                    ]
                ),
                encoding="utf-8",
            )

            counts = scan_todo(todo)

            self.assertEqual(counts["P4"].open_count, 1)
            self.assertEqual(counts["P5"].done_count, 1)
            self.assertEqual(counts["P6"].open_count, 1)

    def test_build_table_lists_p3_through_p6_rows(self) -> None:
        counts = {
            "P0": Counters(open_count=1, done_count=2),
            "P3": Counters(open_count=11, done_count=0),
            "P4": Counters(open_count=40, done_count=3),
            "P5": Counters(open_count=9, done_count=1),
            "P6": Counters(open_count=8, done_count=0),
        }
        table = build_table(counts)
        self.assertIn("| P3 |", table)
        self.assertIn("| P4 |", table)
        self.assertIn("| P5 |", table)
        self.assertIn("| P6 |", table)
        self.assertNotIn("| P3+ |", table)

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

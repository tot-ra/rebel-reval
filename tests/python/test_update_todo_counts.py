#!/usr/bin/env python3
"""Tests for TODO.md priority summary regeneration."""

from __future__ import annotations

import subprocess
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
                        "- [X] P0-071 | deps: P0-078 | deliverable: uppercase completion marker | verify: passes",
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
            self.assertEqual(counts["P0"].done_count, 1)
            self.assertEqual(counts["P1"].done_count, 1)
            self.assertEqual(counts["P3"].open_count, 1)

    def test_scan_counts_indented_checklist_rows(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            todo = Path(temp_dir) / "TODO.md"
            todo.write_text(
                "\n".join(
                    [
                        "# TODO",
                        "",
                        "  - [ ] P2-001 | deps: none | deliverable: nested open | verify: passes",
                        "    - [x] P2-002 | deps: P2-001 | deliverable: nested done | verify: passes",
                    ]
                ),
                encoding="utf-8",
            )

            counts = scan_todo(todo)

            self.assertEqual(counts["P2"].open_count, 1)
            self.assertEqual(counts["P2"].done_count, 1)

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

    def test_scan_groups_future_priority_bands_into_p7_plus(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            todo = Path(temp_dir) / "TODO.md"
            todo.write_text(
                "\n".join(
                    [
                        "# TODO",
                        "",
                        "- [ ] P7-001 | deps: none | deliverable: future task | verify: passes",
                        "- [x] P8-002 | deps: P7-001 | deliverable: later task | verify: passes",
                    ]
                ),
                encoding="utf-8",
            )

            counts = scan_todo(todo)
            table = build_table(counts)

            self.assertEqual(counts["P7+"].open_count, 1)
            self.assertEqual(counts["P7+"].done_count, 1)
            self.assertIn("| P7+ |", table)
            self.assertNotIn("| P7 |", table)
            self.assertNotIn("| P8 |", table)

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

    def test_cli_path_scans_and_rewrites_selected_fixture(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            todo = Path(temp_dir) / "TODO.md"
            todo.write_text(
                "\n".join(
                    [
                        "# Fixture TODO",
                        "",
                        "<!-- Quick-reference counts updated on every structural change -->",
                        "| Priority | Open | Done | Notes |",
                        "|----------|-----:|-----:|-------|",
                        "| P0 | stale | stale | stale |",
                        "",
                        "- [ ] P2-001 | deps: none | deliverable: fixture task | verify: passes",
                        "- [x] P2-002 | deps: P2-001 | deliverable: completed fixture | verify: passes",
                        "",
                        "## Notes",
                        "keep this content",
                    ]
                ),
                encoding="utf-8",
            )
            before_root = (ROOT / "TODO.md").read_bytes()

            command = [
                sys.executable,
                str(TOOLS / "update_todo_counts.py"),
                "--path",
                str(todo),
                "--write",
            ]
            result = subprocess.run(command, capture_output=True, text=True, check=False)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("| P2 |", result.stdout)
            self.assertIn("-> TODO.md summary table rewritten.", result.stdout)
            updated = todo.read_text(encoding="utf-8")
            self.assertIn("| P2 |", updated)
            self.assertIn("|     1  |     1  |", updated)
            self.assertIn("Vertical-slice production (playable MVP)", updated)
            self.assertIn("## Notes\nkeep this content", updated)
            self.assertEqual(before_root, (ROOT / "TODO.md").read_bytes())

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

    def test_rewrite_table_preserves_crlf_line_endings(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            todo = Path(temp_dir) / "TODO.md"
            todo.write_bytes(
                "\r\n".join(
                    [
                        "# TODO",
                        "",
                        "<!-- Quick-reference counts updated on every structural change -->",
                        "| Priority | Open | Done | Notes |",
                        "|----------|-----:|-----:|-------|",
                        "| P0 | stale | stale | stale |",
                        "",
                        "- [ ] P0-999 | deps: none | deliverable: sample | verify: sample",
                    ]
                ).encode("utf-8")
            )

            table = build_table({"P0": Counters(open_count=1, done_count=0)})

            self.assertTrue(rewrite_table(todo, table))
            updated = todo.read_bytes()
            self.assertNotIn(b"\n", updated.replace(b"\r\n", b""))
            self.assertIn(b"\r\n| P0 |     1  |     0  |", updated)


    def test_rewrite_table_preserves_cr_only_line_endings(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            todo = Path(temp_dir) / "TODO.md"
            todo.write_bytes(
                "\r".join(
                    [
                        "# TODO",
                        "",
                        "<!-- Quick-reference counts updated on every structural change -->",
                        "| Priority | Open | Done | Notes |",
                        "|----------|-----:|-----:|-------|",
                        "| P0 | stale | stale | stale |",
                        "",
                        "- [ ] P0-999 | deps: none | deliverable: sample | verify: sample",
                    ]
                ).encode("utf-8")
            )

            table = build_table({"P0": Counters(open_count=1, done_count=0)})

            self.assertTrue(rewrite_table(todo, table))
            updated = todo.read_bytes()
            self.assertNotIn(b"\n", updated)
            self.assertIn(b"\r| P0 |     1  |     0  |", updated)
            self.assertIn(b"\r- [ ] P0-999", updated)

    def test_rewrite_table_fallback_handles_cr_only_line_endings(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            todo = Path(temp_dir) / "TODO.md"
            todo.write_bytes(
                "\r".join(
                    [
                        "# TODO",
                        "",
                        "| Priority | Open | Done | Notes |",
                        "|----------|-----:|-----:|-------|",
                        "| P0 | stale | stale | stale |",
                        "",
                        "- [ ] P0-999 | deps: none | deliverable: sample | verify: sample",
                    ]
                ).encode("utf-8")
            )

            table = build_table({"P0": Counters(open_count=1, done_count=0)})

            self.assertTrue(rewrite_table(todo, table))
            updated = todo.read_bytes()
            self.assertNotIn(b"\n", updated)
            self.assertIn(b"<!-- Quick-reference counts", updated)
            self.assertIn(b"\r| P0 |     1  |     0  |", updated)

    def test_rewrite_table_handles_missing_final_newline(self) -> None:
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
                        "| P0 | stale | stale | stale |",
                    ]
                ),
                encoding="utf-8",
            )
            original = todo.read_bytes()
            self.assertFalse(original.endswith(b"\n"))

            table = build_table({"P0": Counters(open_count=2, done_count=1)})

            self.assertTrue(rewrite_table(todo, table))
            updated = todo.read_bytes()
            self.assertFalse(updated.endswith(b"\n"))
            self.assertIn(b"|     2  |     1  |", updated)
            self.assertNotEqual(original, updated)

    def test_cli_rejects_task_row_without_required_fields(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            todo = Path(temp_dir) / "TODO.md"
            todo.write_text(
                "\n".join(
                    [
                        "# Fixture TODO",
                        "",
                        "- [ ] P2-001 | verify: this row is missing task fields",
                    ]
                ),
                encoding="utf-8",
            )

            command = [
                sys.executable,
                str(TOOLS / "update_todo_counts.py"),
                "--path",
                str(todo),
            ]
            result = subprocess.run(command, capture_output=True, text=True, check=False)

            self.assertEqual(result.returncode, 1)
            self.assertIn("is unparseable", result.stderr)
            self.assertIn("line 3", result.stderr)
            self.assertIn("missing `deps:` and `deliverable:` fields", result.stderr)
            self.assertEqual(
                todo.read_text(encoding="utf-8"),
                "# Fixture TODO\n\n- [ ] P2-001 | verify: this row is missing task fields",
            )


if __name__ == "__main__":
    unittest.main()

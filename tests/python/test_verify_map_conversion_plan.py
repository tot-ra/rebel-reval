#!/usr/bin/env python3
"""Tests for tools/verify_map_conversion_plan.py."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS_DIR = ROOT / "tools"
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from verify_map_conversion_plan import (  # noqa: E402
    PLAN,
    SCENE_INVENTORY,
    TODO,
    main,
    parse_plan,
    repository_scenes,
    validate_map_conversion_plan,
)


class VerifyMapConversionPlanTest(unittest.TestCase):
    def test_repository_plan_has_exact_disposition_and_detail_coverage(self) -> None:
        index_rows, detail_rows = parse_plan(PLAN)
        repository = repository_scenes(ROOT)
        self.assertEqual({row.scene for row in index_rows}, repository)
        self.assertEqual(
            {row.scene for row in detail_rows},
            {row.scene for row in index_rows if row.role in {"level", "map", "event"}},
        )

    def test_repository_plan_passes_via_main(self) -> None:
        self.assertEqual(main([]), 0)

    def test_missing_disposition_is_reported(self) -> None:
        original = PLAN.read_text(encoding="utf-8")
        bad = original.replace(
            "| `scenes/world/viljandi_castle.tscn` | level | `archive` |",
            "| `scenes/world/not_viljandi_castle.tscn` | level | `archive` |",
            1,
        )
        errors = self._validate_with(plan=bad)
        self.assertTrue(any("plan disposition missing scene coverage" in error.message for error in errors))
        self.assertTrue(any("plan disposition has unknown scenes" in error.message for error in errors))

    def test_missing_detailed_specification_is_reported(self) -> None:
        original = PLAN.read_text(encoding="utf-8")
        detail = next(
            line
            for line in original.splitlines()
            if line.startswith("| `scenes/events/paldiski.tscn` | `archive` |")
        )
        errors = self._validate_with(plan=original.replace(detail + "\n", "", 1))
        self.assertTrue(any("missing detailed specifications" in error.message for error in errors))

    def test_missing_source_reference_is_reported(self) -> None:
        original = PLAN.read_text(encoding="utf-8")
        bad = original.replace("`scenes/world/haapsalu_castle.md`", "`scenes/world/missing.md`", 1)
        errors = self._validate_with(plan=bad)
        self.assertTrue(any("missing source reference `scenes/world/missing.md`" in error.message for error in errors))

    def test_missing_strict_task_is_reported(self) -> None:
        original = TODO.read_text(encoding="utf-8")
        task_line = next(
            line for line in original.splitlines()
            if line.startswith(("- [ ] P2-020 |", "- [x] P2-020 |"))
        )
        errors = self._validate_with(todo=original.replace(task_line + "\n", "", 1))
        self.assertTrue(any("missing strict TODO task `P2-020`" in error.message for error in errors))

    def test_slice_gate_must_depend_on_parity_gate(self) -> None:
        original = TODO.read_text(encoding="utf-8")
        bad = original.replace(",P2-021 | deliverable: complete 30-45 minute vertical-slice flow", " | deliverable: complete 30-45 minute vertical-slice flow", 1)
        errors = self._validate_with(todo=bad)
        self.assertTrue(any("P2-012` must depend on parity gate `P2-021" in error.message for error in errors))

    def test_inventory_drift_is_reported(self) -> None:
        original = SCENE_INVENTORY.read_text(encoding="utf-8")
        row = next(
            line
            for line in original.splitlines()
            if "`scenes/map_prototype/smithy_courtyard.tscn`" in line
        )
        errors = self._validate_with(inventory=original.replace(row + "\n", "", 1))
        self.assertTrue(any("scene inventory missing scene coverage" in error.message for error in errors))

    def test_duplicate_inventory_row_is_reported(self) -> None:
        original = SCENE_INVENTORY.read_text(encoding="utf-8")
        row = next(
            line
            for line in original.splitlines()
            if "`scenes/map_prototype/smithy_courtyard.tscn`" in line
        )
        errors = self._validate_with(inventory=original.replace(row, row + "\n" + row, 1))
        self.assertTrue(any("duplicate scene inventory rows" in error.message for error in errors))

    def _validate_with(
        self, *, plan: str | None = None, inventory: str | None = None, todo: str | None = None
    ) -> list:
        with tempfile.TemporaryDirectory() as tmp:
            temp = Path(tmp)
            plan_path = temp / "plan.md"
            inventory_path = temp / "inventory.md"
            todo_path = temp / "TODO.md"
            plan_path.write_text(plan or PLAN.read_text(encoding="utf-8"), encoding="utf-8")
            inventory_path.write_text(
                inventory or SCENE_INVENTORY.read_text(encoding="utf-8"), encoding="utf-8"
            )
            todo_path.write_text(todo or TODO.read_text(encoding="utf-8"), encoding="utf-8")
            return validate_map_conversion_plan(
                root=ROOT,
                plan_path=plan_path,
                inventory_path=inventory_path,
                todo_path=todo_path,
            )


if __name__ == "__main__":
    unittest.main()

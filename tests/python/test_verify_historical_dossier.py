#!/usr/bin/env python3
"""Tests for tools/verify_historical_dossier.py."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import verify_historical_dossier as verifier  # noqa: E402


class VerifyHistoricalDossierTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.dossier = verifier.DOSSIER.read_text(encoding="utf-8")
        cls.registry = verifier.REGISTRY.read_text(encoding="utf-8")
        cls.todo = verifier.TODO.read_text(encoding="utf-8")

    def validate(
        self,
        *,
        dossier: str | None = None,
        registry: str | None = None,
        todo: str | None = None,
    ) -> list[str]:
        return verifier.validate(
            dossier_text=dossier if dossier is not None else self.dossier,
            registry_text=registry if registry is not None else self.registry,
            todo_text=todo if todo is not None else self.todo,
        )

    def test_repository_dossier_covers_registry_and_required_categories(self) -> None:
        self.assertEqual(self.validate(), [])

    def test_new_registry_map_requires_a_dossier_card(self) -> None:
        seeded_registry = self.registry.replace(
            "\t\t{\n\t\t\t\"id\": &\"kalev_smithy\",",
            "\t\t{\n\t\t\t\"id\": &\"seeded_map\",\n\t\t},\n\t\t{\n\t\t\t\"id\": &\"kalev_smithy\",",
            1,
        )
        errors = self.validate(registry=seeded_registry)
        self.assertTrue(any("seeded_map" in error and "missing dossier" in error for error in errors))

    def test_missing_living_world_category_is_rejected(self) -> None:
        row = next(
            line
            for line in self.dossier.splitlines()
            if line.startswith("| Domestic / wild fauna |")
        )
        errors = self.validate(dossier=self.dossier.replace(row + "\n", "", 1))
        self.assertTrue(
            any("kalev_smithy" in error and "Domestic / wild fauna" in error for error in errors)
        )

    def test_target_without_confidence_is_rejected(self) -> None:
        seeded = self.dossier.replace(
            "and **D/U**, with no pen or stable inside the forge",
            "and no confidence label, with no pen or stable inside the forge",
            1,
        )
        errors = self.validate(dossier=seeded)
        self.assertTrue(
            any("kalev_smithy/Domestic / wild fauna" in error and "confidence" in error for error in errors)
        )

    def test_unknown_source_id_is_rejected(self) -> None:
        seeded = self.dossier.replace(
            "H18; exact household fauna unknown",
            "H99; exact household fauna unknown",
            1,
        )
        errors = self.validate(dossier=seeded)
        self.assertTrue(any("unknown source IDs: H99" in error for error in errors))

    def test_pending_review_blocks_p0_072_completion(self) -> None:
        seeded_todo = self.todo.replace("- [ ] P0-072 |", "- [x] P0-072 |", 1)
        errors = self.validate(todo=seeded_todo)
        self.assertTrue(any("human historical review" in error and "P0-072" in error for error in errors))

    def test_pending_review_blocks_p1_036_completion(self) -> None:
        seeded_todo = self.todo.replace("- [ ] P1-036 |", "- [x] P1-036 |", 1)
        errors = self.validate(todo=seeded_todo)
        self.assertTrue(any("human historical review" in error and "P1-036" in error for error in errors))


if __name__ == "__main__":
    unittest.main()

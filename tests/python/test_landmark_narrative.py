#!/usr/bin/env python3
"""Tests for P1-037 landmark narrative coverage and generated outputs."""

from __future__ import annotations

import copy
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import generate_landmark_narrative as generator  # noqa: E402
import verify_landmark_narrative as verifier  # noqa: E402


class LandmarkNarrativeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.manifest = json.loads(verifier.MANIFEST.read_text(encoding="utf-8"))
        cls.document = verifier.DOCUMENT.read_text(encoding="utf-8")
        cls.todo = verifier.TODO.read_text(encoding="utf-8")

    def validate(self, manifest: dict | None = None) -> list[str]:
        return verifier.validate(
            manifest=manifest if manifest is not None else self.manifest,
            document_text=self.document,
            todo_text=self.todo,
        )

    def test_generated_outputs_match_checked_in_files(self) -> None:
        expected_manifest, expected_document = generator._serialized_outputs()
        self.assertEqual(verifier.MANIFEST.read_text(encoding="utf-8"), expected_manifest)
        self.assertEqual(verifier.DOCUMENT.read_text(encoding="utf-8"), expected_document)

    def test_repository_manifest_covers_every_catalog_landmark(self) -> None:
        self.assertEqual(self.validate(), [])
        self.assertEqual(len(self.manifest["integrations"]), 208)

    def test_missing_catalog_integration_is_rejected(self) -> None:
        mutated = copy.deepcopy(self.manifest)
        mutated["integrations"].pop()
        errors = self.validate(mutated)
        self.assertTrue(any("missing catalog integrations" in error for error in errors))
        self.assertTrue(any("expected 208 integrations" in error for error in errors))

    def test_unknown_integration_kind_is_rejected(self) -> None:
        mutated = copy.deepcopy(self.manifest)
        mutated["integrations"][0]["integration_kind"] = "tourism_system"
        errors = self.validate(mutated)
        self.assertTrue(any("invalid integration_kind" in error for error in errors))

    def test_unresolved_authored_anchor_is_rejected(self) -> None:
        mutated = copy.deepcopy(self.manifest)
        mutated["integrations"][0]["map_anchor"]["anchor_id"] = "missing_anchor"
        errors = self.validate(mutated)
        self.assertTrue(any("is not authored" in error for error in errors))

    def test_duplicate_stable_delivery_id_is_rejected(self) -> None:
        mutated = copy.deepcopy(self.manifest)
        duplicate = mutated["integrations"][0]["delivery_id"]
        mutated["integrations"][1]["delivery_id"] = duplicate
        errors = self.validate(mutated)
        self.assertTrue(any("duplicate delivery_id" in error for error in errors))


if __name__ == "__main__":
    unittest.main()

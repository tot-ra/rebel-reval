#!/usr/bin/env python3
"""Tests for tools/verify_map_audit.py."""

from __future__ import annotations

import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from verify_map_audit import MANIFEST, validate_map_audit  # noqa: E402
from verify_map_conversion_plan import PLAN, SCENE_INVENTORY, TODO  # noqa: E402


class VerifyMapAuditTest(unittest.TestCase):
    def test_repository_audit_manifest_passes(self) -> None:
        self.assertEqual(self._validate(), [])

    def test_missing_entry_fails(self) -> None:
        payload = self._payload()
        payload["maps"] = [row for row in payload["maps"] if row["id"] != "kalev_smithy"]
        errors = self._validate(payload)
        self.assertTrue(any("converted plan scenes missing audit entries" in error.message for error in errors))

    def test_duplicate_entry_fails(self) -> None:
        payload = self._payload()
        payload["maps"].append(copy.deepcopy(payload["maps"][0]))
        errors = self._validate(payload)
        self.assertTrue(any("duplicate map audit id entries" in error.message for error in errors))
        self.assertTrue(any("duplicate map audit scene entries" in error.message for error in errors))

    def test_stale_definition_fails(self) -> None:
        payload = self._payload()
        payload["maps"][0]["definition"] = "scripts/map/definitions/stale.gd"
        errors = self._validate(payload)
        self.assertTrue(any("stale definition" in error.message for error in errors))

    def test_missing_capture_fails(self) -> None:
        payload = self._payload()
        payload["maps"][0]["capture"] = "missing.png"
        errors = self._validate(payload, require_captures=True)
        self.assertTrue(any("missing visual capture" in error.message for error in errors))

    @staticmethod
    def _payload() -> dict:
        return json.loads(MANIFEST.read_text(encoding="utf-8"))

    def _validate(self, payload: dict | None = None, *, require_captures: bool = False) -> list:
        with tempfile.TemporaryDirectory() as temp_dir:
            manifest = Path(temp_dir) / "manifest.json"
            manifest.write_text(json.dumps(payload or self._payload()), encoding="utf-8")
            return validate_map_audit(
                root=ROOT,
                manifest_path=manifest,
                plan_path=PLAN,
                inventory_path=SCENE_INVENTORY,
                todo_path=TODO,
                require_captures=require_captures,
            )


if __name__ == "__main__":
    unittest.main()

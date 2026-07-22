#!/usr/bin/env python3

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import verify_outdoor_prototypes as verifier  # noqa: E402


class VerifyOutdoorPrototypesTest(unittest.TestCase):
    def test_repository_prototypes_pass(self) -> None:
        self.assertEqual(verifier.validate(), [])

    def test_active_destination_leak_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            active = Path(temp_dir) / "active.json"
            active.write_text(
                '{"scenes":[{"id":"saaremaa","active":true,"release":true}]}',
                encoding="utf-8",
            )
            with mock.patch.object(verifier, "ACTIVE_DESTINATIONS", active):
                errors = verifier.validate()
            self.assertTrue(any("saaremaa" in error and "active flow" in error for error in errors))

    def test_release_false_developer_destination_is_allowed(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            active = Path(temp_dir) / "active.json"
            active.write_text(
                '{"scenes":[{"id":"saaremaa","active":true,"release":false}]}',
                encoding="utf-8",
            )
            with mock.patch.object(verifier, "ACTIVE_DESTINATIONS", active):
                errors = verifier.validate()
            self.assertFalse(any("saaremaa" in error and "active flow" in error for error in errors))

    def test_missing_capture_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            with mock.patch.object(verifier, "CAPTURE_DIR", Path(temp_dir)):
                errors = verifier.validate()
            self.assertTrue(any("missing outdoor captures" in error for error in errors))

    def test_factory_scope_guard_is_required(self) -> None:
        with mock.patch.object(verifier, "definition_text", return_value=""):
            errors = verifier.validate()
        self.assertTrue(any("prototype scope" in error for error in errors))
        self.assertTrue(any("active=false" in error for error in errors))


if __name__ == "__main__":
    unittest.main()

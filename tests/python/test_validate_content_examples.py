#!/usr/bin/env python3
"""Tests for tools/validate_content_examples.py."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
TOOLS_DIR = ROOT / "tools"
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

import validate_content_examples as validator  # noqa: E402


class ValidateContentExamplesTests(unittest.TestCase):
    def test_malformed_json_is_reported_and_does_not_abort_validation(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            schemas = root / "schemas"
            valid = root / "content" / "valid"
            invalid = root / "content" / "invalid"
            schemas.mkdir(parents=True)
            valid.mkdir(parents=True)
            invalid.mkdir(parents=True)

            (schemas / "character.schema.json").write_text(
                json.dumps(
                    {
                        "type": "object",
                        "required": ["type", "id"],
                        "properties": {
                            "type": {"const": "character"},
                            "id": {"type": "string"},
                        },
                    }
                ),
                encoding="utf-8",
            )
            (valid / "00_broken.json").write_text('{"type": ', encoding="utf-8")
            (valid / "01_valid.json").write_text(
                '{"type": "character", "id": "char.valid"}', encoding="utf-8"
            )
            (invalid / "00_schema_error.json").write_text(
                '{"type": "character"}', encoding="utf-8"
            )

            with mock.patch.object(validator, "ROOT", root), mock.patch.object(
                validator, "SCHEMAS_DIR", schemas
            ), mock.patch.object(validator, "VALID_DIR", valid), mock.patch.object(
                validator, "INVALID_DIR", invalid
            ):
                ok, errors = validator.run()

            self.assertIn("PASS valid content/valid/01_valid.json", ok)
            self.assertTrue(
                any(
                    "FAIL valid content/valid/00_broken.json: invalid JSON:" in error
                    for error in errors
                )
            )
            self.assertTrue(
                any(
                    "PASS invalid rejected content/invalid/00_schema_error.json:" in result
                    for result in ok
                )
            )
            self.assertEqual(len(errors), 1)


if __name__ == "__main__":
    unittest.main()

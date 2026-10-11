#!/usr/bin/env python3
"""Tests for the slice accessibility checklist verifier."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from report_accessibility_checklist import (  # noqa: E402
    load_manifest,
    run_check,
    verify_manifest_contract,
)


class ReportAccessibilityChecklistTest(unittest.TestCase):
    def test_manifest_lists_required_options(self) -> None:
        manifest = load_manifest()
        required = set(manifest["required_options"])
        self.assertTrue(
            {
                "remapping",
                "guard_hold_toggle",
                "text_speed",
                "scalable_text",
                "subtitle_background",
                "focus_contrast",
                "screen_shake",
                "reduced_flashing",
            }.issubset(required)
        )

    def test_manifest_rejects_malformed_required_options(self) -> None:
        for malformed in (None, {}, [], ["remapping", ""]):
            with self.subTest(required_options=malformed):
                failures = verify_manifest_contract(
                    {
                        "required_options": malformed,
                        "supported_resolutions": [
                            {"width": 1280, "height": 720},
                            {"width": 1920, "height": 1080},
                        ],
                        "input_methods": ["keyboard_mouse", "gamepad"],
                    }
                )
                self.assertTrue(
                    any("required_options" in failure for failure in failures),
                    failures,
                )

    def test_manifest_rejects_malformed_collection_fields(self) -> None:
        base_manifest = {
            "required_options": [
                "remapping",
                "guard_hold_toggle",
                "text_speed",
                "scalable_text",
                "subtitle_background",
                "focus_contrast",
                "screen_shake",
                "reduced_flashing",
            ],
            "supported_resolutions": [
                {"width": 1280, "height": 720},
                {"width": 1920, "height": 1080},
            ],
            "input_methods": ["keyboard_mouse", "gamepad"],
        }
        for field in ("supported_resolutions", "input_methods"):
            for malformed in (None, {}):
                with self.subTest(field=field, value=malformed):
                    manifest = dict(base_manifest)
                    manifest[field] = malformed
                    failures = verify_manifest_contract(manifest)
                    self.assertTrue(
                        any(f"{field} must be a list" in failure for failure in failures),
                        failures,
                    )

    def test_manifest_accepts_non_empty_option_names(self) -> None:
        failures = verify_manifest_contract(
            {
                "required_options": ["remapping", " text_speed "],
                "supported_resolutions": [
                    {"width": 1280, "height": 720},
                    {"width": 1920, "height": 1080},
                ],
                "input_methods": ["keyboard_mouse", "gamepad"],
            }
        )
        self.assertFalse(
            any("required_options" in failure for failure in failures),
            failures,
        )

    def test_repository_checklist_passes_on_head(self) -> None:
        passed, failures = run_check()
        self.assertTrue(passed, "\n".join(failures))


if __name__ == "__main__":
    unittest.main()

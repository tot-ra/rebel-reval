#!/usr/bin/env python3
"""Tests for the vertical-slice third-party asset/license report."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from report_slice_third_party import main as report_main  # noqa: E402
from slice_third_party import build_report, notice_ids_in_file  # noqa: E402


class SliceThirdPartyReportTest(unittest.TestCase):
    def test_manifest_is_valid_json(self) -> None:
        manifest_path = ROOT / "docs/data/slice_third_party_manifest.json"
        payload = json.loads(manifest_path.read_text(encoding="utf-8"))
        self.assertEqual(payload["version"], 1)
        self.assertGreaterEqual(len(payload["entries"]), 4)
        self.assertEqual(len(payload["bundles"]), 2)

    def test_notices_file_contains_every_manifest_notice(self) -> None:
        manifest = json.loads(
            (ROOT / "docs/data/slice_third_party_manifest.json").read_text(encoding="utf-8")
        )
        notices = notice_ids_in_file(ROOT / manifest["notices_path"])
        expected = {entry["notice_id"] for entry in manifest["entries"]}
        expected.update(bundle["notice_id"] for bundle in manifest["bundles"])
        self.assertTrue(expected.issubset(notices), msg=sorted(expected - notices))

    def test_repository_slice_report_is_valid(self) -> None:
        report = build_report(ROOT)
        self.assertTrue(report.valid, msg="\n".join(report.errors))
        self.assertGreater(report.bundle_asset_count, 50)
        self.assertGreaterEqual(report.direct_entry_count, 4)

    def test_check_mode_exits_zero_on_current_corpus(self) -> None:
        self.assertEqual(report_main(["--check"]), 0)

    def test_json_output_is_written(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            output = Path(temp_dir) / "slice_third_party.json"
            exit_code = report_main(["--json", str(output), "--check"])
            self.assertEqual(exit_code, 0)
            payload = json.loads(output.read_text(encoding="utf-8"))
            self.assertTrue(payload["valid"])
            self.assertIn("third_party_asset_count", payload)


if __name__ == "__main__":
    unittest.main()

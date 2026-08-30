"""Contract tests for the P5-010 Act 2 authorial gate."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from tools.act2_gate import verify_manifest

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "docs/data/act2_gate_manifest.json"


class TestAct2Gate(unittest.TestCase):
    def test_authored_packages_and_fixtures_match_gate(self) -> None:
        report = verify_manifest(ROOT, MANIFEST)
        self.assertTrue(report.valid, "\n".join(report.errors))
        self.assertTrue(report.within_budget)
        self.assertEqual(report.package_count, 10)
        self.assertEqual(report.branch_count, 20)
        self.assertEqual(report.route_counts, {"combat": 10, "non_combat": 10})
        self.assertEqual(report.fixture_count, 20)
        self.assertEqual(report.mission_copy_words, 906)

    def test_gate_keeps_maintainer_review_pending(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertFalse(any("P5-009 is not complete" in blocker for blocker in manifest["known_blockers"]))
        self.assertTrue(any("Maintainer playable review" in blocker for blocker in manifest["known_blockers"]))
        report = verify_manifest(ROOT, MANIFEST)
        self.assertFalse(report.ready_for_maintainer_review)
        self.assertEqual(len(report.errors), 0)

    def test_branch_map_drift_is_rejected(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        package_row = manifest["packages"][0]
        package_dir = ROOT / package_row["package_dir"]
        branch_path = package_dir / "branch_map.json"
        original = branch_path.read_text(encoding="utf-8")
        mutated = json.loads(original)
        mutated["branches"][0]["expect"]["quest_state"] = "not_authored"
        with tempfile.TemporaryDirectory() as tmp:
            temp_root = Path(tmp)
            temp_package = temp_root / package_row["package_dir"]
            temp_package.mkdir(parents=True)
            for name in ("package.json", "branch_map.json"):
                source = package_dir / name
                (temp_package / name).write_text(
                    json.dumps(mutated if name == "branch_map.json" else json.loads(source.read_text()))
                    if name == "branch_map.json"
                    else source.read_text(),
                    encoding="utf-8",
                )
            content_dir = temp_package / "content"
            content_dir.mkdir()
            (content_dir / "quest.json").write_text(
                (package_dir / "content/quest.json").read_text(), encoding="utf-8"
            )
            temp_manifest = temp_root / "manifest.json"
            manifest["packages"] = [package_row]
            manifest["fixtures"] = []
            manifest["expected"].update(
                {"package_count": 1, "branch_count": 2, "fixture_count": 0}
            )
            temp_manifest.write_text(json.dumps(manifest), encoding="utf-8")
            report = verify_manifest(temp_root, temp_manifest)
        self.assertTrue(any("not_authored" in error for error in report.errors))

    def test_fixture_route_drift_is_rejected(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        manifest["fixtures"][0]["expected_route"] = "non_combat"
        with tempfile.TemporaryDirectory() as tmp:
            temp_manifest = Path(tmp) / "manifest.json"
            temp_manifest.write_text(json.dumps(manifest), encoding="utf-8")
            report = verify_manifest(ROOT, temp_manifest)
        self.assertTrue(any("route identity drift" in error for error in report.errors))


if __name__ == "__main__":
    unittest.main()

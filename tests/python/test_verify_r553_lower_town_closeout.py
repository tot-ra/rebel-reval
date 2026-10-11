from __future__ import annotations

import copy
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tools" / "verify_r553_lower_town_closeout.py"
SPEC = importlib.util.spec_from_file_location("verify_r553_lower_town_closeout", MODULE_PATH)
assert SPEC and SPEC.loader
verifier = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(verifier)


class R553LowerTownCloseoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.report = verifier.DEFAULT_REPORT.read_text(encoding="utf-8")
        cls.thresholds = json.loads(verifier.DEFAULT_THRESHOLDS.read_text(encoding="utf-8"))

    def _validate(self, report: str | None = None, thresholds: dict | None = None) -> list[str]:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            report_path = root / "docs" / "reports" / "r553.md"
            thresholds_path = root / "docs" / "data" / "thresholds.json"
            report_path.parent.mkdir(parents=True)
            thresholds_path.parent.mkdir(parents=True)

            # Preserve the report's real relative links inside the fixture tree so
            # seeded semantic failures are not obscured by unrelated missing links.
            fixture_report = report if report is not None else self.report
            for target in verifier.LINK_RE.findall(fixture_report):
                if target.startswith(("http://", "https://", "#")):
                    continue
                local_target = target.split("#", 1)[0]
                if "does_not_exist" in local_target:
                    continue
                linked = (report_path.parent / local_target).resolve()
                linked.parent.mkdir(parents=True, exist_ok=True)
                if not linked.exists():
                    linked.touch()

            report_path.write_text(fixture_report, encoding="utf-8")
            thresholds_path.write_text(
                json.dumps(thresholds if thresholds is not None else self.thresholds),
                encoding="utf-8",
            )
            return verifier.validate(report_path, thresholds_path)

    def test_repository_report_satisfies_closeout_guard(self) -> None:
        self.assertEqual(
            verifier.validate(verifier.DEFAULT_REPORT, verifier.DEFAULT_THRESHOLDS),
            [],
        )

    def test_advisory_composition_rejects_false_pass_decision(self) -> None:
        seeded = self.report.replace(
            "**Decision:** **BLOCKED - do not close R-553 and do not promote R-109/P0-100 to acceptance.**",
            "**Decision:** **PASS - promote R-109/P0-100 to acceptance.**",
            1,
        ).replace("Do not close R-109/P0-100", "Close R-109/P0-100", 1)
        thresholds = copy.deepcopy(self.thresholds)
        thresholds["maps"]["lower_town_slice"]["enforce"] = False
        errors = self._validate(report=seeded, thresholds=thresholds)
        self.assertTrue(any("Decision must be BLOCKED" in error for error in errors), errors)
        self.assertTrue(any("closure prohibition" in error for error in errors), errors)

    def test_missing_requirement_row_is_rejected(self) -> None:
        missing = verifier.REQUIRED_REQUIREMENTS[1]
        errors = self._validate(report=self.report.replace(missing, "omitted density requirement", 1))
        self.assertTrue(any(missing in error for error in errors), errors)

    def test_missing_reproduction_command_is_rejected(self) -> None:
        missing = verifier.REQUIRED_COMMANDS[3]
        errors = self._validate(report=self.report.replace(missing, "--filter=omitted", 1))
        self.assertTrue(any(missing in error for error in errors), errors)

    def test_broken_local_source_link_is_rejected(self) -> None:
        seeded = self.report + "\n- [missing](../../content/maps/does_not_exist.rrmap)\n"
        errors = self._validate(report=seeded)
        self.assertTrue(any("does_not_exist.rrmap" in error for error in errors), errors)

    def test_enforced_card_does_not_require_advisory_wording(self) -> None:
        thresholds = copy.deepcopy(self.thresholds)
        thresholds["maps"]["lower_town_slice"]["enforce"] = True
        report = self.report.replace("BLOCKED / NOT ENFORCED", "BLOCKED", 1)
        self.assertFalse(
            any("NOT ENFORCED" in error for error in self._validate(report, thresholds))
        )


if __name__ == "__main__":
    unittest.main()

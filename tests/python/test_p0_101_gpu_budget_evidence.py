"""Contract checks for the P0-101 GPU/minimum-hardware evidence ledger."""

from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REPORT_PATH = ROOT / "docs/reports/p0_101_gpu_budget_evidence.md"
TARGET_PATH = ROOT / "tools/benchmarks/minimum-hardware.json"


class TestP0101GpuBudgetEvidence(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.report = REPORT_PATH.read_text(encoding="utf-8")
        cls.target = json.loads(TARGET_PATH.read_text(encoding="utf-8"))

    def _section(self, heading: str, next_heading: str) -> str:
        start = self.report.index(heading) + len(heading)
        end = self.report.index(next_heading, start)
        return self.report[start:end]

    @staticmethod
    def _table_rows(section: str) -> dict[str, str]:
        rows: dict[str, str] = {}
        for line in section.splitlines():
            if not line.startswith("|") or line.startswith("|---"):
                continue
            cells = [cell.strip() for cell in line.strip("|").split("|")]
            if len(cells) < 2 or cells[0].lower() == "metric":
                continue
            rows[re.sub(r"`", "", cells[0]).lower()] = line
        return rows

    def test_declared_target_and_evidence_boundary_are_recorded(self) -> None:
        self.assertIn(
            "**BLOCKED - the declared Intel UHD 620 minimum-hardware profile",
            self.report,
        )
        self.assertIn("non-headless measurement host", self.report.lower())
        self.assertIn("headless development baseline", self.report.lower())
        self.assertIn(self.target["profile_id"], self.report)
        self.assertIn("Intel UHD Graphics 620", self.report)
        self.assertIn("Intel Core i5-8250U", self.report)
        self.assertIn(f"{self.target['memory_gib']} GiB RAM", self.report)
        self.assertIn(self.target["display"], self.report)
        self.assertIn("GL Compatibility renderer", self.report)
        self.assertIn("--rendering-driver opengl3", self.report)
        self.assertIn("No authored budget was raised or waived", self.report)

    def test_non_headless_probe_records_every_required_metric_and_blocks_target_verdict(
        self,
    ) -> None:
        section = self._section(
            "### Non-headless render probe - Apple M5 Pro supplementary evidence",
            "### Headless CPU/resident baseline - kept separate",
        )
        rows = self._table_rows(section)
        required_metrics = {
            "peak draw calls",
            "peak primitives",
            "frame-time median",
            "frame-time p95",
            "video memory",
            "resident node count",
            "resident memory delta",
            "collision count",
            "ambient bird audio peak",
            "ambient bird-flight peak",
            "urban fauna peak",
            "penned fauna peak",
        }
        for metric in required_metrics:
            self.assertIn(metric, rows, f"missing non-headless metric: {metric}")
            self.assertIn(
                "BLOCKED",
                rows[metric],
                f"minimum-target verdict is not blocked: {metric}",
            )
        self.assertIn("Result on declared minimum target", section)
        self.assertIn("supplementary host", section)

    def test_headless_baseline_cannot_be_counted_as_gpu_acceptance(self) -> None:
        section = self._section(
            "### Headless CPU/resident baseline - kept separate",
            "## R-490 reconciliation",
        )
        rows = self._table_rows(section)
        for metric in (
            "frame-time p95",
            "resident node count",
            "resident memory delta",
            "collision count",
            "ambient bird audio peak",
            "ambient bird-flight peak",
            "urban fauna peak",
            "penned fauna peak",
        ):
            self.assertIn(metric, rows, f"missing headless metric: {metric}")
        self.assertIn("CPU-side only", section)
        self.assertIn("not GPU evidence", section)
        self.assertIn("not merged with the non-headless values", section)

    def test_report_preserves_open_r490_blockers_and_source_contract(self) -> None:
        reconciliation = self._section("## R-490 reconciliation", "## Verification record")
        self.assertIn("8,489", reconciliation)
        self.assertIn("8,491", reconciliation)
        self.assertIn("439.303 MiB", reconciliation)
        self.assertIn("Camera acceptance remains **BLOCKED**", reconciliation)
        self.assertIn("cannot be promoted to target acceptance", reconciliation)
        for source in (
            "tools/benchmarks/lower_town_render_probe.tscn",
            "tools/benchmarks/lower_town_render_probe.gd",
            "tools/benchmarks/run_large_map_benchmark.gd",
            "tools/benchmarks/minimum-hardware.json",
        ):
            self.assertTrue((ROOT / source).is_file(), f"missing report source: {source}")


if __name__ == "__main__":
    unittest.main()

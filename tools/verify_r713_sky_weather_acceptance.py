#!/usr/bin/env python3
"""Aggregate the fail-closed R-713 sky/weather acceptance evidence.

This verifier intentionally distinguishes healthy local implementation contracts from
parent acceptance. It returns 0 only when every non-structural gate is explicitly
accepted; known external, hardware, or human-review gaps return 2 (BLOCKED).
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ACCEPTANCE_REPORT = ROOT / "docs/reports/r713_sky_weather_acceptance.md"
CONTINUITY_REPORT = ROOT / "docs/reports/r713_sky_weather_continuity.md"
PERFORMANCE_REPORT = ROOT / "docs/reports/r713_environment_performance.md"
CONTINUITY_VERIFIER = ROOT / "tools/verify_r713_sky_weather_evidence.py"


def _read(path: Path, failures: list[str]) -> str:
    if not path.is_file():
        failures.append(f"missing artifact: {path.relative_to(ROOT)}")
        return ""
    return path.read_text(encoding="utf-8")


def _require(text: str, terms: tuple[str, ...], label: str, failures: list[str]) -> None:
    lowered = text.lower()
    for term in terms:
        if term.lower() not in lowered:
            failures.append(f"{label} missing required term: {term}")


def main() -> int:
    failures: list[str] = []
    blockers: list[str] = []

    acceptance = _read(ACCEPTANCE_REPORT, failures)
    continuity = _read(CONTINUITY_REPORT, failures)
    performance = _read(PERFORMANCE_REPORT, failures)

    _require(
        acceptance,
        (
            "R-774",
            "R-714",
            "R-715",
            "R-726",
            "human visual review",
            "minimum",
            "recommended",
            "Final recommendation",
        ),
        "acceptance report",
        failures,
    )
    _require(
        continuity,
        ("40/40", "20/20", "human visual review pending", "Metal"),
        "continuity report",
        failures,
    )
    _require(
        performance,
        ("minimum-hardware-intel-uhd-620", "development-baseline-m5-pro"),
        "performance report",
        failures,
    )

    if CONTINUITY_VERIFIER.is_file():
        result = subprocess.run(
            [sys.executable, str(CONTINUITY_VERIFIER)],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0:
            detail = (result.stdout + result.stderr).strip()
            failures.append(f"continuity evidence verifier failed: {detail}")
    else:
        failures.append("missing continuity evidence verifier")

    if re.search(r"Status:\s*\*\*BLOCKED", performance, re.IGNORECASE):
        blockers.append("minimum/recommended target-specific performance measurements are BLOCKED")
    if re.search(r"human visual review pending", continuity, re.IGNORECASE):
        blockers.append("named human visual review of the 40-plate continuity packet is pending")

    for ref in ("R-774", "R-714", "R-715", "R-726"):
        pattern = rf"\|\s*{re.escape(ref)}\b[^\n]*\|\s*`?(?:in_progress|todo|blocked)"
        if re.search(pattern, acceptance, re.IGNORECASE):
            blockers.append(f"external or child owner {ref} remains open")

    if failures:
        print("R713_SKY_WEATHER_ACCEPTANCE_FAIL")
        for failure in failures:
            print(f"FAIL: {failure}")
        return 1

    if blockers:
        print("R713_SKY_WEATHER_ACCEPTANCE_BLOCKED")
        for blocker in blockers:
            print(f"BLOCKED: {blocker}")
        return 2

    if not re.search(r"Recommendation:\s*\*\*READY FOR HUMAN SIGN-OFF\*\*", acceptance):
        print("R713_SKY_WEATHER_ACCEPTANCE_FAIL")
        print("FAIL: all evidence gates cleared but report has no READY FOR HUMAN SIGN-OFF recommendation")
        return 1

    print("R713_SKY_WEATHER_ACCEPTANCE_PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

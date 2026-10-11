#!/usr/bin/env python3
"""Generate or verify the P5-010 Act 2 authorial gate report.

Usage:
    python3 tools/report_act2_gate.py
    python3 tools/report_act2_gate.py --check
    python3 tools/report_act2_gate.py --json build/reports/act2_gate.json
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from act2_gate import format_report, verify_manifest

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "docs/data/act2_gate_manifest.json"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=MANIFEST)
    parser.add_argument("--json", type=Path, help="Optional machine-readable report path")
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit non-zero when authored package/fixture contracts fail",
    )
    args = parser.parse_args(argv)

    report = verify_manifest(ROOT, args.manifest)
    print(format_report(report))
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(
            json.dumps(
                {
                    "valid": report.valid,
                    "within_budget": report.within_budget,
                    "ready_for_maintainer_review": report.ready_for_maintainer_review,
                    "package_count": report.package_count,
                    "branch_count": report.branch_count,
                    "route_counts": report.route_counts,
                    "mission_copy_words": report.mission_copy_words,
                    "mission_copy_word_budget": report.mission_copy_word_budget,
                    "fixture_count": report.fixture_count,
                    "errors": report.errors,
                    "warnings": report.warnings,
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
    return 1 if args.check and not report.valid else 0


if __name__ == "__main__":
    raise SystemExit(main())

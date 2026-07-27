#!/usr/bin/env python3
"""Generate or verify the Act 1 content-budget report for P4-010.

Usage:
    python3 tools/report_act1_content_budget.py
    python3 tools/report_act1_content_budget.py --check
    python3 tools/report_act1_content_budget.py --json build/reports/act1_content_budget.json
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from act1_content_budget import build_report, format_report  # noqa: E402


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=ROOT / "docs/data/act1_content_budget_manifest.json",
        help="Act 1 content-budget manifest path",
    )
    parser.add_argument(
        "--json",
        type=Path,
        help="Optional path to write machine-readable report JSON",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit non-zero when Act 1 exceeds any approved budget",
    )
    args = parser.parse_args(argv)

    report = build_report(ROOT, args.manifest)
    print(format_report(report))

    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "within_budget": report.within_budget,
            "district_count": report.district_count,
            "core_character_count": report.core_character_count,
            "cycle_quest_count": report.cycle_quest_count,
            "climax_quest_count": report.climax_quest_count,
            "substantial_quest_count": report.substantial_quest_count,
            "faction_line_count": report.faction_line_count,
            "dialogue_words": report.dialogue_words,
            "dialogue_word_budget": report.dialogue_word_budget,
            "audio_duration_seconds": report.audio_duration_seconds,
            "audio_duration_budget_seconds": report.audio_duration_budget_seconds,
            "warnings": report.warnings,
            "errors": report.errors,
        }
        args.json.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    if args.check and not report.within_budget:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

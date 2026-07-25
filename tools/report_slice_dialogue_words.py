#!/usr/bin/env python3
"""Generate the vertical-slice dialogue word-count report for P2-013.

Counts spoken and displayed player-facing text from the slice dialogue manifest.
IDs, metadata fields, and content references are excluded.

Usage:
    python3 tools/report_slice_dialogue_words.py
    python3 tools/report_slice_dialogue_words.py --json build/reports/slice_dialogue_words.json
    python3 tools/report_slice_dialogue_words.py --check

Exit codes: 0 = within budget, 1 = over budget or manifest errors.
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

from slice_dialogue_words import build_report, format_report  # noqa: E402


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=ROOT / "docs/data/slice_dialogue_manifest.json",
        help="Slice dialogue manifest path",
    )
    parser.add_argument(
        "--json",
        type=Path,
        help="Optional path to write machine-readable report JSON",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit non-zero when the slice exceeds the configured word budget",
    )
    args = parser.parse_args(argv)

    report = build_report(ROOT, args.manifest)
    print(format_report(report))

    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "word_budget": report.word_budget,
            "total_words": report.total_words,
            "within_budget": report.within_budget,
            "grouped_totals": report.grouped_totals(),
            "errors": report.errors,
            "lines": [
                {
                    "source": line.source,
                    "field": line.field,
                    "text": line.text,
                    "words": line.words,
                }
                for line in report.lines
            ],
        }
        args.json.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    if args.check and not report.within_budget:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

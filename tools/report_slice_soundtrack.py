#!/usr/bin/env python3
"""Generate the vertical-slice soundtrack budget report for P2-014.

Reports unique track duration, theme reuse, streaming settings, and rights for
every approved slice theme track listed in docs/data/slice_soundtrack_manifest.json.

Usage:
    python3 tools/report_slice_soundtrack.py
    python3 tools/report_slice_soundtrack.py --json build/reports/slice_soundtrack.json
    python3 tools/report_slice_soundtrack.py --check

Exit codes: 0 = within budget and wiring matches manifest, 1 otherwise.
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

from slice_soundtrack import (  # noqa: E402
    build_report,
    format_report,
    verify_music_director_matches_manifest,
)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=ROOT / "docs/data/slice_soundtrack_manifest.json",
        help="Slice soundtrack manifest path",
    )
    parser.add_argument(
        "--json",
        type=Path,
        help="Optional path to write machine-readable report JSON",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit non-zero when the slice exceeds budget or wiring drifts",
    )
    args = parser.parse_args(argv)

    report = build_report(ROOT, args.manifest)
    report.errors.extend(verify_music_director_matches_manifest(ROOT, args.manifest))
    print(format_report(report))

    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "duration_budget_seconds": report.duration_budget_seconds,
            "budgeted_duration_seconds": report.budgeted_duration_seconds,
            "total_unique_duration_seconds": report.total_unique_duration_seconds,
            "within_budget": report.within_budget,
            "errors": report.errors,
            "tracks": [
                {
                    "path": track.path,
                    "sources_id": track.sources_id,
                    "duration_seconds": track.duration_seconds,
                    "rights_status": track.rights_status,
                    "license": track.license,
                    "owner": track.owner,
                    "themes": track.themes,
                    "stream_modes": track.stream_modes,
                }
                for track in report.tracks
            ],
        }
        args.json.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    if args.check and not report.within_budget:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

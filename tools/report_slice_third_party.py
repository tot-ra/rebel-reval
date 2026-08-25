#!/usr/bin/env python3
"""Generate or verify the vertical-slice third-party asset/license report for P3-013.

Usage:
    python3 tools/report_slice_third_party.py
    python3 tools/report_slice_third_party.py --check
    python3 tools/report_slice_third_party.py --json build/reports/slice_third_party.json

Exit codes: 0 = all mapped assets have notices and approved manifest rows, 1 otherwise.
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

from slice_third_party import build_report, format_report  # noqa: E402


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=ROOT / "docs/data/slice_third_party_manifest.json",
        help="Slice third-party manifest path",
    )
    parser.add_argument(
        "--json",
        type=Path,
        help="Optional path to write machine-readable report JSON",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit non-zero when any mapped asset lacks a notice or approved manifest row",
    )
    args = parser.parse_args(argv)

    report = build_report(ROOT, args.manifest)
    print(format_report(report))

    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "manifest_path": report.manifest_path,
            "notices_path": report.notices_path,
            "direct_entry_count": report.direct_entry_count,
            "bundle_asset_count": report.bundle_asset_count,
            "third_party_asset_count": report.third_party_asset_count,
            "valid": report.valid,
            "errors": report.errors,
        }
        args.json.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
        print(f"JSON report written: {args.json.name}")

    if args.check and not report.valid:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Generate or verify the vertical-slice performance manifest for P3-011.

Usage:
    python3 tools/report_slice_performance.py
    python3 tools/report_slice_performance.py --check
    python3 tools/report_slice_performance.py --check --report build/benchmarks/large-map-ci-smoke.json
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

from slice_performance import (  # noqa: E402
    format_report,
    load_manifest,
    verify_manifest_matches_model,
    verify_performance_report,
)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=ROOT / "docs/data/slice_performance_manifest.json",
        help="Slice performance manifest path",
    )
    parser.add_argument(
        "--report",
        type=Path,
        help="Optional benchmark JSON report to verify against slice gates",
    )
    parser.add_argument(
        "--json",
        type=Path,
        help="Optional path to write machine-readable manifest copy",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit non-zero when manifest/model drift or slice gates fail",
    )
    args = parser.parse_args(argv)

    if args.report:
        report = verify_performance_report(ROOT, args.manifest, args.report)
    else:
        report = verify_manifest_matches_model(ROOT, args.manifest)

    print(format_report(report))

    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        payload = load_manifest(args.manifest)
        args.json.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    if args.check and not report.valid:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

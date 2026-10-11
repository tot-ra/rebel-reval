#!/usr/bin/env python3
"""Generate or verify the vertical-slice end-to-end manifest for P3-016.

Usage:
    python3 tools/report_slice_e2e.py
    python3 tools/report_slice_e2e.py --check
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from slice_e2e import format_report, verify_manifest_matches_model  # noqa: E402


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=ROOT / "docs/data/slice_e2e_manifest.json",
        help="Slice end-to-end manifest path",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit non-zero when manifest/model drift is detected",
    )
    args = parser.parse_args(argv)

    report = verify_manifest_matches_model(ROOT, args.manifest)
    print(format_report(report))

    if args.check and not report.valid:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

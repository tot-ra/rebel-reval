#!/usr/bin/env python3
"""Validate quest package manifests against landmark integrations (P1-038)."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from quest_packages import discover_packages, load_package, validate_package  # noqa: E402

ROOT = TOOLS.parent


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "paths",
        nargs="*",
        help="package directories (defaults to every content/packages/* manifest)",
    )
    args = parser.parse_args(argv)

    package_dirs = [Path(path) for path in args.paths] if args.paths else discover_packages()
    if not package_dirs:
        print("no quest packages discovered", file=sys.stderr)
        return 1

    errors: list[str] = []
    for package_dir in package_dirs:
        package = load_package(package_dir)
        errors.extend(validate_package(package))

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1

    print(f"validated {len(package_dirs)} quest package(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

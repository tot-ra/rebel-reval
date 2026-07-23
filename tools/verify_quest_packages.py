#!/usr/bin/env python3
"""Validate quest package manifests against landmark integrations (P1-038).

Adds a ``--skip-failing`` flag that lets validation continue when one package
fails to load or validate, instead of aborting the whole corpus. This mirrors
``tools/generate_quest_package_tests.py --skip-failing`` for partial authoring.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from quest_packages import discover_packages, load_package, validate_package  # noqa: E402

ROOT = TOOLS.parent


def validate_all(
    package_dirs: list[Path], *, skip_failing: bool = False
) -> tuple[int, list[str], list[str]]:
    """Return (validated_count, skipped_names, errors)."""
    errors: list[str] = []
    skipped: list[str] = []
    validated = 0

    for package_dir in package_dirs:
        try:
            package = load_package(package_dir)
        except Exception as exc:  # pragma: no cover - defensive
            msg = f"{package_dir.name}: failed to load ({exc})"
            if skip_failing:
                print(f"[skip] {msg}", file=sys.stderr)
                skipped.append(package_dir.name)
                continue
            errors.append(msg)
            break

        package_errors = validate_package(package)
        if package_errors:
            msg = f"{package_dir.name}: " + "; ".join(package_errors)
            if skip_failing:
                print(f"[skip] {msg}", file=sys.stderr)
                skipped.append(package_dir.name)
                continue
            errors.extend(package_errors)
            break

        validated += 1

    return validated, skipped, errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "paths",
        nargs="*",
        help="package directories (defaults to every content/packages/* manifest)",
    )
    parser.add_argument(
        "--skip-failing",
        action="store_true",
        help="skip packages that fail to load or validate instead of aborting",
    )
    args = parser.parse_args(argv)

    package_dirs = [Path(path) for path in args.paths] if args.paths else discover_packages()
    if not package_dirs:
        print("no quest packages discovered", file=sys.stderr)
        return 1

    validated, skipped, errors = validate_all(
        package_dirs,
        skip_failing=args.skip_failing,
    )
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1

    if args.skip_failing and skipped:
        plural = "s" if len(skipped) != 1 else ""
        print(
            f"[info] skipped {len(skipped)} broken package{plural}: "
            + ", ".join(skipped),
            file=sys.stderr,
        )

    print(f"validated {validated} quest package(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

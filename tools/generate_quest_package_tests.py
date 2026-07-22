#!/usr/bin/env python3
"""Generate Godot branch-traversal tests from quest packages (P4-018 / P1-038)."""

from __future__ import annotations

import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from quest_packages import (  # noqa: E402
    discover_packages,
    load_package,
    render_godot_test,
    test_output_path,
    validate_package,
)

ROOT = TOOLS.parent
GENERATED_ROOT = ROOT / "tests" / "godot" / "generated"


def _render_all() -> dict[Path, str]:
    rendered: dict[Path, str] = {}
    for package_dir in discover_packages():
        package = load_package(package_dir)
        errors = validate_package(package)
        if errors:
            raise RuntimeError(f"{package_dir}: " + "; ".join(errors))
        rendered[test_output_path(package)] = render_godot_test(package)
    return rendered


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    check = "--check" in args
    unknown = [arg for arg in args if arg != "--check"]
    if unknown:
        print(f"unknown argument(s): {' '.join(unknown)}", file=sys.stderr)
        return 2

    rendered = _render_all()
    GENERATED_ROOT.mkdir(parents=True, exist_ok=True)

    stale: list[str] = []
    for path, expected in sorted(rendered.items(), key=lambda item: item[0].as_posix()):
        actual = path.read_text(encoding="utf-8") if path.exists() else ""
        if actual != expected:
            stale.append(str(path.relative_to(ROOT)))
            if not check:
                path.write_text(expected, encoding="utf-8")

    expected_paths = {path.resolve() for path in rendered}
    for existing in sorted(GENERATED_ROOT.glob("test_quest_package_*.gd")):
        if existing.resolve() not in expected_paths:
            stale.append(str(existing.relative_to(ROOT)))
            if not check:
                existing.unlink()

    if check and stale:
        print(f"stale generated quest package tests: {', '.join(stale)}", file=sys.stderr)
        return 1

    if check:
        print("generated quest package tests are up to date")
        return 0

    print(f"wrote {len(rendered)} generated quest package test(s) under {GENERATED_ROOT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

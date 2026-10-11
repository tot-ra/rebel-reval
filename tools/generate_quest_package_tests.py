#!/usr/bin/env python3
"""Generate Godot branch-traversal tests from quest packages (P4-018 / P1-038).

Adds a `--skip-failing` flag that lets the generator continue processing other
packages when one fails validation or loading, instead of aborting the whole run.
This is useful during content authoring where a broken package should not block
regeneration for the rest of the campaign.
"""

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


def _render_all(skip_failing: bool) -> tuple[dict[Path, str], list[str]]:
    rendered: dict[Path, str] = {}
    skipped: list[str] = []
    for package_dir in discover_packages():
        try:
            package = load_package(package_dir)
        except Exception as exc:  # pragma: no cover - defensive
            msg = f"{package_dir.name}: failed to load ({exc})"
            if skip_failing:
                print(f"[skip] {msg}", file=sys.stderr)
                skipped.append(package_dir.name)
                continue
            raise RuntimeError(msg) from exc
        errors = validate_package(package)
        if errors:
            msg = f"{package_dir.name}: " + "; ".join(errors)
            if skip_failing:
                print(f"[skip] {msg}", file=sys.stderr)
                skipped.append(package_dir.name)
                continue
            raise RuntimeError(msg)
        rendered[test_output_path(package)] = render_godot_test(package)
    return rendered, skipped


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    check = "--check" in args
    skip_failing = "--skip-failing" in args
    unknown = [arg for arg in args if arg not in {"--check", "--skip-failing"}]
    if unknown:
        print(f"unknown argument(s): {' '.join(unknown)}", file=sys.stderr)
        return 2

    rendered, skipped = _render_all(skip_failing=skip_failing)
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

    if skip_failing and skipped:
        plural = "s" if len(skipped) != 1 else ""
        print(
            f"[info] skipped {len(skipped)} broken package{plural}: "
            + ", ".join(skipped),
            file=sys.stderr,
        )

    if check:
        print("generated quest package tests are up to date")
        return 0

    print(f"wrote {len(rendered)} generated quest package test(s) under {GENERATED_ROOT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

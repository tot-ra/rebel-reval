#!/usr/bin/env python3
"""Release-candidate verification scaffold for P0-121.

Automates the repository checks that can run before P3-012, P4-013, or P6-008
human gates: AGPL license presence, asset provenance manifest, export preset and
CI smoke indicators, and the accessibility baseline already shipped in P1-028.

Usage:
    python3 tools/release_candidate_check.py
    python3 tools/release_candidate_check.py --license
    python3 tools/release_candidate_check.py --provenance
    python3 tools/release_candidate_check.py --accessibility
    python3 tools/release_candidate_check.py --platform
    python3 tools/release_candidate_check.py --ci

Exit codes: 0 = all selected checks pass, 1 = one or more checks failed.
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

AGPL_MARKERS = (
    "GNU AFFERO GENERAL PUBLIC LICENSE",
    "Version 3, 19 November 2007",
    "Copyright (C) 2007 Free Software Foundation, Inc.",
)


@dataclass
class CheckResult:
    name: str
    passed: bool
    message: str
    details: list[str] = field(default_factory=list)


def check_license(root: Path = ROOT) -> CheckResult:
    license_file = root / "LICENSE"
    if not license_file.is_file():
        return CheckResult(
            name="License Report",
            passed=False,
            message=f"License file not found: {license_file}",
            details=["Required LICENSE file missing from project root"],
        )

    content = license_file.read_text(encoding="utf-8")
    missing = [marker for marker in AGPL_MARKERS if marker not in content]
    if missing:
        return CheckResult(
            name="License Report",
            passed=False,
            message="LICENSE file is missing required AGPLv3 markers",
            details=[f"missing marker: {marker}" for marker in missing],
        )

    return CheckResult(
        name="License Report",
        passed=True,
        message="AGPLv3 license file present and valid",
        details=[
            f"LICENSE found: {license_file}",
            "Contains GNU AFFERO GENERAL PUBLIC LICENSE header",
            "Contains Version 3, 19 November 2007",
            "Contains FSF copyright notice",
        ],
    )


def check_provenance(root: Path = ROOT) -> CheckResult:
    manifest = root / "assets" / "SOURCES.csv"
    validator = root / "tools" / "validate_asset_sources.py"
    details: list[str] = []
    passed = True

    if not manifest.is_file():
        passed = False
        details.append(f"missing asset provenance manifest: {manifest}")
    else:
        details.append(f"asset provenance manifest found: {manifest}")

    if not validator.is_file():
        passed = False
        details.append(f"missing provenance validator: {validator}")
    else:
        details.append(f"provenance validator found: {validator}")

    return CheckResult(
        name="Asset Provenance",
        passed=passed,
        message="Asset provenance scaffold present" if passed else "Asset provenance scaffold incomplete",
        details=details,
    )


def check_accessibility(root: Path = ROOT) -> CheckResult:
    project_file = root / "project.godot"
    user_settings = root / "scripts" / "settings" / "user_settings.gd"
    controls_overlay = root / "scripts" / "ui" / "controls_overlay.gd"
    input_bindings_test = root / "tests" / "godot" / "test_input_bindings.gd"

    checks: list[tuple[str, bool]] = []
    details: list[str] = []

    if not project_file.is_file():
        checks.append(("project.godot present", False))
        details.append("project.godot missing")
    else:
        content = project_file.read_text(encoding="utf-8")
        has_user_settings = 'UserSettings="*res://scripts/settings/user_settings.gd"' in content
        has_input_section = "\n[input]\n" in f"\n{content}\n"
        has_display_size = "window/size/viewport_width=" in content and "window/size/viewport_height=" in content
        checks.extend(
            [
                ("UserSettings autoload configured", has_user_settings),
                ("Input action map configured", has_input_section),
                ("Display viewport size configured", has_display_size),
            ]
        )
        if has_user_settings:
            details.append("UserSettings autoload is configured")
        else:
            details.append("UserSettings autoload is missing from project.godot")
        if has_input_section:
            details.append("Input action map is configured")
        else:
            details.append("Input action map is missing from project.godot")
        if has_display_size:
            details.append("Display viewport size is configured")
        else:
            details.append("Display viewport size is missing from project.godot")

    has_rebind_api = (
        user_settings.is_file()
        and "func rebind_action(" in user_settings.read_text(encoding="utf-8")
    )
    checks.append(("Persistent input rebinding API present", has_rebind_api))
    if has_rebind_api:
        details.append("user_settings.gd exposes rebind_action")
    else:
        details.append("user_settings.gd is missing rebind_action")

    has_controls_overlay = controls_overlay.is_file()
    checks.append(("Controls overlay present", has_controls_overlay))
    if has_controls_overlay:
        details.append("controls_overlay.gd is present")
    else:
        details.append("controls_overlay.gd is missing")

    has_binding_tests = input_bindings_test.is_file()
    checks.append(("Input binding tests present", has_binding_tests))
    if has_binding_tests:
        details.append("test_input_bindings.gd is present")
    else:
        details.append("test_input_bindings.gd is missing")

    passed_count = sum(1 for _, ok in checks if ok)
    passed = passed_count == len(checks)
    return CheckResult(
        name="Accessibility Baseline",
        passed=passed,
        message=f"Accessibility baseline check completed ({passed_count}/{len(checks)} items)",
        details=details,
    )


def check_platform(root: Path = ROOT) -> CheckResult:
    godot_version_file = root / ".godot-version"
    export_presets = root / "export_presets.cfg"
    details: list[str] = []
    checks: list[tuple[str, bool]] = []

    if not godot_version_file.is_file():
        checks.append((".godot-version present", False))
        details.append(".godot-version missing")
    else:
        version = godot_version_file.read_text(encoding="utf-8").strip()
        checks.append((".godot-version present", bool(version)))
        details.append(f"Godot version pinned: {version or '<empty>'}")

    if not export_presets.is_file():
        checks.append(("export_presets.cfg present", False))
        details.append("export_presets.cfg missing")
    else:
        presets_content = export_presets.read_text(encoding="utf-8")
        lowered = presets_content.lower()
        has_macos_preset = 'platform="macos"' in lowered
        has_universal_arch = 'binary_format/architecture="universal"' in lowered
        checks.extend(
            [
                ("export_presets.cfg present", True),
                ("macOS export preset configured", has_macos_preset),
                ("universal macOS architecture configured", has_universal_arch),
            ]
        )
        if has_macos_preset:
            details.append("macOS export preset configured")
        else:
            details.append("macOS export preset missing from export_presets.cfg")
        if has_universal_arch:
            details.append("Universal macOS architecture configured")
        else:
            details.append("Universal macOS architecture not configured")

    passed_count = sum(1 for _, ok in checks if ok)
    passed = passed_count == len(checks)
    return CheckResult(
        name="Platform Smoke Tests",
        passed=passed,
        message=f"Platform check completed ({passed_count}/{len(checks)} items)",
        details=details,
    )


def check_ci(root: Path = ROOT) -> CheckResult:
    ci_workflow = root / ".github" / "workflows" / "ci.yml"
    checked_runner = root / "tools" / "run_godot_checked.sh"
    restore_lfs = root / "tools" / "restore_lfs_assets.sh"
    details: list[str] = []
    checks: list[tuple[str, bool]] = []

    if not ci_workflow.is_file():
        checks.append(("ci.yml present", False))
        details.append("ci.yml missing")
    else:
        workflow = ci_workflow.read_text(encoding="utf-8")
        checks.extend(
            [
                ("ci.yml present", True),
                ("validate-and-smoke job present", "validate-and-smoke:" in workflow),
                ("clean headless import step present", "clean-import" in workflow),
                ("main scene startup smoke present", "main-scene" in workflow),
            ]
        )
        if "validate-and-smoke:" in workflow:
            details.append("validate-and-smoke job is present")
        else:
            details.append("validate-and-smoke job is missing")
        if "clean-import" in workflow:
            details.append("clean headless import step is present")
        else:
            details.append("clean headless import step is missing")
        if "main-scene" in workflow:
            details.append("main scene startup smoke step is present")
        else:
            details.append("main scene startup smoke step is missing")

    checks.append(("run_godot_checked.sh present", checked_runner.is_file()))
    if checked_runner.is_file():
        details.append("run_godot_checked.sh is present")
    else:
        details.append("run_godot_checked.sh is missing")

    checks.append(("restore_lfs_assets.sh present", restore_lfs.is_file()))
    if restore_lfs.is_file():
        details.append("restore_lfs_assets.sh is present")
    else:
        details.append("restore_lfs_assets.sh is missing")

    passed_count = sum(1 for _, ok in checks if ok)
    passed = passed_count == len(checks)
    return CheckResult(
        name="Clean-clone CI",
        passed=passed,
        message=f"CI scaffold check completed ({passed_count}/{len(checks)} items)",
        details=details,
    )


def run_checks(
    *,
    license_check: bool = True,
    provenance_check: bool = True,
    accessibility_check: bool = True,
    platform_check: bool = True,
    ci_check: bool = True,
    root: Path = ROOT,
) -> list[CheckResult]:
    results: list[CheckResult] = []
    if license_check:
        results.append(check_license(root))
    if provenance_check:
        results.append(check_provenance(root))
    if accessibility_check:
        results.append(check_accessibility(root))
    if platform_check:
        results.append(check_platform(root))
    if ci_check:
        results.append(check_ci(root))
    return results


def print_report(results: list[CheckResult]) -> bool:
    print("=" * 70)
    print("RELEASE CANDIDATE VERIFICATION REPORT")
    print("=" * 70)

    all_passed = True
    for result in results:
        status = "PASS" if result.passed else "FAIL"
        print(f"\n{status}: {result.name}")
        print(f"  {result.message}")
        for detail in result.details:
            print(f"  - {detail}")
        if not result.passed:
            all_passed = False

    print("\n" + "=" * 70)
    print(f"OVERALL STATUS: {'ALL CHECKS PASSED' if all_passed else 'SOME CHECKS FAILED'}")
    return all_passed


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Release candidate verification scaffold")
    parser.add_argument("--license", action="store_true", help="Check AGPL license only")
    parser.add_argument("--provenance", action="store_true", help="Check asset provenance scaffold only")
    parser.add_argument("--accessibility", action="store_true", help="Check accessibility baseline only")
    parser.add_argument("--platform", action="store_true", help="Check export preset scaffold only")
    parser.add_argument("--ci", action="store_true", help="Check clean-clone CI scaffold only")
    args = parser.parse_args(argv)

    selected = [args.license, args.provenance, args.accessibility, args.platform, args.ci]
    run_all = not any(selected)
    results = run_checks(
        license_check=run_all or args.license,
        provenance_check=run_all or args.provenance,
        accessibility_check=run_all or args.accessibility,
        platform_check=run_all or args.platform,
        ci_check=run_all or args.ci,
    )
    return 0 if print_report(results) else 1


if __name__ == "__main__":
    sys.exit(main())

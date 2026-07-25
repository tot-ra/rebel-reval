#!/usr/bin/env python3
"""Release-candidate verification scaffold for P0-121.

Automates the repository checks that can run before P3-012, P4-013, or P6-008
maintainer gates per ADR 0014: AGPL license presence, asset provenance manifest, export preset and
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
    third_party_report = root / "tools" / "report_slice_third_party.py"
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

    if not third_party_report.is_file():
        passed = False
        details.append(f"missing slice third-party report tool: {third_party_report}")
    else:
        details.append(f"slice third-party report tool found: {third_party_report}")

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

    checklist_manifest = root / "docs" / "data" / "accessibility_checklist.json"
    checklist_tool = root / "tools" / "report_accessibility_checklist.py"
    gameplay_settings = root / "scripts" / "settings" / "gameplay_accessibility_settings.gd"
    checks.extend(
        [
            ("Accessibility checklist manifest present", checklist_manifest.is_file()),
            ("Accessibility checklist verifier present", checklist_tool.is_file()),
            ("Gameplay accessibility settings model present", gameplay_settings.is_file()),
        ]
    )
    if checklist_manifest.is_file():
        details.append("accessibility_checklist.json is present")
    else:
        details.append("accessibility_checklist.json is missing")
    if checklist_tool.is_file():
        details.append("report_accessibility_checklist.py is present")
    else:
        details.append("report_accessibility_checklist.py is missing")
    if gameplay_settings.is_file():
        details.append("gameplay_accessibility_settings.gd is present")
    else:
        details.append("gameplay_accessibility_settings.gd is missing")

    info_design_manifest = root / "docs" / "data" / "slice_information_design_manifest.json"
    info_design_tool = root / "tools" / "report_slice_information_design.py"
    info_design_report = root / "docs" / "reports" / "p3_008_information_design.md"
    checks.extend(
        [
            ("Information design manifest present", info_design_manifest.is_file()),
            ("Information design verifier present", info_design_tool.is_file()),
            ("Information design maintainer report present", info_design_report.is_file()),
        ]
    )
    if info_design_manifest.is_file():
        details.append("slice_information_design_manifest.json is present")
    else:
        details.append("slice_information_design_manifest.json is missing")
    if info_design_tool.is_file():
        details.append("report_slice_information_design.py is present")
    else:
        details.append("report_slice_information_design.py is missing")
    if info_design_report.is_file():
        details.append("p3_008_information_design.md is present")
    else:
        details.append("p3_008_information_design.md is missing")

    performance_manifest = root / "docs" / "data" / "slice_performance_manifest.json"
    performance_tool = root / "tools" / "report_slice_performance.py"
    performance_report = root / "docs" / "reports" / "p3_011_performance_budget.md"
    checks.extend(
        [
            ("Slice performance manifest present", performance_manifest.is_file()),
            ("Slice performance verifier present", performance_tool.is_file()),
            ("Slice performance maintainer report present", performance_report.is_file()),
        ]
    )
    if performance_manifest.is_file():
        details.append("slice_performance_manifest.json is present")
    else:
        details.append("slice_performance_manifest.json is missing")
    if performance_tool.is_file():
        details.append("report_slice_performance.py is present")
    else:
        details.append("report_slice_performance.py is missing")
    if performance_report.is_file():
        details.append("p3_011_performance_budget.md is present")
    else:
        details.append("p3_011_performance_budget.md is missing")

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
    platform_manifest = root / "docs" / "data" / "slice_platform_manifest.json"
    platform_report_tool = root / "tools" / "report_slice_platform.py"
    maintainer_report = root / "docs" / "reports" / "p3_012_supported_platforms.md"
    verify_script = root / "tools" / "verify_supported_platform.sh"
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
        has_rr_preset = 'name="rr"' in lowered
        checks.extend(
            [
                ("export_presets.cfg present", True),
                ("macOS export preset configured", has_macos_preset),
                ("universal macOS architecture configured", has_universal_arch),
                ("rr export preset configured", has_rr_preset),
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
        if has_rr_preset:
            details.append("rr export preset configured")
        else:
            details.append("rr export preset missing from export_presets.cfg")

    checks.extend(
        [
            ("slice platform manifest present", platform_manifest.is_file()),
            ("slice platform verifier present", platform_report_tool.is_file()),
            ("supported-platform maintainer report present", maintainer_report.is_file()),
            ("supported-platform smoke script present", verify_script.is_file()),
        ]
    )
    if platform_manifest.is_file():
        details.append("slice_platform_manifest.json is present")
    else:
        details.append("slice_platform_manifest.json is missing")
    if platform_report_tool.is_file():
        details.append("report_slice_platform.py is present")
    else:
        details.append("report_slice_platform.py is missing")
    if maintainer_report.is_file():
        details.append("p3_012_supported_platforms.md is present")
    else:
        details.append("p3_012_supported_platforms.md is missing")
    if verify_script.is_file():
        details.append("verify_supported_platform.sh is present")
    else:
        details.append("verify_supported_platform.sh is missing")

    passed_count = sum(1 for _, ok in checks if ok)
    passed = passed_count == len(checks)
    return CheckResult(
        name="Platform Smoke Tests",
        passed=passed,
        message=f"Platform check completed ({passed_count}/{len(checks)} items)",
        details=details,
    )


def check_slice_release(root: Path = ROOT) -> CheckResult:
    manifest = root / "docs" / "data" / "slice_release_manifest.json"
    report_tool = root / "tools" / "report_slice_release.py"
    maintainer_report = root / "docs" / "reports" / "p3_015_slice_release.md"
    verify_script = root / "tools" / "verify_slice_release.sh"
    fixture_path = root / "content/saves/released/save.slice_prologue_complete.json"
    details: list[str] = []
    checks: list[tuple[str, bool]] = [
        ("slice release manifest present", manifest.is_file()),
        ("slice release verifier present", report_tool.is_file()),
        ("slice release maintainer report present", maintainer_report.is_file()),
        ("slice release verify script present", verify_script.is_file()),
        ("published slice save fixture present", fixture_path.is_file()),
    ]
    if manifest.is_file():
        details.append("slice_release_manifest.json is present")
    else:
        details.append("slice_release_manifest.json is missing")
    if report_tool.is_file():
        details.append("report_slice_release.py is present")
    else:
        details.append("report_slice_release.py is missing")
    if maintainer_report.is_file():
        details.append("p3_015_slice_release.md is present")
    else:
        details.append("p3_015_slice_release.md is missing")
    if verify_script.is_file():
        details.append("verify_slice_release.sh is present")
    else:
        details.append("verify_slice_release.sh is missing")
    if fixture_path.is_file():
        details.append("save.slice_prologue_complete.json is present")
    else:
        details.append("save.slice_prologue_complete.json is missing")

    passed_count = sum(1 for _, ok in checks if ok)
    passed = passed_count == len(checks)
    return CheckResult(
        name="Vertical-slice Release",
        passed=passed,
        message=f"Slice release check completed ({passed_count}/{len(checks)} items)",
        details=details,
    )


def check_slice_gate(root: Path = ROOT) -> CheckResult:
    gate_report = root / "docs" / "reports" / "p3_014_slice_gate.md"
    traversal_tool = root / "tools" / "report_slice_traversal.py"
    branch_tool = root / "tools" / "report_slice_branch_consequences.py"
    details: list[str] = []
    checks: list[tuple[str, bool]] = [
        ("vertical-slice gate maintainer report present", gate_report.is_file()),
        ("slice traversal verifier present", traversal_tool.is_file()),
        ("slice branch consequence verifier present", branch_tool.is_file()),
    ]
    if gate_report.is_file():
        content = gate_report.read_text(encoding="utf-8")
        has_signoff = "Maintainer sign-off" in content and "pass" in content.lower()
        checks.append(("gate report records maintainer sign-off", has_signoff))
        details.append("p3_014_slice_gate.md is present")
        if has_signoff:
            details.append("gate report includes maintainer sign-off")
        else:
            details.append("gate report is missing maintainer sign-off section")
    else:
        details.append("p3_014_slice_gate.md is missing")
    if traversal_tool.is_file():
        details.append("report_slice_traversal.py is present")
    else:
        details.append("report_slice_traversal.py is missing")
    if branch_tool.is_file():
        details.append("report_slice_branch_consequences.py is present")
    else:
        details.append("report_slice_branch_consequences.py is missing")

    passed_count = sum(1 for _, ok in checks if ok)
    passed = passed_count == len(checks)
    return CheckResult(
        name="Vertical-slice Gate",
        passed=passed,
        message=f"Slice gate check completed ({passed_count}/{len(checks)} items)",
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
    slice_gate_check: bool = True,
    slice_release_check: bool = True,
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
    if slice_gate_check:
        results.append(check_slice_gate(root))
    if slice_release_check:
        results.append(check_slice_release(root))
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
    parser.add_argument("--slice-gate", action="store_true", help="Check vertical-slice gate report only")
    parser.add_argument("--slice-release", action="store_true", help="Check vertical-slice release scaffold only")
    args = parser.parse_args(argv)

    selected = [args.license, args.provenance, args.accessibility, args.platform, args.slice_gate, args.slice_release, args.ci]
    run_all = not any(selected)
    results = run_checks(
        license_check=run_all or args.license,
        provenance_check=run_all or args.provenance,
        accessibility_check=run_all or args.accessibility,
        platform_check=run_all or args.platform,
        slice_gate_check=run_all or args.slice_gate,
        slice_release_check=run_all or args.slice_release,
        ci_check=run_all or args.ci,
    )
    return 0 if print_report(results) else 1


if __name__ == "__main__":
    sys.exit(main())

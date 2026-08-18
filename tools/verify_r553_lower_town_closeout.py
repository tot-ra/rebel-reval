#!/usr/bin/env python3
"""Validate the R-553 evidence packet before R-109 can be promoted.

This guard intentionally validates evidence semantics rather than rerunning Godot.
The expensive runtime commands remain documented in the report, while this script
prevents an advisory composition card or incomplete evidence matrix from being
mistaken for Lower Town acceptance.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REPORT = ROOT / "docs" / "reports" / "r553_lower_town_integration_verification.md"
DEFAULT_THRESHOLDS = ROOT / "docs" / "data" / "map_composition_thresholds.json"

REQUIRED_HEADINGS = (
    "## Verification matrix",
    "## Exact reproduction commands",
    "## R-109/P0-100 requirement reconciliation",
    "## Dependency and board status snapshot",
    "## Visual evidence limitations",
    "## Final decision and ownership boundary",
    "## Sources",
)
REQUIRED_REQUIREMENTS = (
    "Historically grounded layout, owned sectors, and intentional open space",
    "Dense property footprints and 7-11 m merchant/craft rhythm",
    "Surface bands, limited stone, earth/grass, and accessible elevation",
    "Smithy, brewery, cistern/checkpoints, transitions, quest and patrol routes",
    "Collision, navigation, conversion, and chunk streaming",
    "Day/night gameplay readability and interaction visibility",
)
REQUIRED_COMMANDS = (
    "--filter=test_lower_town_slice_map",
    "--filter=test_lower_town_authoring_contract",
    "--filter=test_map_composition_audit",
    "--filter=test_map_object_chunk_streaming",
    "--filter=test_r552_lower_town_runtime_acceptance",
    "--filter=test_transition_manifest",
    "--filter=test_capture_lower_town_p0_101",
    "python3 tools/verify_map_conversion_parity.py",
)
LINK_RE = re.compile(r"\[[^]]+\]\(([^)]+)\)")


def validate(report_path: Path, thresholds_path: Path) -> list[str]:
    errors: list[str] = []
    if not report_path.is_file():
        return [f"missing report: {report_path}"]
    if not thresholds_path.is_file():
        return [f"missing thresholds: {thresholds_path}"]

    report = report_path.read_text(encoding="utf-8")
    thresholds = json.loads(thresholds_path.read_text(encoding="utf-8"))
    lower_town = thresholds.get("maps", {}).get("lower_town_slice")
    if not isinstance(lower_town, dict):
        errors.append("thresholds have no lower_town_slice card")
        return errors

    for heading in REQUIRED_HEADINGS:
        if heading not in report:
            errors.append(f"report missing heading: {heading}")
    for requirement in REQUIRED_REQUIREMENTS:
        if requirement not in report:
            errors.append(f"report missing R-109 requirement row: {requirement}")
    for command in REQUIRED_COMMANDS:
        if command not in report:
            errors.append(f"report missing reproduction command: {command}")

    decision_match = re.search(r"^\*\*Decision:\*\*\s*(.+)$", report, re.MULTILINE)
    decision = decision_match.group(1) if decision_match else ""
    if not decision:
        errors.append("report missing explicit Decision field")

    # WHY: an advisory threshold card produces no Lower Town audit result. Any
    # acceptance wording in that state would be a false positive even if unrelated
    # enforced maps happen to pass the repository-wide composition command.
    if lower_town.get("enforce") is not True:
        if "BLOCKED" not in decision:
            errors.append("lower_town_slice composition is advisory, so Decision must be BLOCKED")
        if "BLOCKED / NOT ENFORCED" not in report:
            errors.append("advisory composition card must be reported as BLOCKED / NOT ENFORCED")
        if "Do not close R-109/P0-100" not in report:
            errors.append("advisory composition card requires an explicit R-109 closure prohibition")

    for target in LINK_RE.findall(report):
        if target.startswith(("http://", "https://", "#")):
            continue
        local_target = target.split("#", 1)[0]
        if local_target and not (report_path.parent / local_target).resolve().exists():
            errors.append(f"report contains missing local link: {target}")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    parser.add_argument("--thresholds", type=Path, default=DEFAULT_THRESHOLDS)
    args = parser.parse_args()

    errors = validate(args.report.resolve(), args.thresholds.resolve())
    if errors:
        print("R-553 Lower Town closeout verification failed:")
        for error in errors:
            print(f"  - {error}")
        return 1
    print("R-553 Lower Town closeout verification passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Fail-closed static gate for the R-261 completed-tower portfolio.

The checker intentionally does not start Godot or promote any map. It validates
that the dated registry, portfolio ledger, historical report, and accessibility
contract agree. Missing downstream interiors remain BLOCKED rather than being
silently treated as accepted.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
LEDGER_PATH = Path("docs/data/p4_027f_tower_portfolio.json")
REPORT_PATH = Path("docs/reports/p4_027f_completed_tower_portfolio.md")
REGISTRY_PATH = Path("scripts/map/reval_fortification_registry.gd")
ACCESSIBILITY_PATH = Path("docs/data/accessibility_checklist.json")

EXPECTED_COMPLETED = {
    "nunnatorn",
    "kuldjala",
    "rentenitorn",
    "great_coastal_gate",
}
EXPECTED_CONSTRUCTION = {
    "sand_gate",
    "viru_gate",
    "hinke",
    "cattle_gate",
    "harju_gate",
}
EXPECTED_EXCLUDED = {
    "saunatorn",
    "nunnadetagune",
    "loewenschede",
    "koismae",
    "epping",
    "neitsitorn",
    "kiek_in_de_kok",
    "fat_margaret",
}
REQUIRED_BLOCKERS = {
    "R-270",
    "R-251",
    "R-250",
    "R-246",
    "R-252",
    "R-629",
}
REQUIRED_REPORT_TERMS = (
    "fail-closed",
    "construction candidates",
    "post-1343 exclusions",
    "difficulty, loot, and boss portfolio progression",
    "save migration and retry matrix",
    "performance and accessibility evidence packet",
    "signed day/night captures",
)
REQUIRED_ACCESSIBILITY_OPTIONS = {
    "remapping",
    "guard_hold_toggle",
    "text_speed",
    "scalable_text",
    "subtitle_background",
    "focus_contrast",
    "screen_shake",
    "reduced_flashing",
}


def _read(root: Path, relative: Path) -> str:
    return (root / relative).read_text(encoding="utf-8")


def _registry_sets(source: str) -> tuple[set[str], set[str], set[str]]:
    sections: list[str] = []
    anchors = (
        "const COMPLETED_TOWERS_1343",
        "const CONSTRUCTION_CANDIDATES_1343",
        "const POST_1343_EXCLUSIONS",
        "static func completed_tower_count",
    )
    positions = [source.index(anchor) for anchor in anchors]
    for start, end in zip(positions, positions[1:]):
        sections.append(source[start:end])
    values = [
        set(re.findall(r'"historical_id"\s*:\s*&?"([^"]+)"', section))
        for section in sections[:3]
    ]
    return values[0], values[1], values[2]


def _record_block(source: str, historical_id: str) -> str | None:
    pattern = (
        rf'"historical_id"\s*:\s*&?"{re.escape(historical_id)}"\s*,'
        rf'(?P<body>.*?)(?=\n\t\t\}},|\n\t\}},)'
    )
    match = re.search(pattern, source, re.DOTALL)
    return match.group(0) if match else None


def _load_json(root: Path, relative: Path) -> dict[str, Any]:
    value = json.loads(_read(root, relative))
    if not isinstance(value, dict):
        raise ValueError(f"{relative} must contain a JSON object")
    return value


def _check_ledger(ledger: dict[str, Any], root: Path) -> list[str]:
    errors: list[str] = []
    if ledger.get("schema") != "rebel-reval-tower-portfolio-v1":
        errors.append("ledger schema is not rebel-reval-tower-portfolio-v1")
    if ledger.get("snapshot_year") != 1343:
        errors.append("ledger snapshot_year must be 1343")
    if ledger.get("policy") != "fail_closed":
        errors.append("ledger policy must be fail_closed")
    if ledger.get("completed_registry_count") != len(EXPECTED_COMPLETED):
        errors.append("completed_registry_count must match the four-position registry")
    if set(ledger.get("completed_registry_ids", [])) != EXPECTED_COMPLETED:
        errors.append("ledger completed_registry_ids must match the conservative registry")
    if set(ledger.get("construction_candidates", [])) != EXPECTED_CONSTRUCTION:
        errors.append("ledger construction_candidates drifted from the registry")
    if set(ledger.get("post_1343_exclusions", [])) != EXPECTED_EXCLUDED:
        errors.append("ledger post_1343_exclusions drifted from the registry")

    portfolio = ledger.get("portfolio")
    if not isinstance(portfolio, list):
        return errors + ["portfolio must be a list"]
    ids = [row.get("historical_id") for row in portfolio if isinstance(row, dict)]
    if len(portfolio) != len(EXPECTED_COMPLETED) or set(ids) != EXPECTED_COMPLETED:
        errors.append("portfolio must contain exactly one row for every completed registry ID")
    interior_ids = [row.get("interior_map_id") for row in portfolio if isinstance(row, dict)]
    if len(interior_ids) != len(set(interior_ids)):
        errors.append("completed towers must not share a dedicated interior_map_id")

    for row in portfolio:
        if not isinstance(row, dict):
            errors.append("portfolio rows must be objects")
            continue
        historical_id = row.get("historical_id", "<missing>")
        if historical_id in EXPECTED_CONSTRUCTION or historical_id in EXPECTED_EXCLUDED:
            errors.append(f"{historical_id} cannot be a completed-tower portfolio row")
        if not row.get("map_id") or not row.get("building_id"):
            errors.append(f"{historical_id} needs map_id and building_id")
        if not row.get("interior_map_id") or not row.get("interior_scene"):
            errors.append(f"{historical_id} needs a dedicated interior map and scene contract")
        if not row.get("owner_ref"):
            errors.append(f"{historical_id} needs an owning task reference")
        if row.get("status") == "pass" and row.get("acceptance_ref") is None:
            errors.append(f"{historical_id} cannot pass without an acceptance_ref")

    shared = ledger.get("shared_gate", {})
    if set(shared.get("required_blockers_to_clear", [])) != REQUIRED_BLOCKERS:
        errors.append("shared_gate required_blockers_to_clear must name all current tower owners")
    for key in (
        "one_interior_per_completed_tower",
        "construction_candidates_enterable_as_completed_dungeons",
        "post_1343_exclusions_enterable",
        "requires_reciprocal_transition",
        "requires_multi_floor_and_wall_walk",
        "requires_boss_and_alternate_resolution",
        "requires_save_migration_and_retry",
        "requires_target_hardware_performance_evidence",
        "requires_accessibility_review",
        "requires_signed_day_night_captures",
    ):
        expected = key not in {
            "construction_candidates_enterable_as_completed_dungeons",
            "post_1343_exclusions_enterable",
        }
        if shared.get(key) is not expected:
            errors.append(f"shared_gate.{key} must be {str(expected).lower()}")

    if ledger.get("decision") == "approved":
        if ledger.get("blockers"):
            errors.append("approved portfolio cannot retain blockers")
        if any(row.get("status") != "pass" for row in portfolio if isinstance(row, dict)):
            errors.append("approved portfolio requires every completed row to be pass")
    elif ledger.get("decision") != "blocked":
        errors.append("portfolio decision must be blocked until every row is accepted")

    # Existing files are evidence only. A missing downstream package must keep the
    # row non-pass, never turn into an implicit approval.
    for row in portfolio:
        scene = row.get("interior_scene")
        if row.get("status") == "pass" and isinstance(scene, str) and not (root / scene).is_file():
            errors.append(f"accepted {row.get('historical_id')} scene is missing: {scene}")
    return errors


def verify(root: Path = ROOT) -> list[str]:
    """Return structural errors; an internally consistent blocked ledger is valid."""
    errors: list[str] = []
    try:
        registry = _read(root, REGISTRY_PATH)
        ledger = _load_json(root, LEDGER_PATH)
        accessibility = _load_json(root, ACCESSIBILITY_PATH)
        report = _read(root, REPORT_PATH)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        return [str(exc)]

    try:
        completed, construction, excluded = _registry_sets(registry)
    except ValueError as exc:
        return [f"cannot parse fortification registry: {exc}"]
    if completed != EXPECTED_COMPLETED:
        errors.append("runtime completed registry does not match the four-position portfolio")
    if construction != EXPECTED_CONSTRUCTION:
        errors.append("runtime construction registry does not match the five-position policy")
    if excluded != EXPECTED_EXCLUDED:
        errors.append("runtime exclusion registry does not match the post-1343 policy")
    if completed & construction or completed & excluded or construction & excluded:
        errors.append("registry classes overlap")

    for historical_id, expected in {
        "nunnatorn": ("monastery_quarter", "monastery_wall_tower_northwest"),
        "kuldjala": ("monastery_quarter", "monastery_wall_tower_west_mid"),
        "rentenitorn": ("north_quarter", "merchant_wall_tower_northwest"),
        "great_coastal_gate": ("north_quarter", "coast_gate_west_tower"),
    }.items():
        block = _record_block(registry, historical_id)
        if block is None or any(
            f'"{field}": &"{value}"' not in block
            for field, value in zip(("map_id", "building_id"), expected)
        ):
            errors.append(
                f"{historical_id} registry record does not match its portfolio mapping"
            )

    errors.extend(_check_ledger(ledger, root))
    report_lower = report.lower()
    errors.extend(
        f"report is missing required term: {term}"
        for term in REQUIRED_REPORT_TERMS
        if term not in report_lower
    )
    options = set(accessibility.get("required_options", []))
    errors.extend(
        f"accessibility checklist is missing option: {option}"
        for option in sorted(REQUIRED_ACCESSIBILITY_OPTIONS - options)
    )
    if set(accessibility.get("input_methods", [])) != {"keyboard_mouse", "gamepad"}:
        errors.append("accessibility checklist must cover keyboard_mouse and gamepad")
    if ledger.get("acceptance_report") != str(REPORT_PATH):
        errors.append("ledger acceptance_report must point to the portfolio report")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args(argv)
    root = args.root.resolve()
    errors = verify(root)
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    ledger = _load_json(root, LEDGER_PATH)
    if ledger.get("decision") == "blocked":
        blockers = ", ".join(ledger.get("shared_gate", {}).get("required_blockers_to_clear", []))
        print(f"R-261 tower portfolio gate structurally valid: BLOCKED ({blockers})")
    else:
        print("R-261 tower portfolio gate passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

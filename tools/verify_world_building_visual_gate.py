#!/usr/bin/env python3
"""Validate the world-building visual benchmark and release gate.

The benchmark manifest is deliberately fail-closed: a map cannot be promoted by
having a row in the matrix alone. Every required capture, rubric decision,
human review, and automated check must have an approved status and repository
 evidence before the gate can pass.

Usage:
    python3 tools/verify_world_building_visual_gate.py
    python3 tools/verify_world_building_visual_gate.py --json
    python3 tools/verify_world_building_visual_gate.py --manifest path/to/manifest.json

Exit codes: 0 = the visual gate passes, 1 = the gate is blocked or malformed.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any, Iterable

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "docs" / "data" / "world_building_visual_benchmark.json"

ALLOWED_STATUSES = frozenset({"missing", "pending", "pass", "fail", "not_applicable", "approved"})
REQUIRED_CAPTURE_CATEGORIES = (
    "close_up",
    "gameplay",
    "vista",
    "day",
    "night",
    "rain",
    "wind",
    "water",
    "crowds",
    "characters",
    "landmark_architecture",
    "adjacent_map_traversal",
)
REQUIRED_RUBRIC_CRITERIA = (
    "geometry_silhouette",
    "pbr_response",
    "texture_density",
    "lighting_atmosphere",
    "water_surface",
    "vegetation_distribution",
    "animation_temporal",
    "historical_coherence",
    "repetition_and_variation",
    "seams_and_transitions",
    "temporal_stability",
    "performance_tier",
)
REQUIRED_AUTOMATED_CHECKS = (
    "map_registry",
    "map_audit",
    "capture_manifest",
    "transition_audit",
    "performance_report",
)
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
REQUIRED_PERFORMANCE_TIERS = ("minimum", "recommended")
EXTERIOR_SCENE_EXCLUSIONS = frozenset({
    "forge",
    "nunnatorn_interior",
})


def _check_iso_timestamp(value: Any, context: str, errors: list[str]) -> None:
    if not isinstance(value, str) or not value.strip():
        errors.append(f"{context} requires an ISO-8601 generated_utc timestamp")
        return
    try:
        datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        errors.append(f"{context} generated_utc must be an ISO-8601 timestamp: {value!r}")


def _check_performance_evidence(
    root: Path, manifest: dict[str, Any], errors: list[str]
) -> None:
    performance = manifest.get("performance_evidence")
    if not isinstance(performance, dict):
        errors.append("performance_evidence must be an object with minimum and recommended rows")
        return
    for tier in REQUIRED_PERFORMANCE_TIERS:
        context = f"performance evidence {tier}"
        entry = performance.get(tier)
        status = _check_evidence_entry(root, entry, context, errors)
        if status != "pass":
            errors.append(f"{context} is not accepted: {status}")
        if not isinstance(entry, dict):
            continue
        for identity in ("target_hardware", "measurement_host"):
            value = entry.get(identity)
            if not isinstance(value, dict) or not value:
                errors.append(f"{context} requires {identity} identity")


def _canonical_map_id(map_id: str) -> str:
    """Collapse scene-style world IDs onto the RRMap namespace."""

    return f"world.{map_id[6:]}" if map_id.startswith("world_") else map_id

@dataclass
class GateResult:
    """Machine-readable result of a benchmark gate evaluation."""

    valid: bool
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    expected_map_ids: list[str] = field(default_factory=list)
    manifest_map_ids: list[str] = field(default_factory=list)

    def as_dict(self) -> dict[str, Any]:
        return {
            "valid": self.valid,
            "errors": self.errors,
            "warnings": self.warnings,
            "expected_map_count": len(self.expected_map_ids),
            "manifest_map_count": len(self.manifest_map_ids),
            "expected_map_ids": self.expected_map_ids,
            "manifest_map_ids": self.manifest_map_ids,
        }


def _load_json(path: Path, label: str) -> tuple[Any | None, list[str]]:
    try:
        return json.loads(path.read_text(encoding="utf-8")), []
    except FileNotFoundError:
        return None, [f"missing {label}: {path}"]
    except json.JSONDecodeError as error:
        return None, [
            f"invalid JSON in {label}: line {error.lineno}, "
            f"column {error.colno}: {error.msg}"
        ]


def _as_list(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def _active_registry_ids(root: Path) -> tuple[set[str], list[str]]:
    path = root / "content" / "transitions" / "active_destinations.json"
    payload, errors = _load_json(path, "active destination registry")
    if errors:
        return set(), errors
    if not isinstance(payload, dict):
        return set(), ["active destination registry must contain an object"]
    scene_ids: set[str] = set()
    for scene in _as_list(payload.get("scenes")):
        if not isinstance(scene, dict):
            continue
        if scene.get("active") is True and isinstance(scene.get("id"), str):
            scene_id = scene["id"]
            if scene_id not in EXTERIOR_SCENE_EXCLUSIONS:
                scene_ids.add(_canonical_map_id(scene_id))
    if not scene_ids:
        return set(), ["active destination registry contains no active scene IDs"]
    return scene_ids, []


def _candidate_ids(root: Path) -> tuple[set[str], list[str]]:
    errors: list[str] = []
    candidates: set[str] = set()

    location_path = root / "docs" / "data" / "location_activation_manifest.json"
    location_payload, location_errors = _load_json(location_path, "location activation manifest")
    errors.extend(location_errors)
    if isinstance(location_payload, dict):
        for entry in _as_list(location_payload.get("maps")):
            if isinstance(entry, dict) and isinstance(entry.get("map_id"), str):
                candidates.add(entry["map_id"])

    act3_path = root / "docs" / "data" / "p6_002_activation_manifest.json"
    act3_payload, act3_errors = _load_json(act3_path, "Act 3 activation manifest")
    errors.extend(act3_errors)
    if isinstance(act3_payload, dict):
        for entry in _as_list(act3_payload.get("targets")):
            if isinstance(entry, dict):
                for key in ("id", "rrmap_id"):
                    if isinstance(entry.get(key), str):
                        candidates.add(_canonical_map_id(entry[key]))
    return candidates, errors


def expected_map_ids(root: Path = ROOT) -> tuple[set[str], list[str]]:
    """Return the union of active runtime scenes and candidate exterior maps."""

    active_ids, active_errors = _active_registry_ids(root)
    candidate_ids, candidate_errors = _candidate_ids(root)
    return active_ids | candidate_ids, active_errors + candidate_errors


def _safe_evidence_path(root: Path, value: Any, context: str, errors: list[str]) -> Path | None:
    if not isinstance(value, str) or not value:
        errors.append(f"{context} requires a repository-relative evidence path")
        return None
    if value.startswith("/") or value.startswith("res://"):
        errors.append(f"{context} evidence path must be repository-relative: {value}")
        return None
    candidate = (root / value).resolve()
    root_resolved = root.resolve()
    try:
        candidate.relative_to(root_resolved)
    except ValueError:
        errors.append(f"{context} evidence path escapes the repository: {value}")
        return None
    return candidate


def _check_evidence_entry(
    root: Path,
    entry: Any,
    context: str,
    errors: list[str],
    *,
    accepted_statuses: Iterable[str] = ("pass",),
) -> str | None:
    if not isinstance(entry, dict):
        errors.append(f"{context} must be an object")
        return None
    status = entry.get("status")
    if status not in ALLOWED_STATUSES:
        errors.append(f"{context} has invalid status: {status!r}")
        return None
    evidence = entry.get("evidence")
    if status in accepted_statuses:
        evidence_path = _safe_evidence_path(root, evidence, context, errors)
        if evidence_path is not None and not evidence_path.is_file():
            errors.append(f"{context} evidence file does not exist: {evidence}")
    elif evidence is not None:
        _safe_evidence_path(root, evidence, context, errors)
    return status


def _check_required_keys(
    value: Any, required: Iterable[str], context: str, errors: list[str]
) -> bool:
    if not isinstance(value, dict):
        errors.append(f"{context} must be an object")
        return False
    valid = True
    for key in required:
        if key not in value:
            errors.append(f"{context} is missing required key: {key}")
            valid = False
    return valid


def verify_manifest(root: Path, manifest: dict[str, Any]) -> GateResult:
    """Validate a loaded manifest against repository inventories and gate policy."""

    errors: list[str] = []
    warnings: list[str] = []
    expected_ids, inventory_errors = expected_map_ids(root)
    errors.extend(inventory_errors)

    if manifest.get("schema_version") != 1:
        errors.append("manifest schema_version must be 1")
    if manifest.get("task_id") != "R-716":
        errors.append("manifest task_id must be R-716")

    settings = manifest.get("fixed_capture_settings")
    _check_required_keys(
        settings,
        ("camera", "resolution", "exposure", "time", "weather", "wind_seed"),
        "fixed_capture_settings",
        errors,
    )
    if isinstance(settings, dict) and settings.get("resolution") != "1920x1080":
        errors.append("fixed_capture_settings resolution must remain 1920x1080")

    capture_matrix = manifest.get("capture_matrix")
    if isinstance(capture_matrix, dict):
        categories = capture_matrix.get("required_categories")
        if categories != list(REQUIRED_CAPTURE_CATEGORIES):
            errors.append("capture_matrix.required_categories drifted from the R-716 contract")
        if not isinstance(capture_matrix.get("evidence_root"), str):
            errors.append("capture_matrix.evidence_root must be a repository-relative directory")
    else:
        errors.append("capture_matrix must be an object")

    rubric = manifest.get("visual_rubric")
    rubric_ids: list[str] = []
    if isinstance(rubric, list):
        for entry in rubric:
            if isinstance(entry, dict) and isinstance(entry.get("id"), str):
                rubric_ids.append(entry["id"])
    if rubric_ids != list(REQUIRED_RUBRIC_CRITERIA):
        errors.append("visual_rubric IDs drifted from the R-716 contract")

    automation = manifest.get("automated_checks")
    if not isinstance(automation, dict):
        errors.append("automated_checks must be an object")
        automation = {}
    for check_id in REQUIRED_AUTOMATED_CHECKS:
        if check_id not in automation:
            errors.append(f"automated_checks is missing required check: {check_id}")
        else:
            status = _check_evidence_entry(
                root, automation[check_id], f"automated check {check_id}", errors
            )
            if status != "pass":
                errors.append(f"automated check {check_id} is not accepted: {status}")

    _check_performance_evidence(root, manifest, errors)

    comparison_sheet = manifest.get("comparison_sheet")
    comparison_status = _check_evidence_entry(root, comparison_sheet, "comparison_sheet", errors)
    if comparison_status != "pass":
        errors.append(f"comparison_sheet is not accepted: {comparison_status}")
    if isinstance(comparison_sheet, dict):
        if comparison_status == "pass" and not isinstance(comparison_sheet.get("revision"), str):
            errors.append("comparison_sheet revision must be a non-empty version identifier")
        elif comparison_status == "pass" and not comparison_sheet["revision"].strip():
            errors.append("comparison_sheet revision must be a non-empty version identifier")
        _check_iso_timestamp(comparison_sheet.get("generated_utc"), "comparison_sheet", errors)

    maps = manifest.get("maps")
    if not isinstance(maps, list):
        errors.append("maps must be an array")
        maps = []
    manifest_ids: list[str] = []
    seen: set[str] = set()
    for index, entry in enumerate(maps):
        context = f"maps[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{context} must be an object")
            continue
        map_id = entry.get("id")
        if not isinstance(map_id, str) or not map_id:
            errors.append(f"{context}.id must be a non-empty string")
            continue
        manifest_ids.append(map_id)
        if map_id in seen:
            errors.append(f"duplicate benchmark map ID: {map_id}")
        seen.add(map_id)
        if not isinstance(entry.get("source_path"), str):
            errors.append(f"{context}.source_path must identify the authored map source")
        elif not (root / entry["source_path"]).is_file():
            errors.append(f"{context}.source_path does not exist: {entry['source_path']}")

        captures = entry.get("captures")
        if not isinstance(captures, dict):
            errors.append(f"{context}.captures must be an object")
            captures = {}
        for category in REQUIRED_CAPTURE_CATEGORIES:
            if category not in captures:
                errors.append(f"{map_id} capture category missing: {category}")
            else:
                status = _check_evidence_entry(
                    root, captures[category], f"{map_id} capture {category}", errors
                )
                if status != "pass":
                    errors.append(f"{map_id} capture {category} is not accepted: {status}")

        reviews = entry.get("rubric_reviews")
        if not isinstance(reviews, dict):
            errors.append(f"{context}.rubric_reviews must be an object")
            reviews = {}
        for criterion in REQUIRED_RUBRIC_CRITERIA:
            if criterion not in reviews:
                errors.append(f"{map_id} rubric review missing: {criterion}")
            else:
                status = _check_evidence_entry(
                    root, reviews[criterion], f"{map_id} rubric {criterion}", errors
                )
                if status != "pass":
                    errors.append(f"{map_id} rubric {criterion} is not accepted: {status}")

        human_review = entry.get("human_review")
        if not isinstance(human_review, dict):
            errors.append(f"{map_id} human_review must be an object")
            continue
        review_status = human_review.get("status")
        if review_status != "approved":
            errors.append(f"{map_id} human art review is not approved: {review_status}")
        reviewer = human_review.get("reviewer")
        if not isinstance(reviewer, str) or not reviewer.strip():
            errors.append(f"{map_id} human art review requires reviewer")
        review_date = human_review.get("review_date")
        if not isinstance(review_date, str) or not DATE_RE.fullmatch(review_date):
            errors.append(f"{map_id} human art review requires YYYY-MM-DD review_date")
        _check_evidence_entry(root, human_review, f"{map_id} human art review", errors, accepted_statuses=("approved",))

    missing_ids = sorted(expected_ids - seen)
    if missing_ids:
        errors.append("benchmark matrix is missing active/candidate map IDs: " + ", ".join(missing_ids))
    extra_ids = sorted(seen - expected_ids)
    if extra_ids:
        warnings.append("benchmark matrix contains explicit non-registry rows: " + ", ".join(extra_ids))

    return GateResult(
        valid=not errors,
        errors=errors,
        warnings=warnings,
        expected_map_ids=sorted(expected_ids),
        manifest_map_ids=sorted(manifest_ids),
    )


def verify_manifest_file(root: Path = ROOT, manifest_path: Path = DEFAULT_MANIFEST) -> GateResult:
    payload, errors = _load_json(manifest_path, "world-building visual benchmark manifest")
    if errors:
        return GateResult(valid=False, errors=errors)
    if not isinstance(payload, dict):
        return GateResult(valid=False, errors=["world-building visual benchmark manifest must be an object"])
    return verify_manifest(root, payload)


def _print_report(result: GateResult, as_json: bool) -> None:
    if as_json:
        print(json.dumps(result.as_dict(), indent=2, sort_keys=True))
        return
    print("WORLD-BUILDING VISUAL RELEASE GATE")
    print(
        f"Benchmark rows: {len(result.manifest_map_ids)}/{len(result.expected_map_ids)} "
        "expected active/candidate maps"
    )
    if result.warnings:
        for warning in result.warnings:
            print(f"WARNING: {warning}")
    if result.errors:
        print(f"BLOCKED: {len(result.errors)} gate finding(s)")
        for error in result.errors:
            print(f"- {error}")
    else:
        print("PASS: capture, rubric, human review, and automated evidence are complete")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--json", action="store_true", help="print machine-readable JSON")
    args = parser.parse_args(argv)
    result = verify_manifest_file(ROOT, args.manifest)
    _print_report(result, args.json)
    return 0 if result.valid else 1


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Generate and verify the P0-039 blind gameplay-scale readability stimulus pack.

Builds a facilitator-facing pack from committed gameplay-scale captures. Blind
labels hide map IDs, style names, and engine terminology from participants. The
committed JSON manifest is checked in CI; use --write to refresh blind copies.

Usage:
    python3 tools/generate_p039_readability_pack.py --write
    python3 tools/generate_p039_readability_pack.py --check
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "docs" / "reports" / "data" / "p039_readability_pack.json"
PROTOCOL = ROOT / "docs" / "reports" / "p0_039_blind_readability_protocol.md"
BLIND_DIR = ROOT / "docs" / "reports" / "images" / "p039_blind_pack"
TEMPLATE = ROOT / "docs" / "reports" / "data" / "p039_readability_results.template.json"

SCHEMA_VERSION = 1
MINIMUM_PARTICIPANTS = 5
RECOGNITION_TARGETS = ("silhouette", "interaction", "depth", "motion")
BLIND_LABELS = ("Stimulus A", "Stimulus B", "Stimulus C", "Stimulus D", "Stimulus E", "Stimulus F")

# Deterministic stimulus order: gameplay exterior day/night, interior day/night, motion cues.
STIMULUS_SOURCES: tuple[dict[str, Any], ...] = (
    {
        "stimulus_id": "stimulus.lower_town_day",
        "source_path": "docs/reports/images/view3d/lower_town_slice_day.png",
        "map_id": "lower_town_slice",
        "time_of_day": "day",
        "motion": False,
        "facilitator_notes": (
            "Exterior Lower Town district at gameplay framing. Ask what buildings, "
            "routes, and interactables read without labels."
        ),
    },
    {
        "stimulus_id": "stimulus.lower_town_night",
        "source_path": "docs/reports/images/view3d/lower_town_slice_night.png",
        "map_id": "lower_town_slice",
        "time_of_day": "night",
        "motion": False,
        "facilitator_notes": (
            "Same district at night. Confirm routes, landmarks, and interactables "
            "remain legible without color-only cues."
        ),
    },
    {
        "stimulus_id": "stimulus.smithy_day",
        "source_path": "docs/reports/images/view3d/kalev_smithy_day.png",
        "map_id": "kalev_smithy",
        "time_of_day": "day",
        "motion": False,
        "facilitator_notes": (
            "Interior forge workspace. Ask which tools, work surfaces, and exits "
            "participants would approach first."
        ),
    },
    {
        "stimulus_id": "stimulus.smithy_night",
        "source_path": "docs/reports/images/view3d/kalev_smithy_night.png",
        "map_id": "kalev_smithy",
        "time_of_day": "night",
        "motion": False,
        "facilitator_notes": (
            "Interior forge at night. Confirm depth, props, and the player accent "
            "remain readable."
        ),
    },
    {
        "stimulus_id": "stimulus.walk_cycle",
        "source_path": "docs/reports/images/view3d/start_scene_walk.png",
        "map_id": "start_scene",
        "time_of_day": "day",
        "motion": True,
        "facilitator_notes": (
            "Animated walk capture. Ask whether motion direction, foot contact, and "
            "foreground/background separation read at gameplay scale."
        ),
    },
    {
        "stimulus_id": "stimulus.smithy_fp_depth",
        "source_path": "docs/reports/images/view3d/smithy_fp/smithy_fp_yaw090.png",
        "map_id": "kalev_smithy",
        "time_of_day": "day",
        "motion": False,
        "facilitator_notes": (
            "First-person interior framing. Ask which surfaces feel nearest, which "
            "props invite interaction, and whether architectural depth is clear."
        ),
    },
)


def _read_json(path: Path) -> dict[str, Any]:
    parsed = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(parsed, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return parsed


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


def build_manifest(*, root: Path = ROOT) -> dict[str, Any]:
    if len(STIMULUS_SOURCES) != len(BLIND_LABELS):
        raise ValueError("stimulus source count must match blind label count")

    protocol_path = root / "docs/reports/p0_039_blind_readability_protocol.md"
    template_path = root / "docs/reports/data/p039_readability_results.template.json"
    blind_dir = root / "docs/reports/images/p039_blind_pack"

    stimuli: list[dict[str, Any]] = []
    for index, source in enumerate(STIMULUS_SOURCES):
        source_path = root / source["source_path"]
        if not source_path.is_file():
            raise FileNotFoundError(f"missing stimulus source: {source_path.relative_to(root)}")
        blind_label = BLIND_LABELS[index]
        blind_copy = blind_dir / f"stimulus_{chr(ord('a') + index)}.png"
        stimuli.append(
            {
                **source,
                "blind_label": blind_label,
                "blind_copy": blind_copy.relative_to(root).as_posix(),
                "sha256": _sha256(source_path),
            }
        )

    return {
        "schema_version": SCHEMA_VERSION,
        "task_id": "P0-039",
        "generated_utc": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "minimum_participants": MINIMUM_PARTICIPANTS,
        "recognition_targets": list(RECOGNITION_TARGETS),
        "protocol_path": protocol_path.relative_to(root).as_posix(),
        "results_template_path": template_path.relative_to(root).as_posix(),
        "stimuli": stimuli,
        "facilitator_rules": [
            "Show only blind-labelled PNGs. Do not reveal map IDs, engine names, or style candidates.",
            "Collect at least five independent participants.",
            "Record silhouette, interaction priority, depth, and motion recognition for every stimulus.",
            "Use the 1-5 rubric in the protocol for each recognition target.",
        ],
    }


def write_pack(*, root: Path = ROOT) -> dict[str, Any]:
    manifest = build_manifest(root=root)
    blind_dir = root / "docs/reports/images/p039_blind_pack"
    manifest_path = root / "docs/reports/data/p039_readability_pack.json"
    blind_dir.mkdir(parents=True, exist_ok=True)
    for stimulus in manifest["stimuli"]:
        source = root / stimulus["source_path"]
        target = root / stimulus["blind_copy"]
        shutil.copy2(source, target)
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def validate_manifest(manifest: dict[str, Any], *, root: Path = ROOT) -> list[str]:
    errors: list[str] = []

    if manifest.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"schema_version must be {SCHEMA_VERSION}")

    if manifest.get("minimum_participants") != MINIMUM_PARTICIPANTS:
        errors.append(f"minimum_participants must be {MINIMUM_PARTICIPANTS}")

    targets = manifest.get("recognition_targets")
    if targets != list(RECOGNITION_TARGETS):
        errors.append("recognition_targets must list silhouette, interaction, depth, motion")

    stimuli = manifest.get("stimuli")
    if not isinstance(stimuli, list) or len(stimuli) != len(STIMULUS_SOURCES):
        errors.append(f"stimuli must contain exactly {len(STIMULUS_SOURCES)} entries")
        return errors

    labels = [entry.get("blind_label") for entry in stimuli if isinstance(entry, dict)]
    if labels != list(BLIND_LABELS):
        errors.append("blind labels are out of order or missing")

    for entry in stimuli:
        if not isinstance(entry, dict):
            errors.append("stimulus entry must be an object")
            continue
        stimulus_id = entry.get("stimulus_id", "")
        source_path = root / str(entry.get("source_path", ""))
        blind_copy = root / str(entry.get("blind_copy", ""))
        expected_sha = entry.get("sha256", "")
        if not source_path.is_file():
            errors.append(f"{stimulus_id}: missing source capture {source_path.relative_to(root)}")
            continue
        if expected_sha and _sha256(source_path) != expected_sha:
            errors.append(f"{stimulus_id}: sha256 mismatch for {source_path.relative_to(root)}")
        if not blind_copy.is_file():
            errors.append(f"{stimulus_id}: missing blind copy {blind_copy.relative_to(root)}")

    return errors


def check(*, root: Path = ROOT) -> list[str]:
    errors: list[str] = []
    protocol_path = root / "docs/reports/p0_039_blind_readability_protocol.md"
    template_path = root / "docs/reports/data/p039_readability_results.template.json"
    manifest_path = root / "docs/reports/data/p039_readability_pack.json"
    if not protocol_path.is_file():
        errors.append(f"missing protocol: {protocol_path.relative_to(root)}")
    if not template_path.is_file():
        errors.append(f"missing results template: {template_path.relative_to(root)}")
    if not manifest_path.is_file():
        errors.append(f"missing manifest: {manifest_path.relative_to(root)}")
        return errors
    try:
        manifest = _read_json(manifest_path)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        errors.append(f"manifest unreadable: {exc}")
        return errors
    errors.extend(validate_manifest(manifest, root=root))
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="Regenerate blind copies and manifest")
    parser.add_argument("--check", action="store_true", help="Verify committed pack artifacts")
    args = parser.parse_args()

    if args.write:
        try:
            manifest = write_pack()
        except (OSError, ValueError) as exc:
            print(f"P0-039 readability pack generation failed: {exc}", file=sys.stderr)
            return 1
        print(
            f"P0-039 readability pack written ({len(manifest['stimuli'])} stimuli, "
            f"minimum {manifest['minimum_participants']} participants)"
        )
        return 0

    if args.check or not args.write:
        errors = check()
        if errors:
            print("P0-039 readability pack verification failed:")
            for error in errors:
                print(f"  - {error}")
            return 1
        print("P0-039 readability pack verification passed")
        return 0

    parser.error("specify --write or --check")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Verify P2-021a gameplay-parity scaffold for converted slice maps.

Checks anchor accounting, capture evidence, report metadata, and delegates
collision/navigation/route proofs to the existing Godot map suites.

Full visual human sign-off remains on **P2-021**; pass ``--require-human-sign-off``
only when closing that task.

Usage:
    python3 tools/verify_map_conversion_parity.py
    python3 tools/verify_map_conversion_parity.py --require-human-sign-off
    python3 tools/verify_map_conversion_parity.py --skip-godot
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "docs/data/map_conversion_parity_manifest.json"
ANCHOR_RE = re.compile(r"^anchor\s+(\S+)")
TRANSITION_RE = re.compile(r"^transition\s+(\S+)")
MIN_DAY_NIGHT_LUMINANCE_DELTA = 10.0
MIN_LUMINANCE_STDEV = 5.0

if str(ROOT / "tools") not in sys.path:
    sys.path.insert(0, str(ROOT / "tools"))

from verify_slice_surface_captures import capture_stats  # noqa: E402


@dataclass(frozen=True)
class ValidationError:
    message: str


def load_manifest(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _parity_anchor_ids(root: Path, fixture_rel: str) -> set[str]:
    fixture_path = root / fixture_rel
    payload = json.loads(fixture_path.read_text(encoding="utf-8"))
    return {str(entry["id"]) for entry in payload.get("anchors", [])}


def _rrmap_anchor_ids(root: Path, map_rel: str) -> set[str]:
    map_path = root / map_rel
    anchors: set[str] = set()
    for line in map_path.read_text(encoding="utf-8").splitlines():
        match = ANCHOR_RE.match(line.strip())
        if match:
            anchors.add(match.group(1))
    return anchors


def _rrmap_transition_ids(root: Path, map_rel: str) -> set[str]:
    map_path = root / map_rel
    transitions: set[str] = set()
    for line in map_path.read_text(encoding="utf-8").splitlines():
        match = TRANSITION_RE.match(line.strip())
        if match:
            transitions.add(match.group(1))
    return transitions


def validate_anchor_accounting(root: Path, manifest: dict) -> list[ValidationError]:
    errors: list[ValidationError] = []
    for map_entry in manifest.get("maps", []):
        map_id = str(map_entry.get("map_id", ""))
        required = [str(anchor) for anchor in map_entry.get("required_anchors", [])]
        rejected = {str(anchor) for anchor in map_entry.get("rejected_anchors", [])}
        if not required:
            errors.append(ValidationError(f"{map_id}: required_anchors must not be empty"))
            continue

        if parity_fixture := map_entry.get("parity_fixture"):
            present = _parity_anchor_ids(root, str(parity_fixture))
            source_label = str(parity_fixture)
        elif source_map := map_entry.get("source_map"):
            present = _rrmap_anchor_ids(root, str(source_map))
            source_label = str(source_map)
        else:
            errors.append(ValidationError(f"{map_id}: map entry needs parity_fixture or source_map"))
            continue

        missing = sorted(set(required) - present - rejected)
        if missing:
            errors.append(
                ValidationError(
                    f"{map_id}: missing required anchors in {source_label}: {', '.join(missing)}"
                )
            )

        overlap = sorted(set(required) & rejected)
        if overlap:
            errors.append(
                ValidationError(
                    f"{map_id}: anchor cannot be both required and rejected: {', '.join(overlap)}"
                )
            )

        accounted = len(set(required) - rejected)
        present_required = len(set(required) & present)
        if present_required != accounted:
            continue
        print(
            f"* {map_id}: anchor accounting {present_required}/{accounted} "
            f"({source_label})"
        )

        for transition_id in map_entry.get("required_transitions", []):
            transition_id = str(transition_id)
            source_map = str(map_entry.get("source_map", ""))
            if not source_map:
                errors.append(
                    ValidationError(f"{map_id}: required_transitions need source_map")
                )
                continue
            if transition_id not in _rrmap_transition_ids(root, source_map):
                errors.append(
                    ValidationError(
                        f"{map_id}: missing required transition {transition_id} in {source_map}"
                    )
                )

        topology = [str(node) for node in map_entry.get("topology_route", [])]
        allowed_topology = set(required) | rejected | present
        for transition_id in map_entry.get("required_transitions", []):
            allowed_topology.add(str(transition_id))
        if topology and not set(topology).issubset(allowed_topology):
            errors.append(
                ValidationError(f"{map_id}: topology_route references unknown anchors")
            )
    return errors


def validate_captures(root: Path, manifest: dict) -> list[ValidationError]:
    errors: list[ValidationError] = []
    expected_width = int(manifest.get("capture_width", 1280))
    expected_height = int(manifest.get("capture_height", 720))
    captures = {str(entry["id"]): entry for entry in manifest.get("captures", [])}

    for capture_id, entry in captures.items():
        rel_path = str(entry.get("path", ""))
        path = root / rel_path
        if not path.is_file():
            errors.append(ValidationError(f"missing capture {capture_id}: {rel_path}"))
            continue
        try:
            stats = capture_stats(path)
        except ValueError as exc:
            errors.append(ValidationError(str(exc)))
            continue
        if stats.width != expected_width or stats.height != expected_height:
            errors.append(
                ValidationError(
                    f"{rel_path}: expected {expected_width}x{expected_height}, "
                    f"got {stats.width}x{stats.height}"
                )
            )
        if stats.luminance_stdev < MIN_LUMINANCE_STDEV:
            errors.append(
                ValidationError(
                    f"{rel_path}: capture looks flat or blank "
                    f"(luminance stdev {stats.luminance_stdev:.2f})"
                )
            )

        pair_night_id = entry.get("pair_night_id")
        if not pair_night_id:
            continue
        night_entry = captures.get(str(pair_night_id))
        if night_entry is None:
            errors.append(ValidationError(f"{capture_id}: missing pair {pair_night_id}"))
            continue
        night_path = root / str(night_entry["path"])
        if not night_path.is_file():
            continue
        day_stats = stats
        night_stats = capture_stats(night_path)
        if day_stats.digest == night_stats.digest:
            errors.append(ValidationError(f"{capture_id}: day and night captures must differ"))
        if day_stats.mean_luminance <= night_stats.mean_luminance:
            errors.append(
                ValidationError(
                    f"{capture_id}: day luminance ({day_stats.mean_luminance:.1f}) "
                    f"must exceed night ({night_stats.mean_luminance:.1f})"
                )
            )
        delta = day_stats.mean_luminance - night_stats.mean_luminance
        if delta < MIN_DAY_NIGHT_LUMINANCE_DELTA:
            errors.append(
                ValidationError(
                    f"{capture_id}: day/night luminance delta {delta:.1f} "
                    f"is below {MIN_DAY_NIGHT_LUMINANCE_DELTA}"
                )
            )
    return errors


def validate_report(root: Path, manifest: dict, *, require_human_sign_off: bool) -> list[ValidationError]:
    errors: list[ValidationError] = []
    report_rel = str(manifest.get("report_path", "docs/reports/map_conversion_parity.md"))
    report_path = root / report_rel
    if not report_path.is_file():
        errors.append(ValidationError(f"missing parity report: {report_rel}"))
        return errors

    text = report_path.read_text(encoding="utf-8")
    for heading in ("## Gameplay parity", "## Capture evidence", "## Visual review"):
        if heading not in text:
            errors.append(ValidationError(f"{report_rel}: missing section {heading!r}"))

    review = manifest.get("human_visual_review", {})
    if require_human_sign_off:
        if not review.get("signed"):
            errors.append(
                ValidationError(
                    "human visual review is not signed; close P2-021 only after maintainer sign-off"
                )
            )
        if not str(review.get("reviewer", "")).strip():
            errors.append(ValidationError("human visual review missing reviewer"))
        if not str(review.get("review_date", "")).strip():
            errors.append(ValidationError("human visual review missing review_date"))
    return errors


def run_godot_map_tests(root: Path, manifest: dict) -> list[ValidationError]:
    errors: list[ValidationError] = []
    godot_bin = os.environ.get("GODOT_BIN", "godot")
    filters = sorted(
        {
            str(map_entry.get("godot_test_filter", ""))
            for map_entry in manifest.get("maps", [])
            if map_entry.get("godot_test_filter")
        }
    )
    for test_filter in filters:
        command = [
            godot_bin,
            "--headless",
            "--path",
            str(root),
            "--script",
            "tools/run_godot_tests.gd",
            "--",
            f"--filter={test_filter}",
        ]
        try:
            completed = subprocess.run(
                command,
                cwd=root,
                capture_output=True,
                text=True,
                check=False,
                timeout=300,
            )
        except FileNotFoundError:
            errors.append(
                ValidationError(
                    f"Godot binary not found ({godot_bin}); rerun with --skip-godot or set GODOT_BIN"
                )
            )
            return errors
        except subprocess.TimeoutExpired:
            errors.append(ValidationError(f"Godot filter timed out: {test_filter}"))
            continue

        if completed.returncode != 0:
            tail = (completed.stdout + completed.stderr).strip().splitlines()[-8:]
            errors.append(
                ValidationError(
                    f"Godot filter failed: {test_filter} (exit {completed.returncode})\n"
                    + "\n".join(tail)
                )
            )
        else:
            print(f"* Godot filter green: {test_filter}")
    return errors


def validate(
    *,
    root: Path = ROOT,
    manifest_path: Path = DEFAULT_MANIFEST,
    require_human_sign_off: bool = False,
    skip_godot: bool = False,
) -> list[ValidationError]:
    if not manifest_path.is_file():
        return [ValidationError(f"missing manifest: {manifest_path.relative_to(root)}")]

    manifest = load_manifest(manifest_path)
    errors: list[ValidationError] = []
    errors.extend(validate_anchor_accounting(root, manifest))
    errors.extend(validate_captures(root, manifest))
    errors.extend(validate_report(root, manifest, require_human_sign_off=require_human_sign_off))
    if not skip_godot:
        errors.extend(run_godot_map_tests(root, manifest))
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=DEFAULT_MANIFEST,
        help="Gameplay parity manifest path",
    )
    parser.add_argument(
        "--require-human-sign-off",
        action="store_true",
        help="Require maintainer visual review (P2-021 closeout)",
    )
    parser.add_argument(
        "--skip-godot",
        action="store_true",
        help="Skip Godot map suite delegation",
    )
    args = parser.parse_args(argv)

    errors = validate(
        manifest_path=args.manifest,
        require_human_sign_off=args.require_human_sign_off,
        skip_godot=args.skip_godot,
    )
    if errors:
        print("map conversion parity verification failed:")
        for error in errors:
            print(f"  - {error.message}")
        return 1

    mode = "P2-021 full gate" if args.require_human_sign_off else "P2-021a gameplay scaffold"
    print(f"map conversion parity verification passed ({mode})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

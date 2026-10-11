#!/usr/bin/env python3
"""Verify facilitator-recorded P0-039 blind readability results.

Checks that a completed session JSON records silhouette, interaction, depth, and
motion recognition for every blind-labelled stimulus from at least five
participants. Use --check on the committed results file once a human session
lands.

Usage:
    python3 tools/verify_p039_readability_results.py --check
    python3 tools/verify_p039_readability_results.py path/to/results.json
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
PACK_MANIFEST = ROOT / "docs" / "reports" / "data" / "p039_readability_pack.json"
DEFAULT_RESULTS = ROOT / "docs" / "reports" / "data" / "p039_readability_results.json"

SCHEMA_VERSION = 1
RECOGNITION_TARGETS = ("silhouette", "interaction", "depth", "motion")
SCORE_MIN = 1
SCORE_MAX = 5


def _read_json(path: Path) -> dict[str, Any]:
    parsed = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(parsed, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return parsed


def load_pack_labels(
    *, root: Path = ROOT, manifest_path: Path | None = None
) -> tuple[int, list[str], list[str]]:
    path = manifest_path or (root / "docs/reports/data/p039_readability_pack.json")
    if not path.is_file():
        raise FileNotFoundError(f"missing pack manifest: {path}")
    manifest = _read_json(path)
    minimum = int(manifest.get("minimum_participants", 0))
    labels = [
        str(entry.get("blind_label", ""))
        for entry in manifest.get("stimuli", [])
        if isinstance(entry, dict)
    ]
    motion_labels = [
        str(entry.get("blind_label", ""))
        for entry in manifest.get("stimuli", [])
        if isinstance(entry, dict) and entry.get("motion") is True
    ]
    if not labels:
        raise ValueError("pack manifest contains no stimuli")
    return minimum, labels, motion_labels


def _score_value(raw: Any) -> int | None:
    if raw is None:
        return None
    if isinstance(raw, bool):
        raise ValueError("score must be numeric, not boolean")
    score = int(raw)
    if score < SCORE_MIN or score > SCORE_MAX:
        raise ValueError(f"score {score} outside rubric range {SCORE_MIN}-{SCORE_MAX}")
    return score


def validate_results(
    results: dict[str, Any],
    *,
    minimum_participants: int,
    blind_labels: list[str],
    motion_labels: list[str],
) -> list[str]:
    errors: list[str] = []

    if results.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"schema_version must be {SCHEMA_VERSION}")

    if not results.get("session_utc"):
        errors.append("session_utc is required")

    if not str(results.get("facilitator", "")).strip():
        errors.append("facilitator is required")

    participants = results.get("participants")
    if not isinstance(participants, list):
        errors.append("participants must be a list")
        return errors

    if len(participants) < minimum_participants:
        errors.append(
            f"at least {minimum_participants} participants required, found {len(participants)}"
        )

    participant_ids: set[str] = set()
    for index, participant in enumerate(participants, start=1):
        prefix = f"participant[{index}]"
        if not isinstance(participant, dict):
            errors.append(f"{prefix} must be an object")
            continue
        participant_id = str(participant.get("participant_id", "")).strip()
        if not participant_id:
            errors.append(f"{prefix}: participant_id is required")
            continue
        if participant_id in participant_ids:
            errors.append(f"{prefix}: duplicate participant_id {participant_id}")
        participant_ids.add(participant_id)

        responses = participant.get("responses")
        if not isinstance(responses, list):
            errors.append(f"{prefix}: responses must be a list")
            continue

        seen_labels: set[str] = set()
        for response_index, response in enumerate(responses, start=1):
            response_prefix = f"{prefix}.responses[{response_index}]"
            if not isinstance(response, dict):
                errors.append(f"{response_prefix} must be an object")
                continue
            blind_label = str(response.get("blind_label", "")).strip()
            if blind_label not in blind_labels:
                errors.append(f"{response_prefix}: unknown blind_label {blind_label!r}")
                continue
            if blind_label in seen_labels:
                errors.append(f"{response_prefix}: duplicate blind_label {blind_label}")
            seen_labels.add(blind_label)

            for target in RECOGNITION_TARGETS:
                score_key = f"{target}_score"
                notes_key = f"{target}_notes"
                raw_score = response.get(score_key, "__missing__")
                if raw_score == "__missing__":
                    errors.append(f"{response_prefix}: missing {score_key}")
                    continue
                try:
                    score = _score_value(raw_score)
                except ValueError as exc:
                    errors.append(f"{response_prefix}: {exc}")
                    continue
                if target == "motion" and blind_label not in motion_labels:
                    if score is not None:
                        errors.append(
                            f"{response_prefix}: motion_score must be null for static stimuli"
                        )
                elif score is None:
                    errors.append(f"{response_prefix}: {score_key} is required")

                notes = str(response.get(notes_key, "")).strip()
                if not notes:
                    errors.append(f"{response_prefix}: {notes_key} is required")

        missing_labels = sorted(set(blind_labels) - seen_labels)
        if missing_labels:
            errors.append(f"{prefix}: missing responses for {', '.join(missing_labels)}")

    return errors


def verify_file(path: Path, *, root: Path = ROOT) -> list[str]:
    try:
        minimum, labels, motion_labels = load_pack_labels(root=root)
        results = _read_json(path)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        return [str(exc)]
    return validate_results(
        results,
        minimum_participants=minimum,
        blind_labels=labels,
        motion_labels=motion_labels,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "results_path",
        nargs="?",
        default=str(DEFAULT_RESULTS.relative_to(ROOT)),
        help="Path to facilitator results JSON",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Verify the default committed results file when present",
    )
    args = parser.parse_args()

    results_path = Path(args.results_path)
    if not results_path.is_absolute():
        results_path = ROOT / results_path

    if args.check and not results_path.is_file():
        print(
            "P0-039 readability results not recorded yet "
            f"({results_path.relative_to(ROOT)} missing; human session still open)"
        )
        return 0

    if not results_path.is_file():
        print(f"P0-039 readability results verification failed: missing {results_path}", file=sys.stderr)
        return 1

    errors = verify_file(results_path)
    if errors:
        print("P0-039 readability results verification failed:")
        for error in errors:
            print(f"  - {error}")
        return 1

    results = _read_json(results_path)
    participant_count = len(results.get("participants", []))
    print(
        f"P0-039 readability results verification passed "
        f"({participant_count} participant(s))"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

"""Act 2 authorial acceptance gate helpers for P5-010.

The gate treats authored quest packages and their branch maps as the source of
truth. It validates that every declared branch is executable through the
quest's transition graph, that the corresponding save fixture preserves the
branch identity, and that the authored copy remains within the gate budget.
The Paide finale transition is validated separately by its dedicated model and
Godot suite; maintainer playable review remains a separate acceptance step.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

WORD_RE = re.compile(r"\b[\w’'-]+\b")
ALLOWED_ROUTES = {"combat", "non_combat"}


@dataclass
class Act2GateReport:
    package_count: int = 0
    branch_count: int = 0
    route_counts: dict[str, int] = field(default_factory=dict)
    mission_copy_words: int = 0
    mission_copy_word_budget: int = 0
    fixture_count: int = 0
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    @property
    def valid(self) -> bool:
        return not self.errors

    @property
    def within_budget(self) -> bool:
        return self.mission_copy_words <= self.mission_copy_word_budget

    @property
    def ready_for_maintainer_review(self) -> bool:
        return self.valid and self.within_budget and not self.warnings


def load_manifest(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _read_json(path: Path, errors: list[str], label: str) -> dict[str, Any] | None:
    if not path.is_file():
        errors.append(f"missing {label}: {path}")
        return None
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        errors.append(f"invalid JSON in {label} {path}: {exc}")
        return None
    if not isinstance(payload, dict):
        errors.append(f"{label} must be an object: {path}")
        return None
    return payload


def _mission_copy_words(quest: dict[str, Any]) -> int:
    fields: list[str] = [str(quest.get("title", "")), str(quest.get("summary", ""))]
    fields.extend(str(row.get("label", "")) for row in quest.get("states", []))
    fields.extend(str(row.get("text", "")) for row in quest.get("objectives", []))
    fields.extend(str(row.get("summary", "")) for row in quest.get("outcomes", []))
    return sum(len(WORD_RE.findall(value)) for value in fields)


def _branch_expectation_key(
    quest_id: str, expected: dict[str, Any]
) -> tuple[str, str, str, str]:
    return (
        quest_id,
        str(expected.get("quest_state", "")),
        json.dumps(expected.get("flags", {}), sort_keys=True),
        json.dumps([str(value) for value in expected.get("ledger_events", [])]),
    )


def _verify_branch(
    quest: dict[str, Any], branch: dict[str, Any], label: str, errors: list[str]
) -> None:
    transitions = {
        str(row.get("id", "")): row for row in quest.get("transitions", [])
    }
    states = {str(row.get("id", "")) for row in quest.get("states", [])}
    current = str(quest.get("initial_state", ""))
    observed_flags: dict[str, Any] = {}
    observed_events: list[str] = []

    route = str(branch.get("route", ""))
    if route not in ALLOWED_ROUTES:
        errors.append(f"{label}: unsupported route {route!r}")

    transition_ids = branch.get("transitions", [])
    if not isinstance(transition_ids, list) or not transition_ids:
        errors.append(f"{label}: branch must declare transitions")
        return

    for transition_id_raw in transition_ids:
        transition_id = str(transition_id_raw)
        transition = transitions.get(transition_id)
        if transition is None:
            errors.append(f"{label}: missing transition {transition_id}")
            continue
        from_state = str(transition.get("from_state", ""))
        to_state = str(transition.get("to_state", ""))
        if from_state != current:
            errors.append(
                f"{label}: transition {transition_id} starts at {from_state!r}, "
                f"expected {current!r}"
            )
        if from_state not in states or to_state not in states:
            errors.append(f"{label}: transition {transition_id} references unknown state")
        current = to_state
        for effect in transition.get("effects", []):
            operation = str(effect.get("op", ""))
            if operation == "set_flag":
                observed_flags[str(effect.get("key", ""))] = effect.get("value")
            elif operation == "record_faction_event":
                observed_events.append(str(effect.get("key", "")))

    expected = branch.get("expect", {})
    expected_state = str(expected.get("quest_state", ""))
    if current != expected_state:
        errors.append(f"{label}: reaches {current!r}, expected {expected_state!r}")
    if observed_flags != dict(expected.get("flags", {})):
        errors.append(
            f"{label}: flag effects do not match expectation: "
            f"{observed_flags!r} != {expected.get('flags', {})!r}"
        )
    if observed_events != [str(value) for value in expected.get("ledger_events", [])]:
        errors.append(
            f"{label}: ledger effects do not match expectation: "
            f"{observed_events!r} != {expected.get('ledger_events', [])!r}"
        )


def _verify_package(
    root: Path,
    row: dict[str, Any],
    report: Act2GateReport,
    branch_routes: dict[tuple[str, str, str, str], set[str]],
    quest_package_ids: dict[str, str],
) -> None:
    package_dir = root / str(row.get("package_dir", ""))
    package = _read_json(package_dir / "package.json", report.errors, "package")
    if package is None:
        return

    quest_ref = str(package.get("quest", "content/quest.json"))
    branch_ref = str(package.get("branch_map", "branch_map.json"))
    quest = _read_json(package_dir / quest_ref, report.errors, "quest")
    branch_map = _read_json(package_dir / branch_ref, report.errors, "branch map")
    if quest is None or branch_map is None:
        return

    expected_quest_id = str(row.get("quest_id", ""))
    if str(package.get("id", "")) != str(row.get("package_id", "")):
        report.errors.append(f"{package_dir}: package id drift")
    if str(quest.get("id", "")) != expected_quest_id:
        report.errors.append(f"{package_dir}: quest id drift")
    if str(branch_map.get("quest_id", "")) != expected_quest_id:
        report.errors.append(f"{package_dir}: branch map quest id drift")

    branches = branch_map.get("branches", [])
    if not isinstance(branches, list):
        report.errors.append(f"{package_dir}: branches must be an array")
        return
    if len(branches) != int(row.get("branch_count", len(branches))):
        report.errors.append(f"{package_dir}: branch count drift")

    report.package_count += 1
    report.branch_count += len(branches)
    report.mission_copy_words += _mission_copy_words(quest)
    quest_id = str(quest.get("id", ""))
    quest_package_ids[quest_id] = str(package.get("id", ""))
    for branch in branches:
        branch_id = str(branch.get("id", ""))
        route = str(branch.get("route", ""))
        report.route_counts[route] = report.route_counts.get(route, 0) + 1
        branch_routes.setdefault(
            _branch_expectation_key(
                quest_id,
                branch.get("expect", {}),
            ),
            set(),
        ).add(route)
        _verify_branch(quest, branch, f"{package_dir.name}/{branch_id}", report.errors)


def _verify_fixtures(
    root: Path,
    manifest: dict[str, Any],
    report: Act2GateReport,
    branch_routes: dict[tuple[str, str, str, str], set[str]],
    quest_package_ids: dict[str, str],
) -> None:
    fixtures = manifest.get("fixtures", [])
    if not isinstance(fixtures, list):
        report.errors.append("fixtures must be an array")
        return
    report.fixture_count = len(fixtures)
    for row in fixtures:
        fixture_id = str(row.get("id", ""))
        path = root / "content/saves" / str(row.get("path", ""))
        payload = _read_json(path, report.errors, f"fixture {fixture_id}")
        if payload is None:
            continue
        state = payload.get("game_state")
        if payload.get("save_version") != 1 or not isinstance(state, dict):
            report.errors.append(f"fixture {fixture_id}: not a current save envelope")
            continue
        if state.get("version") != 2:
            report.errors.append(f"fixture {fixture_id}: expected game-state version 2")
        if state.get("phase") != row.get("expected_phase"):
            report.errors.append(f"fixture {fixture_id}: phase identity drift")
        quest_states = state.get("quest_states", {})
        expected_quest_id = str(row.get("expected_quest_id", ""))
        expected_state = str(row.get("expected_quest_state", ""))
        if quest_states.get(expected_quest_id) != expected_state:
            report.errors.append(f"fixture {fixture_id}: quest identity drift")
        expected_key = _branch_expectation_key(
            expected_quest_id,
            {
                "quest_state": expected_state,
                "flags": row.get("expected_flags", {}),
                "ledger_events": row.get("expected_ledger_events", []),
            },
        )
        routes = branch_routes.get(expected_key, set())
        if not routes:
            report.errors.append(f"fixture {fixture_id}: no authored branch matches result")
        elif row.get("expected_route") not in routes:
            report.errors.append(
                f"fixture {fixture_id}: route identity drift: "
                f"{row.get('expected_route')!r} not in {sorted(routes)!r}"
            )
        package_id = row.get("expected_package_id")
        if quest_package_ids.get(expected_quest_id) != package_id:
            report.errors.append(f"fixture {fixture_id}: package identity drift")
        flags = state.get("flags", {})
        for flag, value in row.get("expected_flags", {}).items():
            if flags.get(flag) != value:
                report.errors.append(f"fixture {fixture_id}: missing expected flag {flag}")
        event_ids = {str(event.get("event_id", "")) for event in state.get("faction_events", [])}
        for event_id in row.get("expected_ledger_events", []):
            if str(event_id) not in event_ids:
                report.errors.append(f"fixture {fixture_id}: missing ledger event {event_id}")


def verify_manifest(root: Path, manifest_path: Path | None = None) -> Act2GateReport:
    manifest_file = manifest_path or root / "docs/data/act2_gate_manifest.json"
    manifest = load_manifest(manifest_file)
    report = Act2GateReport(
        mission_copy_word_budget=int(manifest.get("content_budget", {}).get("mission_copy_word_cap", 0))
    )
    branch_routes: dict[tuple[str, str, str, str], set[str]] = {}
    quest_package_ids: dict[str, str] = {}
    for row in manifest.get("packages", []):
        _verify_package(root, row, report, branch_routes, quest_package_ids)
    _verify_fixtures(root, manifest, report, branch_routes, quest_package_ids)

    expected = manifest.get("expected", {})
    if report.package_count != int(expected.get("package_count", report.package_count)):
        report.errors.append("authored package count drift")
    if report.branch_count != int(expected.get("branch_count", report.branch_count)):
        report.errors.append("authored branch count drift")
    if report.route_counts != dict(expected.get("route_counts", report.route_counts)):
        report.errors.append("route coverage drift")
    if report.fixture_count != int(expected.get("fixture_count", report.fixture_count)):
        report.errors.append("fixture count drift")
    if report.mission_copy_words > report.mission_copy_word_budget:
        report.errors.append(
            f"mission copy budget exceeded: {report.mission_copy_words} > "
            f"{report.mission_copy_word_budget}"
        )
    for blocker in manifest.get("known_blockers", []):
        report.warnings.append(str(blocker))
    return report


def format_report(report: Act2GateReport) -> str:
    lines = [
        "Act 2 authorial gate (P5-010)",
        f"  authored packages: {report.package_count}",
        f"  reachable branches: {report.branch_count}",
        f"  route coverage: {report.route_counts}",
        f"  save fixtures: {report.fixture_count}",
        f"  mission copy: {report.mission_copy_words}/{report.mission_copy_word_budget} words",
    ]
    if report.errors:
        lines.append("Errors:")
        lines.extend(f"  - {error}" for error in report.errors)
    if report.warnings:
        lines.append("Warnings:")
        lines.extend(f"  - {warning}" for warning in report.warnings)
    if not report.errors:
        lines.append("Authored Act 2 packages and fixtures match the gate manifest.")
    return "\n".join(lines)

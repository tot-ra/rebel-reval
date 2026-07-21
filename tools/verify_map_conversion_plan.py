#!/usr/bin/env python3
"""Verify MAP_CONVERSION_PLAN coverage against scenes, inventory, and TODO tasks."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLAN = ROOT / "docs" / "MAP_CONVERSION_PLAN.md"
SCENE_INVENTORY = ROOT / "docs" / "reports" / "scene_inventory.md"
TODO = ROOT / "TODO.md"

VALID_ROLES = frozenset({"level", "map", "event", "support", "actor", "ui", "test"})
VALID_STATUSES = frozenset({"convert", "archive", "retain"})
DETAILED_ROLES = frozenset({"level", "map", "event"})
# Local agent/worktree mirrors must not pollute repository scene discovery.
SKIP_TREE_PARTS = frozenset({".git", ".godot", ".a2gent-worktrees"})
REQUIRED_TASK_IDS = tuple(f"P0-{number:03d}" for number in range(43, 47)) + tuple(
    f"P2-{number:03d}" for number in range(18, 22)
) + ("P4-014", "P4-015")

INDEX_ROW = re.compile(
    r"^\| `(?P<scene>[^`]+\.tscn)` \| (?P<role>[^|]+?) \| `(?P<status>[^`]+)` \| "
    r"(?P<canonical>[^|]+?) \| (?P<scope>[^|]+?) \| (?P<target>[^|]+?) \|$"
)
DETAIL_ROW = re.compile(
    r"^\| `(?P<scene>[^`]+\.tscn)` \| `(?P<status>[^`]+)` \| (?P<terrain>[^|]+?) \| "
    r"(?P<bounds>[^|]+?) \| (?P<requirements>[^|]+?) \| (?P<transitions>[^|]+?) \| "
    r"(?P<collision>[^|]+?) \| (?P<sources>[^|]+?) \| (?P<target>[^|]+?) \|$"
)
INVENTORY_ROW = re.compile(
    r"^\| \d+ \| `(?P<scene>[^`]+\.tscn)` \| `?(?P<class>working|partial|placeholder|archive)`? \|"
)
TASK_ROW = re.compile(
    r"^- \[(?:x| )\](?: \[x\])?\s+(?P<id>P[0-9]+-[0-9]+) \| deps: (?P<deps>[^|]+) \| deliverable: (?P<deliverable>.*?) "
    r"\| allowed files: (?P<allowed>.*?) \| constraints: (?P<constraints>.*?) \| verify: (?P<verify>.*)$"
)
CODE_PATH = re.compile(r"`([^`]+)`")


@dataclass(frozen=True)
class PlanRow:
    scene: str
    role: str
    status: str
    canonical: str
    scope: str
    target: str


@dataclass(frozen=True)
class DetailRow:
    scene: str
    status: str
    terrain: str
    bounds: str
    requirements: str
    transitions: str
    collision: str
    sources: str
    target: str


@dataclass(frozen=True)
class ValidationError:
    message: str


def repository_scenes(root: Path) -> set[str]:
    return {
        path.relative_to(root).as_posix()
        for path in root.rglob("*.tscn")
        if SKIP_TREE_PARTS.isdisjoint(path.parts)
    }


def parse_inventory(path: Path) -> list[str]:
    scenes: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        match = INVENTORY_ROW.match(line)
        if match:
            scenes.append(match.group("scene"))
    return scenes


def parse_plan(path: Path) -> tuple[list[PlanRow], list[DetailRow]]:
    index_rows: list[PlanRow] = []
    detail_rows: list[DetailRow] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        index_match = INDEX_ROW.match(line)
        if index_match:
            values = index_match.groupdict()
            index_rows.append(
                PlanRow(
                    scene=values["scene"],
                    role=values["role"].strip(),
                    status=values["status"].strip(),
                    canonical=values["canonical"].strip(),
                    scope=values["scope"].strip(),
                    target=values["target"].strip(),
                )
            )
            continue
        detail_match = DETAIL_ROW.match(line)
        if detail_match:
            values = {key: value.strip() for key, value in detail_match.groupdict().items()}
            detail_rows.append(DetailRow(**values))
    return index_rows, detail_rows


def parse_tasks(path: Path) -> dict[str, dict[str, str]]:
    tasks: dict[str, dict[str, str]] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        match = TASK_ROW.match(line)
        if match:
            values = {key: value.strip() for key, value in match.groupdict().items()}
            tasks[values["id"]] = values
    return tasks


def _duplicates(values: list[str]) -> list[str]:
    seen: set[str] = set()
    duplicates: set[str] = set()
    for value in values:
        if value in seen:
            duplicates.add(value)
        seen.add(value)
    return sorted(duplicates)


def _format_paths(paths: set[str] | list[str]) -> str:
    return ", ".join(f"`{path}`" for path in sorted(paths))


def validate_map_conversion_plan(
    *, root: Path, plan_path: Path, inventory_path: Path, todo_path: Path
) -> list[ValidationError]:
    errors: list[ValidationError] = []
    repo_scenes = repository_scenes(root)
    inventory_rows = parse_inventory(inventory_path)
    inventory_scenes = set(inventory_rows)
    index_rows, detail_rows = parse_plan(plan_path)
    tasks = parse_tasks(todo_path)

    index_scenes = [row.scene for row in index_rows]
    detail_scenes = [row.scene for row in detail_rows]
    index_by_scene = {row.scene: row for row in index_rows}
    detail_by_scene = {row.scene: row for row in detail_rows}

    duplicate_index = _duplicates(index_scenes)
    duplicate_details = _duplicates(detail_scenes)
    duplicate_inventory = _duplicates(inventory_rows)
    if duplicate_index:
        errors.append(ValidationError("duplicate disposition rows: " + _format_paths(duplicate_index)))
    if duplicate_details:
        errors.append(ValidationError("duplicate detailed rows: " + _format_paths(duplicate_details)))
    if duplicate_inventory:
        errors.append(ValidationError("duplicate scene inventory rows: " + _format_paths(duplicate_inventory)))

    for label, actual in (("plan disposition", set(index_scenes)), ("scene inventory", inventory_scenes)):
        missing = repo_scenes - actual
        extra = actual - repo_scenes
        if missing:
            errors.append(ValidationError(f"{label} missing scene coverage: " + _format_paths(missing)))
        if extra:
            errors.append(ValidationError(f"{label} has unknown scenes: " + _format_paths(extra)))

    required_details = {row.scene for row in index_rows if row.role in DETAILED_ROLES}
    missing_details = required_details - set(detail_scenes)
    extra_details = set(detail_scenes) - required_details
    if missing_details:
        errors.append(ValidationError("missing detailed specifications: " + _format_paths(missing_details)))
    if extra_details:
        errors.append(ValidationError("unexpected detailed specifications: " + _format_paths(extra_details)))

    for row in index_rows:
        if row.role not in VALID_ROLES:
            errors.append(ValidationError(f"invalid role `{row.role}` for `{row.scene}`"))
        if row.status not in VALID_STATUSES:
            errors.append(ValidationError(f"invalid status `{row.status}` for `{row.scene}`"))
        if not row.canonical:
            errors.append(ValidationError(f"missing canonical responsibility for `{row.scene}`"))
        if not row.scope:
            errors.append(ValidationError(f"missing scope or activation rule for `{row.scene}`"))
        if row.status == "archive" and row.target != "none - archive":
            errors.append(ValidationError(f"archive scene `{row.scene}` must target `none - archive`"))
        if row.status == "convert" and row.role in DETAILED_ROLES:
            expected_prefix = "`scripts/map/definitions/"
            if not row.target.startswith(expected_prefix) or not row.target.endswith(".gd`"):
                errors.append(ValidationError(f"converted map `{row.scene}` needs a declarative definition target"))

    for row in detail_rows:
        index = index_by_scene.get(row.scene)
        if index is None:
            continue
        if row.status != index.status:
            errors.append(
                ValidationError(
                    f"status mismatch for `{row.scene}`: index `{index.status}`, detail `{row.status}`"
                )
            )
        if row.target != index.target:
            errors.append(ValidationError(f"target mismatch for `{row.scene}`"))
        for field_name in ("terrain", "bounds", "requirements", "transitions", "collision", "sources"):
            if not getattr(row, field_name):
                errors.append(ValidationError(f"missing {field_name} specification for `{row.scene}`"))
        if row.status == "archive":
            if not row.terrain.startswith("none - archive"):
                errors.append(ValidationError(f"archive terrain must be explicit for `{row.scene}`"))
            if not row.bounds.startswith("none - archive"):
                errors.append(ValidationError(f"archive bounds must be explicit for `{row.scene}`"))
            if row.transitions != "No destination or spawn":
                errors.append(ValidationError(f"archive transitions must be disabled for `{row.scene}`"))
            if not row.collision.startswith("No collision or navigation"):
                errors.append(ValidationError(f"archive collision/navigation must be disabled for `{row.scene}`"))
        for source_path in CODE_PATH.findall(row.sources):
            if source_path.startswith(("http://", "https://", "res://")):
                continue
            if not (root / source_path).exists():
                errors.append(ValidationError(f"missing source reference `{source_path}` for `{row.scene}`"))

    # TODO tasks are part of executability: each planned phase must be independently scoped and verifiable.
    for task_id in REQUIRED_TASK_IDS:
        task = tasks.get(task_id)
        if task is None:
            errors.append(ValidationError(f"missing strict TODO task `{task_id}`"))
            continue
        allowed_paths = CODE_PATH.findall(task["allowed"])
        if not allowed_paths:
            errors.append(ValidationError(f"task `{task_id}` has no exact allowed files"))
        if "*" in task["allowed"]:
            errors.append(ValidationError(f"task `{task_id}` allowed files must not use globs"))
        if not task["verify"] or "TBD" in task["verify"]:
            errors.append(ValidationError(f"task `{task_id}` has no objective verification"))
        if not task["constraints"]:
            errors.append(ValidationError(f"task `{task_id}` has no constraints"))

    # Approved production conversion is intentionally restricted to these two legacy scenes.
    production_targets = {
        row.scene
        for row in index_rows
        if row.status == "convert" and "definitions/lower_town/" in row.target
    }
    expected_production_targets = {
        "scenes/reval_east/forge/forge.tscn",
        "scenes/reval_east/reval_east.tscn",
    }
    if production_targets != expected_production_targets:
        errors.append(
            ValidationError(
                "production-playable conversion set must be exactly: "
                + _format_paths(expected_production_targets)
            )
        )

    for scene, detail in detail_by_scene.items():
        if "definitions/prototypes/" in detail.target:
            scope = index_by_scene[scene].scope
            if "active=false" not in scope or "approval artifact" not in scope:
                errors.append(ValidationError(f"prototype `{scene}` lacks activation gate"))

    todo_text = todo_path.read_text(encoding="utf-8")
    slice_gate = re.search(r"^- \[(?:x| )\](?: \[x\])?\s+P2-012 \| deps: (?P<deps>[^|]+) \|", todo_text, re.MULTILINE)
    if slice_gate is None or "P2-021" not in {dep.strip() for dep in slice_gate.group("deps").split(",")}:
        errors.append(ValidationError("vertical-slice gate `P2-012` must depend on parity gate `P2-021`"))

    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--plan", type=Path, default=PLAN)
    parser.add_argument("--inventory", type=Path, default=SCENE_INVENTORY)
    parser.add_argument("--todo", type=Path, default=TODO)
    args = parser.parse_args(argv)

    errors = validate_map_conversion_plan(
        root=args.root,
        plan_path=args.plan,
        inventory_path=args.inventory,
        todo_path=args.todo,
    )
    if errors:
        print("map conversion plan verification failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error.message}", file=sys.stderr)
        return 1

    print(f"map conversion plan verification passed ({len(repository_scenes(args.root))} scenes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

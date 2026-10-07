#!/usr/bin/env python3
"""Verify cutscene records against the files and scenes they reference (ADR 0034).

`tools/validate_content.py` checks the schema. This checks the things a schema cannot:

* every shot's still exists on disk and has a Godot `*.import` sidecar;
* every still is listed in `assets/SOURCES.csv`;
* every `next` chain target resolves (cutscene ID, transition-manifest scene and spawn,
  or scene file on disk);
* shot and line IDs are unique inside a record;
* the authoring block is filled in, so no shot ships without the prompt that made it.

Exit code 0 means clean. Usage: python3 tools/verify_cutscenes.py [--json]
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CUTSCENE_DIR = ROOT / "content" / "cutscenes"
SOURCES_CSV = ROOT / "assets" / "SOURCES.csv"
TRANSITIONS = ROOT / "content" / "transitions" / "active_destinations.json"
RES_PREFIX = "res://"


def _res_to_path(res_path: str) -> Path:
    return ROOT / res_path[len(RES_PREFIX) :]


def _load_records() -> dict[str, dict]:
    records: dict[str, dict] = {}
    for path in sorted(CUTSCENE_DIR.glob("*.json")):
        with path.open(encoding="utf-8") as handle:
            record = json.load(handle)
        records[str(record.get("id", path.stem))] = record
    return records


def _load_sourced_paths() -> set[str]:
    if not SOURCES_CSV.exists():
        return set()
    with SOURCES_CSV.open(encoding="utf-8", newline="") as handle:
        return {row["path"] for row in csv.DictReader(handle) if row.get("path")}


def _load_transitions() -> dict[str, set[str]]:
    if not TRANSITIONS.exists():
        return {}
    with TRANSITIONS.open(encoding="utf-8") as handle:
        manifest = json.load(handle)
    return {
        str(scene["id"]): {str(spawn["id"]) for spawn in scene.get("spawns", [])}
        for scene in manifest.get("scenes", [])
        if isinstance(scene, dict) and "id" in scene
    }


def _check_chain(
    record_id: str, target: dict, records: dict[str, dict], scenes: dict[str, set[str]]
) -> list[str]:
    kind = str(target.get("kind", ""))
    if kind in ("", "return"):
        return []
    if kind == "cutscene":
        next_id = str(target.get("cutscene_id", ""))
        if next_id not in records:
            return [f"{record_id}: next.cutscene_id {next_id!r} is not a known cutscene"]
        return []
    if kind == "door":
        scene_id = str(target.get("scene_id", ""))
        spawn_id = str(target.get("spawn_id", ""))
        if scene_id not in scenes:
            return [f"{record_id}: next.scene_id {scene_id!r} is not in the transition manifest"]
        if spawn_id not in scenes[scene_id]:
            return [f"{record_id}: next.spawn_id {spawn_id!r} is not a spawn of {scene_id!r}"]
        return []
    if kind == "scene_file":
        scene_path = str(target.get("scene_path", ""))
        if not scene_path.startswith(RES_PREFIX) or not _res_to_path(scene_path).exists():
            return [f"{record_id}: next.scene_path {scene_path!r} does not exist"]
        return []
    return [f"{record_id}: unknown next.kind {kind!r}"]


def verify() -> list[str]:
    if not CUTSCENE_DIR.exists():
        return [f"missing cutscene directory {CUTSCENE_DIR}"]

    records = _load_records()
    if not records:
        return [f"no cutscene records under {CUTSCENE_DIR}"]

    sourced = _load_sourced_paths()
    scenes = _load_transitions()
    problems: list[str] = []

    for record_id, record in sorted(records.items()):
        shot_ids: set[str] = set()
        for shot in record.get("shots", []):
            shot_id = str(shot.get("id", ""))
            where = f"{record_id}/{shot_id}"
            if shot_id in shot_ids:
                problems.append(f"{where}: duplicate shot id")
            shot_ids.add(shot_id)

            line_ids: set[str] = set()
            for line in shot.get("lines", []):
                line_id = str(line.get("id", ""))
                if line_id in line_ids:
                    problems.append(f"{where}: duplicate line id {line_id!r}")
                line_ids.add(line_id)

            still = str(shot.get("still", ""))
            if not still.startswith(RES_PREFIX):
                problems.append(f"{where}: still must be a res:// path, got {still!r}")
                continue
            still_path = _res_to_path(still)
            relative = still[len(RES_PREFIX) :]
            if not still_path.exists():
                problems.append(f"{where}: still is missing on disk: {relative}")
                continue
            if not still_path.with_suffix(still_path.suffix + ".import").exists():
                problems.append(f"{where}: still has no Godot .import sidecar: {relative}")
            if relative not in sourced:
                problems.append(f"{where}: still has no assets/SOURCES.csv row: {relative}")

            authoring = shot.get("authoring", {})
            for field in ("direction", "image_prompt", "video_prompt"):
                if not str(authoring.get(field, "")).strip():
                    problems.append(f"{where}: authoring.{field} is empty")

        problems.extend(_check_chain(record_id, record.get("next", {}), records, scenes))

    return problems


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="emit problems as JSON")
    args = parser.parse_args(argv)

    problems = verify()
    if args.json:
        print(json.dumps({"ok": not problems, "problems": problems}, indent=2))
    else:
        for problem in problems:
            print(problem, file=sys.stderr)
        if not problems:
            print("cutscenes OK")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())

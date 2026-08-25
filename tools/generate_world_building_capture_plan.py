#!/usr/bin/env python3
"""Generate a deterministic capture job list for the R-716 visual matrix.

This planner keeps capture ordering and identity stable while map-specific
capture runners are authored. It never marks evidence as accepted and never
creates placeholder PNGs.

Usage:
    python3 tools/generate_world_building_capture_plan.py
    python3 tools/generate_world_building_capture_plan.py --output /tmp/r716-plan.json
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "docs" / "data" / "world_building_visual_benchmark.json"


def build_plan(manifest: dict[str, Any]) -> dict[str, Any]:
    settings = manifest["fixed_capture_settings"]
    matrix = manifest["capture_matrix"]
    categories = matrix["required_categories"]
    jobs: list[dict[str, Any]] = []
    for entry in manifest["maps"]:
        map_id = entry["id"]
        for category in categories:
            jobs.append(
                {
                    "job_id": f"{map_id}.{category}",
                    "map_id": map_id,
                    "category": category,
                    "source_path": entry["source_path"],
                    "settings": settings,
                    "output_path": f"{matrix['evidence_root']}/{map_id}/{category}.png",
                    "performance_tiers": ["minimum", "recommended"],
                    "acceptance_status": "pending",
                }
            )
    return {
        "schema_version": 1,
        "task_id": manifest["task_id"],
        "manifest_path": "docs/data/world_building_visual_benchmark.json",
        "job_count": len(jobs),
        "comparison_sheet": matrix["comparison_sheet"],
        "jobs": jobs,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=MANIFEST)
    parser.add_argument("--output", type=Path, help="write the plan instead of stdout")
    args = parser.parse_args(argv)
    try:
        manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
        payload = build_plan(manifest)
    except (OSError, json.JSONDecodeError, KeyError, TypeError) as error:
        print(f"ERROR: cannot build capture plan: {error}", file=sys.stderr)
        return 1
    rendered = json.dumps(payload, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
        print(f"Wrote {payload['job_count']} capture jobs to {args.output}")
    else:
        print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

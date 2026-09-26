#!/usr/bin/env python3
"""Verify P1-036 map composition audit thresholds and enforced registry maps.

Also runs the WB-10 (R-982) dressing-and-ground density contract for every
registry map, prints the per-map baseline table, and with --write-baseline
publishes docs/reports/map_density_baseline_2026-09-26.md and the per-map
`automated_density` rows the R-716 visual gate consumes.

Usage:
    python3 tools/verify_map_composition.py
    python3 tools/verify_map_composition.py --write-baseline
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
THRESHOLDS = ROOT / "docs" / "data" / "map_composition_thresholds.json"
AUDIT_MANIFEST = ROOT / "content" / "map_audit_manifest.json"
LOWER_TOWN_OWNERSHIP = ROOT / "docs" / "data" / "lower_town_authoring_contract.json"
REGISTRY = ROOT / "scripts" / "map" / "map_blueprint_registry.gd"
DOSSIER = ROOT / "docs" / "HISTORICAL_AUDIT.md"
TODO = ROOT / "TODO.md"
BENCHMARK = ROOT / "docs" / "data" / "world_building_visual_benchmark.json"
BASELINE_REPORT = ROOT / "docs" / "reports" / "map_density_baseline_2026-09-26.md"

DENSITY_CLASSES = ("dense_urban", "sparse_urban", "foreland", "rural", "interior")
DENSITY_CLASS_KEYS = (
    "props_per_1000_min",
    "decals_per_1000_min",
    "distinct_prop_kinds_min",
    "max_prop_kind_share_pct",
    "ground_cover_pct_min",
    "elevation_range_min",
    "max_identical_footprint_run",
    "tier_spread_active",
)
DENSITY_LINE_PREFIX = "DENSITY_JSON "


def resolve_godot() -> Path | None:
    override = os.environ.get("GODOT_BIN")
    if override:
        path = Path(override)
        if path.is_file():
            return path
    found = shutil.which("godot") or shutil.which("godot4")
    if found:
        return Path(found)
    mac_default = Path("/Applications/Godot.app/Contents/MacOS/Godot")
    if mac_default.is_file():
        return mac_default
    return None


def parse_registry_ids(text: str) -> list[str]:
    import re

    return re.findall(r'"id"\s*:\s*&"([a-z][a-z0-9_.]*)"', text)


def p1_036_complete(todo_text: str) -> bool:
    import re

    return bool(re.search(r"^- \[x\] P1-036\b", todo_text, re.MULTILINE))


def _load_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"could not parse {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ValueError(f"{path}: top-level JSON value must be an object")
    return value


def validate_threshold_contract() -> list[str]:
    errors: list[str] = []
    if not THRESHOLDS.is_file():
        return [f"missing thresholds file: {THRESHOLDS}"]
    try:
        payload = _load_json(THRESHOLDS)
    except ValueError as exc:
        return [str(exc)]
    maps: dict = payload.get("maps", {})
    if not maps:
        errors.append("thresholds file has no map cards")
    try:
        registry_ids = parse_registry_ids(REGISTRY.read_text(encoding="utf-8"))
    except OSError as exc:
        return [f"could not read map registry: {exc}"]
    missing = sorted(set(registry_ids) - set(maps))
    extra = sorted(set(maps) - set(registry_ids))
    if missing:
        errors.append("registry maps missing threshold cards: " + ", ".join(missing))
    if extra:
        errors.append("threshold cards absent from registry: " + ", ".join(extra))
    for map_id, card in maps.items():
        if not isinstance(card, dict):
            errors.append(f"{map_id}: threshold card must be an object")
            continue
        if card.get("enforce", True) is False:
            continue
        if card.get("interior"):
            if not card.get("surface_shares"):
                errors.append(f"{map_id}: interior map needs surface_shares")
            if not card.get("open_floor_pct"):
                errors.append(f"{map_id}: interior map needs open_floor_pct")
        elif not card.get("surface_shares"):
            errors.append(f"{map_id}: outdoor map needs surface_shares")

    errors.extend(validate_lower_town_enforcement())
    errors.extend(validate_density_contract(payload))
    errors.extend(validate_historical_band_grace(payload))
    return errors


def validate_density_contract(payload: dict) -> list[str]:
    """WB-10: every card names a class, every class states every floor or cap
    (null means "not applicable to this class", never "forgotten"), and every
    production grace entry names the task that will remove it."""
    errors: list[str] = []
    contract = payload.get("density_contract")
    if not isinstance(contract, dict):
        return ["density_contract missing from thresholds file"]
    classes = contract.get("classes", {})
    for class_id in DENSITY_CLASSES:
        card = classes.get(class_id)
        if not isinstance(card, dict):
            errors.append(f"density_contract.classes.{class_id} missing")
            continue
        for key in DENSITY_CLASS_KEYS:
            if key not in card:
                errors.append(f"density_contract.classes.{class_id} must state {key} (null if n/a)")
    for class_id in classes:
        if class_id not in DENSITY_CLASSES:
            errors.append(f"density_contract.classes.{class_id} is not a known map class")
    benchmark = contract.get("benchmark", {})
    if not benchmark.get("map_id") or not benchmark.get("why"):
        errors.append("density_contract.benchmark must name the benchmark map and why")
    if not contract.get("derivation"):
        errors.append("density_contract.derivation must justify every floor")
    maps = payload.get("maps", {})
    for map_id, card in maps.items():
        if isinstance(card, dict) and card.get("map_class") not in DENSITY_CLASSES:
            errors.append(f"{map_id}: map_class must be one of {', '.join(DENSITY_CLASSES)}")
    for map_id, grace in contract.get("production_grace", {}).items():
        if map_id not in maps:
            errors.append(f"density grace names unknown map: {map_id}")
        if not isinstance(grace, dict) or not grace.get("until") or not grace.get("reason"):
            errors.append(f"density grace for {map_id} needs `until` (closing task) and `reason`")
    return errors


def validate_historical_band_grace(payload: dict) -> list[str]:
    """R-990: P1-036 band deferrals name a closing task and keep the card enrolled.

    Cards stay `enforce=true` so ownership tests and activation manifests keep
    treating the gate as explicit. CI skips failing those bands until the
    named owner deletes the grace row. Do not use this to lower signed bands.
    """
    errors: list[str] = []
    grace_maps = payload.get("historical_band_grace", {})
    if grace_maps and not isinstance(grace_maps, dict):
        return ["historical_band_grace must be an object of map_id -> {until, reason}"]
    maps = payload.get("maps", {})
    for map_id, grace in grace_maps.items():
        card = maps.get(map_id)
        if not isinstance(card, dict):
            errors.append(f"historical band grace names unknown map: {map_id}")
            continue
        if card.get("enforce") is not True:
            errors.append(
                f"historical band grace for {map_id} requires enforce=true; "
                "do not silently unenroll the card"
            )
        if not isinstance(grace, dict) or not grace.get("until") or not grace.get("reason"):
            errors.append(
                f"historical band grace for {map_id} needs `until` (closing task) and `reason`"
            )
    return errors


def parse_density_rows(output: str) -> list[dict]:
    """Collect the audit tool's one-line-per-map DENSITY_JSON records."""
    rows: list[dict] = []
    for line in output.splitlines():
        if not line.startswith(DENSITY_LINE_PREFIX):
            continue
        try:
            rows.append(json.loads(line[len(DENSITY_LINE_PREFIX):]))
        except json.JSONDecodeError:
            continue
    return rows


def _fmt(value: object, digits: int = 1) -> str:
    if isinstance(value, float):
        return f"{value:.{digits}f}"
    return str(value)


def format_density_table(rows: list[dict]) -> str:
    header = (
        "| Map | Class | Scope | Mode | Walkable | Props/1000 | Decals/1000 | Kinds "
        "| Max kind share % | Ground cover % | Relief m | Footprint run | Status | Failing metrics |"
    )
    lines = [header, "|" + "---|" * 14]
    for row in rows:
        metrics = row.get("metrics", {})
        if row.get("status") == "compile_error":
            lines.append(f"| `{row['map_id']}` | | | | | | | | | | | | compile_error | |")
            continue
        lines.append(
            "| `{map_id}` | {cls} | {scope} | {mode} | {walk} | {props} | {decals} | {kinds} "
            "| {share} | {cover} | {relief} | {run} | {status} | {failing} |".format(
                map_id=row["map_id"],
                cls=row.get("map_class", ""),
                scope=row.get("scope", ""),
                mode=row.get("mode", ""),
                walk=metrics.get("walkable_cells", 0),
                props=_fmt(metrics.get("props_per_1000", 0.0)),
                decals=_fmt(metrics.get("decals_per_1000", 0.0)),
                kinds=metrics.get("distinct_prop_kinds", 0),
                share=_fmt(metrics.get("max_prop_kind_share_pct", 0.0)),
                cover=_fmt(metrics.get("ground_cover_pct", 0.0)),
                relief=_fmt(metrics.get("relief_span_m", 0.0), 2),
                run=metrics.get("max_identical_footprint_run", 0),
                status=row.get("status", ""),
                failing=", ".join(row.get("failing_metrics", [])),
            )
        )
    return "\n".join(lines)


def registry_id_for_source(source_path: str) -> str:
    """content/maps/world_harju.rrmap -> world.harju; others use the file stem."""
    stem = Path(source_path).stem
    return f"world.{stem[6:]}" if stem.startswith("world_") else stem


def density_gate_rows(rows: list[dict], benchmark: dict) -> dict[str, dict]:
    """Build the `automated_density` entry for every visual-gate map row."""
    by_map = {row["map_id"]: row for row in rows}
    evidence = str(BASELINE_REPORT.relative_to(ROOT))
    result: dict[str, dict] = {}
    for entry in benchmark.get("maps", []):
        registry_id = registry_id_for_source(entry.get("source_path", ""))
        row = by_map.get(registry_id)
        if row is None:
            result[entry["id"]] = {
                "status": "missing",
                "source_map_id": registry_id,
                "note": "not in MapBlueprintRegistry, so the composition audit cannot measure it",
            }
            continue
        status = row.get("status")
        result[entry["id"]] = {
            "status": status if status in ("pass", "fail") else "missing",
            "evidence": evidence,
            "source_map_id": registry_id,
            "map_class": row.get("map_class", ""),
            "failing_metrics": row.get("failing_metrics", []),
        }
    return result


def write_baseline(rows: list[dict]) -> None:
    payload = _load_json(THRESHOLDS)
    contract = payload.get("density_contract", {})
    report = [
        "# Map density baseline (WB-10, R-982) - 2026-09-26",
        "",
        "Generated by `python3 tools/verify_map_composition.py --write-baseline` from the compiled",
        "`MapDefinition` of every `MapBlueprintRegistry` map. Floors, caps and their derivation live in",
        "`docs/data/map_composition_thresholds.json` under `density_contract`; the contract is",
        "`docs/tasks/world/WB-10_authoring_density_contract.md`.",
        "",
        "`Mode`: `enforced` fails CI, `grace` is a production map with a named closing task,",
        "`report` is a prototype shown without failing. The R-716 visual gate blocks promotion of any",
        "map whose status is not `pass`, whatever its mode.",
        "",
        "The benchmark is `kalev_smithy`, the only shipped dressed space. Dressing props exclude trees",
        "and bushes, which count toward ground cover instead.",
        "",
        format_density_table(rows),
        "",
        "## Class floors",
        "",
        "| Class | Props/1000 >= | Decals/1000 >= | Kinds >= | Max kind share % <= | Ground cover % >= | Relief m >= | Footprint run <= |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for class_id in DENSITY_CLASSES:
        card = contract.get("classes", {}).get(class_id, {})
        values = [
            card.get(key)
            for key in (
                "props_per_1000_min",
                "decals_per_1000_min",
                "distinct_prop_kinds_min",
                "max_prop_kind_share_pct",
                "ground_cover_pct_min",
                "elevation_range_min",
                "max_identical_footprint_run",
            )
        ]
        report.append(
            f"| {class_id} | " + " | ".join("n/a" if v is None else str(v) for v in values) + " |"
        )
    report.extend(["", "## Production grace", ""])
    for map_id, grace in contract.get("production_grace", {}).items():
        report.append(f"- `{map_id}` until {grace.get('until')}: {grace.get('reason')}")
    BASELINE_REPORT.parent.mkdir(parents=True, exist_ok=True)
    BASELINE_REPORT.write_text("\n".join(report) + "\n", encoding="utf-8")

    benchmark = _load_json(BENCHMARK)
    gate_rows = density_gate_rows(rows, benchmark)
    for entry in benchmark.get("maps", []):
        entry["automated_density"] = gate_rows[entry["id"]]
    BENCHMARK.write_text(json.dumps(benchmark, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def validate_lower_town_enforcement() -> list[str]:
    """Require an explicit gate and ownership source for the playable slice."""
    errors: list[str] = []
    try:
        thresholds = _load_json(THRESHOLDS)
        manifest = _load_json(AUDIT_MANIFEST)
        ownership = _load_json(LOWER_TOWN_OWNERSHIP)
    except ValueError as exc:
        return [str(exc)]

    card = thresholds.get("maps", {}).get("lower_town_slice")
    if not isinstance(card, dict):
        return ["lower_town_slice: missing threshold card"]
    if card.get("enforce") is not True or card.get("enforcement_state") != "enforced":
        errors.append("lower_town_slice: composition gate must be explicitly enforced")
    if card.get("ownership_contract") != "docs/data/lower_town_authoring_contract.json":
        errors.append("lower_town_slice: threshold card must name its ownership contract")
    if not card.get("source_refs") or not {"H04-H05", "H09-H10"}.issubset(card["source_refs"]):
        errors.append("lower_town_slice: H04-H05 and H09-H10 source refs are required")

    rows = [row for row in manifest.get("maps", []) if row.get("id") == "lower_town_slice"]
    if len(rows) != 1:
        errors.append("lower_town_slice: audit manifest must contain exactly one map row")
        return errors
    enforcement = rows[0].get("composition_enforcement", {})
    expected = {
        "state": "enforced",
        "thresholds": "docs/data/map_composition_thresholds.json#maps.lower_town_slice",
        "ownership": "docs/data/lower_town_authoring_contract.json",
        "open_region_exclusions": "ownership.open_regions[].exclude_from_unowned_empty_region",
    }
    for key, value in expected.items():
        if enforcement.get(key) != value:
            errors.append(f"lower_town_slice: manifest composition_enforcement.{key} must be {value!r}")

    if ownership.get("map_id") != "lower_town_slice":
        errors.append("lower_town_slice: ownership contract has the wrong map_id")
    open_regions = ownership.get("open_regions", [])
    if not open_regions:
        errors.append("lower_town_slice: ownership contract must list intentional open regions")
    for region in open_regions:
        region_id = region.get("id", "<unnamed>")
        if not region.get("bounds_cells"):
            errors.append(f"lower_town_slice: open region {region_id} needs bounds_cells")
        if not region.get("reason"):
            errors.append(f"lower_town_slice: open region {region_id} needs an exclusion reason")
        if region.get("exclude_from_unowned_empty_region") is not True:
            errors.append(
                f"lower_town_slice: open region {region_id} must explicitly opt out of the empty-region metric"
            )
    return errors


def run_godot_audit() -> tuple[int, str]:
    godot = resolve_godot()
    if godot is None:
        return 1, "Godot binary not found; set GODOT_BIN or install Godot 4.7"
    result = subprocess.run(
        [
            str(godot),
            "--headless",
            "--path",
            str(ROOT),
            "--script",
            "tools/audit_map_composition.gd",
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    output = (result.stdout or "") + (result.stderr or "")
    return result.returncode, output


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--write-baseline",
        action="store_true",
        help="write the density baseline report and visual-gate automated_density rows",
    )
    args = parser.parse_args(argv)
    errors = validate_threshold_contract()
    if errors:
        print("map composition verification failed:")
        for error in errors:
            print(f"  - {error}")
        return 1

    code, output = run_godot_audit()
    rows = parse_density_rows(output)
    if rows:
        print("WB-10 density baseline:")
        print(format_density_table(rows))
    if args.write_baseline:
        if not rows:
            print("no DENSITY_JSON rows in audit output; baseline not written")
            return 1
        write_baseline(rows)
        print(f"wrote {BASELINE_REPORT.relative_to(ROOT)} and automated_density rows in {BENCHMARK.relative_to(ROOT)}")
    if code != 0:
        print("map composition audit failed:")
        print(output)
        return 1

    enforced = sum(
        1
        for card in json.loads(THRESHOLDS.read_text(encoding="utf-8"))["maps"].values()
        if card.get("enforce", True)
    )
    print(
        f"map composition verification passed ({enforced} enforced map(s); "
        f"thresholds={THRESHOLDS.relative_to(ROOT)})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

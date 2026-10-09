#!/usr/bin/env python3
"""Validate the physical-object catalog (content/objects/).

Checks, in order: JSON schema; file name/folder; unique ids; the handling /
mass / action / block consistency rules; GLB model, node and measured size
really exist; preview/icon files; derived lifecycle; composition and item_ref
links; and *coverage* - every runtime prop/equipment GLB and every map prop
kind is either catalogued or excluded with a reason in
docs/data/object_catalog_coverage.json. Exit status is non-zero on any problem.

Usage:
    python3 tools/validate_object_catalog.py
    python3 tools/validate_object_catalog.py --quiet
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Any

TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import object_catalog_lib as lib  # noqa: E402
from object_catalog_glb import GlbFile  # noqa: E402
from validate_content_examples import SchemaStore, SchemaValidationError, validate_value  # noqa: E402

MAP_TYPES = lib.ROOT / "scripts" / "map" / "map_types.gd"
STYLE_VARIANTS = lib.ROOT / "scripts" / "map" / "map_prop_style_variants.gd"
TRADE_VARIANTS = lib.ROOT / "scripts" / "map" / "view3d" / "map_view_trade_goods_models.gd"
GLB_SCOPES = (
    "assets/props/**/*.glb",
    "assets/storybook/equipment/*.glb",
    "assets/characters/shared/hero_*.glb",
)
SIZE_TOLERANCE = 0.03
THROW_MAX_MASS_KG = 15.0
FIXED_FORBIDDEN = {"take", "drop", "throw", "push", "pull", "stack", "equip", "load_on_cart"}
HEAVY_FORBIDDEN = {"take", "drop", "throw", "equip", "stack"}


def _known_prop_kinds() -> tuple[set[str], set[str]]:
    """(all ALL_PROP_KINDS values, every &"..." literal in map_types.gd / style variants)."""
    text = MAP_TYPES.read_text(encoding="utf-8")
    variants_text = STYLE_VARIANTS.read_text(encoding="utf-8") + TRADE_VARIANTS.read_text(encoding="utf-8")
    values = {m.group(1): m.group(2) for m in re.finditer(r'const (PROP_KIND_\w+)\s*:=\s*&"([^"]+)"', text)}
    block = re.search(r"const ALL_PROP_KINDS[^=]*=\s*\[(.*?)\]", text, re.S)
    listed = set()
    if block:
        for name in re.findall(r"PROP_KIND_\w+", block.group(1)):
            if name in values:
                listed.add(values[name])
    literals = set(re.findall(r'&"([^"]+)"', text + variants_text))
    return listed, literals


def _known_items() -> dict[str, dict[str, Any]]:
    ids: dict[str, dict[str, Any]] = {}
    for path in (lib.ROOT / "content").rglob("item.*.json"):
        if lib.CATALOG_DIR in path.parents:
            continue
        try:
            record = lib.load_json(path)
        except ValueError:
            continue
        if isinstance(record, dict) and isinstance(record.get("id"), str):
            ids[record["id"]] = record
    return ids


def _check_entry(entry: dict[str, Any], path: Path, problems: list[str], glb_cache: dict[str, GlbFile | None]) -> None:
    oid = entry["id"]

    def bad(message: str) -> None:
        problems.append(f"{oid}: {message}")

    if path != lib.entry_path(entry):
        bad(f"file must live at {lib.entry_path(entry).relative_to(lib.ROOT)} (found {path.relative_to(lib.ROOT)})")

    handling = entry["handling"]
    mass = entry["physical"]["mass_kg"]
    actions = set(entry["actions"])
    if handling in lib.MASS_BOUNDS:
        low, high = lib.MASS_BOUNDS[handling]
        if not (low < mass <= high):
            bad(f"handling {handling} needs mass in ({low}, {high}] kg, got {mass}")
    if handling == "fixed":
        for action in sorted(actions & FIXED_FORBIDDEN):
            bad(f"fixed objects cannot {action}")
        if entry["economy"]["theft_severity"] != 0:
            bad("fixed objects cannot be stolen (theft_severity must be 0)")
    if handling == "heavy":
        for action in sorted(actions & HEAVY_FORBIDDEN):
            bad(f"heavy objects cannot {action} (push/pull only)")
        if not actions & {"push", "pull"} and entry["category"] != "composite":
            bad("heavy objects must be movable with push or pull")
    if handling in lib.TAKEABLE:
        if "take" not in actions:
            bad("takeable handling classes must list the take action")
        if "drop" not in actions:
            bad("takeable handling classes must list the drop action")
    if "throw" in actions:
        if handling not in lib.TAKEABLE or mass > THROW_MAX_MASS_KG:
            bad(f"throw needs a takeable object up to {THROW_MAX_MASS_KG} kg")
        if "throw" not in entry:
            bad("throw action needs a throw block")
    elif "throw" in entry:
        bad("throw block without the throw action")
    if "stack" in actions and not entry.get("carry", {}).get("stackable"):
        bad("stack action needs carry.stackable")

    for block, action in (("edible", "consume"), ("container", "open"), ("light", "light"), ("equip", "equip")):
        if (block in entry) != (action in actions):
            bad(f"{block} block and the {action} action must appear together")
    if "carry" in entry:
        if handling not in lib.BAGGABLE:
            bad("carry (bag footprint) is only for pocketable / carry_one_hand objects")
        elif entry["carry"]["stackable"] and "max_stack" not in entry["carry"]:
            bad("stackable carry needs max_stack")
        cells = entry["carry"]["grid_width"] * entry["carry"]["grid_height"]
        if handling == "pocketable" and cells > 2:
            bad("pocketable objects occupy at most 2 bag cells")
        if handling == "carry_one_hand" and cells < 2:
            bad("carry_one_hand objects occupy at least 2 bag cells")
    elif handling in lib.BAGGABLE:
        bad("pocketable / carry_one_hand objects need a carry block")
    if {"sit", "sleep"} & actions and entry["category"] not in {"furniture", "structure"}:
        bad("sit/sleep only apply to furniture or structures")
    if "hang" in actions and entry["placement"]["mount"] not in {"wall", "hanging"}:
        bad("hang action needs placement.mount wall or hanging")
    if entry["category"] in {"food", "drink"} and "edible" not in entry:
        bad("food/drink objects need an edible block")
    own = entry["economy"]["ownership"]
    if handling in lib.TAKEABLE and entry["economy"]["theft_severity"] == 0 and own not in {"public", "wild"}:
        bad("owned takeable objects need theft_severity >= 1")
    if entry["category"] == "composite":
        if "composition" not in entry:
            bad("composite objects need a composition list")

    # -- model ----------------------------------------------------------------
    model = entry["model"]
    status = model["status"]
    if status == "glb":
        glb_ref = model.get("glb")
        if not glb_ref:
            bad("model.status glb needs model.glb")
        else:
            glb_path = lib.res_to_path(glb_ref)
            if glb_ref not in glb_cache:
                try:
                    glb_cache[glb_ref] = GlbFile.load(glb_path)
                except (OSError, ValueError) as exc:
                    glb_cache[glb_ref] = None
                    bad(f"cannot read {glb_ref}: {exc}")
            glb = glb_cache[glb_ref]
            if glb is not None:
                nodes = [model["node"]] if "node" in model else []
                nodes += list(model.get("states", {}).values())
                for node in nodes:
                    if glb.find_node(node) is None:
                        bad(f"node {node!r} not found in {glb_ref}")
                target = glb.find_node(nodes[0]) if nodes else None
                if not nodes or glb.find_node(nodes[0]) is not None:
                    bounds = glb.triangles(target).bounds()
                    if bounds is None:
                        bad("model has no triangles")
                    else:
                        measured = [round(float(v), 3) for v in bounds[1] - bounds[0]]
                        recorded = model.get("measured_size_m")
                        if recorded is None:
                            bad("model.measured_size_m missing (run `object_catalog.py sync`)")
                        elif any(abs(a - b) > max(0.01, SIZE_TOLERANCE * b) for a, b in zip(recorded, measured)):
                            bad(f"model.measured_size_m {recorded} is stale; GLB measures {measured} (run sync)")
                        if entry["physical"]["size_m"] != (recorded or entry["physical"]["size_m"]):
                            bad("physical.size_m must equal model.measured_size_m (run sync)")
        for fitted in model.get("fitted_variants", []):
            if not lib.res_to_path(fitted).is_file():
                bad(f"fitted variant missing: {fitted}")
    else:
        for key in ("glb", "node", "states", "fitted_variants", "measured_size_m"):
            if key in model:
                bad(f"model.{key} is only valid for model.status glb")
    if status == "procedural":
        builder = model.get("builder")
        if not builder or not lib.res_to_path(builder).is_file():
            bad("procedural models need an existing model.builder script")
        if "prop_kind" not in model:
            bad("procedural models need model.prop_kind (the map placement hook)")

    # -- visuals / lifecycle -------------------------------------------------------
    visual = entry["visual"]
    if visual["preview"] != f"docs/reports/images/object_catalog/{oid}.png":
        bad(f"visual.preview must be docs/reports/images/object_catalog/{oid}.png")
    elif status == "glb" and not (lib.ROOT / visual["preview"]).is_file():
        bad("preview image missing (run tools/render_object_previews.py)")
    if visual["icon"] != f"res://assets/objects/icons/{oid}.png":
        bad(f"visual.icon must be res://assets/objects/icons/{oid}.png")
    if visual["icon_status"] != "missing" and not lib.res_to_path(visual["icon"]).is_file():
        bad(f"icon_status {visual['icon_status']} but {visual['icon']} does not exist")
    expected = lib.expected_lifecycle(entry)
    if entry["lifecycle"] != expected:
        bad(f"lifecycle should be {expected!r}, got {entry['lifecycle']!r}")


def _check_household_needs(
    data: Any, entries: dict[str, dict[str, Any]], store: SchemaStore
) -> list[str]:
    """Validate authoring quotas only; planned models remain allowed in HOMEOBJ-1."""
    try:
        validate_value(data, store.resolve("household_needs.schema.json"), store)
    except SchemaValidationError as exc:
        return [f"household needs: {exc}"]
    problems: list[str] = []
    for need, tiers in data["needs"].items():
        for tier, requirements in tiers.items():
            seen: set[str] = set()
            for requirement in requirements:
                oid = requirement["id"]
                label = f"household needs {need}/{tier}"
                if oid in seen:
                    problems.append(f"{label}: duplicate object {oid}")
                seen.add(oid)
                if oid not in entries:
                    problems.append(f"{label}: unknown catalog object {oid}")
    return problems


def validate() -> list[str]:
    problems: list[str] = []
    store = SchemaStore(lib.ROOT / "schemas")
    schema = store.resolve("world_object.schema.json")
    entries: dict[str, dict[str, Any]] = {}
    paths: dict[str, Path] = {}
    for path in lib.catalog_files():
        try:
            entry = lib.load_json(path)
        except ValueError as exc:
            problems.append(f"{path.relative_to(lib.ROOT)}: invalid JSON: {exc}")
            continue
        try:
            validate_value(entry, schema, store)
        except SchemaValidationError as exc:
            problems.append(f"{path.relative_to(lib.ROOT)}: {exc}")
            continue
        if entry["id"] in entries:
            problems.append(f"{entry['id']}: duplicate id ({path.relative_to(lib.ROOT)})")
            continue
        entries[entry["id"]] = entry
        paths[entry["id"]] = path

    glb_cache: dict[str, GlbFile | None] = {}
    for oid, entry in entries.items():
        _check_entry(entry, paths[oid], problems, glb_cache)
        for part in entry.get("composition", []):
            if part["id"] not in entries:
                problems.append(f"{oid}: composition references unknown {part['id']}")
            elif part["id"] == oid:
                problems.append(f"{oid}: composition cannot contain itself")

    items = _known_items()
    for oid, entry in entries.items():
        if "item_ref" not in entry:
            continue
        record = items.get(entry["item_ref"])
        if record is None:
            problems.append(f"{oid}: item_ref {entry['item_ref']} is not a known item record")
            continue
        carry = record.get("gameplay", {}).get("carry")
        mine = entry.get("carry")
        if carry and mine is None:
            problems.append(f"{oid}: item {entry['item_ref']} is bagged but this object has no carry block")
        elif carry and mine:
            if round(entry["physical"]["mass_kg"] * 1000) != carry["weight_g"]:
                problems.append(f"{oid}: mass_kg disagrees with {entry['item_ref']} weight_g {carry['weight_g']}")
            if (mine["grid_width"], mine["grid_height"]) != (carry["grid_width"], carry["grid_height"]):
                problems.append(f"{oid}: carry grid disagrees with {entry['item_ref']}")

    needs_path = lib.CATALOG_DIR / "_household_needs.json"
    try:
        needs = lib.load_json(needs_path)
    except (OSError, ValueError) as exc:
        problems.append(f"household needs: missing or invalid {needs_path.name}: {exc}")
    else:
        problems += _check_household_needs(needs, entries, store)

    problems += _check_coverage(entries)
    return problems


def _check_coverage(entries: dict[str, dict[str, Any]]) -> list[str]:
    problems: list[str] = []
    if not lib.COVERAGE_PATH.is_file():
        return [f"missing {lib.COVERAGE_PATH.relative_to(lib.ROOT)}"]
    coverage = lib.load_json(lib.COVERAGE_PATH)
    excluded_glbs: dict[str, str] = coverage.get("excluded_glbs", {})
    excluded_kinds: dict[str, str] = coverage.get("excluded_prop_kinds", {})

    referenced: dict[str, str] = {}
    for oid, entry in entries.items():
        model = entry["model"]
        for ref in [model.get("glb"), *model.get("fitted_variants", [])]:
            if ref:
                referenced.setdefault(ref, oid)

    on_disk = set()
    for pattern in GLB_SCOPES:
        for path in lib.ROOT.glob(pattern):
            on_disk.add(lib.path_to_res(path))
    for ref in sorted(on_disk):
        if ref in referenced and ref in excluded_glbs:
            problems.append(f"coverage: {ref} is both catalogued ({referenced[ref]}) and excluded")
        elif ref not in referenced and ref not in excluded_glbs:
            problems.append(f"coverage: {ref} has no catalog object and no exclusion reason")
    for ref, reason in excluded_glbs.items():
        if ref not in on_disk:
            problems.append(f"coverage: excluded GLB {ref} no longer exists")
        if not reason.strip():
            problems.append(f"coverage: exclusion for {ref} needs a reason")
    for ref in referenced:
        if lib.res_to_path(ref).suffix == ".glb" and ref not in on_disk and not lib.res_to_path(ref).is_file():
            problems.append(f"coverage: catalogued GLB {ref} does not exist")

    listed_kinds, literals = _known_prop_kinds()
    catalogued_kinds = {e["model"]["prop_kind"] for e in entries.values() if "prop_kind" in e["model"]}
    for entry in entries.values():
        variant = entry["model"].get("variant")
        if variant and variant not in literals:
            problems.append(f"{entry['id']}: model.variant {variant!r} is not defined in MapTypes / map_prop_style_variants.gd / map_view_trade_goods_models.gd")
    for kind in sorted(catalogued_kinds - literals):
        problems.append(f"coverage: prop_kind {kind!r} is not defined in scripts/map/map_types.gd")
    for kind in sorted(listed_kinds - catalogued_kinds - set(excluded_kinds)):
        problems.append(f"coverage: map prop kind {kind!r} has no catalog object and no exclusion reason")
    for kind in sorted(set(excluded_kinds) & catalogued_kinds):
        problems.append(f"coverage: prop kind {kind!r} is both catalogued and excluded")
    for kind in sorted(set(excluded_kinds) - listed_kinds):
        problems.append(f"coverage: excluded prop kind {kind!r} is not in MapTypes.ALL_PROP_KINDS")
    return problems


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args(argv)
    problems = validate()
    if not args.quiet:
        for problem in problems:
            print(problem)
        count = len(lib.catalog_files())
        print(f"object catalog: {count} object(s), {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())

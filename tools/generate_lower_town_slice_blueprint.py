#!/usr/bin/env python3
"""Generate a compact LowerTownSliceBlueprint with grouped terrain, shared styles, and rows."""

from __future__ import annotations

import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tests/fixtures/maps/lower_town_slice_legacy_definition.gd"
OUTPUT = ROOT / "scripts/map/definitions/lower_town/lower_town_slice_blueprint.gd"

TERRAIN_BATCHES = [
    ("grass", "MapTypes.TERRAIN_GRASS", 0),
    ("water", "MapTypes.TERRAIN_WATER", 1),
    ("causeway", "MapTypes.TERRAIN_DIRT", 2),
    ("cobble", "MapTypes.TERRAIN_COBBLESTONE", 3),
    ("stone", "MapTypes.TERRAIN_STONE", 4),
    ("feature", None, 5),
]


def parse_legacy() -> dict:
    text = SOURCE.read_text(encoding="utf-8")
    zones = [
        (m.group(1), f"Rect2i({m.group(2)})")
        for m in re.finditer(
            r'\{"terrain": (MapTypes\.TERRAIN_\w+), "rect": Rect2i\(([^)]+)\)\}', text
        )
    ]
    buildings_block = text.split("definition.buildings = [", 1)[1].split("\n\t]", 1)[0]
    buildings: list[dict] = []
    for raw in buildings_block.split("\n\t\t"):
        raw = raw.strip().rstrip(",")
        if not raw.startswith("{"):
            continue
        entry: dict[str, str] = {}
        id_m = re.search(r'"id": &"([^"]+)"', raw)
        if not id_m:
            continue
        entry["id"] = id_m.group(1)
        kind_m = re.search(r'"kind": (MapTypes\.BUILDING_KIND_\w+)', raw)
        entry["kind"] = kind_m.group(1).replace("MapTypes.BUILDING_KIND_", "").lower()
        rect_m = re.search(r"Rect2i\(([^)]+)\)", raw)
        entry["rect"] = rect_m.group(1)
        for field in ("wall_height", "door_side", "ridge_axis"):
            fm = re.search(rf'"{field}": ([^,}}]+)', raw)
            if fm:
                val = fm.group(1).strip()
                if val.startswith("&"):
                    val = val[1:].strip('"')
                entry[field] = val
        for field in ("wall_color", "roof_color"):
            fm = re.search(rf'"{field}": Color\(([^)]+)\)', raw)
            if fm:
                entry[field] = fm.group(1)
        buildings.append(entry)
    return {"zones": zones, "buildings": buildings}


def style_key(entry: dict) -> tuple:
    return tuple(
        (k, entry[k])
        for k in ("kind", "wall_height", "wall_color", "roof_color", "door_side", "ridge_axis")
        if k in entry
    )


def style_label(index: int, entry: dict) -> str:
    door = entry.get("door_side", "")
    height = int(float(entry.get("wall_height", "0")))
    kind = entry.get("kind", "obj")
    return f"{kind}.{door or 'plain'}.h{height}.{index:02d}"


def terrain_batches(zones: list[tuple[str, str]]) -> list[tuple[str, str, int, list[str]]]:
    batches: list[tuple[str, str, int, list[str]]] = []
    if not zones:
        return batches
    current_terrain = zones[0][0]
    current_rects = [zones[0][1]]
    current_order = 0
    batch_index = 0
    for index in range(1, len(zones)):
        terrain, rect = zones[index]
        if terrain == current_terrain:
            current_rects.append(rect)
            continue
        batches.append((f"terrain.{batch_index:02d}", current_terrain, current_order, current_rects))
        batch_index += 1
        current_order = index
        current_terrain = terrain
        current_rects = [rect]
    batches.append((f"terrain.{batch_index:02d}", current_terrain, current_order, current_rects))
    return batches


def main() -> None:
    data = parse_legacy()
    seen: dict[tuple, str] = {}
    styles: dict[str, dict] = {}
    style_index = 0
    building_rows: list[str] = []
    for entry in data["buildings"]:
        key = style_key(entry)
        if key not in seen:
            label = style_label(style_index, entry)
            style_index += 1
            seen[key] = label
            values: dict[str, str] = {}
            if "wall_height" in entry:
                values["wall_height"] = entry["wall_height"]
            if "wall_color" in entry:
                values["wall_color"] = f"Color({entry['wall_color']})"
            if "roof_color" in entry:
                values["roof_color"] = f"Color({entry['roof_color']})"
            if "door_side" in entry:
                values["door_side"] = f'&"{entry["door_side"]}"'
            if "ridge_axis" in entry:
                values["ridge_axis"] = f'&"{entry["ridge_axis"]}"'
            styles[label] = values
        building_rows.append(
            f'{entry["id"]}|{entry["kind"]}|{entry["rect"].replace(" ", "")}|{seen[key]}'
        )

    lines = [
        "class_name LowerTownSliceBlueprint",
        "extends RefCounted",
        "",
        "## Compact MapBlueprint source for the Viru Gate Lower Town slice (P2-019).",
        "",
        "",
        "static func create() -> MapBlueprint:",
        "\tvar map := MapBlueprint.new(&\"lower_town_slice\", &\"loc.lower_town_slice\", Vector2i(88, 56), MapTypes.TERRAIN_DIRT)",
        "\tmap.scope = &\"production\"",
        "\tmap.active = true",
        "\tmap.palette = &\"clean_painted\"",
        "\t_define_styles(map)",
        "\t_add_terrain(map)",
        "\t_add_structures(map)",
        "\t_add_landmarks_props_routes(map)",
        "\tmap.surroundings([&\"north\", &\"west\"])",
        "\tmap.add_source_references(_SOURCE_REFERENCES)",
        "\treturn map",
        "",
        "",
        "const _SOURCE_REFERENCES: Array[String] = [",
        '\t"scenes/reval_east/reval_east.tscn", "scenes/revel-map.jpg",',
        '\t"scenes/reval_walls_towers/wall-map.png", "scenes/reval_walls_towers/viru_gate.md",',
        '\t"docs/SCENES/the-makers-mark.md", "docs/SCENES/a-bitter-brew.md",',
        '\t"content/locations/loc.lower_town_slice.json",',
        "]",
        "",
    ]

    lines.append("static func _define_styles(map: MapBlueprint) -> void:")
    lines.append("\tfor style_id in _STYLES:")
    lines.append("\t\tmap.style(style_id, _STYLES[style_id])")
    lines.append("")
    style_parts = []
    for label in sorted(styles):
        parts = [f'"{k}": {v}' for k, v in styles[label].items()]
        style_parts.append(f'&"{label}": {{{", ".join(parts)}}}')
    lines.append(f"const _STYLES := {{{', '.join(style_parts)}}}")

    lines.extend(["", "static func _add_terrain(map: MapBlueprint) -> void:"])
    for batch_id, terrain, order, rects in terrain_batches(data["zones"]):
        rect_list = ", ".join(rects)
        lines.append(
            f"\tmap.terrain_rects(&\"{batch_id}\", {terrain}, [{rect_list}], 0, {order})"
        )

    lines.extend(
        [
            "",
            "static func _add_structures(map: MapBlueprint) -> void:",
            "\tfor row in _BUILDING_ROWS.split(\"\\n\"):",
            "\t\tif row.strip_edges().is_empty():",
            "\t\t\tcontinue",
            "\t\tvar parts := row.split(\"|\")",
            "\t\tvar rect_parts := parts[2].split(\",\")",
            "\t\tmap.structure_rect(",
            "\t\t\tStringName(parts[0]),",
            "\t\t\t_KINDS[parts[1]],",
            "\t\t\tRect2i(int(rect_parts[0]), int(rect_parts[1]), int(rect_parts[2]), int(rect_parts[3])),",
            "\t\t\tStringName(parts[3]),",
            "\t\t)",
            "",
            "const _KINDS := {",
            '\t"house": MapTypes.BUILDING_KIND_HOUSE,',
            '\t"wall": MapTypes.BUILDING_KIND_WALL,',
            "}",
            "",
        ]
    )
    lines.append('const _BUILDING_ROWS := "' + "\\n".join(building_rows) + '"')

    # landmarks, props, anchors - keep explicit block from legacy (compact)
    lines.extend(
        [
            "",
            "",
            "static func _add_landmarks_props_routes(map: MapBlueprint) -> void:",
            "\t# Gate arches and district boundary landmarks.",
            "\tfor spec in _LANDMARKS:",
            "\t\tmap.view_landmark(spec[0], spec[1], spec[2], &\"\", spec[3])",
            "\tfor spec in _PROPS:",
            "\t\tmap.prop_rect(spec[0], spec[1], spec[2])",
            "\tfor spec in _ANCHORS:",
            "\t\tmap.interaction_anchor_rect(spec[0], spec[1])",
            "\tmap.player_spawn_rect(&\"spawn.street_start\", Rect2i(48, 20, 2, 2))",
            "\tfor spec in _TRANSITIONS:",
            "\t\tmap.transition(spec[0], spec[1], spec[2], spec[3], spec[4], &\"\", spec[5])",
            "\tmap.patrol_path_rects(&\"viru_watch\", _PATROL_RECTS)",
            "\tmap.fade_rect(&\"fade.viru_street\", Rect2i(10, 17, 44, 8))",
            "\tmap.direction_sign_rect(&\"sign.harbour\", \"to harbour\", Rect2i(78, 17, 1, 1), Vector2i.RIGHT)",
            "\tmap.direction_sign_rect(&\"sign.town_centre\", \"to town centre\", Rect2i(2, 18, 1, 1), Vector2i.LEFT)",
            "\tmap.direction_sign_rect(&\"sign.karja_suburb\", \"beyond the walls\", Rect2i(41, 51, 1, 1), Vector2i.DOWN)",
            "",
            "const _LANDMARKS: Array = [",
            '\t[&"viru_gate_arch", &"gate_arch", Rect2i(62, 19, 5, 3), {"wall_color": Color(0.56, 0.55, 0.50), "top_px": 256.0, "door_material": &"wood"}],',
            '\t[&"viru_foregate_arch", &"gate_arch", Rect2i(72, 19, 3, 3), {"wall_color": Color(0.56, 0.55, 0.50), "top_px": 176.0, "door_material": &"wood"}],',
            '\t[&"karja_gate_arch", &"gate_arch", Rect2i(36, 47, 3, 4), {"wall_color": Color(0.56, 0.55, 0.50), "top_px": 256.0, "door_material": &"metal"}],',
            '\t[&"vanaturu_kael_arch", &"gate_arch", Rect2i(0, 19, 2, 4), {"wall_color": Color(0.52, 0.50, 0.46), "top_px": 160.0, "passage_axis": &"x"}],',
            '\t[&"vene_district_arch", &"gate_arch", Rect2i(14, 0, 3, 2), {"wall_color": Color(0.52, 0.50, 0.46), "top_px": 160.0, "passage_axis": &"z"}],',
            '\t[&"viru_suburb_arch", &"gate_arch", Rect2i(84, 19, 4, 3), {"wall_color": Color(0.52, 0.50, 0.46), "top_px": 140.0, "door_material": &"wood", "passage_axis": &"x"}],',
            '\t[&"karja_suburb_arch", &"gate_arch", Rect2i(36, 53, 3, 3), {"wall_color": Color(0.52, 0.50, 0.46), "top_px": 140.0, "door_material": &"wood", "passage_axis": &"z"}],',
            "]",
            "",
            "const _PROPS: Array = [",
        ]
    )

    text = SOURCE.read_text(encoding="utf-8")
    props_block = text.split("definition.props = [", 1)[1].split("\n\t]", 1)[0]
    for raw in props_block.split("\n\t\t"):
        raw = raw.strip().rstrip(",")
        id_m = re.search(r'"id": &"([^"]+)"', raw)
        kind_m = re.search(r'"kind": (MapTypes\.PROP_KIND_\w+)', raw)
        rect_m = re.search(r"Rect2i\(([^)]+)\)", raw)
        if id_m and kind_m and rect_m:
            lines.append(
                f'\t[&"{id_m.group(1)}", {kind_m.group(1)}, Rect2i({rect_m.group(1)})],'
            )
    lines.extend(
        [
            "]",
            "",
            "const _ANCHORS: Array = [",
            '\t[&"street_start", Rect2i(48, 20, 2, 2)], [&"smithy_door", Rect2i(51, 27, 2, 1)],',
            '\t[&"brewery_door", Rect2i(45, 22, 2, 1)], [&"checkpoint_west", Rect2i(2, 19, 2, 2)],',
            '\t[&"checkpoint_east", Rect2i(63, 19, 2, 2)], [&"katariina_kaik", Rect2i(34, 8, 2, 2)],',
            '\t[&"monastery_gate", Rect2i(27, 6, 2, 2)], [&"karja_gate_south", Rect2i(36, 49, 2, 2)],',
            '\t[&"vene_street_north", Rect2i(14, 1, 2, 2)],',
            "]",
            "",
            "const _TRANSITIONS: Array = [",
            '\t[&"smithy_door_transition", Rect2i(51, 27, 2, 1), &"forge", &"door_courtyard", &"forge", {"spawn_offset_px": Vector2(0, 48), "highlight_area": true}],',
            '\t[&"vana_turg_boundary", Rect2i(0, 19, 2, 4), &"reval_center", &"from_reval_east", &"vana_turg_boundary", {"spawn_offset_px": Vector2(48, 0), "highlight_area": true, "view_landmark_id": &"vanaturu_kael_arch"}],',
            '\t[&"vene_district_boundary", Rect2i(14, 0, 3, 2), &"reval_north", &"from_reval_east", &"vene_district_boundary", {"spawn_offset_px": Vector2(0, 48), "highlight_area": true, "view_landmark_id": &"vene_district_arch"}],',
            '\t[&"viru_road_boundary", Rect2i(84, 19, 4, 3), &"harbor_warehouse", &"from_reval_east", &"viru_road_boundary", {"spawn_offset_px": Vector2(-48, 0), "highlight_area": true, "view_landmark_id": &"viru_suburb_arch"}],',
            '\t[&"karja_road_boundary", Rect2i(36, 53, 3, 3), &"", &"", &"karja_road_boundary", {"spawn_offset_px": Vector2(0, -48), "highlight_area": true, "view_landmark_id": &"karja_suburb_arch"}],',
            '\t[&"street_start_spawn", Rect2i(48, 20, 2, 2), &"", &"", &"street_start", {}],',
            "]",
            "",
            "const _PATROL_RECTS: Array[Rect2i] = [",
            "\tRect2i(63, 19, 2, 2), Rect2i(29, 19, 2, 2), Rect2i(3, 19, 2, 2),",
            "\tRect2i(36, 29, 2, 2), Rect2i(36, 44, 2, 2),",
            "]",
            "",
        ]
    )

    OUTPUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT} ({len(lines)} lines)")


if __name__ == "__main__":
    main()

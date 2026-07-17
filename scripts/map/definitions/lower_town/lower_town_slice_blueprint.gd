class_name LowerTownSliceBlueprint
extends RefCounted

## Compact MapBlueprint source for the Viru Gate Lower Town slice (P2-019).


static func create() -> MapBlueprint:
	var map := MapBlueprint.new(&"lower_town_slice", &"loc.lower_town_slice", Vector2i(88, 56), MapTypes.TERRAIN_DIRT)
	map.scope = &"production"
	map.active = true
	map.palette = &"clean_painted"
	_define_styles(map)
	_add_terrain(map)
	_add_structures(map)
	_add_landmarks_props_routes(map)
	map.surroundings([&"north", &"west"])
	map.add_source_references(_SOURCE_REFERENCES)
	return map


const _SOURCE_REFERENCES: Array[String] = [
	"scenes/reval_east/reval_east.tscn", "scenes/revel-map.jpg",
	"scenes/reval_walls_towers/wall-map.png", "scenes/reval_walls_towers/viru_gate.md",
	"docs/SCENES/the-makers-mark.md", "docs/SCENES/a-bitter-brew.md",
	"content/locations/loc.lower_town_slice.json",
]

static func _define_styles(map: MapBlueprint) -> void:
	for style_id in _STYLES:
		map.style(style_id, _STYLES[style_id])

const _STYLES := {&"house.east.h104.40": {"wall_height": 104.0, "wall_color": Color(0.39, 0.35, 0.29), "roof_color": Color(0.22, 0.19, 0.16), "door_side": &"east"}, &"house.east.h104.41": {"wall_height": 104.0, "wall_color": Color(0.39, 0.35, 0.30), "roof_color": Color(0.22, 0.20, 0.17), "door_side": &"east"}, &"house.east.h104.42": {"wall_height": 104.0, "wall_color": Color(0.38, 0.34, 0.29), "roof_color": Color(0.22, 0.19, 0.16), "door_side": &"east"}, &"house.east.h112.11": {"wall_height": 112.0, "wall_color": Color(0.40, 0.36, 0.30), "roof_color": Color(0.22, 0.20, 0.18), "door_side": &"east"}, &"house.east.h112.12": {"wall_height": 112.0, "wall_color": Color(0.41, 0.37, 0.31), "roof_color": Color(0.23, 0.20, 0.17), "door_side": &"east"}, &"house.east.h112.14": {"wall_height": 112.0, "wall_color": Color(0.40, 0.36, 0.30), "roof_color": Color(0.22, 0.19, 0.16), "door_side": &"east"}, &"house.east.h120.17": {"wall_height": 120.0, "wall_color": Color(0.46, 0.42, 0.36), "roof_color": Color(0.25, 0.21, 0.16), "door_side": &"east"}, &"house.east.h128.24": {"wall_height": 128.0, "wall_color": Color(0.50, 0.46, 0.40), "roof_color": Color(0.26, 0.15, 0.12), "door_side": &"east"}, &"house.east.h96.43": {"wall_height": 96.0, "wall_color": Color(0.37, 0.33, 0.28), "roof_color": Color(0.21, 0.19, 0.16), "door_side": &"east"}, &"house.east.h96.52": {"wall_height": 96.0, "wall_color": Color(0.39, 0.35, 0.30), "roof_color": Color(0.22, 0.20, 0.17), "door_side": &"east"}, &"house.none.h128.46": {"wall_height": 128.0, "wall_color": Color(0.34, 0.30, 0.26), "roof_color": Color(0.22, 0.20, 0.18), "door_side": &"none"}, &"house.north.h104.32": {"wall_height": 104.0, "wall_color": Color(0.39, 0.35, 0.29), "roof_color": Color(0.22, 0.19, 0.16), "door_side": &"north"}, &"house.north.h104.34": {"wall_height": 104.0, "wall_color": Color(0.39, 0.35, 0.30), "roof_color": Color(0.22, 0.20, 0.17), "door_side": &"north"}, &"house.north.h104.35": {"wall_height": 104.0, "wall_color": Color(0.38, 0.34, 0.29), "roof_color": Color(0.22, 0.19, 0.16), "door_side": &"north"}, &"house.north.h104.36": {"wall_height": 104.0, "wall_color": Color(0.40, 0.36, 0.30), "roof_color": Color(0.22, 0.20, 0.18), "door_side": &"north"}, &"house.north.h104.39": {"wall_height": 104.0, "wall_color": Color(0.40, 0.36, 0.30), "roof_color": Color(0.23, 0.20, 0.17), "door_side": &"north"}, &"house.north.h112.19": {"wall_height": 112.0, "wall_color": Color(0.42, 0.37, 0.31), "roof_color": Color(0.24, 0.20, 0.16), "door_side": &"north"}, &"house.north.h112.21": {"wall_height": 112.0, "wall_color": Color(0.41, 0.37, 0.31), "roof_color": Color(0.23, 0.20, 0.17), "door_side": &"north"}, &"house.north.h112.23": {"wall_height": 112.0, "wall_color": Color(0.40, 0.36, 0.30), "roof_color": Color(0.22, 0.20, 0.18), "door_side": &"north"}, &"house.north.h112.31": {"wall_height": 112.0, "wall_color": Color(0.42, 0.38, 0.31), "roof_color": Color(0.23, 0.20, 0.17), "door_side": &"north"}, &"house.north.h120.20": {"wall_height": 120.0, "wall_color": Color(0.46, 0.40, 0.33), "roof_color": Color(0.26, 0.21, 0.16), "door_side": &"north"}, &"house.north.h120.33": {"wall_height": 120.0, "wall_color": Color(0.46, 0.42, 0.36), "roof_color": Color(0.25, 0.21, 0.16), "door_side": &"north"}, &"house.north.h120.45": {"wall_height": 120.0, "wall_color": Color(0.38, 0.32, 0.26), "roof_color": Color(0.24, 0.20, 0.16), "door_side": &"north"}, &"house.north.h136.22": {"wall_height": 136.0, "wall_color": Color(0.52, 0.48, 0.42), "roof_color": Color(0.26, 0.14, 0.11), "door_side": &"north", "ridge_axis": &"z"}, &"house.north.h96.44": {"wall_height": 96.0, "wall_color": Color(0.37, 0.33, 0.28), "roof_color": Color(0.21, 0.19, 0.16), "door_side": &"north"}, &"house.north.h96.49": {"wall_height": 96.0, "wall_color": Color(0.38, 0.34, 0.29), "roof_color": Color(0.22, 0.19, 0.16), "door_side": &"north"}, &"house.north.h96.51": {"wall_height": 96.0, "wall_color": Color(0.39, 0.35, 0.30), "roof_color": Color(0.22, 0.20, 0.17), "door_side": &"north"}, &"house.south.h104.54": {"wall_height": 104.0, "wall_color": Color(0.40, 0.36, 0.30), "roof_color": Color(0.22, 0.20, 0.18), "door_side": &"south"}, &"house.south.h112.16": {"wall_height": 112.0, "wall_color": Color(0.42, 0.37, 0.31), "roof_color": Color(0.24, 0.20, 0.16), "door_side": &"south"}, &"house.south.h112.29": {"wall_height": 112.0, "wall_color": Color(0.41, 0.37, 0.31), "roof_color": Color(0.23, 0.20, 0.17), "door_side": &"south"}, &"house.south.h112.38": {"wall_height": 112.0, "wall_color": Color(0.42, 0.38, 0.31), "roof_color": Color(0.23, 0.20, 0.17), "door_side": &"south"}, &"house.south.h120.09": {"wall_height": 120.0, "wall_color": Color(0.44, 0.40, 0.34), "roof_color": Color(0.24, 0.20, 0.16), "door_side": &"south"}, &"house.south.h120.10": {"wall_height": 120.0, "wall_color": Color(0.42, 0.38, 0.31), "roof_color": Color(0.23, 0.20, 0.17), "door_side": &"south"}, &"house.south.h120.18": {"wall_height": 120.0, "wall_color": Color(0.44, 0.39, 0.32), "roof_color": Color(0.24, 0.20, 0.16), "door_side": &"south"}, &"house.south.h120.25": {"wall_height": 120.0, "wall_color": Color(0.44, 0.40, 0.34), "roof_color": Color(0.24, 0.20, 0.16), "door_side": &"south", "ridge_axis": &"z"}, &"house.south.h120.30": {"wall_height": 120.0, "wall_color": Color(0.43, 0.38, 0.31), "roof_color": Color(0.25, 0.21, 0.16), "door_side": &"south"}, &"house.south.h128.06": {"wall_height": 128.0, "wall_color": Color(0.62, 0.60, 0.55), "roof_color": Color(0.28, 0.16, 0.12), "door_side": &"south"}, &"house.south.h128.15": {"wall_height": 128.0, "wall_color": Color(0.50, 0.45, 0.38), "roof_color": Color(0.26, 0.15, 0.12), "door_side": &"south"}, &"house.south.h128.26": {"wall_height": 128.0, "wall_color": Color(0.48, 0.43, 0.36), "roof_color": Color(0.26, 0.15, 0.12), "door_side": &"south"}, &"house.south.h128.27": {"wall_height": 128.0, "wall_color": Color(0.52, 0.50, 0.46), "roof_color": Color(0.26, 0.14, 0.11), "door_side": &"south", "ridge_axis": &"z"}, &"house.south.h136.28": {"wall_height": 136.0, "wall_color": Color(0.50, 0.46, 0.40), "roof_color": Color(0.26, 0.15, 0.12), "door_side": &"south"}, &"house.south.h192.05": {"wall_height": 192.0, "wall_color": Color(0.66, 0.64, 0.58), "roof_color": Color(0.30, 0.16, 0.12), "door_side": &"south"}, &"house.south.h96.08": {"wall_height": 96.0, "wall_color": Color(0.44, 0.40, 0.34), "roof_color": Color(0.24, 0.20, 0.16), "door_side": &"south"}, &"house.south.h96.48": {"wall_height": 96.0, "wall_color": Color(0.39, 0.35, 0.30), "roof_color": Color(0.22, 0.20, 0.17), "door_side": &"south"}, &"house.south.h96.50": {"wall_height": 96.0, "wall_color": Color(0.40, 0.36, 0.30), "roof_color": Color(0.23, 0.20, 0.17), "door_side": &"south"}, &"house.west.h120.13": {"wall_height": 120.0, "wall_color": Color(0.46, 0.40, 0.33), "roof_color": Color(0.26, 0.21, 0.16), "door_side": &"west"}, &"house.west.h120.37": {"wall_height": 120.0, "wall_color": Color(0.46, 0.42, 0.36), "roof_color": Color(0.25, 0.21, 0.16), "door_side": &"west"}, &"house.west.h96.53": {"wall_height": 96.0, "wall_color": Color(0.38, 0.34, 0.29), "roof_color": Color(0.22, 0.19, 0.16), "door_side": &"west"}, &"wall.plain.h128.03": {"wall_height": 128.0, "wall_color": Color(0.57, 0.56, 0.51)}, &"wall.plain.h176.04": {"wall_height": 176.0, "wall_color": Color(0.56, 0.55, 0.50)}, &"wall.plain.h192.00": {"wall_height": 192.0, "wall_color": Color(0.58, 0.57, 0.52)}, &"wall.plain.h240.01": {"wall_height": 240.0, "wall_color": Color(0.55, 0.54, 0.50)}, &"wall.plain.h256.02": {"wall_height": 256.0, "wall_color": Color(0.56, 0.55, 0.50)}, &"wall.plain.h56.47": {"wall_height": 56.0, "wall_color": Color(0.48, 0.50, 0.54)}, &"wall.plain.h96.07": {"wall_height": 96.0, "wall_color": Color(0.60, 0.58, 0.53)}}

static func _add_terrain(map: MapBlueprint) -> void:
	map.terrain_rects(&"terrain.00", MapTypes.TERRAIN_GRASS, [Rect2i(66, 0, 22, 50), Rect2i(0, 50, 88, 6), Rect2i(18, 0, 26, 7), Rect2i(44, 0, 16, 8), Rect2i(9, 38, 26, 8), Rect2i(4, 36, 5, 10), Rect2i(44, 28, 6, 10), Rect2i(54, 32, 12, 8), Rect2i(44, 40, 22, 10)], 0, 0)
	map.terrain_rects(&"terrain.01", MapTypes.TERRAIN_WATER, [Rect2i(70, 0, 3, 16), Rect2i(70, 14, 5, 2), Rect2i(73, 16, 3, 10), Rect2i(70, 25, 5, 2), Rect2i(70, 27, 3, 7), Rect2i(64, 32, 7, 3), Rect2i(58, 35, 7, 3), Rect2i(56, 38, 5, 3), Rect2i(52, 41, 6, 3), Rect2i(48, 44, 5, 3), Rect2i(46, 47, 4, 3), Rect2i(44, 50, 4, 3), Rect2i(0, 52, 88, 2)], 0, 9)
	map.terrain_rects(&"terrain.02", MapTypes.TERRAIN_DIRT, [Rect2i(66, 19, 22, 3), Rect2i(36, 50, 3, 6)], 0, 22)
	map.terrain_rects(&"terrain.03", MapTypes.TERRAIN_COBBLESTONE, [Rect2i(0, 19, 58, 4)], 0, 24)
	map.terrain_rects(&"terrain.04", MapTypes.TERRAIN_STONE, [Rect2i(58, 19, 9, 3)], 0, 25)
	map.terrain_rects(&"terrain.05", MapTypes.TERRAIN_COBBLESTONE, [Rect2i(0, 14, 9, 13), Rect2i(14, 0, 3, 19)], 0, 26)
	map.terrain_rects(&"terrain.06", MapTypes.TERRAIN_STONE, [Rect2i(14, 8, 46, 2)], 0, 28)
	map.terrain_rects(&"terrain.07", MapTypes.TERRAIN_COBBLESTONE, [Rect2i(36, 23, 3, 24), Rect2i(33, 44, 9, 3)], 0, 29)
	map.terrain_rects(&"terrain.08", MapTypes.TERRAIN_STONE, [Rect2i(36, 47, 3, 3)], 0, 31)
	map.terrain_rects(&"terrain.09", MapTypes.TERRAIN_COBBLESTONE, [Rect2i(9, 27, 17, 2), Rect2i(8, 32, 28, 2)], 0, 32)
	map.terrain_rects(&"terrain.10", MapTypes.TERRAIN_HAY, [Rect2i(50, 28, 2, 2)], 0, 34)
	map.terrain_rects(&"terrain.11", MapTypes.TERRAIN_MUD, [Rect2i(18, 46, 4, 2)], 0, 35)

static func _add_structures(map: MapBlueprint) -> void:
	for row in _BUILDING_ROWS.split("\n"):
		if row.strip_edges().is_empty():
			continue
		var parts := row.split("|")
		var rect_parts := parts[2].split(",")
		map.structure_rect(
			StringName(parts[0]),
			_KINDS[parts[1]],
			Rect2i(int(rect_parts[0]), int(rect_parts[1]), int(rect_parts[2]), int(rect_parts[3])),
			StringName(parts[3]),
		)

const _KINDS := {
	"house": MapTypes.BUILDING_KIND_HOUSE,
	"wall": MapTypes.BUILDING_KIND_WALL,
}

const _BUILDING_ROWS := "city_wall_north|wall|64,0,2,15|wall.plain.h192.00\nwall_tower_northeast|wall|63,2,4,3|wall.plain.h240.01\nwall_tower_north|wall|63,9,4,3|wall.plain.h240.01\nviru_gate_north_tower|wall|62,15,5,4|wall.plain.h256.02\nviru_gate_south_tower|wall|62,22,5,4|wall.plain.h256.02\nforegate_wall_north|wall|67,18,6,1|wall.plain.h128.03\nforegate_wall_south|wall|67,22,6,1|wall.plain.h128.03\nforegate_tower_north|wall|72,16,3,3|wall.plain.h176.04\nforegate_tower_south|wall|72,22,3,3|wall.plain.h176.04\ncity_wall_gate_south|wall|63,26,2,4|wall.plain.h192.00\nwall_seal_viru_south_west|wall|62,26,1,4|wall.plain.h192.00\nwall_seal_viru_south_east|wall|65,26,2,4|wall.plain.h192.00\nwall_seal_hinke_north|wall|60,26,3,3|wall.plain.h192.00\nwall_seal_bend_a_east|wall|60,30,1,2|wall.plain.h192.00\nwall_seal_bend_b_north|wall|52,30,2,4|wall.plain.h192.00\nwall_seal_bend_c_west|wall|44,38,2,2|wall.plain.h192.00\nwall_seal_bend_d_north|wall|42,38,2,4|wall.plain.h192.00\nhinke_tower|wall|60,29,4,4|wall.plain.h240.01\ncity_wall_bend_a|wall|55,30,5,2|wall.plain.h192.00\nwall_tower_southeast|wall|52,30,3,4|wall.plain.h240.01\ncity_wall_bend_b|wall|52,34,2,5|wall.plain.h192.00\nwall_tower_south|wall|50,37,4,4|wall.plain.h240.01\ncity_wall_bend_c|wall|44,38,6,2|wall.plain.h192.00\nwall_tower_southwest|wall|42,38,3,4|wall.plain.h240.01\ncity_wall_bend_d|wall|42,42,2,6|wall.plain.h192.00\nkarja_gate_east_tower|wall|39,47,4,4|wall.plain.h256.02\nkarja_gate_west_tower|wall|32,47,4,4|wall.plain.h256.02\ncity_wall_southwest|wall|0,48,32,2|wall.plain.h192.00\nst_catherines_church|house|20,1,12,5|house.south.h192.05\nmonastery_cloister|house|33,0,9,6|house.south.h128.06\nmonastery_precinct_wall_west|wall|18,0,1,7|wall.plain.h96.07\nmonastery_precinct_wall_south_a|wall|18,7,9,1|wall.plain.h96.07\nmonastery_precinct_wall_south_b|wall|30,7,14,1|wall.plain.h96.07\nmonastery_barn|house|46,2,4,3|house.south.h96.08\npikk_corner_house|house|0,0,5,4|house.south.h120.09\nvene_row_house|house|6,0,5,4|house.south.h120.10\nvene_corner_house|house|11,0,3,4|house.east.h112.11\nmarket_row_house|house|0,5,4,5|house.east.h112.12\nsaiakang_house|house|5,5,5,5|house.west.h120.13\nvene_gate_house|house|11,5,3,5|house.east.h112.14\napothecary_house|house|0,10,4,4|house.south.h128.15\nturg_house_north|house|5,10,4,4|house.south.h112.16\nmoneychangers_house|house|10,10,4,4|house.east.h120.17\nvanaturu_kael_house|house|9,15,5,4|house.south.h120.18\nkaik_house_west|house|18,10,6,4|house.north.h112.19\nkaik_house_mid|house|25,10,6,4|house.north.h120.20\nkaik_house_east|house|34,10,6,4|house.north.h112.21\nguild_storehouse|house|41,10,6,4|house.north.h136.22\nglovers_house|house|48,10,5,4|house.north.h112.23\ncorner_house_muurivahe|house|54,10,5,4|house.east.h128.24\nviru_house_west|house|18,15,6,4|house.south.h120.25\nviru_house_mid|house|25,14,7,5|house.south.h128.26\nviru_house_stone|house|34,15,6,4|house.south.h128.27\nmerchants_house|house|41,14,6,5|house.south.h136.28\nviru_house_east|house|48,15,5,4|house.south.h112.29\nweary_traveler_inn|house|54,15,5,4|house.south.h120.30\nsaddlers_house|house|9,23,5,4|house.north.h112.23\ncoopers_house|house|15,23,5,4|house.north.h112.31\nsauna_corner_house|house|20,23,4,4|house.north.h104.32\nrope_makers_house|house|26,23,5,4|house.north.h112.21\nkarja_corner_house|house|31,23,5,4|house.north.h120.33\nkuninga_house_west|house|9,29,5,3|house.north.h104.34\nkuninga_house_mid|house|15,29,5,3|house.north.h104.35\nkuninga_house_east|house|20,29,4,3|house.north.h104.36\npublic_bathhouse|house|26,29,5,3|house.west.h120.37\nvaike_karja_house|house|31,29,5,3|house.south.h112.38\ntenement_row|house|9,34,5,4|house.north.h112.23\nlaundress_house|house|15,34,5,4|house.north.h104.35\nwidows_house|house|21,34,5,4|house.north.h104.34\ndyers_house|house|27,34,5,4|house.north.h104.39\nkarja_gate_house|house|33,34,3,4|house.east.h104.40\nturg_south_house|house|0,27,4,4|house.east.h112.12\nwest_lane_house|house|0,32,4,4|house.east.h104.41\nhedge_house|house|0,37,4,4|house.east.h104.42\nwall_side_house|house|0,42,4,4|house.east.h96.43\nartisan_shed|house|44,29,4,3|house.north.h96.44\npotters_house|house|44,33,4,3|house.north.h104.32\nglassblowers_house|house|39,23,4,4|house.north.h112.23\nfoaming_mug_brewery|house|44,23,6,4|house.north.h120.45\nkalev_smithy|house|50,23,5,4|house.none.h128.46\nsmithy_yard_fence_north|wall|55,23,2,1|wall.plain.h56.47\nsmithy_yard_fence_east|wall|59,23,1,5|wall.plain.h56.47\nsuburb_house_north_a|house|68,16,4,3|house.south.h96.48\nsuburb_house_south_a|house|68,23,4,3|house.north.h96.49\nsuburb_house_north_b|house|76,16,4,3|house.south.h96.50\nsuburb_house_south_b|house|76,23,4,3|house.north.h96.51\nkarja_suburb_house_west|house|32,53,3,3|house.east.h96.52\nkarja_suburb_house_east|house|40,53,3,3|house.west.h96.53\nmuurivahe_house_north|house|58,0,5,3|house.south.h104.54"


static func _add_landmarks_props_routes(map: MapBlueprint) -> void:
	# Gate arches and district boundary landmarks.
	for spec in _LANDMARKS:
		map.view_landmark(spec[0], spec[1], spec[2], &"", spec[3])
	for spec in _PROPS:
		map.prop_rect(spec[0], spec[1], spec[2])
	for spec in _ANCHORS:
		map.interaction_anchor_rect(spec[0], spec[1])
	map.player_spawn_rect(&"spawn.street_start", Rect2i(48, 20, 2, 2))
	for spec in _TRANSITIONS:
		map.transition(spec[0], spec[1], spec[2], spec[3], spec[4], &"", spec[5])
	map.patrol_path_rects(&"viru_watch", _PATROL_RECTS)
	map.fade_rect(&"fade.viru_street", Rect2i(10, 17, 44, 8))
	map.direction_sign_rect(&"sign.harbour", "to harbour", Rect2i(78, 17, 1, 1), Vector2i.RIGHT)
	map.direction_sign_rect(&"sign.town_centre", "to town centre", Rect2i(41, 51, 1, 1), Vector2i.DOWN)

const _LANDMARKS: Array = [
	[&"viru_gate_arch", &"gate_arch", Rect2i(62, 19, 5, 3), {"wall_color": Color(0.56, 0.55, 0.50), "top_px": 256.0, "door_material": &"wood"}],
	[&"viru_foregate_arch", &"gate_arch", Rect2i(72, 19, 3, 3), {"wall_color": Color(0.56, 0.55, 0.50), "top_px": 176.0, "door_material": &"wood"}],
	[&"karja_gate_arch", &"gate_arch", Rect2i(36, 47, 3, 4), {"wall_color": Color(0.56, 0.55, 0.50), "top_px": 256.0, "door_material": &"metal"}],
	[&"vanaturu_kael_arch", &"gate_arch", Rect2i(0, 19, 2, 4), {"wall_color": Color(0.52, 0.50, 0.46), "top_px": 160.0, "passage_axis": &"x"}],
	[&"vene_district_arch", &"gate_arch", Rect2i(14, 0, 3, 2), {"wall_color": Color(0.52, 0.50, 0.46), "top_px": 160.0, "passage_axis": &"z"}],
	[&"viru_suburb_arch", &"gate_arch", Rect2i(84, 19, 4, 3), {"wall_color": Color(0.52, 0.50, 0.46), "top_px": 140.0, "door_material": &"wood", "passage_axis": &"x"}],
	[&"karja_suburb_arch", &"gate_arch", Rect2i(36, 53, 3, 3), {"wall_color": Color(0.52, 0.50, 0.46), "top_px": 140.0, "door_material": &"wood", "passage_axis": &"z"}],
]

const _PROPS: Array = [
	[&"courtyard_anvil", MapTypes.PROP_KIND_ANVIL, Rect2i(56, 24, 2, 2)],
	[&"courtyard_furnace", MapTypes.PROP_KIND_FURNACE, Rect2i(55, 27, 2, 2)],
	[&"courtyard_quench", MapTypes.PROP_KIND_QUENCH, Rect2i(57, 28, 1, 1)],
	[&"hay_store", MapTypes.PROP_KIND_HAY_STACK, Rect2i(50, 28, 2, 2)],
	[&"cistern", MapTypes.PROP_KIND_WELL, Rect2i(60, 22, 2, 2)],
	[&"monastery_well", MapTypes.PROP_KIND_WELL, Rect2i(42, 4, 2, 2)],
	[&"market_stall_gate", MapTypes.PROP_KIND_STALL, Rect2i(59, 22, 2, 1)],
	[&"market_stall_turg_north", MapTypes.PROP_KIND_STALL, Rect2i(3, 16, 2, 2)],
	[&"market_stall_turg_south", MapTypes.PROP_KIND_STALL, Rect2i(6, 23, 2, 2)],
	[&"street_cart", MapTypes.PROP_KIND_CART, Rect2i(28, 21, 2, 2)],
	[&"gate_cart", MapTypes.PROP_KIND_CART, Rect2i(68, 20, 2, 2)],
	[&"yard_cart", MapTypes.PROP_KIND_CART, Rect2i(46, 31, 2, 2)],
	[&"brewery_barrels", MapTypes.PROP_KIND_BARRELS, Rect2i(44, 27, 2, 1)],
	[&"evidence_barrels", MapTypes.PROP_KIND_BARRELS, Rect2i(46, 28, 2, 2)],
]

const _ANCHORS: Array = [
	[&"street_start", Rect2i(48, 20, 2, 2)], [&"smithy_door", Rect2i(51, 27, 2, 1)],
	[&"brewery_door", Rect2i(45, 22, 2, 1)], [&"checkpoint_west", Rect2i(2, 19, 2, 2)],
	[&"checkpoint_east", Rect2i(63, 19, 2, 2)], [&"katariina_kaik", Rect2i(34, 8, 2, 2)],
	[&"monastery_gate", Rect2i(27, 6, 2, 2)], [&"karja_gate_south", Rect2i(36, 49, 2, 2)],
	[&"vene_street_north", Rect2i(14, 1, 2, 2)],
]

const _TRANSITIONS: Array = [
	[&"smithy_door_transition", Rect2i(51, 27, 2, 1), &"forge", &"door_courtyard", &"forge", {"spawn_offset_px": Vector2(0, 48), "highlight_area": true}],
	[&"vana_turg_boundary", Rect2i(0, 19, 2, 4), &"reval_center", &"from_reval_east", &"vana_turg_boundary", {"spawn_offset_px": Vector2(48, 0), "highlight_area": true, "view_landmark_id": &"vanaturu_kael_arch"}],
	[&"vene_district_boundary", Rect2i(14, 0, 3, 2), &"reval_north", &"from_reval_east", &"vene_district_boundary", {"spawn_offset_px": Vector2(0, 48), "highlight_area": true, "view_landmark_id": &"vene_district_arch"}],
	[&"viru_road_boundary", Rect2i(84, 19, 4, 3), &"harbor_warehouse", &"from_reval_east", &"viru_road_boundary", {"spawn_offset_px": Vector2(-48, 0), "highlight_area": true, "view_landmark_id": &"viru_suburb_arch"}],
	[&"karja_road_boundary", Rect2i(36, 53, 3, 3), &"reval_center", &"from_reval_east_south", &"karja_road_boundary", {"spawn_offset_px": Vector2(0, -48), "highlight_area": true, "view_landmark_id": &"karja_suburb_arch"}],
	[&"street_start_spawn", Rect2i(48, 20, 2, 2), &"", &"", &"street_start", {}],
]

const _PATROL_RECTS: Array[Rect2i] = [
	Rect2i(63, 19, 2, 2), Rect2i(29, 19, 2, 2), Rect2i(3, 19, 2, 2),
	Rect2i(36, 29, 2, 2), Rect2i(36, 44, 2, 2),
]


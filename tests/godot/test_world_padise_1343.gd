extends "res://tests/godot/test_case.gd"

## Padise on 1 May 1343 after the P6 rework.
##
## The earlier contract described one oversized timber shed built from roofless
## interior-wall panels on a 50x30 map. That read as a stockade in the 3D view.
## This contract fixes the reworked site instead: a 100x60 plateau above the
## Kloostri, roofed timber claustral ranges around an open garth, the two stone
## buildings the excavations place before the quadrangle, and a working grange.
##
## The post-uprising fortified complex must stay out. Villu Kadakas (AVE 2011)
## dates the northern, eastern and southern ranges to ~1350-1400 and the church
## consecration to 1448, and concludes the quadrangle was begun only after 1343.

const MAP_PATH := "res://content/maps/world_padise.rrmap"
const LATE_PRIMITIVES: Array[StringName] = [&"stone_church", &"monastic_range", &"gatehouse"]
const ATTESTED_STONE_IDS: Array[StringName] = [&"early_west_stone_house", &"arched_niche_house"]
const CLAUSTRAL_RANGE_IDS: Array[StringName] = [
	&"timber_oratory",
	&"timber_west_range",
	&"timber_east_range",
	&"timber_south_range",
]
const CLOISTER_WALK_IDS: Array[StringName] = [
	&"cloister_walk_north",
	&"cloister_walk_south",
	&"cloister_walk_west",
	&"cloister_walk_east",
]
const PRECINCT_WALL_IDS: Array[StringName] = [
	&"precinct_wall_north_west",
	&"precinct_wall_north_east",
	&"precinct_wall_west",
	&"precinct_wall_east",
	&"precinct_wall_south_west",
	&"precinct_wall_south_east",
]
const MANDATORY_ANCHORS: Array[StringName] = [
	&"landmark_early_stone_house",
	&"landmark_timber_oratory",
	&"landmark_fire_damage",
	&"landmark_work_yard",
	&"landmark_monastery_well",
]
const PRECINCT_ANCHORS: Array[StringName] = [
	&"room_cloister_garth",
	&"room_chapter_range",
	&"room_refectory",
	&"room_infirmary",
	&"room_brewhouse",
	&"room_lay_brothers",
	&"precinct_gate_anchor",
	&"landmark_watermill",
	&"landmark_monks_cemetery",
	&"landmark_river_ford",
	&"landmark_arched_niche_house",
]


func test_world_padise_is_a_four_times_larger_monastic_estate() -> void:
	var definition := _definition()
	if definition == null:
		return
	assert_eq(definition.size_cells, Vector2i(100, 60), "the rework quadruples the 50x30 site area")
	var buildings := _buildings_by_id(definition)
	for stone_id in ATTESTED_STONE_IDS:
		assert_true(buildings.has(stone_id), "missing archaeologically attested stone building: %s" % stone_id)
		assert_eq(buildings[stone_id].get("primitive"), &"stone_hall")
		assert_eq(buildings[stone_id].get("kind"), MapTypes.BUILDING_KIND_HOUSE, "attested masonry must be a roofed mass")
	for primitive in LATE_PRIMITIVES:
		assert_eq(_primitive_count(definition, primitive), 0, "post-1343 fortified primitive must not appear: %s" % primitive)


func test_world_padise_claustral_ranges_are_roofed_not_a_wall_maze() -> void:
	var definition := _definition()
	if definition == null:
		return
	var buildings := _buildings_by_id(definition)
	for range_id in CLAUSTRAL_RANGE_IDS:
		assert_true(buildings.has(range_id), "missing claustral range: %s" % range_id)
		assert_eq(
			buildings[range_id].get("kind"),
			MapTypes.BUILDING_KIND_HOUSE,
			"a conventual range must be a roofed house mass, not a roofless panel: %s" % range_id,
		)
	assert_eq(
		buildings[&"timber_oratory"].get("primitive"),
		&"timber_oratory_1343",
		"the oratory carries the timber bellcote and lancet dressing",
	)
	# Roofless records are reserved for the two burnt-out shells of 23 April.
	var roofless := definition.buildings.filter(
		func(building): return building.get("kind") == MapTypes.BUILDING_KIND_WALL \
			and String(building.get("id", "")).begins_with("burned_")
	)
	assert_true(roofless.size() >= 2, "the 23 April fire needs readable burnt-out shells")
	assert_eq(
		_kind_count(definition, MapTypes.BUILDING_KIND_INTERIOR_WALL),
		0,
		"the outdoor estate must not rebuild the roofless interior-wall maze",
	)


func test_world_padise_cloister_walks_stay_walkable_landmarks() -> void:
	var definition := _definition()
	if definition == null:
		return
	var grid := MapBuilder.build(definition)
	var landmarks: Dictionary = {}
	for landmark in definition.view_landmarks:
		landmarks[landmark.get("id")] = landmark
	for walk_id in CLOISTER_WALK_IDS:
		assert_true(landmarks.has(walk_id), "missing cloister walk landmark: %s" % walk_id)
		var walk: Dictionary = landmarks[walk_id]
		assert_eq(walk.get("kind"), &"cloister_walk")
		assert_true(
			MapDefinition.WORLD_SIDES.has(StringName(String(walk.get("interior_side", "")))),
			"a cloister walk needs the range side that carries its high eaves: %s" % walk_id,
		)
		var rect: Rect2 = walk["rect"]
		assert_true(
			MapVerification.route_exists(definition, grid, definition.player_spawn, rect.get_center()),
			"a covered walk must remain a walkable route: %s" % walk_id,
		)


func test_world_padise_precinct_and_grange_read_as_an_abbey_close() -> void:
	var definition := _definition()
	if definition == null:
		return
	var buildings := _buildings_by_id(definition)
	for wall_id in PRECINCT_WALL_IDS:
		assert_true(buildings.has(wall_id), "missing precinct enclosure run: %s" % wall_id)
		assert_eq(buildings[wall_id].get("kind"), MapTypes.BUILDING_KIND_WALL)
		assert_true(
			MapTypes.resolved_wall_height_px(buildings[wall_id]) < 160.0,
			"the 1343 close is a low boundary, not the later fortified circuit: %s" % wall_id,
		)
	for grange_id in [&"grange_barn", &"grange_granary", &"grange_stable", &"watermill"]:
		assert_true(buildings.has(grange_id), "the house needs its working grange: %s" % grange_id)
	# Estate work, not interior furniture, is what dresses an outdoor precinct.
	assert_true(_prop_count(definition, MapTypes.PROP_KIND_FIELD_STRIP) >= 2, "the estate needs worked field strips")
	assert_true(_prop_count(definition, MapTypes.PROP_KIND_KITCHEN_GARDEN) >= 2, "a Cistercian close needs garden beds")
	assert_true(_prop_count(definition, MapTypes.PROP_KIND_WELL) >= 1, "the well remains a landmark")
	assert_array_contains(MapBuilder.build(definition).used_terrain_ids(), MapTypes.TERRAIN_ASH)
	assert_true(
		definition.decals.any(func(decal): return decal.get("kind") == MapTypes.DECAL_KIND_SCORCH),
		"the 1 May phase needs restrained evidence of the 23 April fire",
	)


func test_world_padise_anchors_and_travel_edges_are_reachable() -> void:
	var definition := _definition()
	if definition == null:
		return
	var grid := MapBuilder.build(definition)
	var required := MANDATORY_ANCHORS.duplicate()
	required.append_array(PRECINCT_ANCHORS)
	for anchor_id in required:
		assert_true(MapVerification.has_anchor(definition, anchor_id), "missing Padise anchor %s" % anchor_id)
		assert_true(
			MapVerification.route_exists(definition, grid, definition.player_spawn, MapVerification.anchor_position(definition, anchor_id)),
			"Padise anchor is unreachable: %s" % anchor_id,
		)
	var transition_ids: Array = definition.transitions.map(func(transition): return transition.get("id"))
	for transition_id in [&"road_to_reval", &"road_to_parnu"]:
		assert_array_contains(transition_ids, transition_id)
	assert_true(MapVerification.collision_parity(definition))


func _definition() -> MapDefinition:
	var parsed := MapRrmapParser.parse_file(MAP_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return null
	return parsed.definition


func _buildings_by_id(definition: MapDefinition) -> Dictionary:
	var result: Dictionary = {}
	for building in definition.buildings:
		result[building.get("id")] = building
	return result


func _kind_count(definition: MapDefinition, kind: StringName) -> int:
	return definition.buildings.filter(func(building): return building.get("kind") == kind).size()


func _prop_count(definition: MapDefinition, kind: StringName) -> int:
	return definition.props.filter(func(prop): return prop.get("kind") == kind).size()


func _primitive_count(definition: MapDefinition, primitive: StringName) -> int:
	return definition.buildings.filter(func(building): return building.get("primitive") == primitive).size()

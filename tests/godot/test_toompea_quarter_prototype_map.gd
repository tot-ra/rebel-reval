extends "res://tests/godot/test_case.gd"

const ToompeaQuarterDefinition := preload("res://scripts/map/definitions/prototypes/toompea_quarter_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")


func test_toompea_matches_reference_map_footprint() -> void:
	var definition: MapDefinition = ToompeaQuarterDefinition.create()
	assert_eq(definition.size_cells, Vector2i(144, 192))
	assert_eq(definition.camera_bounds, definition.cell_rect_to_world_rect(Rect2i(0, 0, 144, 192)))
	assert_eq(definition.ground_elevation, 2.8)
	assert_true(MapBuilder.validate(definition).is_empty())
	assert_true(definition.buildings.size() >= 28, "Upper Town needs district-scale built density")
	assert_true(
		definition.size_cells.y > definition.size_cells.x,
		"Map Alignment uses the north-south footprint of the walled Toompea district"
	)


func test_toompea_limits_cobble_to_gate_descents_and_lossi_plats() -> void:
	var definition: MapDefinition = ToompeaQuarterDefinition.create()
	var grid := MapBuilder.build(definition)
	var cobble := 0
	var earth := 0
	var grass := 0
	var total: int = definition.size_cells.x * definition.size_cells.y
	for y in range(definition.size_cells.y):
		for x in range(definition.size_cells.x):
			match grid.get_terrain(Vector2i(x, y)):
				MapTypes.TERRAIN_COBBLESTONE:
					cobble += 1
				MapTypes.TERRAIN_DIRT, MapTypes.TERRAIN_MUD, MapTypes.TERRAIN_SAND:
					earth += 1
				MapTypes.TERRAIN_GRASS:
					grass += 1
	assert_true(cobble <= int(total * 0.05), "Upper Town cobble must remain limited to major fortified routes")
	assert_true(earth >= int(total * 0.50), "Closes and secondary lanes must remain packed earth or mud")
	assert_true(grass >= int(total * 0.40), "Plateau compounds and orchard ground must remain green")
	assert_eq(grid.get_terrain(Vector2i(126, 40)), MapTypes.TERRAIN_COBBLESTONE, "Pikk Jalg remains a paved main descent")
	assert_eq(grid.get_terrain(Vector2i(60, 60)), MapTypes.TERRAIN_DIRT, "The cathedral close remains packed earth")


func test_toompea_landmarks_follow_historic_upper_town_geography() -> void:
	var definition: MapDefinition = ToompeaQuarterDefinition.create()
	var castle := _building_by_id(definition, &"castle_mass")
	var cathedral := _building_by_id(definition, &"cathedral_silhouette")
	var pikk_gate := _landmark_by_id(definition, &"pikk_jalg_gate")
	var luhike_gate := _landmark_by_id(definition, &"luhike_jalg_gate_arch")
	assert_false(castle.is_empty())
	assert_false(cathedral.is_empty())
	assert_false(pikk_gate.is_empty())
	assert_false(luhike_gate.is_empty())
	assert_true((castle["footprint"] as Rect2).get_center().x < definition.world_size().x * 0.4, "Castle must anchor the south-western plateau")
	assert_true((castle["footprint"] as Rect2).get_center().y > definition.world_size().y * 0.5, "Castle must anchor the south-western plateau")
	assert_true((cathedral["footprint"] as Rect2).get_center().y < definition.world_size().y * 0.5, "Cathedral close must stand north of Lossi plats")
	assert_eq((pikk_gate["rect"] as Rect2).end.x, definition.world_size().x, "Pikk Jalg must descend from the east edge")
	assert_eq((luhike_gate["rect"] as Rect2).end.x, definition.world_size().x, "Lühike Jalg must descend from the east edge")


func test_toompea_plateau_routes_connect_landmarks_and_all_three_descents() -> void:
	var definition: MapDefinition = ToompeaQuarterDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	for anchor_id in [&"castle_courtyard", &"cathedral_frontage", &"luhike_jalg_gate", &"from_reval_north", &"from_archbishops_garden"]:
		assert_true(MapVerification.has_anchor(definition, anchor_id), "Missing Toompea anchor %s" % anchor_id)
		assert_true(
			MapVerification.route_exists_exact(
				definition,
				grid,
				definition.player_spawn,
				MapVerification.anchor_position(definition, anchor_id)
			),
			"Toompea route is blocked at %s" % anchor_id
		)


func test_toompea_precinct_life_dressing() -> void:
	var definition: MapDefinition = ToompeaQuarterDefinition.create()
	var precinct_kinds := {
		MapTypes.PROP_KIND_FARM_CART: false,
		MapTypes.PROP_KIND_BANNER: false,
		MapTypes.PROP_KIND_HERB_DRYING_RACK: false,
		MapTypes.PROP_KIND_WASH_TUB: false,
	}
	for prop in definition.props:
		var kind: StringName = prop.get("kind", &"")
		if precinct_kinds.has(kind):
			precinct_kinds[kind] = true
	for precinct_kind in precinct_kinds:
		assert_true(precinct_kinds[precinct_kind], "Toompea needs precinct prop %s" % String(precinct_kind))
	assert_false(_prop_by_id(definition, &"stable_cart").is_empty())
	assert_eq(_prop_by_id(definition, &"stable_cart").get("kind"), MapTypes.PROP_KIND_FARM_CART)
	assert_true(
		_prop_near_building(definition, &"castle_courtyard_banner", &"castle_mass", 8),
		"Castle banner must sit beside the castle compound"
	)
	assert_true(
		_prop_near_building(definition, &"cathedral_terrace_banner", &"cathedral_silhouette", 8),
		"Cathedral terrace banner must sit beside the cathedral close"
	)
	assert_true(
		_prop_near_building(definition, &"cathedral_close_herbs", &"cathedral_silhouette", 10),
		"Herb drying rack must dress the cathedral terrace"
	)
	assert_true(
		_prop_near_building(definition, &"stable_cart", &"castle_stables", 8),
		"Stable cart must sit beside castle_stables"
	)
	var grid := MapBuilder.build(definition)
	for point in (definition.patrols[0]["points"] as Array):
		assert_true(
			MapVerification.is_walkable_point(definition, grid, point),
			"Patrol point %s must stay walkable after precinct dressing" % point
		)


func _prop_near_building(
	definition: MapDefinition,
	prop_id: StringName,
	building_id: StringName,
	max_distance_cells: int
) -> bool:
	var prop := _prop_by_id(definition, prop_id)
	var building := _building_by_id(definition, building_id)
	if prop.is_empty() or building.is_empty():
		return false
	var prop_pos: Vector2 = prop.get("position", Vector2.ZERO)
	var footprint: Rect2 = building["footprint"]
	var closest := Vector2(
		clampf(prop_pos.x, footprint.position.x, footprint.end.x),
		clampf(prop_pos.y, footprint.position.y, footprint.end.y)
	)
	return prop_pos.distance_to(closest) <= float(max_distance_cells * definition.cell_size)


func _prop_by_id(definition: MapDefinition, prop_id: StringName) -> Dictionary:
	for prop in definition.props:
		if prop["id"] == prop_id:
			return prop
	return {}


func _building_by_id(definition: MapDefinition, building_id: StringName) -> Dictionary:
	for building in definition.buildings:
		if building["id"] == building_id:
			return building
	return {}


func _landmark_by_id(definition: MapDefinition, landmark_id: StringName) -> Dictionary:
	for landmark in definition.view_landmarks:
		if landmark["id"] == landmark_id:
			return landmark
	return {}

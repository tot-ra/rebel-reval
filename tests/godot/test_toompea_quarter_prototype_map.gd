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
	for anchor_id in [&"castle_courtyard", &"cathedral_frontage", &"luhike_jalg_gate", &"from_reval_north", &"from_reval_south"]:
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

extends "res://tests/godot/test_case.gd"

const NorthQuarterDefinition := preload("res://scripts/map/definitions/prototypes/north_quarter_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")


func test_north_quarter_prototype_bounds_and_spine() -> void:
	var definition: MapDefinition = NorthQuarterDefinition.create()
	assert_eq(definition.size_cells, Vector2i(208, 140))
	assert_true(MapBuilder.validate(definition).is_empty())
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	assert_true(MapVerification.has_anchor(definition, &"pikk_street_spine"))
	assert_true(MapVerification.has_anchor(definition, &"merchant_court"))
	assert_true(
		MapVerification.route_exists(
			definition,
			grid,
			definition.player_spawn,
			MapVerification.anchor_position(definition, &"pikk_street_spine")
		)
	)
	assert_true(
		MapVerification.route_exists(
			definition,
			grid,
			definition.player_spawn,
			MapVerification.anchor_position(definition, &"merchant_court")
		)
	)


func test_merchant_district_has_three_sided_walls_round_turrets_and_harbor_gate() -> void:
	var definition: MapDefinition = NorthQuarterDefinition.create()
	for wall_id in [&"city_wall_north_west", &"city_wall_north_east", &"city_wall_west", &"city_wall_east"]:
		assert_false(_building_by_id(definition, wall_id).is_empty(), "Missing Merchant District wall %s" % wall_id)
	for tower_id in [&"coast_gate_west_tower", &"coast_gate_east_tower", &"merchant_wall_tower_west_mid", &"merchant_wall_tower_east_mid"]:
		var tower := _building_by_id(definition, tower_id)
		assert_true(bool(tower.get("tower", false)), "%s must use the round fortification-tower renderer" % tower_id)
		var node := MapViewMeshBuilder.build_building(tower, definition.cell_size)
		assert_true((node.get_node("Walls") as MeshInstance3D).mesh is CylinderMesh, "%s must be circular like Workers' District towers" % tower_id)
		node.free()
	var harbor_transition := _transition_by_id(definition, &"to_reval_harbor")
	var coast_gate := _landmark_by_id(definition, &"coast_gate_arch")
	assert_eq(harbor_transition.get("view_landmark_id", &""), &"coast_gate_arch")
	assert_true((coast_gate["rect"] as Rect2).encloses(harbor_transition["rect"]), "Great Coast Gate must cover the route to Trade Harbour")


func test_merchant_district_connects_to_monastery_district() -> void:
	var definition: MapDefinition = NorthQuarterDefinition.create()
	var transition_by_id: Dictionary = {}
	for transition in definition.transitions:
		transition_by_id[transition["id"]] = transition
	assert_true(transition_by_id.has(&"to_monastery"))
	var to_monastery: Dictionary = transition_by_id[&"to_monastery"]
	assert_eq(to_monastery["destination_scene_id"], &"reval_monastery")
	assert_eq(to_monastery["destination_spawn_id"], &"from_reval_north")
	assert_eq(to_monastery["spawn_id"], &"from_monastery")


func test_north_quarter_connects_to_harbor() -> void:
	var definition: MapDefinition = NorthQuarterDefinition.create()
	var transition_by_id: Dictionary = {}
	for transition in definition.transitions:
		transition_by_id[transition["id"]] = transition
	assert_true(transition_by_id.has(&"to_reval_harbor"))
	var to_harbor: Dictionary = transition_by_id[&"to_reval_harbor"]
	assert_eq(to_harbor["destination_scene_id"], &"reval_harbor_north")
	assert_eq(to_harbor["destination_spawn_id"], &"from_reval_north")
	assert_eq(to_harbor["spawn_id"], &"to_reval_harbor")


func _transition_by_id(definition: MapDefinition, transition_id: StringName) -> Dictionary:
	for transition in definition.transitions:
		if transition["id"] == transition_id:
			return transition
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

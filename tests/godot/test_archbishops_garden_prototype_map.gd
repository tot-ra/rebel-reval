extends "res://tests/godot/test_case.gd"

const ArchbishopsGardenDefinition := preload("res://scripts/map/definitions/prototypes/archbishops_garden_definition.gd")


func test_archbishops_garden_is_a_connected_western_toompea_region() -> void:
	var definition: MapDefinition = ArchbishopsGardenDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	assert_eq(definition.size_cells, Vector2i(144, 48))
	assert_eq(definition.ground_elevation, 2.8)
	assert_true(MapBuilder.validate(definition).is_empty())
	for anchor_id in [&"archbishops_garden", &"medieval_well", &"western_view", &"from_reval_toompea", &"from_reval_center", &"from_reval_south"]:
		assert_true(MapVerification.has_anchor(definition, anchor_id), "Missing garden anchor %s" % anchor_id)
		assert_true(
			MapVerification.route_exists_exact(
				definition,
				grid,
				definition.player_spawn,
				MapVerification.anchor_position(definition, anchor_id)
			),
			"Garden route is blocked at %s" % anchor_id
		)


func test_archbishops_garden_uses_round_towers_and_period_safe_landmarks() -> void:
	var definition: MapDefinition = ArchbishopsGardenDefinition.create()
	assert_true(_building_by_id(definition, &"bishop_house").is_empty(), "The Bishop's House is not attested until 1420")
	assert_false(_prop_by_id(definition, &"medieval_well_prop").is_empty())
	for tower_id in [&"garden_wall_tower_northwest", &"garden_wall_tower_west_bend", &"garden_wall_tower_southwest", &"center_gate_north_tower", &"center_gate_south_tower"]:
		var tower := _building_by_id(definition, tower_id)
		assert_true(bool(tower.get("tower", false)), "%s must be a round fortification tower" % tower_id)
		var node := MapViewMeshBuilder.build_building(tower, definition.cell_size)
		assert_true((node.get_node("Walls") as MeshInstance3D).mesh is CylinderMesh)
		node.free()


func _building_by_id(definition: MapDefinition, building_id: StringName) -> Dictionary:
	for building in definition.buildings:
		if building["id"] == building_id:
			return building
	return {}


func _prop_by_id(definition: MapDefinition, prop_id: StringName) -> Dictionary:
	for prop in definition.props:
		if prop["id"] == prop_id:
			return prop
	return {}

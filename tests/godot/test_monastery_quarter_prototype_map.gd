extends "res://tests/godot/test_case.gd"

const MonasteryQuarterDefinition := preload("res://scripts/map/definitions/prototypes/monastery_quarter_definition.gd")


func test_monastery_district_is_the_wide_lower_half_of_the_northern_ward() -> void:
	var definition: MapDefinition = MonasteryQuarterDefinition.create()
	assert_eq(definition.size_cells, Vector2i(208, 112))
	assert_true(definition.size_cells.x > definition.size_cells.y)
	assert_true(MapBuilder.validate(definition).is_empty())
	for anchor_id in [&"monastery_close", &"st_olaf_frontage", &"guild_frontage", &"from_reval_north"]:
		assert_true(MapVerification.has_anchor(definition, anchor_id), "Missing Monastery District anchor %s" % anchor_id)


func test_monastery_district_has_tallinn_walls_and_round_turrets_on_both_sides() -> void:
	var definition: MapDefinition = MonasteryQuarterDefinition.create()
	for wall_id in [&"monastery_city_wall_west_north", &"monastery_city_wall_west_south", &"monastery_city_wall_east"]:
		assert_false(_building_by_id(definition, wall_id).is_empty(), "Missing Monastery District wall %s" % wall_id)
	for tower_id in [&"monastery_wall_tower_northwest", &"monastery_wall_tower_west_mid", &"monastery_wall_tower_northeast", &"monastery_wall_tower_east_mid"]:
		var tower := _building_by_id(definition, tower_id)
		assert_true(bool(tower.get("tower", false)), "%s must use the round fortification-tower renderer" % tower_id)
		var node := MapViewMeshBuilder.build_building(tower, definition.cell_size)
		assert_true((node.get_node("Walls") as MeshInstance3D).mesh is CylinderMesh, "%s must be circular like Workers' District towers" % tower_id)
		node.free()


func test_monastery_district_links_the_merchant_civic_worker_and_toompea_maps() -> void:
	var definition: MapDefinition = MonasteryQuarterDefinition.create()
	var destinations: Dictionary = {}
	for transition in definition.transitions:
		destinations[transition["destination_scene_id"]] = transition["destination_spawn_id"]
	assert_eq(destinations[&"reval_north"], &"from_monastery")
	assert_eq(destinations[&"reval_center"], &"to_reval_north")
	assert_eq(destinations[&"reval_east"], &"vene_district_boundary")
	assert_eq(destinations[&"reval_toompea"], &"from_reval_north")


func _building_by_id(definition: MapDefinition, building_id: StringName) -> Dictionary:
	for building in definition.buildings:
		if building["id"] == building_id:
			return building
	return {}

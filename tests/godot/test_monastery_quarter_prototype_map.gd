extends "res://tests/godot/test_case.gd"

const MonasteryQuarterDefinition := preload("res://scripts/map/definitions/prototypes/monastery_quarter_definition.gd")


func test_monastery_district_is_the_wide_lower_half_of_the_northern_ward() -> void:
	var definition: MapDefinition = MonasteryQuarterDefinition.create()
	assert_eq(definition.size_cells, Vector2i(208, 112))
	assert_true(definition.size_cells.x > definition.size_cells.y)
	assert_true(MapBuilder.validate(definition).is_empty())
	for anchor_id in [&"monastery_close", &"st_olaf_frontage", &"guild_frontage", &"from_reval_north"]:
		assert_true(MapVerification.has_anchor(definition, anchor_id), "Missing Monastery District anchor %s" % anchor_id)


func test_monastery_district_uses_earth_base_and_street_spines_not_blanket_cobble() -> void:
	# HISTORICAL_AUDIT monastery ground ranges + cross-map exclusion 1 forbid map-wide cobble.
	var definition: MapDefinition = MonasteryQuarterDefinition.create()
	assert_eq(definition.base_terrain, MapTypes.TERRAIN_DIRT)
	var grid := MapBuilder.build(definition)
	var cobble := 0
	var dirt_or_mud := 0
	var grass := 0
	var stone := 0
	var total: int = definition.size_cells.x * definition.size_cells.y
	for y in range(definition.size_cells.y):
		for x in range(definition.size_cells.x):
			match grid.get_terrain(Vector2i(x, y)):
				MapTypes.TERRAIN_COBBLESTONE:
					cobble += 1
				MapTypes.TERRAIN_DIRT, MapTypes.TERRAIN_MUD:
					dirt_or_mud += 1
				MapTypes.TERRAIN_GRASS:
					grass += 1
				MapTypes.TERRAIN_STONE:
					stone += 1
	assert_true(cobble <= int(total * 0.03), "Cobble must be limited to the primary Pikk spine")
	assert_true(dirt_or_mud >= int(total * 0.25), "Earth/mud/service yard share must reach the 25%% monastery floor")
	assert_true(grass >= int(total * 0.20), "Garden/grass share must remain substantial outside street spines")
	assert_true(stone < int(total * 0.20), "Stone closes must stay compact, not district-scale plazas")
	assert_true(
		MapVerification.has_anchor(definition, &"pikk_street_spine"),
		"Primary Pikk spine anchor must survive the street-surface pass"
	)
	assert_eq(grid.get_terrain(Vector2i(101, 50)), MapTypes.TERRAIN_COBBLESTONE, "Pikk remains the paved primary spine")
	assert_eq(grid.get_terrain(Vector2i(135, 50)), MapTypes.TERRAIN_DIRT, "Lai remains an unpaved secondary lane")


func test_monastery_district_has_dated_early_towers_and_later_wall_positions() -> void:
	var definition: MapDefinition = MonasteryQuarterDefinition.create()
	for wall_id in [&"monastery_city_wall_west_north", &"monastery_city_wall_west_south", &"monastery_city_wall_east"]:
		assert_false(_building_by_id(definition, wall_id).is_empty(), "Missing Monastery District wall %s" % wall_id)
	for tower_id in [&"monastery_wall_tower_northwest", &"monastery_wall_tower_west_mid"]:
		var tower := _building_by_id(definition, tower_id)
		assert_true(bool(tower.get("tower", false)), "%s must be completed in the conservative 1343 registry" % tower_id)
		var node := MapViewMeshBuilder.build_building(tower, definition.cell_size)
		assert_true((node.get_node("Walls") as MeshInstance3D).mesh is CylinderMesh)
		node.free()
	for unfinished_id in [&"monastery_wall_tower_northeast", &"monastery_wall_tower_east_mid"]:
		assert_false(bool(_building_by_id(definition, unfinished_id).get("tower", true)), "%s must not render as a completed 1343 tower" % unfinished_id)


func test_monastery_district_links_the_merchant_civic_worker_and_toompea_maps() -> void:
	var definition: MapDefinition = MonasteryQuarterDefinition.create()
	var destinations: Dictionary = {}
	for transition in definition.transitions:
		destinations[transition["destination_scene_id"]] = transition["destination_spawn_id"]
	assert_eq(destinations[&"reval_north"], &"from_monastery")
	assert_eq(destinations[&"reval_center"], &"to_reval_north")
	assert_eq(destinations[&"reval_east"], &"vene_district_boundary")
	assert_eq(destinations[&"reval_toompea"], &"from_reval_north")


func test_monastery_guild_rowfronts_avoid_later_monument_styles() -> void:
	# P4-023e: later Great Guild / Blackheads monuments must not read as 1343 fabric.
	var definition: MapDefinition = MonasteryQuarterDefinition.create()
	for building_id in [&"great_guild_front", &"blackheads_corner", &"brotherhood_wing"]:
		var building := _building_by_id(definition, building_id)
		assert_false(building.is_empty(), "Missing guild-row building %s" % building_id)
		assert_eq(
			building.get("wall_material", &""),
			&"plaster",
			"%s must use ordinary merchant plaster, not monumental guild limestone" % building_id
		)
		assert_eq(
			int(building.get("wall_height", 0)),
			120,
			"%s must stay at merchant-house height, not guild-hall scale" % building_id
		)


func _building_by_id(definition: MapDefinition, building_id: StringName) -> Dictionary:
	for building in definition.buildings:
		if building["id"] == building_id:
			return building
	return {}

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


func test_archbishops_garden_favors_orchard_vegetation_over_brick_plazas() -> void:
	# HISTORICAL_AUDIT archbishops_garden ground ranges: stone 10-20%, earth 15-25%,
	# grass/orchard/garden 60-75%. Keep the close compact and plant the plateau.
	var definition: MapDefinition = ArchbishopsGardenDefinition.create()
	var grid := MapBuilder.build(definition)
	var stone_or_cobble := 0
	var earth := 0
	var garden_ground := 0
	var total: int = definition.size_cells.x * definition.size_cells.y
	for y in range(definition.size_cells.y):
		for x in range(definition.size_cells.x):
			match grid.get_terrain(Vector2i(x, y)):
				MapTypes.TERRAIN_STONE, MapTypes.TERRAIN_COBBLESTONE:
					stone_or_cobble += 1
				MapTypes.TERRAIN_DIRT, MapTypes.TERRAIN_MUD:
					earth += 1
				MapTypes.TERRAIN_GRASS, MapTypes.TERRAIN_FOREST_FLOOR:
					garden_ground += 1
	assert_true(stone_or_cobble >= int(total * 0.10), "Canon close and Toom-Kooli need a readable stone spine")
	assert_true(stone_or_cobble <= int(total * 0.20), "Stone/cobble must stay under the garden historical ceiling")
	assert_true(earth >= int(total * 0.15), "Dirt walks and terrace/quarry fill must remain visible")
	assert_true(earth <= int(total * 0.25), "Earth fill must not erase the orchard lawn")
	assert_true(garden_ground >= int(total * 0.60), "Grass/orchard/garden must dominate the plateau")

	var vegetation_styles: Dictionary = {}
	for zone in definition.zones:
		var variant: StringName = zone.get("style_variant", &"")
		if not variant.is_empty():
			vegetation_styles[variant] = true
	for required in [
		&"grass.flowers",
		&"grass.clover",
		&"grass.fern",
		&"grass.mossy",
		&"grass.tall",
		&"bush.dense",
		&"bush.scrub",
		&"tree.orchard",
		&"tree.spruce",
	]:
		assert_true(vegetation_styles.has(required), "Garden needs vegetation style %s" % required)

	var bush_props := 0
	var timber_fences := 0
	for prop in definition.props:
		match prop["kind"]:
			MapTypes.PROP_KIND_BUSH:
				bush_props += 1
			MapTypes.PROP_KIND_TIMBER_FENCE:
				timber_fences += 1
	assert_true(bush_props >= 20, "Authored shrub props should dress orchard, well, and terrace edges")
	assert_true(timber_fences >= 3, "Timber orchard/kitchen edges should replace long brick plot walls")
	assert_false(_prop_by_id(definition, &"orchard_plot_fence_north").is_empty())
	assert_false(_prop_by_id(definition, &"kitchen_plot_fence").is_empty())


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

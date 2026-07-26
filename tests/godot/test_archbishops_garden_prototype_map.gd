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


func test_archbishops_garden_renders_apple_and_cherry_orchard_batches() -> void:
	var definition: MapDefinition = ArchbishopsGardenDefinition.create()
	var scatter := MapViewMeshBuilder.build_scatter(definition, MapBuilder.build(definition))
	for species in [MapViewTreeSpecies.SPECIES_APPLE, MapViewTreeSpecies.SPECIES_CHERRY]:
		var label := String(species).capitalize()
		var canopy := scatter.get_node_or_null("Trees_%s" % label) as MultiMeshInstance3D
		var fruit := scatter.get_node_or_null("TreeFruit_%s" % label) as MultiMeshInstance3D
		assert_true(canopy != null, "Garden must render %s crowns" % species)
		assert_true(fruit != null, "Garden must render visible %s fruit" % species)
		if canopy != null and fruit != null:
			assert_true(canopy.multimesh.instance_count > 0)
			assert_eq(fruit.multimesh.instance_count, canopy.multimesh.instance_count)
	scatter.free()


func test_archbishops_garden_precinct_life_dressing() -> void:
	var definition: MapDefinition = ArchbishopsGardenDefinition.create()
	var garden_kinds := {
		MapTypes.PROP_KIND_HERB_DRYING_RACK: false,
		MapTypes.PROP_KIND_FARM_CART: false,
		MapTypes.PROP_KIND_HAY_STACK: false,
		MapTypes.PROP_KIND_TIMBER_FENCE: false,
	}
	for prop in definition.props:
		var kind: StringName = prop.get("kind", &"")
		if garden_kinds.has(kind):
			garden_kinds[kind] = true
	for garden_kind in garden_kinds:
		assert_true(garden_kinds[garden_kind], "Garden needs precinct prop %s" % String(garden_kind))
	assert_false(_prop_by_id(definition, &"hay_store").is_empty())
	assert_eq(_prop_by_id(definition, &"gardener_cart").get("kind"), MapTypes.PROP_KIND_FARM_CART)
	assert_true(
		_prop_near_prop(definition, &"kitchen_herb_rack", &"kitchen_plot_fence", 6),
		"Herb drying rack must sit beside the kitchen plot fence"
	)
	assert_true(
		_prop_near_building(definition, &"gardener_cart", &"orchard_store", 8),
		"Gardener cart must sit beside orchard_store"
	)
	assert_true(
		_prop_near_building(definition, &"hay_store", &"orchard_store", 8),
		"Hay store must sit beside orchard_store"
	)
	assert_false(_prop_by_id(definition, &"orchard_plot_fence_north").is_empty())
	assert_false(_prop_by_id(definition, &"kitchen_plot_fence").is_empty())
	var grid := MapBuilder.build(definition)
	for point in (definition.patrols[0]["points"] as Array):
		assert_true(
			MapVerification.is_walkable_point(definition, grid, point),
			"Patrol point %s must stay walkable after garden dressing" % point
		)


func _prop_near_prop(
	definition: MapDefinition,
	prop_id: StringName,
	other_prop_id: StringName,
	max_distance_cells: int
) -> bool:
	var prop := _prop_by_id(definition, prop_id)
	var other := _prop_by_id(definition, other_prop_id)
	if prop.is_empty() or other.is_empty():
		return false
	var prop_pos: Vector2 = prop.get("position", Vector2.ZERO)
	var other_pos: Vector2 = other.get("position", Vector2.ZERO)
	return prop_pos.distance_to(other_pos) <= float(max_distance_cells * definition.cell_size)


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

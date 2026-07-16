extends "res://tests/godot/test_case.gd"

const SmithyCourtyardDefinition := preload("res://scripts/map/smithy_courtyard_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapTypes := preload("res://scripts/map/map_types.gd")
const MapBuildingRenderer := preload("res://scripts/map/map_building_renderer.gd")
const MapTerrainRenderer := preload("res://scripts/map/map_terrain_renderer.gd")


func test_map_definition_validates() -> void:
	var definition: MapDefinition = SmithyCourtyardDefinition.create()
	var errors: Array[String] = MapBuilder.validate(definition)
	assert_true(errors.is_empty(), "Expected valid definition, got: %s" % str(errors))


func test_map_builder_determinism() -> void:
	var definition: MapDefinition = SmithyCourtyardDefinition.create()
	var first: MapTerrainGrid = MapBuilder.build(definition)
	var second: MapTerrainGrid = MapBuilder.build(definition)
	assert_eq(first.fingerprint(), second.fingerprint(), "Terrain grid fingerprint must be stable")


func test_terrain_coverage_has_no_gaps() -> void:
	var definition: MapDefinition = SmithyCourtyardDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)

	for y in grid.size_cells.y:
		for x in grid.size_cells.x:
			var terrain: StringName = grid.get_terrain(Vector2i(x, y))
			assert_false(terrain.is_empty(), "Missing terrain at cell (%d, %d)" % [x, y])


func test_all_terrain_ids_are_present() -> void:
	var definition: MapDefinition = SmithyCourtyardDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var used: Array[StringName] = grid.used_terrain_ids()

	for terrain_id in MapTypes.ALL_TERRAINS:
		assert_array_contains(used, terrain_id, "Terrain ID missing from built map: %s" % String(terrain_id))


func test_building_collisions_cover_footprints() -> void:
	var definition: MapDefinition = SmithyCourtyardDefinition.create()
	assert_eq(definition.buildings.size(), 8)

	for building in definition.buildings:
		var body: StaticBody2D = MapBuildingRenderer.create_building(building)
		assert_true(body.is_in_group("map_building_collision"))

		var collision := body.get_child(0) as CollisionShape2D
		assert_ne(collision, null, "Building %s is missing collision" % String(building["id"]))

		var shape := collision.shape as RectangleShape2D
		assert_ne(shape, null, "Building %s must use RectangleShape2D" % String(building["id"]))

		var footprint: Rect2 = building["footprint"]
		var collision_rect := Rect2(body.position + collision.position - shape.size * 0.5, shape.size)
		assert_eq(collision_rect, footprint, "Collision must match declared footprint")

		var probe_points: Array[Vector2] = [
			footprint.get_center(),
			footprint.position + footprint.size * Vector2(0.25, 0.25),
			footprint.position + footprint.size * Vector2(0.75, 0.75),
		]
		for point in probe_points:
			assert_true(
				collision_rect.has_point(point),
				"Footprint probe must be blocked for %s" % String(building["id"])
			)

		body.free()


func test_world_bounds_filled_by_terrain_renderer() -> void:
	var definition: MapDefinition = SmithyCourtyardDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var renderer: MapTerrainRenderer = MapTerrainRenderer.new(grid)

	assert_eq(renderer.grid.size_cells, definition.size_cells)
	assert_eq(
		Vector2(float(grid.size_cells.x * grid.cell_size), float(grid.size_cells.y * grid.cell_size)),
		definition.world_size()
	)

	renderer.free()


func test_cell_rect_helpers_convert_consistently() -> void:
	var definition: MapDefinition = SmithyCourtyardDefinition.create()
	var cell_rect := Rect2i(31, 18, 4, 3)
	var world_rect := definition.cell_rect_to_world_rect(cell_rect)
	var center := definition.cell_rect_center(cell_rect)

	assert_eq(world_rect, Rect2(992.0, 576.0, 128.0, 96.0))
	assert_eq(center, world_rect.get_center())
	assert_eq(center, Vector2(1056.0, 624.0))


func test_well_prop_matches_water_zone_center() -> void:
	var definition: MapDefinition = SmithyCourtyardDefinition.create()
	var water_zone := Rect2i(31, 18, 4, 3)
	var expected := definition.cell_rect_center(water_zone)

	for prop in definition.props:
		if prop["id"] == &"well":
			assert_eq(prop["position"], expected, "Well prop must sit on the water zone center")
			return

	fail("Well prop missing from definition")


func test_building_y_sort_anchor_is_south_footprint_edge() -> void:
	var definition: MapDefinition = SmithyCourtyardDefinition.create()
	for building in definition.buildings:
		var footprint: Rect2 = building["footprint"]
		var body: StaticBody2D = MapBuildingRenderer.create_building(building)
		var expected := MapBuildingRenderer.footprint_y_sort_anchor(footprint)
		assert_eq(body.position, expected)
		assert_eq(body.get_meta("y_sort_anchor"), expected)
		body.free()


func test_validation_rejects_duplicate_ids() -> void:
	var definition: MapDefinition = SmithyCourtyardDefinition.create()
	definition.props.append(
		{"id": &"anvil", "kind": MapTypes.PROP_KIND_CART, "position": Vector2(100.0, 100.0)}
	)
	var errors: Array[String] = definition.validate()
	assert_false(errors.is_empty())
	assert_true(errors[0].contains("duplicate stable id"))


func test_validation_rejects_unknown_building_kind() -> void:
	var definition: MapDefinition = SmithyCourtyardDefinition.create()
	definition.buildings[0]["kind"] = &"tower"
	var errors: Array[String] = definition.validate()
	assert_false(errors.is_empty())
	assert_true(str(errors).contains("kind is unknown"))


func test_validation_rejects_unknown_prop_kind() -> void:
	var definition: MapDefinition = SmithyCourtyardDefinition.create()
	definition.props[0]["kind"] = &"statue"
	var errors: Array[String] = definition.validate()
	assert_false(errors.is_empty())
	assert_true(str(errors).contains("kind is unknown"))


func test_validation_rejects_out_of_bounds_spawn() -> void:
	var definition: MapDefinition = SmithyCourtyardDefinition.create()
	definition.player_spawn = Vector2(2000.0, 2000.0)
	var errors: Array[String] = definition.validate()
	assert_false(errors.is_empty())
	assert_true(str(errors).contains("player_spawn is outside world bounds"))


func test_validation_rejects_out_of_bounds_prop() -> void:
	var definition: MapDefinition = SmithyCourtyardDefinition.create()
	definition.props[0]["position"] = Vector2(-10.0, 50.0)
	var errors: Array[String] = definition.validate()
	assert_false(errors.is_empty())
	assert_true(str(errors).contains("position is outside world bounds"))



func test_validation_rejects_empty_zone() -> void:
	var definition: MapDefinition = SmithyCourtyardDefinition.create()
	definition.zones.append(
		{"terrain": MapTypes.TERRAIN_GRASS, "rect": Rect2i(2, 2, 0, 4)}
	)
	var errors: Array[String] = definition.validate()
	assert_false(errors.is_empty())
	assert_true(str(errors).contains("rect must have positive size"))

func test_courtyard_has_enclosing_wall_segments() -> void:
	var definition: MapDefinition = SmithyCourtyardDefinition.create()
	var wall_ids: Array[StringName] = []
	for building in definition.buildings:
		if building.get("kind", MapTypes.BUILDING_KIND_HOUSE) == MapTypes.BUILDING_KIND_WALL:
			wall_ids.append(building["id"])

	assert_eq(wall_ids.size(), 5)
	assert_array_contains(wall_ids, &"wall_west")
	assert_array_contains(wall_ids, &"wall_east")
	assert_array_contains(wall_ids, &"wall_south")
	assert_array_contains(wall_ids, &"wall_north_west")
	assert_array_contains(wall_ids, &"wall_north_east")

extends "res://tests/godot/test_case.gd"


func test_rrmap_grass_variants_compile_into_zones_and_grid() -> void:
	var parsed := MapRrmapParser.parse_file("res://tests/fixtures/maps/rrmap_courtyard_example.rrmap")
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	var definition := parsed.definition
	var grid := MapBuilder.build(definition)
	assert_eq(grid.get_style_variant(Vector2i(1, 1)), &"grass.short")
	assert_eq(grid.get_style_variant(Vector2i(17, 1)), &"grass.flowers")
	assert_true(grid.get_movement_speed_multiplier(Vector2i(18, 11)) < 1.0)


func test_bush_prop_slows_player_position_inside_footprint() -> void:
	var definition := MapDefinition.new()
	definition.map_id = &"movement_test"
	definition.location = &"loc.movement_test"
	definition.scope = &"prototype"
	definition.palette = &"clean_painted"
	definition.fingerprint = "movement_test"
	definition.size_cells = Vector2i(8, 8)
	definition.cell_size = 32
	definition.base_terrain = MapTypes.TERRAIN_GRASS
	definition.player_spawn = Vector2(48, 48)
	definition.props.append({
		"id": &"bush.test",
		"kind": MapTypes.PROP_KIND_BUSH,
		"position": Vector2(96, 96),
		"footprint": Rect2(80, 80, 64, 64),
		"movement_speed_multiplier": 0.5,
	})
	var grid := MapBuilder.build(definition)
	var inside := MapTerrainMovement.speed_multiplier_at(definition, grid, Vector2(112, 112))
	var outside := MapTerrainMovement.speed_multiplier_at(definition, grid, Vector2(16, 16))
	assert_eq(inside, 0.5)
	assert_eq(outside, 1.0)

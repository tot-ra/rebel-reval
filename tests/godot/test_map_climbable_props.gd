extends "res://tests/godot/test_case.gd"

## Climbable low props lift the derived 3D actor without changing 2D walkability.


func test_climbable_kinds_match_outdoor_cargo_silhouettes() -> void:
	assert_true(MapClimbableProps.STAND_HEIGHT_BY_KIND.has(MapTypes.PROP_KIND_CARGO_CRATES))
	assert_true(MapClimbableProps.STAND_HEIGHT_BY_KIND.has(MapTypes.PROP_KIND_BARRELS))
	assert_true(MapClimbableProps.STAND_HEIGHT_BY_KIND.has(MapTypes.PROP_KIND_CART))
	assert_true(MapClimbableProps.STAND_HEIGHT_BY_KIND.has(MapTypes.PROP_KIND_HAY_STACK))
	assert_false(MapClimbableProps.STAND_HEIGHT_BY_KIND.has(MapTypes.PROP_KIND_ANVIL))
	assert_false(MapClimbableProps.STAND_HEIGHT_BY_KIND.has(MapTypes.PROP_KIND_FURNACE))


func test_actor_rises_when_standing_on_cargo_crates() -> void:
	var definition := MapDefinition.new()
	definition.map_id = &"climbable_prop_fixture"
	definition.location = &"loc.test.climbable"
	definition.size_cells = Vector2i(8, 8)
	definition.cell_size = 32
	definition.base_terrain = MapTypes.TERRAIN_DIRT
	definition.player_spawn = Vector2(32.0, 32.0)
	definition.scope = &"prototype"
	definition.palette = &"clean_painted"
	definition.fingerprint = "climbable-prop-fixture-v1"
	definition.props = [
		{
			"id": &"dock_crates",
			"kind": MapTypes.PROP_KIND_CARGO_CRATES,
			"position": Vector2(96.0, 96.0),
			"footprint": Rect2(64.0, 64.0, 64.0, 64.0),
		},
	]
	var grid := MapBuilder.build(definition)
	var view := MapView3D.create(definition, grid)
	var actor := Node3D.new()
	view.sync_actor(actor, Vector2(32.0, 32.0))
	var ground_y := actor.position.y
	view.sync_actor(actor, Vector2(96.0, 96.0))
	assert_true(
		actor.position.y > ground_y + 0.4,
		"standing on cargo crates must lift the 3D actor above ground"
	)
	assert_eq(
		MapClimbableProps.elevation_at(definition, Vector2(96.0, 96.0)),
		0.62,
		"crate stand height must match the mesh top"
	)
	assert_eq(
		MapClimbableProps.elevation_at(definition, Vector2(32.0, 32.0)),
		0.0,
		"off-prop cells must keep zero climb elevation"
	)
	actor.free()
	view.free()


func test_wall_walk_elevation_outranks_low_props() -> void:
	var definition := MapDefinition.new()
	definition.map_id = &"climbable_wall_precedence"
	definition.location = &"loc.test.climbable_wall"
	definition.size_cells = Vector2i(16, 16)
	definition.cell_size = 32
	definition.base_terrain = MapTypes.TERRAIN_DIRT
	definition.buildings = [
		{
			"id": &"city_wall",
			"kind": MapTypes.BUILDING_KIND_WALL,
			"footprint": Rect2(320.0, 64.0, 64.0, 320.0),
			"wall_height": 192.0,
			"tower": false,
		},
	]
	definition.props = [
		{
			"id": &"gallery",
			"kind": MapTypes.PROP_KIND_STAIRS,
			"primitive": MapWallWalkAccess.PLATFORM_PRIMITIVE,
			"position": Vector2(336.0, 160.0),
			"footprint": Rect2(320.0, 128.0, 64.0, 96.0),
			"facing": Vector2.UP,
		},
		{
			"id": &"crates_on_gallery",
			"kind": MapTypes.PROP_KIND_CARGO_CRATES,
			"position": Vector2(336.0, 160.0),
			"footprint": Rect2(320.0, 128.0, 64.0, 96.0),
		},
	]
	var on_gallery := Vector2(336.0, 160.0)
	var wall_elevation := MapWallWalkAccess.elevation_at(definition, on_gallery)
	var crate_elevation := MapClimbableProps.elevation_at(definition, on_gallery)
	assert_true(wall_elevation > crate_elevation)
	assert_eq(
		maxf(wall_elevation, crate_elevation),
		wall_elevation,
		"authored wall-walk height must win over low cargo stand height"
	)

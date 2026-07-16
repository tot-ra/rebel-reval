extends "res://tests/godot/test_case.gd"

const MarketSquareDefinition := preload("res://scripts/map/definitions/prototypes/market_square_definition.gd")
const StOlafsGuildHallDefinition := preload("res://scripts/map/definitions/prototypes/st_olafs_guild_hall_definition.gd")
const MarketCivicQuarterDefinition := preload("res://scripts/map/definitions/prototypes/market_civic_quarter_definition.gd")
const NorthQuarterDefinition := preload("res://scripts/map/definitions/prototypes/north_quarter_definition.gd")
const HarborWarehouseDefinition := preload("res://scripts/map/definitions/prototypes/harbor_warehouse_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")


func test_market_prototypes_validate_and_stay_inactive() -> void:
	for factory in [
		MarketSquareDefinition,
		StOlafsGuildHallDefinition,
		MarketCivicQuarterDefinition,
		NorthQuarterDefinition,
		HarborWarehouseDefinition,
	]:
		var definition: MapDefinition = factory.create()
		assert_eq(definition.scope, &"prototype")
		assert_false(definition.active)
		assert_true(MapBuilder.validate(definition).is_empty(), factory.resource_path)


func test_market_prototype_door_lanes_have_walkable_coverage() -> void:
	var definition: MapDefinition = MarketSquareDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	for y in grid.size_cells.y:
		for x in grid.size_cells.x:
			assert_false(String(grid.get_terrain(Vector2i(x, y))).is_empty())
	assert_true(MapVerification.has_anchor(definition, &"inspection_spawn"))


func test_guild_hall_assembly_nav_and_anchors() -> void:
	var definition: MapDefinition = StOlafsGuildHallDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	assert_true(MapVerification.has_anchor(definition, &"dais"))
	assert_true(
		MapVerification.route_exists(
			definition,
			grid,
			definition.player_spawn,
			MapVerification.anchor_position(definition, &"dais")
		)
	)
	assert_true(MapVerification.collision_parity(definition))

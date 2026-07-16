extends "res://tests/godot/test_case.gd"

const NorthQuarterDefinition := preload("res://scripts/map/definitions/prototypes/north_quarter_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")


func test_north_quarter_prototype_bounds_and_spine() -> void:
	var definition: MapDefinition = NorthQuarterDefinition.create()
	assert_eq(definition.size_cells, Vector2i(64, 36))
	assert_true(MapBuilder.validate(definition).is_empty())
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	assert_true(MapVerification.has_anchor(definition, &"pikk_street_spine"))
	assert_true(
		MapVerification.route_exists(
			definition,
			grid,
			definition.player_spawn,
			MapVerification.anchor_position(definition, &"pikk_street_spine")
		)
	)

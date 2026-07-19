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
	assert_true(MapVerification.has_anchor(definition, &"guild_frontage"))
	assert_true(
		MapVerification.route_exists(
			definition,
			grid,
			definition.player_spawn,
			MapVerification.anchor_position(definition, &"pikk_street_spine")
		)
	)
	assert_true(
		MapVerification.route_exists(
			definition,
			grid,
			definition.player_spawn,
			MapVerification.anchor_position(definition, &"guild_frontage")
		)
	)


func test_north_quarter_connects_to_lower_town_and_center() -> void:
	var definition: MapDefinition = NorthQuarterDefinition.create()
	var transition_by_id: Dictionary = {}
	for transition in definition.transitions:
		transition_by_id[transition["id"]] = transition
	assert_true(transition_by_id.has(&"to_reval_east"))
	var to_east: Dictionary = transition_by_id[&"to_reval_east"]
	assert_eq(to_east["destination_scene_id"], &"reval_east")
	assert_eq(to_east["destination_spawn_id"], &"vene_district_boundary")
	assert_eq(to_east["spawn_id"], &"from_reval_east")
	assert_true(transition_by_id.has(&"to_reval_center"))
	var to_center: Dictionary = transition_by_id[&"to_reval_center"]
	assert_eq(to_center["destination_scene_id"], &"reval_center")
	assert_eq(to_center["destination_spawn_id"], &"to_reval_north")

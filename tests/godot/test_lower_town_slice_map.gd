extends "res://tests/godot/test_case.gd"

const LowerTownSliceDefinition := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")


func test_lower_town_slice_validates() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	assert_eq(definition.size_cells, Vector2i(64, 36))
	var errors: Array[String] = MapBuilder.validate(definition)
	assert_true(errors.is_empty(), str(errors))


func test_lower_town_required_route_endpoints_reachable() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var start := MapVerification.anchor_position(definition, &"street_start")
	var checks: Array[StringName] = [
		&"smithy_door",
		&"brewery_door",
		&"checkpoint_west",
		&"checkpoint_east",
	]
	for anchor_id in checks:
		assert_true(
			MapVerification.route_exists(definition, grid, start, MapVerification.anchor_position(definition, anchor_id)),
			"Missing route to %s" % String(anchor_id)
		)

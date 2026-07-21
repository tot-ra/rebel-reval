extends "res://tests/godot/test_case.gd"

const NorthQuarterDefinition := preload("res://scripts/map/definitions/prototypes/north_quarter_definition.gd")


func test_harbor_arrival_uses_the_inner_merchant_district_spawn() -> void:
	## Regression: the old 96 px offset left arrivals at the map edge, so the
	## fixed camera looked north across empty surroundings instead of into town.
	var definition: MapDefinition = NorthQuarterDefinition.create()
	var grid := MapBuilder.build(definition)
	var to_harbor := _transition(definition, &"to_reval_harbor")
	var arrival := (to_harbor["rect"] as Rect2).get_center() + (to_harbor["spawn_offset"] as Vector2)
	var inner_spawn := MapVerification.anchor_position(definition, &"from_reval_harbor")

	assert_eq(arrival, inner_spawn, "harbor arrivals must use the authored inner Coastal Gate spawn")
	assert_true(MapVerification.is_walkable_point(definition, grid, arrival))
	assert_true(
		MapVerification.route_exists_exact(
			definition,
			grid,
			arrival,
			MapVerification.anchor_position(definition, &"pikk_street_spine")
		),
		"harbor arrivals must be able to continue into the Merchant District"
	)


func _transition(definition: MapDefinition, transition_id: StringName) -> Dictionary:
	for transition in definition.transitions:
		if transition["id"] == transition_id:
			return transition
	fail("missing transition %s on %s" % [String(transition_id), String(definition.map_id)])
	return {}

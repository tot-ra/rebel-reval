extends "res://tests/godot/test_case.gd"

## Regression: district-edge green triggers must not contain their own spawn
## markers, or reciprocal maps loop on arrival.


func _definition_loaders() -> Array[Callable]:
	return [
		preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd").create,
		preload("res://scripts/map/definitions/outdoor/viru_gate_foreland_definition.gd").create,
		preload("res://scripts/map/definitions/outdoor/reval_harbor_north_definition.gd").create,
		preload("res://scripts/map/definitions/outdoor/reval_harbor_east_definition.gd").create,
		preload("res://scripts/map/definitions/prototypes/north_quarter_definition.gd").create,
		preload("res://scripts/map/definitions/prototypes/monastery_quarter_definition.gd").create,
		preload("res://scripts/map/definitions/prototypes/market_civic_quarter_definition.gd").create,
		preload("res://scripts/map/definitions/prototypes/south_quarter_definition.gd").create,
		preload("res://scripts/map/definitions/prototypes/toompea_quarter_definition.gd").create,
		preload("res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd").create,
		preload("res://scripts/map/definitions/prototypes/st_olafs_guild_hall_definition.gd").create,
	]


func test_active_transition_spawns_clear_their_triggers() -> void:
	for loader in _definition_loaders():
		var definition: MapDefinition = loader.call()
		for transition in definition.transitions:
			if String(transition.get("destination_scene_id", "")).is_empty():
				continue
			if not transition.has("spawn_id"):
				continue
			assert_true(
				MapVerification.spawn_clears_transition_trigger(transition),
				"%s/%s spawn_offset %s must clear trigger %s (player capsule half %s)"
				% [
					String(definition.map_id),
					String(transition.get("id", &"")),
					str(transition.get("spawn_offset", Vector2.ZERO)),
					str(transition.get("rect", Rect2())),
					str(MapVerification.PLAYER_COLLISION_HALF),
				]
			)


func test_viru_foreland_pair_uses_inward_offsets() -> void:
	var east: MapDefinition = preload(
		"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
	).create()
	var foreland: MapDefinition = preload(
		"res://scripts/map/definitions/outdoor/viru_gate_foreland_definition.gd"
	).create()
	var viru := _transition(east, &"viru_road_boundary")
	var to_east := _transition(foreland, &"to_reval_east")
	assert_true(viru.has("spawn_offset"), "viru_road_boundary must declare spawn_offset")
	assert_true(to_east.has("spawn_offset"), "foreland to_reval_east must declare spawn_offset")
	assert_true((viru["spawn_offset"] as Vector2).x < 0.0, "arrival from foreland must land west of the Viru trigger")
	assert_true((to_east["spawn_offset"] as Vector2).x > 0.0, "arrival from town must land east of the foreland trigger")
	assert_true(MapVerification.spawn_clears_transition_trigger(viru))
	assert_true(MapVerification.spawn_clears_transition_trigger(to_east))


func test_center_monastery_pair_uses_inward_offsets() -> void:
	var center: MapDefinition = preload(
		"res://scripts/map/definitions/prototypes/market_civic_quarter_definition.gd"
	).create()
	var monastery: MapDefinition = preload(
		"res://scripts/map/definitions/prototypes/monastery_quarter_definition.gd"
	).create()
	var to_north := _transition(center, &"to_reval_north")
	var to_center := _transition(monastery, &"to_reval_center")
	assert_true(to_north.has("spawn_offset"), "center to_reval_north must declare spawn_offset")
	assert_true(to_center.has("spawn_offset"), "monastery to_reval_center must declare spawn_offset")
	assert_true((to_north["spawn_offset"] as Vector2).y > 0.0, "arrival from monastery must land south of the center north-edge trigger")
	assert_true((to_center["spawn_offset"] as Vector2).y < 0.0, "arrival from center must land north of the monastery south-edge trigger")
	assert_true(absf((to_center["spawn_offset"] as Vector2).y) >= 128.0)
	assert_true(MapVerification.spawn_clears_transition_trigger(to_north))
	assert_true(MapVerification.spawn_clears_transition_trigger(to_center))


func test_center_monastery_pair_lands_on_walkable_street_cells() -> void:
	## Regression: to_reval_north sat east of Holy Spirit so spawn_offset (0,96)
	## landed inside holy_spirit_hospital and Pikk never reached the door.
	var center: MapDefinition = preload(
		"res://scripts/map/definitions/prototypes/market_civic_quarter_definition.gd"
	).create()
	var monastery: MapDefinition = preload(
		"res://scripts/map/definitions/prototypes/monastery_quarter_definition.gd"
	).create()
	var center_grid := MapBuilder.build(center)
	var monastery_grid := MapBuilder.build(monastery)
	var to_north := _transition(center, &"to_reval_north")
	var to_center := _transition(monastery, &"to_reval_center")
	var center_arrival := (to_north["rect"] as Rect2).get_center() + (to_north["spawn_offset"] as Vector2)
	var monastery_arrival := (to_center["rect"] as Rect2).get_center() + (to_center["spawn_offset"] as Vector2)
	assert_true(
		MapVerification.is_walkable_point(center, center_grid, center_arrival),
		"monastery->center arrival %s must be walkable (not inside Holy Spirit)" % center_arrival
	)
	assert_true(
		MapVerification.is_walkable_point(monastery, monastery_grid, monastery_arrival),
		"center->monastery arrival %s must be walkable" % monastery_arrival
	)
	assert_true(
		MapVerification.route_exists_exact(
			center, center_grid, MapVerification.anchor_position(center, &"pikk_street_spine"), (to_north["rect"] as Rect2).get_center()
		),
		"Pikk spine must reach the Monastery District door"
	)
	assert_true(
		MapVerification.route_exists_exact(
			monastery, monastery_grid, MapVerification.anchor_position(monastery, &"pikk_street_spine"), (to_center["rect"] as Rect2).get_center()
		),
		"Monastery Pikk spine must reach the Central District door"
	)


func test_global_mockup_transition_spawns_are_clear_and_reachable() -> void:
	for scene_id in GlobalMapCatalog.distant_scene_ids():
		var definition := DistantLocationDefinitions.create(scene_id)
		assert_true(definition != null, "%s needs a playable mockup definition" % scene_id)
		var grid := MapBuilder.build(definition)
		for transition in definition.transitions:
			assert_true(MapVerification.spawn_clears_transition_trigger(transition))
			var arrival: Vector2 = transition["rect"].get_center() + transition.get("spawn_offset", Vector2.ZERO)
			assert_true(
				MapVerification.route_exists(definition, grid, definition.player_spawn, arrival),
				"%s must route from its inspection spawn to %s" % [scene_id, transition["id"]]
			)


func _transition(definition: MapDefinition, transition_id: StringName) -> Dictionary:
	for transition in definition.transitions:
		if transition["id"] == transition_id:
			return transition
	fail("missing transition %s on %s" % [String(transition_id), String(definition.map_id)])
	return {}

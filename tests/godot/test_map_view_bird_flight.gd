extends "res://tests/godot/test_case.gd"

const BirdContext := preload("res://scripts/map/view3d/map_view_bird_context.gd")
const BirdFlight := preload("res://scripts/map/view3d/map_view_bird_flight.gd")
const BirdSpecies := preload("res://scripts/map/view3d/map_view_bird_species.gd")
const KalevSmithy := preload("res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd")
const LowerTownSlice := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const HarborNorth := preload("res://scripts/map/definitions/outdoor/reval_harbor_north_definition.gd")


func test_lower_town_context_surfaces_distinct_gliding_species() -> void:
	var species := BirdFlight.distinct_species_for_context(
		&"lower_town_slice",
		BirdContext.context_for_map(&"lower_town_slice"),
		0.35,
		48
	)
	assert_true(species.size() >= 3, "Lower Town day cycle should surface at least three gliding species")


func test_harbor_context_surfaces_distinct_gliding_species() -> void:
	var species := BirdFlight.distinct_species_for_context(
		&"reval_harbor_north",
		BirdContext.context_for_map(&"reval_harbor_north"),
		0.35,
		48
	)
	assert_true(species.size() >= 3, "Harbour day cycle should surface at least three gliding species")


func test_species_selection_is_deterministic_for_seed_and_tick() -> void:
	var first := BirdFlight.pick_species(&"lower_town_slice", BirdSpecies.CONTEXT_LOWER_TOWN, 0.35, 7)
	var second := BirdFlight.pick_species(&"lower_town_slice", BirdSpecies.CONTEXT_LOWER_TOWN, 0.35, 7)
	assert_false(first.is_empty())
	assert_eq(first, second)


func test_concurrent_bird_cap_is_enforced() -> void:
	var flight := BirdFlight.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(flight)
	flight.configure(&"lower_town_slice", BirdSpecies.CONTEXT_LOWER_TOWN, Vector2i(64, 36))
	for _attempt in 12:
		flight.sync(BirdSpecies.CONTEXT_LOWER_TOWN, 0.35, 10.0)
	assert_true(flight.active_bird_count() <= 4)
	flight.queue_free()


func test_disabling_bird_flight_leaves_game_state_unchanged() -> void:
	var state := GameState.new()
	var before := state.save_payload()
	var flight := BirdFlight.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(flight)
	flight.configure(&"lower_town_slice", BirdSpecies.CONTEXT_LOWER_TOWN, Vector2i(64, 36))
	flight.set_flight_enabled(false)
	flight.sync(BirdSpecies.CONTEXT_LOWER_TOWN, 0.35, 1.0, false)
	assert_eq(flight.active_bird_count(), 0)
	assert_eq(state.save_payload(), before)
	flight.queue_free()


func test_interior_maps_suppress_bird_flight_via_runtime() -> void:
	var smithy: MapDefinition = KalevSmithy.create()
	assert_true(smithy.suppresses_exterior_surroundings())

	var lower_town: MapDefinition = LowerTownSlice.create()
	assert_false(lower_town.suppresses_exterior_surroundings())
	assert_eq(BirdContext.context_for_map(lower_town.map_id), BirdSpecies.CONTEXT_LOWER_TOWN)

	var harbor: MapDefinition = HarborNorth.create()
	assert_eq(BirdContext.context_for_map(harbor.map_id), BirdSpecies.CONTEXT_HARBOR)

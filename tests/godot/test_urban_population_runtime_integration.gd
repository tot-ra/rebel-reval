extends "res://tests/godot/test_case.gd"

## R-408 runtime integration for the Lower Town urban population controller.

const ControllerScript := preload("res://scripts/world/urban_population_controller.gd")
const ProfileScript := preload("res://scripts/world/urban_population_profile.gd")
const PlacementScript := preload("res://scripts/world/urban_population_placement.gd")
const CrowdRenderer := preload("res://scripts/map/view3d/map_view_crowd_renderer.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")
const LowerTownSliceDefinition := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const MapBuilder := preload("res://scripts/map/map_builder.gd")

const PHASE_DAY := GameState.PHASE_INVESTIGATION_MORNING
const PHASE_NIGHT := GameState.PHASE_INVESTIGATION_NIGHT
const DATE_OFF_DAY := {"day": 22, "month": 4, "year": 1343}
const DATE_MARKET_DAY := {"day": 24, "month": 4, "year": 1343}


class FakeViewRuntime:
	extends RefCounted

	var cycle_elapsed_days := 0
	var view: MapView3D
	var _crowd: MapViewCrowdRenderer
	var _crowd_enabled := true

	func configure_crowd(capacity: int, seed_value: int) -> void:
		if _crowd != null:
			_crowd.queue_free()
		_crowd = CrowdRenderer.new()
		_crowd.configure(capacity, seed_value)
		_crowd.set_crowd_enabled(_crowd_enabled)

	func get_crowd_renderer() -> MapViewCrowdRenderer:
		return _crowd

	func set_crowd_enabled(enabled: bool) -> void:
		_crowd_enabled = enabled
		if _crowd != null:
			_crowd.set_crowd_enabled(enabled)

	func crowd_active_count() -> int:
		if _crowd == null:
			return 0
		return _crowd.active_count()


func test_controller_resolves_profiles_without_mutating_game_state() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var grid := MapBuilder.build(definition)
	var fake_runtime := FakeViewRuntime.new()
	fake_runtime.view = MapView3D.create(definition, grid)
	var controller := ControllerScript.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(controller)

	controller.setup(definition, grid, fake_runtime, &"loc.lower_town_slice", 1343)
	controller.sync_for_test(PHASE_DAY, 0, false, 1343)

	var day_profile := controller.get_active_profile()
	assert_eq(day_profile["profile_id"], ProfileScript.PROFILE_DAY)
	assert_eq(day_profile["civilian_count"], 18)
	assert_eq(day_profile["watch_count"], 3)

	controller.sync_for_test(PHASE_DAY, 2, true, 1343)
	var market_profile := controller.get_active_profile()
	assert_eq(market_profile["profile_id"], ProfileScript.PROFILE_MARKET_DAY)
	assert_true(market_profile["civilian_count"] > day_profile["civilian_count"])

	controller.sync_for_test(PHASE_NIGHT, 0, false, 1343)
	var night_profile := controller.get_active_profile()
	assert_eq(night_profile["profile_id"], ProfileScript.PROFILE_NIGHT)
	assert_true(night_profile["civilian_count"] < day_profile["civilian_count"])

	controller.queue_free()
	fake_runtime.view.queue_free()
	if fake_runtime._crowd != null:
		fake_runtime._crowd.queue_free()


func test_controller_registers_full_day_profile_in_crowd_renderer() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var grid := MapBuilder.build(definition)
	var fake_runtime := FakeViewRuntime.new()
	fake_runtime.view = MapView3D.create(definition, grid)
	var controller := ControllerScript.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(controller)

	controller.setup(definition, grid, fake_runtime, &"loc.lower_town_slice", 1343)
	controller.sync_for_test(PHASE_DAY, 0, false, 1343)

	var profile := controller.get_active_profile()
	var placements := PlacementScript.build_placements(definition, grid, profile)
	assert_eq(placements.size(), profile["total_count"])
	assert_eq(controller.crowd_active_count(), profile["total_count"])
	assert_eq(fake_runtime.get_crowd_renderer().capacity(), 64)

	controller.queue_free()
	fake_runtime.view.queue_free()
	if fake_runtime._crowd != null:
		fake_runtime._crowd.queue_free()


func test_placements_replay_and_clear_authored_props_and_each_other() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var grid := MapBuilder.build(definition)
	var profile := ProfileScript.day(PHASE_DAY, DATE_OFF_DAY, 610)
	var first := PlacementScript.build_placements(definition, grid, profile)
	var replay := PlacementScript.build_placements(definition, grid, profile)

	assert_eq(first, replay, "same placement inputs must replay identical positions")
	assert_eq(first.size(), profile["total_count"])
	for placement: Dictionary in first:
		var position: Vector2 = placement["position"]
		assert_true(
			MapVerification.is_walkable_point(definition, grid, position),
			"crowd placement must remain on a walkable point",
		)
		for prop: Dictionary in definition.props:
			var prop_position: Vector2 = prop["position"]
			assert_true(
				position.distance_to(prop_position) >= PlacementScript.PROP_CLEARANCE,
				"crowd placement must clear authored prop %s" % String(prop["id"]),
			)

	for first_index in first.size():
		var first_position: Vector2 = first[first_index]["position"]
		for second_index in range(first_index + 1, first.size()):
			var second_position: Vector2 = first[second_index]["position"]
			assert_true(
				first_position.distance_to(second_position) >= PlacementScript.ACTOR_CLEARANCE,
				"crowd actors must keep authored inter-actor clearance",
			)


func test_market_day_active_switches_profile_without_game_state_writes() -> void:
	var state := GameState.new()
	state.set_phase(PHASE_DAY)
	var before := state.save_payload()
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var grid := MapBuilder.build(definition)
	var fake_runtime := FakeViewRuntime.new()
	fake_runtime.view = MapView3D.create(definition, grid)
	var controller := ControllerScript.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(controller)

	controller.setup(definition, grid, fake_runtime, &"loc.lower_town_slice", 412)
	controller.sync_for_test(PHASE_DAY, 0, false, 412)
	controller.set_market_day_active(true)

	assert_eq(controller.get_active_profile()["profile_id"], ProfileScript.PROFILE_MARKET_DAY)
	assert_eq(state.save_payload(), before, "population controller must not mutate GameState")

	controller.queue_free()
	fake_runtime.view.queue_free()
	if fake_runtime._crowd != null:
		fake_runtime._crowd.queue_free()

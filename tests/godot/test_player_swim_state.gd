extends "res://tests/godot/test_case.gd"

## ADR 0021: medium thresholds, dive/breath rules and combat lock of PlayerSwimState.

const M_WALK := PlayerSwimState.Medium.WALK
const M_WADE := PlayerSwimState.Medium.WADE
const M_SWIM := PlayerSwimState.Medium.SWIM
const M_DIVE := PlayerSwimState.Medium.DIVE


func test_classify_walks_wades_and_swims_by_depth() -> void:
	assert_eq(PlayerSwimState.classify(0.0, M_WALK), M_WALK)
	var just_dry := PlayerSwimState.WADE_MIN_DEPTH - 0.01
	assert_eq(PlayerSwimState.classify(just_dry, M_WALK), M_WALK)
	assert_eq(PlayerSwimState.classify(0.5, M_WALK), M_WADE)
	var chest_deep := PlayerSwimState.SWIM_ENTER_DEPTH
	assert_eq(PlayerSwimState.classify(chest_deep, M_WADE), M_SWIM)


func test_swim_exit_threshold_is_lower_than_entry() -> void:
	# Between the two thresholds the previous medium holds, so a wave cannot flicker it.
	var between := (PlayerSwimState.SWIM_ENTER_DEPTH + PlayerSwimState.SWIM_EXIT_DEPTH) * 0.5
	assert_eq(PlayerSwimState.classify(between, M_WADE), M_WADE)
	assert_eq(PlayerSwimState.classify(between, M_SWIM), M_SWIM)
	var below_exit := PlayerSwimState.SWIM_EXIT_DEPTH - 0.01
	assert_eq(PlayerSwimState.classify(below_exit, M_SWIM), M_WADE)


func test_shallow_column_never_reaches_swim() -> void:
	# Basin depth of shallow_water tops out at 1.0, below SWIM_ENTER_DEPTH: wading only.
	var state := PlayerSwimState.new()
	state.update(MapViewMeshBuilderConfig.SEA_BASIN_DEPTH[MapTypes.TERRAIN_SHALLOW_WATER], true, 1.0)
	assert_eq(state.medium, M_WADE)


func test_wading_slows_more_the_deeper_it_gets() -> void:
	var ankle := PlayerSwimState.WADE_MIN_DEPTH
	var chest := PlayerSwimState.SWIM_ENTER_DEPTH
	var shallow := PlayerSwimState.speed_fraction(M_WADE, ankle)
	var deep := PlayerSwimState.speed_fraction(M_WADE, chest)
	assert_true(shallow > deep, "deeper water drags more")
	var swim := PlayerSwimState.speed_fraction(M_SWIM, 3.0)
	assert_true(deep > swim, "swimming is slower than wading")
	assert_eq(PlayerSwimState.speed_fraction(M_WALK, 0.0), 1.0)


func test_dive_needs_a_deep_column_and_holds_the_input() -> void:
	var state := PlayerSwimState.new()
	state.update(3.6, false, 0.1)
	assert_eq(state.medium, M_SWIM)
	for i in 60:
		state.update(3.6, true, 0.05)
	assert_eq(state.medium, M_DIVE)
	var deepest := PlayerSwimState.max_submersion(3.6) + 0.001
	assert_true(state.submersion <= deepest, "keeps clear of the bed")
	for i in 80:
		state.update(3.6, false, 0.05)
	assert_eq(state.medium, M_SWIM, "releasing the input surfaces")
	assert_eq(state.submersion, 0.0)
	var shallow_swimmer := PlayerSwimState.new()
	shallow_swimmer.update(PlayerSwimState.SWIM_ENTER_DEPTH + 0.01, true, 1.0)
	assert_eq(shallow_swimmer.medium, M_SWIM, "too shallow to dive under")


func test_breath_drains_only_with_the_head_under_and_refills_at_the_surface() -> void:
	var state := PlayerSwimState.new()
	for i in 20:
		state.update(3.6, false, 0.5)
	assert_eq(state.breath_sec, PlayerSwimState.BREATH_MAX_SEC, "floating never drains")
	for i in 100:
		state.update(3.6, true, 0.05)
	assert_true(state.breath_sec < PlayerSwimState.BREATH_MAX_SEC, "diving drains")
	for i in 100:
		state.update(3.6, false, 0.05)
	assert_eq(state.breath_sec, PlayerSwimState.BREATH_MAX_SEC, "breath is back after surfacing")


func test_running_out_of_breath_forces_the_surface_once_and_locks_the_dive() -> void:
	var state := PlayerSwimState.new()
	var events := 0
	for i in int(PlayerSwimState.BREATH_MAX_SEC / 0.1) + 200:
		state.update(3.6, true, 0.1)
		if state.out_of_breath_event:
			events += 1
	assert_eq(events, 1, "the penalty fires exactly once per forced surfacing")
	assert_true(state.dive_locked, "still locked while the input stays held")
	assert_true(state.medium != M_DIVE, "never dives on empty lungs")
	state.update(3.6, false, 0.1)
	for i in 30:
		state.update(3.6, false, 0.1)
	assert_false(state.dive_locked, "released and recovered")


func test_dive_unlocks_once_breath_recovers() -> void:
	var state := PlayerSwimState.new()
	state.dive_locked = true
	state.breath_sec = 0.0
	state.update(3.6, true, 1.0)
	assert_true(state.dive_locked, "still held: stays locked")
	state.update(3.6, false, 1.0)
	assert_true(state.breath_fraction() >= PlayerSwimState.BREATH_RELOCK_FRACTION)
	assert_false(state.dive_locked)


func test_combat_is_blocked_only_while_swimming() -> void:
	var state := PlayerSwimState.new()
	state.update(0.5, false, 0.1)
	assert_false(state.blocks_combat(), "wading may still fight")
	state.update(3.6, false, 0.1)
	assert_true(state.blocks_combat())


func test_leaving_the_water_resets_submersion() -> void:
	var state := PlayerSwimState.new()
	for i in 40:
		state.update(3.6, true, 0.05)
	state.update(0.0, true, 0.05)
	assert_eq(state.medium, M_WALK)
	assert_eq(state.submersion, 0.0)

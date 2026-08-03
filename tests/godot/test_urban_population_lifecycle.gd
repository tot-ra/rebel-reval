extends "res://tests/godot/test_case.gd"

## Focused R-414 lifecycle coverage for urban population profiles.
## Keep this separate from the general save suite: only profile/placement outputs
## and the state fields explicitly involved in the lifecycle are compared.

const ProfileScript := preload("res://scripts/world/urban_population_profile.gd")
const CrowdRenderer := preload("res://scripts/map/view3d/map_view_crowd_renderer.gd")

const PHASE_DAY := GameState.PHASE_INVESTIGATION_MORNING
const PHASE_NIGHT := GameState.PHASE_INVESTIGATION_NIGHT
const DATE_OFF_DAY := {"day": 22, "month": 4, "year": 1343}
const REPLAY_SEED := 1343

var _test_root := ""


func before_each() -> void:
	_test_root = "user://test_saves/urban_population_lifecycle_%d" % Time.get_ticks_usec()


func after_each() -> void:
	_remove_tree(_test_root)


func test_night_and_crackdown_reduce_civilians_reposition_them_and_raise_watch() -> void:
	var day := ProfileScript.day(PHASE_DAY, DATE_OFF_DAY, REPLAY_SEED)
	var night := ProfileScript.night(PHASE_NIGHT, DATE_OFF_DAY, REPLAY_SEED)
	var crackdown := ProfileScript.crackdown(PHASE_DAY, DATE_OFF_DAY, REPLAY_SEED)

	assert_true(int(night["civilian_count"]) < int(day["civilian_count"]))
	assert_true(int(crackdown["civilian_count"]) < int(day["civilian_count"]))
	assert_true(int(night["watch_count"]) > int(day["watch_count"]))
	assert_true(int(crackdown["watch_count"]) > int(day["watch_count"]))
	assert_ne(
		_civilian_zone_sequence(day),
		_civilian_zone_sequence(night),
		"night civilians must use a different authored placement sequence"
	)
	assert_ne(
		_civilian_zone_sequence(day),
		_civilian_zone_sequence(crackdown),
		"crackdown civilians must use a different authored placement sequence"
	)
	assert_array_contains(night["zone_ids"], ProfileScript.ZONE_SAFE_INTERIOR)
	assert_array_contains(crackdown["zone_ids"], ProfileScript.ZONE_CHECKPOINT)


func test_disabling_population_renderer_leaves_game_state_unchanged() -> void:
	var state := GameState.new()
	state.set_phase(PHASE_NIGHT)
	state.player.location_id = &"lower_town_slice"
	state.set_flag(&"flag.population_lifecycle_probe", true)
	var before := state.save_payload()

	var renderer := CrowdRenderer.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(renderer)
	renderer.configure(16, REPLAY_SEED)
	renderer.set_crowd_enabled(false)

	assert_false(renderer.is_crowd_enabled())
	assert_false(renderer.visible)
	assert_eq(state.save_payload(), before, "renderer disable must not mutate GameState")
	renderer.queue_free()


func test_clean_save_replay_rederives_identical_profile_and_placements() -> void:
	var state := GameState.new()
	state.set_phase(PHASE_NIGHT)
	state.player.location_id = &"lower_town_slice"
	var service := SaveService.new()
	service.save_directory = _test_root

	var before_save := ProfileScript.resolve(ProfileScript.PROFILE_NIGHT, state.get_phase(), DATE_OFF_DAY, REPLAY_SEED)
	assert_true(service.save_game(state), "clean lifecycle save must succeed")

	var loaded := service.load_game()
	assert_true(loaded["ok"], ", ".join(loaded["errors"]))
	var restored := loaded["state"] as GameState
	assert_eq(restored.get_phase(), PHASE_NIGHT, "save replay must preserve the profile phase")
	var after_load := ProfileScript.resolve(ProfileScript.PROFILE_NIGHT, restored.get_phase(), DATE_OFF_DAY, REPLAY_SEED)

	assert_eq(
		_profile_placement_snapshot(after_load),
		_profile_placement_snapshot(before_save),
		"same phase/date/seed after clean save must reproduce placements"
	)


func test_replay_inputs_and_actor_plan_are_stable_after_same_phase_date_and_seed() -> void:
	var first := ProfileScript.resolve(PHASE_DAY, PHASE_DAY, DATE_OFF_DAY, REPLAY_SEED)
	var second := ProfileScript.resolve(PHASE_DAY, PHASE_DAY, DATE_OFF_DAY, REPLAY_SEED)

	assert_eq(first["replay_inputs"], second["replay_inputs"])
	assert_eq(first["actor_plan"], second["actor_plan"])
	assert_eq(first["zone_ids"], second["zone_ids"])
	assert_eq(first["civilian_count"], second["civilian_count"])
	assert_eq(first["watch_count"], second["watch_count"])


func _civilian_zone_sequence(profile: Dictionary) -> Array[StringName]:
	var zones: Array[StringName] = []
	for actor: Dictionary in profile["actor_plan"]:
		if actor["role"] == &"civilian":
			zones.append(actor["zone_id"])
	return zones


func _profile_placement_snapshot(profile: Dictionary) -> Dictionary:
	return {
		"profile_id": profile["profile_id"],
		"phase_id": profile["phase_id"],
		"date": profile["date"],
		"seed": profile["seed"],
		"civilian_count": profile["civilian_count"],
		"watch_count": profile["watch_count"],
		"total_count": profile["total_count"],
		"zone_ids": profile["zone_ids"],
		"movement_mode": profile["movement_mode"],
		"anchor_mode": profile["anchor_mode"],
		"actor_plan": profile["actor_plan"],
	}


func _remove_tree(path: String) -> void:
	if path.is_empty():
		return
	var dir := DirAccess.open(path)
	if dir == null:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := path.path_join(entry)
			if dir.current_is_dir():
				_remove_tree(child)
			else:
				DirAccess.remove_absolute(child)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)

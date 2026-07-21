extends "res://tests/godot/test_case.gd"

const VALID_DIR := "res://content/examples/valid"
const SUPPORT_DIR := "res://content/examples/support"
const DIALOGUE_RUNNER_SCRIPT := preload("res://scripts/dialogue/dialogue_runner.gd")
const MUSIC_DIRECTOR_SCRIPT := preload("res://scripts/global/music_director.gd")
const PhaseProfileModelScript := preload("res://scripts/phase/phase_profile_model.gd")
const MapPhaseBinderScript := preload("res://scripts/phase/map_phase_binder.gd")
const MapPatrolControllerScript := preload("res://scripts/phase/map_patrol_controller.gd")

const BARK_INVESTIGATION := &"bark.investigation.morning_watch"
const BARK_PROLOGUE := &"bark.prologue.watch_pressure"
const LOC_LOWER_TOWN := &"loc.lower_town_slice"
const LOC_SMITHY := &"loc.kalev_smithy"


var db: ContentDB
var state: GameState
var _hook_visible := true


func before_each() -> void:
	db = ContentDB.new()
	assert_true(db.load_from_directories([VALID_DIR, SUPPORT_DIR]))
	state = GameState.new()
	_hook_visible = true


func test_slice_profiles_cover_every_game_state_phase() -> void:
	for phase_id in GameState.SLICE_PHASES:
		var profile := PhaseProfileModelScript.resolve_profile(phase_id, db)
		assert_false(profile.is_empty(), "missing profile for %s" % String(phase_id))
		assert_eq(StringName(String(profile.get("phase_id", ""))), phase_id)


func test_ordered_profiles_match_slice_sequence() -> void:
	var profiles := PhaseProfileModelScript.ordered_profiles(db)
	assert_eq(profiles.size(), GameState.SLICE_PHASES.size())
	for index in GameState.SLICE_PHASES.size():
		assert_eq(
			StringName(String(profiles[index].get("phase_id", ""))),
			GameState.SLICE_PHASES[index]
		)


func test_next_phase_advances_slice_order() -> void:
	assert_eq(
		PhaseProfileModelScript.next_phase_id(GameState.PHASE_PROLOGUE_DAY, db),
		GameState.PHASE_INVESTIGATION_MORNING
	)
	assert_eq(
		PhaseProfileModelScript.next_phase_id(GameState.PHASE_REFLECTION_MORNING, db),
		&""
	)


func test_investigation_bark_requires_matching_phase() -> void:
	var runner := DIALOGUE_RUNNER_SCRIPT.new()
	runner.configure(db, state, null)
	var investigation := runner.resolve_bark(
		BARK_INVESTIGATION,
		GameState.PHASE_INVESTIGATION_MORNING,
		LOC_LOWER_TOWN
	)
	assert_false(investigation.is_empty())
	assert_true(String(investigation.get("text", "")).contains("brewery"))

	var wrong_phase := runner.resolve_bark(
		BARK_INVESTIGATION,
		GameState.PHASE_PROLOGUE_DAY,
		LOC_LOWER_TOWN
	)
	assert_true(wrong_phase.is_empty())

	var prologue := runner.resolve_bark(BARK_PROLOGUE, GameState.PHASE_PROLOGUE_DAY, LOC_SMITHY)
	assert_false(prologue.is_empty())


func test_profile_presentation_drives_music_night_selection() -> void:
	var night_profile := PhaseProfileModelScript.resolve_profile(GameState.PHASE_INVESTIGATION_NIGHT, db)
	var presentation := PhaseProfileModelScript.presentation(night_profile)
	var progress := float(presentation.get("cycle_progress", 0.25))
	if bool(presentation.get("music_night_tracks", false)):
		progress = 0.0
	assert_true(MUSIC_DIRECTOR_SCRIPT.is_night_period(progress))


func test_day_profiles_enable_the_shared_sun_cycle() -> void:
	# Workers' District binds phase presentation; frozen day profiles made the
	# sun sit still while harbor (no binder) kept moving.
	for phase_id in [
		GameState.PHASE_PROLOGUE_DAY,
		GameState.PHASE_INVESTIGATION_MORNING,
		GameState.PHASE_REFLECTION_MORNING,
	]:
		var presentation := PhaseProfileModelScript.presentation(
			PhaseProfileModelScript.resolve_profile(phase_id, db)
		)
		assert_true(
			bool(presentation.get("cycle_enabled", false)),
			"%s must keep the outdoor sun moving" % String(phase_id)
		)


func test_night_profiles_freeze_the_sun_cycle() -> void:
	for phase_id in [
		GameState.PHASE_INVESTIGATION_NIGHT,
		GameState.PHASE_CONSEQUENCE_NIGHT,
	]:
		var presentation := PhaseProfileModelScript.presentation(
			PhaseProfileModelScript.resolve_profile(phase_id, db)
		)
		assert_false(
			bool(presentation.get("cycle_enabled", true)),
			"%s must freeze night lighting for investigation pacing" % String(phase_id)
		)


func test_map_phase_binder_continues_live_cycle_when_enabled() -> void:
	MusicDirector.set_cycle_progress(0.61)
	var definition := MapDefinition.new()
	var scene_root := Node2D.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene_root)

	var runtime := MapViewRuntime.new()
	runtime.name = "MapViewRuntime"
	scene_root.add_child(runtime)

	var binder := MapPhaseBinderScript.new()
	scene_root.add_child(binder)
	binder.setup(LOC_LOWER_TOWN, definition, runtime, false)
	var morning := PhaseProfileModelScript.resolve_profile(GameState.PHASE_INVESTIGATION_MORNING, db)
	binder.apply_authored_profile(morning)

	assert_true(runtime.cycle_enabled, "day profiles must leave the runtime cycle running")
	assert_true(
		is_equal_approx(runtime.cycle_progress, 0.61),
		"binder must keep the shared MusicDirector clock instead of rewinding"
	)
	scene_root.free()
	MusicDirector.clear_cycle_progress()


func test_map_phase_binder_freezes_night_to_authored_progress() -> void:
	MusicDirector.set_cycle_progress(0.61)
	var definition := MapDefinition.new()
	var scene_root := Node2D.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene_root)

	var runtime := MapViewRuntime.new()
	runtime.name = "MapViewRuntime"
	scene_root.add_child(runtime)

	var binder := MapPhaseBinderScript.new()
	scene_root.add_child(binder)
	binder.setup(LOC_LOWER_TOWN, definition, runtime, false)
	var night := PhaseProfileModelScript.resolve_profile(GameState.PHASE_INVESTIGATION_NIGHT, db)
	binder.apply_authored_profile(night)

	assert_false(runtime.cycle_enabled, "night profiles must freeze the outdoor cycle")
	assert_true(
		is_equal_approx(runtime.cycle_progress, 0.02),
		"frozen night must snap to the authored phase progress"
	)
	scene_root.free()
	MusicDirector.clear_cycle_progress()


func test_location_rules_toggle_patrols_npcs_and_props() -> void:
	var morning := PhaseProfileModelScript.resolve_profile(GameState.PHASE_INVESTIGATION_MORNING, db)
	var town_rules := PhaseProfileModelScript.location_rules(morning, LOC_LOWER_TOWN)
	var patrols: Array = town_rules.get("patrols", [])
	assert_eq(patrols.size(), 1)
	assert_true(bool((patrols[0] as Dictionary).get("enabled", false)))

	var smithy_rules := PhaseProfileModelScript.location_rules(morning, LOC_SMITHY)
	var props: Array = smithy_rules.get("props", [])
	assert_eq(props.size(), 1)
	assert_false(bool((props[0] as Dictionary).get("visible", true)))


func test_map_phase_binder_updates_npc_and_patrol_hooks() -> void:
	var definition := _stub_lower_town_definition()
	var scene_root := Node2D.new()
	var mart := DemoMartNpc.new()
	scene_root.add_child(mart)
	mart.global_position = Vector2(9999, 9999)

	var patrol := MapPatrolControllerScript.new()
	scene_root.add_child(patrol)
	patrol.setup(definition, &"viru_watch", scene_root)

	var binder := MapPhaseBinderScript.new()
	scene_root.add_child(binder)
	binder.setup(LOC_LOWER_TOWN, definition, null, false)
	binder.register_npc(&"mart", mart, &"mart_street")
	binder.register_patrol(&"viru_watch", patrol)

	var morning_profile := PhaseProfileModelScript.resolve_profile(GameState.PHASE_INVESTIGATION_MORNING, db)
	binder.apply_authored_profile(morning_profile)

	assert_true(patrol.is_enabled())
	assert_true(mart.visible)
	assert_eq(mart.global_position, Vector2(100, 200))

	var prologue_profile := PhaseProfileModelScript.resolve_profile(GameState.PHASE_PROLOGUE_DAY, db)
	binder.apply_authored_profile(prologue_profile)
	assert_false(patrol.is_enabled())


func test_map_phase_binder_invokes_prop_visibility_hook() -> void:
	var definition := MapDefinition.new()
	var binder := MapPhaseBinderScript.new()
	var scene_root := Node2D.new()
	scene_root.add_child(binder)
	binder.setup(LOC_SMITHY, definition, null, false)
	var visible_state := true
	binder.register_prop(
		&"spearhead_anvil",
		func(next_visible: bool) -> void:
			visible_state = next_visible
			_hook_visible = next_visible
	)
	var investigation := PhaseProfileModelScript.resolve_profile(GameState.PHASE_INVESTIGATION_MORNING, db)
	binder.apply_authored_profile(investigation)
	assert_false(_hook_visible)


func _stub_lower_town_definition() -> MapDefinition:
	var definition := MapDefinition.new()
	definition.interaction_anchors.append({
		"id": &"mart_street",
		"position": Vector2(100, 200),
	})
	definition.patrols.append({
		"id": &"viru_watch",
		"points": [Vector2(10, 10), Vector2(20, 20)],
	})
	return definition

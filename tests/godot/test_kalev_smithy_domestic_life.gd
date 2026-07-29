extends "res://tests/godot/test_case.gd"

const ControllerScript := preload("res://scripts/world/smithy_routine_controller.gd")
const ReservationsScript := preload("res://scenes/reval_east/forge/smithy_station_reservations.gd")
const PresenterScript := preload("res://scenes/reval_east/forge/smithy_domestic_life_presenter.gd")
const HenningScript := preload("res://scenes/reval_east/forge/smithy_henning.gd")
const KALEV_RIG := preload("res://assets/characters/kalev/kalev.tscn")

const ROUTINE_PATH := "res://content/routines/kalev_smithy.json"
const KALEV := &"char.kalev"
const MART := &"char.mart"
const SOAK_SECONDS := 1200


func _controller(reservations: SmithyStationReservations = null) -> SmithyRoutineController:
	var controller := ControllerScript.new()
	controller.configure_from_file(ROUTINE_PATH)
	controller.set_station_reservations(reservations)
	return controller


func test_semantic_station_reservation_prevents_cross_activity_collision() -> void:
	var reservations := ReservationsScript.new()
	var kalev := _controller(reservations)
	var mart := _controller(reservations)
	var context := {
		"phase_id": GameState.PHASE_INVESTIGATION_MORNING,
		"time_band": &"midday",
		"seed": 1343,
		"mart_missing": false,
	}
	assert_true(kalev.begin_activity(KALEV, &"ap.hearth.tend", context))
	assert_false(mart.begin_activity(MART, &"ap.hearth.cookpot", context))
	assert_eq(reservations.reservation_count(), 1)
	assert_eq(reservations.telemetry()["prevented_contention_count"], 1)
	assert_eq(reservations.invariant_errors(), [])
	kalev.end_activity(KALEV)
	assert_eq(reservations.reservation_count(), 0)
	kalev.free()
	mart.free()
	reservations.free()


func test_active_action_snapshot_round_trips_through_map_world_state() -> void:
	var source := GameState.new()
	var presenter_snapshot := {
		"activity_id": "ap.hearth.cookpot",
		"held_prop": "cooking_ladle",
		"animation_time_sec": 2.25,
		"duration_sec": 7.0,
	}
	assert_true(source.map_world_state.record_object_delta(
		&"loc.kalev_smithy",
		&"runtime.smithy_domestic_vignette",
		{
			"snapshot_version": 1,
			"active": true,
			"activity_id": "ap.hearth.cookpot",
			"remaining_sec": 4.75,
			"presenter": presenter_snapshot,
		}
	))
	var restored := GameState.new()
	assert_eq(restored.load_map_world_state(source.save_map_world_state()), [])
	var snapshot := restored.map_world_state.object_delta(
		&"loc.kalev_smithy",
		&"runtime.smithy_domestic_vignette"
	)
	assert_true(snapshot["active"])
	assert_eq(snapshot["activity_id"], "ap.hearth.cookpot")
	assert_eq(snapshot["remaining_sec"], 4.75)
	assert_eq((snapshot["presenter"] as Dictionary)["held_prop"], "cooking_ladle")


func test_presenter_restores_equipment_and_bounds_held_props_effects_and_audio() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var rig := KALEV_RIG.instantiate() as SharedCharacterRig
	tree.root.add_child(rig)
	var original_root := Node3D.new()
	original_root.name = "OriginalTool"
	var original_scene := PackedScene.new()
	assert_eq(original_scene.pack(original_root), OK)
	original_root.free()
	rig.equip(&"right_hand", original_scene)
	var presenter := PresenterScript.new()
	tree.root.add_child(presenter)
	presenter.configure(rig, GameState.new(), ContentDB.new())
	var held_by_activity: Dictionary = {
		&"ap.wash.basin": &"wash_cloth",
		&"ap.fetch.water": &"water_bucket",
		&"ap.prepare.board": &"prep_knife",
		&"ap.hearth.cookpot": &"cooking_ladle",
		&"ap.sweep.floor": &"broom",
		&"ap.carry.fuel": &"kindling_bundle",
		&"ap.forge.bellows": &"bellows_handle",
	}
	for key: Variant in PresenterScript.ACTIVITY_PROFILES.keys():
		var activity_id := StringName(String(key))
		var held := StringName(String(held_by_activity.get(activity_id, "")))
		assert_true(presenter.begin_activity(activity_id, held, 4.0))
		presenter.tick(0.25)
		assert_true(presenter.active_held_prop_count() <= 1)
		assert_true(presenter.active_effect_root_count() <= 1)
		assert_true(presenter.active_audio_voice_count() <= 2)
		assert_eq(presenter.invariant_errors(), [])
		presenter.clear_activity(true)
	assert_true(presenter.telemetry()["held_prop_peak"] <= 1)
	assert_true(presenter.telemetry()["effect_root_peak"] <= 1)
	assert_true(presenter.telemetry()["audio_voice_peak"] <= 2)
	await tree.process_frame
	var restored_tool := rig.equipped(&"right_hand")
	assert_true(restored_tool != null)
	if restored_tool != null:
		assert_eq(restored_tool.name, "OriginalTool")
	presenter.queue_free()
	rig.queue_free()
	await tree.process_frame


func test_henning_active_visit_snapshot_restores_action_and_pose_state() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var original := HenningScript.new() as SmithyHenning
	tree.root.add_child(original)
	original.begin_prologue_visit()
	original._routine_controller.end_activity(original.stable_id)
	assert_true(original._routine_controller.begin_activity(
		original.stable_id,
		&"ap.visitor.inspect",
		original._visit_context()
	))
	original._current_activity = &"ap.visitor.inspect"
	original._activity_mode = SmithyHenning.ActivityMode.ACTING
	original._activity_seconds = 1.75
	original.global_position = Vector2(184.0, 216.0)
	var snapshot := original.runtime_snapshot()
	var restored := HenningScript.new() as SmithyHenning
	tree.root.add_child(restored)
	assert_true(restored.restore_runtime_snapshot(snapshot))
	assert_true(restored.is_visit_active())
	assert_eq(restored._current_activity, &"ap.visitor.inspect")
	assert_eq(restored._activity_seconds, 1.75)
	assert_eq(restored.global_position, Vector2(184.0, 216.0))
	original.free()
	restored.free()


func test_accelerated_twenty_minute_soak_is_deterministic_and_clean() -> void:
	var first := _run_soak()
	var second := _run_soak()
	assert_eq(first, second)
	assert_eq(first["invariant_errors"], [])
	assert_eq(first["active_reservations"], 0)
	assert_true(first["reservation_count"] > 0)
	assert_true(first["prevented_contention_count"] > 0)
	assert_true(first["max_simultaneous_reservations"] <= 1)
	assert_eq(first["simulated_seconds"], SOAK_SECONDS)
	assert_eq(first["visited_phases"], GameState.SLICE_PHASES.size())


func _run_soak() -> Dictionary:
	var reservations := ReservationsScript.new()
	var controller := _controller(reservations)
	var state := GameState.new()
	var active := &""
	var remaining := 0.0
	var visited := {}
	var completed := 0
	var phase_span := maxi(SOAK_SECONDS / GameState.SLICE_PHASES.size(), 1)
	for second in SOAK_SECONDS:
		var phase_index := mini(second / phase_span, GameState.SLICE_PHASES.size() - 1)
		state.phase = GameState.SLICE_PHASES[phase_index]
		visited[state.phase] = true
		var bands: Array[StringName] = [&"dawn", &"morning", &"midday", &"evening"]
		var band := bands[(second / 17) % bands.size()]
		var context := controller.build_kalev_context(state, band)
		if active.is_empty():
			var available := controller.list_available_activities(KALEV, context)
			if not available.is_empty():
				active = available[second % available.size()]
				if controller.begin_activity(KALEV, active, context):
					var point := controller.get_activity_point(active)
					remaining = point.sample_duration_sec(1343 + second)
					reservations.try_reserve(MART, &"contender.%s" % String(active), point)
				else:
					active = &""
		else:
			remaining -= 1.0
			if remaining <= 0.0:
				controller.end_activity(KALEV)
				active = &""
				completed += 1
	if not active.is_empty():
		controller.end_activity(KALEV)
	var result := reservations.telemetry()
	result["simulated_seconds"] = SOAK_SECONDS
	result["visited_phases"] = visited.size()
	result["completed_activities"] = completed
	controller.free()
	reservations.free()
	return result

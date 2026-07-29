extends "res://tests/godot/test_case.gd"

const FORGE_SCENE := preload("res://scenes/reval_east/forge/forge.tscn")


func test_henning_is_a_logic_actor_mirrored_by_the_smithy_3d_view() -> void:
	var forge := FORGE_SCENE.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(forge)

	var henning := forge.get_node("Actors/Henning") as SmithyHenning
	var runtime := forge.get_node("MapViewRuntime") as MapViewRuntime
	var rig := runtime.get_node("HenningRig") as SharedCharacterRig
	assert_true(henning != null, "the smithy must contain Henning's collision and navigation actor")
	assert_true(rig != null, "the 3D view must mirror Henning through his generated rig")
	if henning != null and rig != null:
		assert_eq(henning.stable_id, &"char.henning")
		assert_eq(rig.variant_id(), &"char.henning")
		henning.begin_prologue_visit()
		await tree.process_frame
		var animation := rig.current_canonical_animation()
		assert_true(
			animation == &"walk" or animation == &"idle",
			"Henning should walk in or hold at the door approach"
		)
		var expected := MapViewBridge.logic_to_world(henning.global_position, MapTypes.DEFAULT_CELL_SIZE)
		assert_true(
			Vector2(rig.position.x, rig.position.z).is_equal_approx(Vector2(expected.x, expected.z)),
			"Henning's visible rig must be driven by the 2D gameplay position"
		)

	forge.queue_free()


func test_henning_routine_exposes_social_and_seated_animation_states() -> void:
	var henning := SmithyHenning.new()
	_mount_henning(henning)
	henning.begin_prologue_visit()
	var expected := {
		SmithyHenning.ActivityMode.WALKING: &"walk",
		SmithyHenning.ActivityMode.ACTING: &"idle",
		SmithyHenning.ActivityMode.SITTING_DOWN: &"sit_down",
		SmithyHenning.ActivityMode.SITTING: &"sit_idle",
		SmithyHenning.ActivityMode.STANDING_UP: &"sit_up",
	}
	for mode in expected:
		henning._activity_mode = mode
		assert_eq(henning.view_animation(), expected[mode])
	henning._current_activity = &"ap.visitor.inspect"
	henning._activity_mode = SmithyHenning.ActivityMode.ACTING
	assert_eq(henning.view_animation(), &"talk_gesture")
	henning.free()


func test_henning_sitting_origin_tracks_the_authored_work_chair() -> void:
	var definition: MapDefinition = preload(
		"res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd"
	).create()
	var chair_position := MapVerification.prop_position(definition, &"work_chair")
	var henning := SmithyHenning.new()
	_mount_henning(henning)
	henning.configure_navigation(RID(), chair_position)
	henning.begin_prologue_visit()

	var controller := henning.get_node("HenningRoutineController") as SmithyRoutineController
	var context := {
		"phase_id": GameState.PHASE_PROLOGUE_DAY,
		"time_band": &"any",
		"seed": 1343,
		"visitor_allowed": true,
	}
	while controller.active_activity_for(&"char.henning") != &"ap.visitor.talk":
		var active := controller.active_activity_for(&"char.henning")
		if active.is_empty():
			break
		controller.end_activity(&"char.henning", SmithyRoutineController.REASON_COMPLETED)
		var next := controller.pick_next_activity(&"char.henning", context)
		if next.is_empty():
			break
		controller.begin_activity(&"char.henning", next, context)
		henning._current_activity = next
		henning._begin_current_activity(false)

	var point := controller.get_activity_point(&"ap.visitor.talk")
	var expected_origin := chair_position + SmithyHenning.CHAIR_ROOT_OFFSET
	henning._current_activity = &"ap.visitor.talk"
	henning._begin_current_activity(false)
	assert_eq(henning._target_position, expected_origin)

	henning.global_position = Vector2.ZERO
	henning._arrive_at_activity(point)
	assert_eq(henning.global_position, expected_origin)
	assert_eq(henning.view_facing(), SmithyHenning.CHAIR_FACING)
	assert_eq(henning.view_animation(), &"sit_down")
	henning.free()


func test_henning_visitor_sequence_completes_without_resident_loop() -> void:
	var henning := SmithyHenning.new()
	_mount_henning(henning)
	henning.configure_navigation(RID(), Vector2(320, 320))
	henning.begin_prologue_visit()
	assert_true(henning.is_visit_active())
	assert_false(henning.is_visit_complete())

	var controller := henning.get_node("HenningRoutineController") as SmithyRoutineController
	var context := {
		"phase_id": GameState.PHASE_PROLOGUE_DAY,
		"time_band": &"any",
		"seed": 1343,
		"visitor_allowed": true,
	}
	var steps: Array[StringName] = []
	for _i in 6:
		var active := controller.active_activity_for(&"char.henning")
		if active.is_empty():
			var next := controller.pick_next_activity(&"char.henning", context)
			if next.is_empty():
				break
			controller.begin_activity(&"char.henning", next, context)
			active = next
		steps.append(active)
		controller.end_activity(&"char.henning", SmithyRoutineController.REASON_COMPLETED)
		if active == &"ap.visitor.leave":
			henning._complete_visit()
			break

	assert_eq(
		steps,
		[
			&"ap.visitor.enter",
			&"ap.visitor.wait",
			&"ap.visitor.inspect",
			&"ap.visitor.talk",
			&"ap.visitor.leave",
		]
	)
	assert_true(henning.is_visit_complete())
	assert_false(henning.is_visit_active())
	assert_false(henning.visible)
	henning.free()


func test_henning_stays_hidden_outside_active_visit() -> void:
	var henning := SmithyHenning.new()
	_mount_henning(henning)
	henning.set_phase_visibility(true)
	assert_false(henning.visible)
	henning.begin_prologue_visit()
	assert_true(henning.visible)
	henning._complete_visit()
	assert_false(henning.visible)
	henning.free()


func _mount_henning(henning: SmithyHenning) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(henning)

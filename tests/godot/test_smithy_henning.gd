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
		assert_eq(rig.current_canonical_animation(), &"walk")
		var expected := MapViewBridge.logic_to_world(henning.global_position, MapTypes.DEFAULT_CELL_SIZE)
		assert_true(
			Vector2(rig.position.x, rig.position.z).is_equal_approx(Vector2(expected.x, expected.z)),
			"Henning's visible rig must be driven by the 2D gameplay position"
		)

	forge.queue_free()


func test_henning_routine_exposes_social_and_seated_animation_states() -> void:
	var henning := SmithyHenning.new()
	var expected := {
		SmithyHenning.RoutineState.WALKING: &"walk",
		SmithyHenning.RoutineState.IDLE: &"idle",
		SmithyHenning.RoutineState.GESTURING: &"talk_gesture",
		SmithyHenning.RoutineState.SITTING_DOWN: &"sit_down",
		SmithyHenning.RoutineState.SITTING: &"sit_idle",
		SmithyHenning.RoutineState.STANDING_UP: &"sit_up",
	}
	for state in expected:
		henning._set_state(state, 1.0)
		assert_eq(henning.view_animation(), expected[state])
	henning.free()


func test_henning_sitting_origin_tracks_the_authored_work_chair() -> void:
	var definition: MapDefinition = preload(
		"res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd"
	).create()
	var chair_position := MapVerification.prop_position(definition, &"work_chair")
	var henning := SmithyHenning.new()
	henning.configure_navigation(RID(), chair_position)

	var seat_route_index := henning._route.size() - 1
	var expected_origin := chair_position + SmithyHenning.CHAIR_ROOT_OFFSET
	assert_eq(henning._route[seat_route_index], expected_origin)

	# Arrival must remove NavigationAgent2D tolerance and face Henning away from
	# the backrest before the animation moves his hips backward onto the seat.
	henning.global_position = Vector2.ZERO
	henning._route_index = seat_route_index
	henning._arrive()
	assert_eq(henning.global_position, expected_origin)
	assert_eq(henning.view_facing(), SmithyHenning.CHAIR_FACING)
	assert_eq(henning.view_animation(), &"sit_down")
	henning.free()

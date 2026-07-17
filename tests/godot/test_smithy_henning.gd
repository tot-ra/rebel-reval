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

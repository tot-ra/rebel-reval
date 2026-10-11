extends "res://tests/godot/map_view_3d_test_base.gd"

## R-1161 end to end: the real game path (left click routed by
## MapClickInputController, roll and cast on the Player, presented by
## MapViewRuntime on the 3D PlayerRig) must visibly move Kalev's bones. The
## unit tests in test_combat_animation.gd drive the rig directly; this file
## guards the wiring between them (docs/SYSTEMS/COMBAT_ANIMATION.md).
##
## WHY real engine frames instead of calling _physics_process/_sync_player in a
## loop: the rig's AnimationPlayer advances its cross-fades on the idle frame.
## Without frames the idle -> attack blend never progresses and the bones stay
## in the idle pose, so a manual loop cannot tell a working swing from a frozen one.


func test_left_click_roll_and_cast_animate_the_3d_player_rig() -> void:
	_ensure_content_loaded()
	_equip(&"item.forge_hammer")
	var tree := Engine.get_main_loop() as SceneTree
	var scene_root := Node2D.new()
	var map_root := Node2D.new()
	var actors := Node2D.new()
	var player := PLAYER_SCENE.instantiate() as Player
	scene_root.add_child(map_root)
	scene_root.add_child(actors)
	actors.add_child(player)
	tree.root.add_child(scene_root)
	var definition := KalevSmithyDefinition.create()
	var bootstrap := {
		"definition": definition,
		"grid": MapBuilder.build(definition),
		"assembled": {"buildings": [], "props": []},
	}
	var runtime := MapViewRuntime.install(scene_root, bootstrap, map_root, player)
	var clicks := MapClickInputController.new()
	scene_root.add_child(clicks)
	clicks.setup(player, runtime)
	var rig := runtime.get_node("PlayerRig") as SharedCharacterRig
	var skeleton := rig.skeleton()
	var hand := skeleton.find_bone("hand.r")
	var hips := skeleton.find_bone("hips")
	player.stamina = 100.0
	await _wait(tree, 0.3)

	# (a) Default third-person left click: press + release commits a light strike.
	assert_true(clicks.is_character_relative_mode(), "the game starts in third person")
	assert_true(clicks.try_handle_click(_left_button(true)), "left click must start an attack")
	assert_true(clicks.try_handle_primary_release(_left_button(false)))
	assert_eq(player.action_state_machine.state, PlayerActionState.State.ATTACK)
	var swing := await _sample(tree, rig, hand, hips, &"hammer_attack", 0.7)
	assert_true(
		float(swing["travel"]) > 0.15,
		"the 3D hammer hand must swing in the real runtime (moved %.3f m)" % float(swing["travel"])
	)
	await _wait(tree, 1.0)

	# (b) Space + left: a roll that tumbles the 3D body and moves Kalev left.
	var before := player.global_position
	player.stamina = 100.0
	assert_true(player.try_start_roll(Vector2.LEFT))
	var roll := await _sample(tree, rig, hand, hips, CombatMoveCatalog.ROLL_FORWARD, 0.62)
	assert_true(
		float(roll["min_up_dot"]) < -0.5,
		"the 3D body must go head over heels (min up dot %.2f)" % float(roll["min_up_dot"])
	)
	assert_true(player.global_position.x < before.x - 60.0, "a left roll travels left")
	await _wait(tree, 0.6)

	# (c) A successful spell cast plays its gesture on the 3D rig.
	assert_true(player.begin_cast_gesture("projectile"))
	var cast := await _sample(tree, rig, hand, hips, CombatMoveCatalog.CAST_PROJECTILE, 0.5)
	assert_true(
		float(cast["travel"]) > 0.1,
		"the cast gesture must move the hand (moved %.3f m)" % float(cast["travel"])
	)
	_free_map_scene(scene_root)


## Samples the rendered pose on every idle frame while `animation` is the rig's
## current clip: max hand travel from the first sample and the lowest dot
## between the hips' up axis and its first sample (a full tumble goes below 0).
func _sample(
	tree: SceneTree,
	rig: SharedCharacterRig,
	hand: int,
	hips: int,
	animation: StringName,
	seconds: float
) -> Dictionary:
	var skeleton := rig.skeleton()
	var first_hand := Vector3.INF
	var first_up := Vector3.ZERO
	var travel := 0.0
	var min_up_dot := 1.0
	var end_msec := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end_msec:
		await tree.process_frame
		if rig.current_canonical_animation() != animation:
			continue
		var hand_origin := skeleton.get_bone_global_pose(hand).origin
		var up := skeleton.get_bone_global_pose(hips).basis.y.normalized()
		if first_hand == Vector3.INF:
			first_hand = hand_origin
			first_up = up
		travel = maxf(travel, first_hand.distance_to(hand_origin))
		min_up_dot = minf(min_up_dot, up.dot(first_up))
	assert_true(first_hand != Vector3.INF, "the 3D rig never played %s" % animation)
	return {"travel": travel, "min_up_dot": min_up_dot}


func _wait(tree: SceneTree, seconds: float) -> void:
	var end_msec := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end_msec:
		await tree.process_frame


func _left_button(pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = Vector2(400.0, 300.0)
	return event


func _equip(item_id: StringName) -> void:
	if SessionState.state.equipped_item(&"right_hand") == item_id:
		return
	if not SessionState.state.equipped_item(&"right_hand").is_empty():
		assert_true(SessionState.state.unequip_to_bag(&"right_hand"))
	if SessionState.state.bag.find_placement(item_id) == null:
		assert_eq(SessionState.state.bag.try_add(item_id), InventoryBag.AddResult.OK)
	assert_true(SessionState.state.equip_from_bag(&"right_hand", item_id))


func _ensure_content_loaded() -> void:
	if not SessionState.content_db.is_loaded():
		assert_true(SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	SessionState.state.bag.set_content_db(SessionState.content_db)

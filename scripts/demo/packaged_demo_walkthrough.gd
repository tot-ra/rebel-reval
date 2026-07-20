class_name PackagedDemoWalkthrough
extends Node

## Opt-in D-004c smoke path that runs from the real exported main scene.
## Pass `-- --verify-packaged-demo` to a release binary. Keeping the switch in
## Godot's user-argument segment avoids release-template path overrides.

const USER_ARGUMENT := "--verify-packaged-demo"
const START_MARKER := "D-004C_PACKAGED_WALKTHROUGH_START"
const PASS_MARKER := "D-004C_PACKAGED_WALKTHROUGH_PASS"
const FAIL_MARKER := "D-004C_PACKAGED_WALKTHROUGH_FAIL"
const SCENE_WAIT_FRAMES := 600
const SETTLE_FRAMES := 12
const MAX_RUNTIME_SECONDS := 90.0

const LOC_SMITHY := &"loc.kalev_smithy"
const OBJ_SPEAR := &"world.spearhead_anvil"
const ITEM_SPEARHEAD := &"item.seized_spearhead"
const FLAG_DEMO_MART_SPOKEN := &"flag.demo_mart_spoken"

var _finished := false


func _ready() -> void:
	if not is_requested(OS.get_cmdline_user_args()):
		queue_free()
		return
	call_deferred("_activate")


func _activate() -> void:
	# WHY: DoorNavigator replaces current_scene. Reparenting keeps the verifier
	# alive while the real menu, forge, and Lower Town scenes replace each other.
	# Do this deferred because Godot forbids reparenting while the menu is adding
	# this child and executing its first _ready notification.
	var tree := get_tree()
	if get_parent() != tree.root:
		reparent(tree.root)
	print(START_MARKER)
	tree.create_timer(MAX_RUNTIME_SECONDS).timeout.connect(_on_timeout)
	call_deferred("_run")


static func is_requested(user_args: PackedStringArray) -> bool:
	return user_args.has(USER_ARGUMENT)


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame

	if SessionState.state.has_item(ITEM_SPEARHEAD):
		_fail("new packaged session already owns the anvil spearhead")
		return
	if SessionState.state.get_flag(FLAG_DEMO_MART_SPOKEN):
		_fail("new packaged session already has the Mart completion flag")
		return

	var menu := tree.current_scene
	if menu == null or menu.scene_file_path != "res://scenes/menu/main_menu.tscn":
		_fail("release app did not start on the authored main menu")
		return
	var start_label := menu.get_node_or_null("Start label") as Control
	if start_label == null:
		_fail("main menu Start control is missing")
		return

	# Exercise the same GUI signal and handler used by a player's mouse click.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	start_label.gui_input.emit(click)

	var forge: Node = await _wait_for_scene(&"forge")
	if forge == null:
		_fail("Start did not reach forge/smithy_start")
		return
	var player := forge.get_node_or_null("Actors/Player") as Player
	if player == null:
		_fail("forge player is missing")
		return
	if not await _prove_player_movement(player):
		_fail("ui_right input did not move the player in the forge")
		return

	DoorNavigator.go_to_scene(&"reval_east", &"forge")
	var east: Node = await _wait_for_scene(&"reval_east")
	if east == null:
		_fail("forge transition did not reach Lower Town")
		return
	if not await _complete_mart_dialogue(east):
		_fail("Mart interaction did not complete or set its state flag")
		return

	DoorNavigator.go_to_scene(&"forge", &"door_courtyard")
	forge = await _wait_for_scene(&"forge")
	if forge == null:
		_fail("Lower Town transition did not return to the forge")
		return
	if not await _pickup_spearhead(forge):
		_fail("anvil spearhead interaction did not place the item in the bag")
		return

	_finished = true
	print("%s steps=start,move,mart,pickup" % PASS_MARKER)
	tree.quit(0)


func _prove_player_movement(player: Player) -> bool:
	var start_position := player.global_position
	Input.action_press("ui_right")
	for _frame in 20:
		await get_tree().physics_frame
	Input.action_release("ui_right")
	await get_tree().physics_frame
	return player.global_position.distance_to(start_position) > 1.0


func _complete_mart_dialogue(east: Node) -> bool:
	var encounter := east.get_node_or_null("DemoMartEncounter") as DemoMartEncounter
	var player := east.get_node_or_null("Actors/Player") as Player
	if encounter == null or player == null:
		return false
	var talk := encounter.get_interactable()
	var runner := encounter.get_dialogue_runner()
	if talk == null or runner == null:
		return false

	player.global_position = talk.global_position
	talk.register_actor_in_range(player)
	if not talk.interact(player) or not runner.is_active():
		return false

	var advances := 0
	while runner.is_active() and advances < 16:
		runner.advance_for_test()
		advances += 1
		await get_tree().process_frame
	return not runner.is_active() and bool(SessionState.state.get_flag(FLAG_DEMO_MART_SPOKEN))


func _pickup_spearhead(forge: Node) -> bool:
	var player := forge.get_node_or_null("Actors/Player") as Player
	var pickup := _find_pickup(forge)
	if player == null or pickup == null:
		return false
	player.global_position = pickup.global_position
	pickup.register_actor_in_range(player)
	if not pickup.interact(player):
		return false
	for _frame in 4:
		await get_tree().process_frame
	return (
		SessionState.state.has_item(ITEM_SPEARHEAD)
		and not SessionState.state.is_world_item_placed(LOC_SMITHY, OBJ_SPEAR)
		and SessionState.state.bag.find_placement(ITEM_SPEARHEAD) != null
	)


func _wait_for_scene(scene_id: StringName) -> Node:
	var expected_path := DoorNavigator.get_scene_path(scene_id)
	if expected_path.is_empty():
		return null
	for _frame in SCENE_WAIT_FRAMES:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path == expected_path:
			for _settle_frame in SETTLE_FRAMES:
				await get_tree().process_frame
			return scene
	return null


func _find_pickup(forge: Node) -> Interactable:
	for node in forge.find_children("*", "Area2D", true, false):
		var interactable := node as Interactable
		if interactable != null and interactable.get_interaction_kind() == InteractionKinds.PICKUP:
			return interactable
	return null


func _on_timeout() -> void:
	if not _finished:
		_fail("walkthrough exceeded %.0f seconds" % MAX_RUNTIME_SECONDS)


func _fail(reason: String) -> void:
	if _finished:
		return
	_finished = true
	Input.action_release("ui_right")
	printerr("%s reason=%s" % [FAIL_MARKER, reason])
	get_tree().quit(1)

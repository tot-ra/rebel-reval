extends "res://tests/godot/test_case.gd"

## D-004: headless proof that the packaged demo loop (move, talk to Mart,
## pick up the anvil spearhead) completes without debug presets.

const FORGE_SCENE := preload("res://scenes/reval_east/forge/forge.tscn")
const EAST_SCENE := preload("res://scenes/reval_east/reval_east.tscn")

const LOC_SMITHY := &"loc.kalev_smithy"
const OBJ_SPEAR := &"world.spearhead_anvil"
const ITEM_SPEARHEAD := &"item.seized_spearhead"
const ITEM_HAMMER := &"item.forge_hammer"
const FLAG_DEMO_MART_SPOKEN := &"flag.demo_mart_spoken"
const DIALOGUE_ID := &"dialogue.demo.mart_street"


func test_demo_move_talk_pickup_without_debug_presets() -> void:
	_reset_demo_session()
	assert_false(SessionState.state.has_item(ITEM_SPEARHEAD))
	assert_false(SessionState.state.get_flag(FLAG_DEMO_MART_SPOKEN))
	assert_false(SessionState.state.are_world_defaults_seeded(LOC_SMITHY))

	var tree := Engine.get_main_loop() as SceneTree
	var forge: Node2D = FORGE_SCENE.instantiate()
	tree.root.add_child(forge)
	await _settle_frames(2)

	var player := forge.get_node("Actors/Player") as Player
	assert_true(player != null, "Start spawn must place Kalev in the forge")
	var start_position := player.global_position
	player.global_position = start_position + Vector2(48.0, 0.0)
	assert_true(
		player.global_position.distance_to(start_position) > 1.0,
		"player must be able to move from smithy_start"
	)

	var spear_before := _find_pickup_interactable(forge)
	assert_true(spear_before != null, "anvil spearhead must exist before leaving the forge")
	_free_scene(forge)

	var east: Node2D = EAST_SCENE.instantiate()
	tree.root.add_child(east)
	await _settle_frames(2)
	assert_true(_complete_mart_dialogue(east), "Mart talk must finish without debug presets")
	assert_true(SessionState.state.get_flag(FLAG_DEMO_MART_SPOKEN))
	_free_scene(east)

	forge = FORGE_SCENE.instantiate()
	tree.root.add_child(forge)
	await _settle_frames(2)
	assert_true(_find_pickup_interactable(forge) != null, "spearhead must still be on the anvil after the street visit")
	_pickup_spearhead(forge)
	assert_true(SessionState.state.has_item(ITEM_SPEARHEAD))
	assert_false(SessionState.state.is_world_item_placed(LOC_SMITHY, OBJ_SPEAR))
	assert_true(SessionState.state.bag.find_placement(ITEM_SPEARHEAD) != null)
	assert_true(SessionState.state.get_flag(FLAG_DEMO_MART_SPOKEN), "Mart flag must survive forge re-entry")
	_free_scene(forge)

	forge = FORGE_SCENE.instantiate()
	tree.root.add_child(forge)
	await _settle_frames(2)
	assert_eq(_find_pickup_interactable(forge), null, "picked spearhead must stay gone after smithy re-entry")
	_free_scene(forge)


func test_demo_content_and_start_spawn_are_release_ready() -> void:
	assert_true(DoorNavigator.has_active_scene(&"forge"), "release Start target forge must be registered")
	assert_true(DoorNavigator.has_spawn(&"forge", &"smithy_start"))
	assert_true(DoorNavigator.has_active_scene(&"reval_east"))
	assert_true(DoorNavigator.has_spawn(&"reval_east", &"forge"))

	var db := ContentDB.new()
	assert_true(db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	var dialogue := db.get_dialogue(DIALOGUE_ID)
	assert_false(dialogue.is_empty(), "demo Mart dialogue must ship in release content dirs")
	assert_false(db.get_item(ITEM_SPEARHEAD).is_empty(), "spearhead item record must ship")
	assert_false(db.get_item(ITEM_HAMMER).is_empty(), "forge hammer item record must ship")


func _reset_demo_session() -> void:
	SessionState.state = GameState.new()
	SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS)
	SessionState.state.bag.set_content_db(SessionState.content_db)
	SessionState.state.bag.try_add(ITEM_HAMMER)
	SessionState.state.equip_from_bag(&"right_hand", ITEM_HAMMER)


func _complete_mart_dialogue(east: Node) -> bool:
	var encounter := east.get_node_or_null("DemoMartEncounter") as DemoMartEncounter
	if encounter == null:
		fail("Lower Town must wire DemoMartEncounter")
		return false
	var interactable := encounter.get_interactable()
	var runner := encounter.get_dialogue_runner()
	var player := east.get_node("Actors/Player") as Player
	assert_true(interactable != null and runner != null and player != null)
	player.global_position = interactable.global_position
	interactable.register_actor_in_range(player)
	assert_true(interactable.interact(player), "Talk to Mart must succeed")
	var guard := 0
	while runner.is_active() and guard < 16:
		runner.advance_for_test()
		guard += 1
	assert_false(runner.is_active(), "Mart dialogue must complete")
	return SessionState.state.get_flag(FLAG_DEMO_MART_SPOKEN)


func _pickup_spearhead(forge: Node2D) -> void:
	var player := forge.get_node("Actors/Player") as Player
	var interactable := _find_pickup_interactable(forge)
	assert_true(interactable != null, "forge needs a pickup interactable")
	player.global_position = interactable.global_position
	interactable.register_actor_in_range(player)
	assert_true(interactable.interact(player), "pickup interact should succeed")


func _find_pickup_interactable(forge: Node) -> Interactable:
	for node in forge.find_children("*", "Area2D", true, false):
		var interactable := node as Interactable
		if interactable != null and interactable.get_interaction_kind() == InteractionKinds.PICKUP:
			return interactable
	return null


func _settle_frames(count: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for _i in count:
		await tree.process_frame


func _free_scene(scene: Node) -> void:
	if scene == null or not is_instance_valid(scene):
		return
	MapView3D._strip_geometry_materials(scene)
	scene.free()

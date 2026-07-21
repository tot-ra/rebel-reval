extends "res://tests/godot/test_case.gd"

## P1-035 acceptance coverage for the two production SessionState replacement
## entry points. These tests keep live scene consumers mounted so stale references
## cannot hide behind GameState payload-only round trips.

const FORGE_SCENE := preload("res://scenes/reval_east/forge/forge.tscn")
const LOC_SMITHY := &"loc.kalev_smithy"
const OBJ_SPEAR := &"world.spearhead_anvil"
const ITEM_HAMMER := &"item.forge_hammer"
const ITEM_SPEARHEAD := &"item.seized_spearhead"
const FLAG_OLD_ONLY := &"flag.test.state_replacement.old_only"
const FLAG_NEW_ONLY := &"flag.test.state_replacement.new_only"
const FLAG_CAT_SPOKEN := &"flag.demo_forge_cat_spoken"
const CAT_DIALOGUE_ID := &"dialogue.demo.forge_cat"

var _original_state: GameState
var _original_save_service: SaveService
var _forge: Node2D
var _save_directory := ""
var _replacement_events: Array[Dictionary] = []


func before_each() -> void:
	_replacement_events.clear()
	_original_state = SessionState.state
	_original_save_service = SessionState.save_service
	SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS)
	SessionState.debug_presets.load_manifest()
	SessionState.replace_state(_preset_state("debug.reset.demo_fresh"), &"test_setup")


func after_each() -> void:
	if SessionState.state_replaced.is_connected(_record_state_replacement):
		SessionState.state_replaced.disconnect(_record_state_replacement)
	_free_forge()
	SessionState.save_service = _original_save_service
	SessionState.replace_state(_original_state, &"test_cleanup")
	if not _save_directory.is_empty():
		_remove_tree(_save_directory)
	_save_directory = ""


func test_manual_load_rebinds_live_consumers_and_subsequent_saves() -> void:
	var previous := SessionState.state
	var target := _preset_state("debug.reset.demo_post_pickup")
	target.set_phase(GameState.PHASE_INVESTIGATION_NIGHT)
	target.set_quest_state(&"quest.makers_mark", &"not_started")
	target.set_fact(&"fact.seized_spearhead_seen", true)
	assert_true(target.equip_from_bag(&"left_hand", ITEM_SPEARHEAD))

	var service := SaveService.new()
	_save_directory = _temp_dir("manual_load")
	service.save_directory = _save_directory
	assert_true(service.save_game(target))
	SessionState.save_service = service

	_forge = _spawn_forge()
	var player := _forge.get_node("Actors/Player") as Player
	var inventory := player.get_node("InventoryController") as InventoryController
	var journal := player.get_node("JournalController") as JournalController
	var runtime := _forge.get_node("MapViewRuntime") as MapViewRuntime
	var world_items := _forge.get_node("WorldItemController") as WorldItemController
	inventory.open()
	assert_true(inventory.is_open())
	assert_true(world_items._items_root.get_child_count() > 0)

	SessionState.state_replaced.connect(_record_state_replacement)
	assert_true(SessionState.load_game())

	var current := SessionState.state
	_assert_single_ordered_event(previous, current, SessionState.STATE_REPLACE_REASON_MANUAL_LOAD)
	assert_eq(PhaseDirector._connected_state, current)
	assert_eq(runtime._equipment_state, current)
	assert_eq(world_items._state, current)
	assert_eq(inventory._overlay._state, current)
	assert_eq(inventory._overlay._bag, current.bag)
	assert_eq(journal._overlay._state, current)
	assert_true(inventory.is_open(), "an open inventory must reopen against the loaded bag")
	assert_eq(world_items._items_root.get_child_count(), 0)
	assert_false(current.is_world_item_placed(LOC_SMITHY, OBJ_SPEAR))
	assert_true(runtime._player_rig.equipped(&"right_hand") != null)
	assert_true(runtime._player_rig.equipped(&"left_hand") != null)

	# The retired state must no longer drive the equipment view. The current state
	# must continue to do so after replacement.
	assert_true(previous.unequip_to_bag(&"right_hand"))
	assert_true(runtime._player_rig.equipped(&"right_hand") != null)
	assert_true(current.unequip_to_bag(&"left_hand"))
	assert_eq(runtime._player_rig.equipped(&"left_hand"), null)

	journal.open()
	assert_true(journal.is_open())
	assert_eq(journal._overlay._objective_title.text, "The Maker's Mark")
	assert_true(journal._overlay._evidence_list.item_count > 0)

	# PhaseDirector must autosave and present only the current state after rebinding.
	current.set_phase(GameState.PHASE_CONSEQUENCE_NIGHT)
	var autosaved := service.load_game()
	assert_true(autosaved["ok"])
	assert_eq((autosaved["state"] as GameState).get_phase(), GameState.PHASE_CONSEQUENCE_NIGHT)

	previous.set_flag(FLAG_OLD_ONLY, true)
	current.set_flag(FLAG_NEW_ONLY, true)
	assert_true(SessionState.save_game())
	var saved := service.load_game()
	assert_true(saved["ok"])
	var saved_state := saved["state"] as GameState
	assert_true(saved_state.get_flag(FLAG_NEW_ONLY))
	assert_false(saved_state.get_flag(FLAG_OLD_ONLY))


func test_debug_preset_rebinds_open_ui_world_and_active_dialogue() -> void:
	var previous := SessionState.state
	_forge = _spawn_forge()
	var player := _forge.get_node("Actors/Player") as Player
	var inventory := player.get_node("InventoryController") as InventoryController
	var journal := player.get_node("JournalController") as JournalController
	var runtime := _forge.get_node("MapViewRuntime") as MapViewRuntime
	var world_items := _forge.get_node("WorldItemController") as WorldItemController
	var encounter := _forge.get_node("ForgeDialogueEncounter") as ForgeDialogueEncounter
	var runner := encounter.get_dialogue_runner()
	var cat := _forge.get_node("Actors/Cat") as ForgeCat

	journal.open()
	assert_true(journal.is_open())
	assert_true(runner.start(CAT_DIALOGUE_ID, cat))
	assert_true(runner.is_active())
	assert_true(world_items._items_root.get_child_count() > 0)

	SessionState.state_replaced.connect(_record_state_replacement)
	assert_true(SessionState.apply_debug_preset("debug.reset.demo_post_pickup"))

	var current := SessionState.state
	_assert_single_ordered_event(previous, current, SessionState.STATE_REPLACE_REASON_DEBUG_PRESET)
	assert_eq(PhaseDirector._connected_state, current)
	assert_eq(runtime._equipment_state, current)
	assert_eq(world_items._state, current)
	assert_eq(inventory._overlay._state, current)
	assert_eq(inventory._overlay._bag, current.bag)
	assert_eq(journal._overlay._state, current)
	assert_true(journal.is_open(), "an open journal must reopen against the preset state")
	assert_eq(world_items._items_root.get_child_count(), 0)
	assert_false(runner.is_active(), "state replacement must cancel the retired conversation")
	assert_eq(runner._state, current)

	assert_true(runner.start(CAT_DIALOGUE_ID, cat))
	while runner.is_active():
		runner.advance_for_test()
	assert_true(current.get_flag(FLAG_CAT_SPOKEN))
	assert_false(previous.get_flag(FLAG_CAT_SPOKEN))


func _record_state_replacement(
	previous: GameState,
	current: GameState,
	reason: StringName
) -> void:
	_replacement_events.append({
		"previous": previous,
		"current": current,
		"reason": reason,
		"canonical_installed": SessionState.state == current,
		# The authored spearhead weighs 0.35 kg; fallback lookup is much heavier.
		# Recording this inside the callback proves bag binding precedes notification.
		"bag_bound": is_equal_approx(
			current.bag.profile_for(ITEM_SPEARHEAD).weight_kg,
			0.35
		),
	})


func _assert_single_ordered_event(
	previous: GameState,
	current: GameState,
	reason: StringName
) -> void:
	assert_eq(_replacement_events.size(), 1, "each replacement path must emit exactly once")
	if _replacement_events.is_empty():
		return
	var event := _replacement_events[0]
	assert_eq(event["previous"], previous)
	assert_eq(event["current"], current)
	assert_eq(event["reason"], reason)
	assert_true(event["canonical_installed"])
	assert_true(event["bag_bound"])


func _preset_state(preset_id: String) -> GameState:
	var result: Dictionary = SessionState.debug_presets.apply_preset(preset_id)
	assert_true(bool(result.get("ok", false)), String(result.get("error", "preset failed")))
	return result.get("state") as GameState


func _spawn_forge() -> Node2D:
	var forge := FORGE_SCENE.instantiate() as Node2D
	(Engine.get_main_loop() as SceneTree).root.add_child(forge)
	return forge


func _free_forge() -> void:
	if _forge == null or not is_instance_valid(_forge):
		return
	MapView3D._strip_geometry_materials(_forge)
	_forge.free()
	_forge = null


func _temp_dir(label: String) -> String:
	return "user://test_saves/%s_%d" % [label, Time.get_ticks_usec()]


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		DirAccess.remove_absolute(path)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := path.path_join(entry)
			if DirAccess.dir_exists_absolute(child):
				_remove_tree(child)
			else:
				DirAccess.remove_absolute(child)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)

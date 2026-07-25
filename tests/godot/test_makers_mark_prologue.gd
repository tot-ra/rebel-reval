extends "res://tests/godot/test_case.gd"

const FORGE_SCENE := preload("res://scenes/reval_east/forge/forge.tscn")
const PrologueControllerScript := preload("res://scripts/forge/forge_prologue_controller.gd")

const QUEST_ID := &"quest.makers_mark"
const COMMISSION_ID := &"commission.watch_buckle_repair"
const RECORD_HONEST := &"forged.watch_buckle_repair.honest_work"
const FLAG_INCIDENT := &"flag.prologue_maker_mark_incident"
const FLAG_MART_MISSING := &"flag.mart_missing"
const FLAG_PRESERVED := &"flag.forge_ledger_preserved"
const FLAG_ALTERED := &"flag.forge_ledger_altered"
const FLAG_DESTROYED := &"flag.forge_ledger_destroyed"
const ITEM_HAMMER := &"item.forge_hammer"


func test_prologue_starts_quest_and_blocks_rest_until_ledger_committed() -> void:
	_prepare_prologue_state()
	var forge := await _spawn_forge()
	var controller = _find_prologue_controller(forge)
	assert_true(controller != null)

	assert_eq(SessionState.state.get_quest_state(QUEST_ID), &"not_started")
	var rest := _find_rest_interactable(forge)
	assert_true(rest != null)
	assert_false(rest.is_enabled(), "bed must stay disabled until the ledger branch is committed")

	await _complete_commission(forge)
	await _complete_henning_dialogue(controller)
	await _complete_chest_discovery(controller, forge)
	await _complete_ledger_choice(controller, forge, "preserve_ledger")

	assert_eq(SessionState.state.get_quest_state(QUEST_ID), &"ledger_committed")
	assert_true(SessionState.state.get_flag(FLAG_PRESERVED))
	assert_true(rest.is_enabled(), "bed must unlock after the ledger branch is committed")
	_free_scene(forge)


func test_prologue_supports_all_three_ledger_branches() -> void:
	var branches := [
		{"choice": "preserve_ledger", "flag": FLAG_PRESERVED, "pressure": 0, "henning": 1, "mart": 0},
		{"choice": "alter_ledger", "flag": FLAG_ALTERED, "pressure": 0, "henning": 0, "mart": 1},
		{"choice": "destroy_ledger", "flag": FLAG_DESTROYED, "pressure": 1, "henning": 0, "mart": 0},
	]
	for branch in branches:
		_prepare_prologue_state()
		var forge := await _spawn_forge()
		var controller = _find_prologue_controller(forge)
		await _complete_commission(forge)
		await _complete_henning_dialogue(controller)
		await _complete_chest_discovery(controller, forge)
		await _complete_ledger_choice(controller, forge, branch["choice"])

		assert_eq(SessionState.state.get_quest_state(QUEST_ID), &"ledger_committed")
		assert_true(SessionState.state.get_flag(branch["flag"]))
		assert_eq(SessionState.state.get_pressure(&"pressure.suspicion"), branch["pressure"])
		assert_eq(SessionState.state.get_relationship(&"rel.henning_trust"), branch["henning"])
		assert_eq(SessionState.state.get_relationship(&"rel.mart_trust"), branch["mart"])
		_free_scene(forge)


func test_bed_advances_phase_after_ledger_commit() -> void:
	_prepare_prologue_state()
	var forge := await _spawn_forge()
	var controller = _find_prologue_controller(forge)
	await _complete_commission(forge)
	await _complete_henning_dialogue(controller)
	await _complete_chest_discovery(controller, forge)
	await _complete_ledger_choice(controller, forge, "preserve_ledger")

	var rest := _find_rest_interactable(forge)
	var player := forge.get_node("Actors/Player") as Player
	_activate_interactable(player, rest)
	assert_true(rest.interact(player))
	assert_eq(SessionState.state.get_phase(), GameState.PHASE_INVESTIGATION_MORNING)
	_free_scene(forge)


func _prepare_prologue_state() -> void:
	SessionState.state = GameState.new()
	SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS)
	SessionState.state.bag.set_content_db(SessionState.content_db)
	SessionState.state.bag.try_add(ITEM_HAMMER)
	SessionState.state.equip_from_bag(&"right_hand", ITEM_HAMMER)
	SessionState.state.set_phase(GameState.PHASE_PROLOGUE_DAY)
	if Engine.get_main_loop().root.get_node_or_null("PhaseDirector") != null:
		PhaseDirector.rebind_session_state()


func _spawn_forge() -> Node2D:
	var tree := Engine.get_main_loop() as SceneTree
	var forge: Node2D = FORGE_SCENE.instantiate()
	tree.root.add_child(forge)
	await _settle_frames(2)
	return forge


func _find_prologue_controller(forge: Node):
	return forge.get_node_or_null("ForgePrologueController")


func _complete_commission(forge: Node2D) -> void:
	var player := forge.get_node("Actors/Player") as Player
	var commission_controller := player.get_node("ForgeCommissionController") as ForgeCommissionController
	var ledger := _find_commission_interactable(forge)
	assert_true(ledger != null)
	_activate_interactable(player, ledger)
	assert_true(ledger.interact(player))

	var overlay := player.find_child("ForgeCommissionOverlay", true, false) as ForgeCommissionOverlay
	assert_true(overlay != null)
	overlay.option_selected.emit("honest_work")

	var feedback_overlay := commission_controller.get_node("ForgeFeedbackOverlay") as ForgeFeedbackOverlay
	for _phase_index in 4:
		feedback_overlay._unhandled_input(_accept_event())
		await _settle_frames(1)

	assert_true(SessionState.state.has_forged_record(RECORD_HONEST))
	await _settle_frames(2)


func _complete_henning_dialogue(controller) -> void:
	var runner: DialogueRunner = controller.get_dialogue_runner()
	var guard := 0
	while not runner.is_active() and guard < 20:
		await _settle_frames(1)
		guard += 1
	assert_true(runner.is_active(), "Henning arrival dialogue should start after the commission")

	runner.advance_for_test()
	assert_true(runner.select_choice("ask_where_found"))
	runner.advance_for_test()
	assert_false(runner.is_active())
	assert_true(SessionState.state.get_flag(FLAG_INCIDENT))
	assert_eq(SessionState.state.get_quest_state(QUEST_ID), &"incident_known")


func _complete_chest_discovery(controller, forge: Node2D) -> void:
	var chest: Interactable = controller.get_chest_interactable()
	assert_true(chest.is_enabled())
	var player := forge.get_node("Actors/Player") as Player
	_activate_interactable(player, chest)
	assert_true(chest.interact(player))

	var runner: DialogueRunner = controller.get_dialogue_runner()
	runner.advance_for_test()
	runner.advance_for_test()
	assert_false(runner.is_active())
	assert_true(SessionState.state.get_flag(FLAG_MART_MISSING))


func _complete_ledger_choice(
	controller,
	forge: Node2D,
	choice_id: String
) -> void:
	var ledger: Interactable = controller.get_ledger_choice_interactable()
	assert_true(ledger.is_enabled())
	var player := forge.get_node("Actors/Player") as Player
	_activate_interactable(player, ledger)
	assert_true(ledger.interact(player))

	var runner: DialogueRunner = controller.get_dialogue_runner()
	runner.advance_for_test()
	assert_true(runner.select_choice(choice_id))
	runner.advance_for_test()
	assert_false(runner.is_active())


func _find_commission_interactable(forge: Node) -> Interactable:
	for node in forge.find_children("*", "Area2D", true, false):
		var interactable := node as Interactable
		if interactable == null:
			continue
		if interactable.get_interaction_kind() == InteractionKinds.USE \
				and String(interactable.get_interactable_id()).begins_with("interact.commission."):
			return interactable
	return null


func _find_rest_interactable(forge: Node) -> Interactable:
	for node in forge.find_children("*", "Area2D", true, false):
		var interactable := node as Interactable
		if interactable != null and interactable.get_interactable_id() == &"interact.rest.bed_alcove":
			return interactable
	return null


func _activate_interactable(player: Player, interactable: Interactable) -> void:
	player.global_position = interactable.global_position
	interactable.register_actor_in_range(player)


func _accept_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	return event


func _settle_frames(count: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for _i in count:
		await tree.process_frame


func _free_scene(scene: Node) -> void:
	if scene == null or not is_instance_valid(scene):
		return
	MapView3D._strip_geometry_materials(scene)
	scene.free()

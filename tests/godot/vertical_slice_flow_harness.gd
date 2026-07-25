extends "res://tests/godot/test_case.gd"

## Shared headless helpers for vertical-slice flow and save-matrix tests.

const FORGE_SCENE := preload("res://scenes/reval_east/forge/forge.tscn")
const LOWER_TOWN_SCENE := preload("res://scenes/reval_east/reval_east.tscn")
const FlowModel := preload("res://scripts/slice/vertical_slice_flow_model.gd")
const AftermathModel := preload("res://scripts/investigation/bitter_brew_aftermath_model.gd")
const ReflectionModel := preload("res://scripts/reflection/reflection_model.gd")
const InvestigationScript := preload("res://scripts/investigation/bitter_brew_investigation.gd")
const NightConsequenceScript := preload(
	"res://scripts/investigation/bitter_brew_night_consequence.gd"
)

const ITEM_HAMMER := &"item.forge_hammer"
const RECORD_HONEST := &"forged.watch_buckle_repair.honest_work"
const FLAG_INCIDENT := &"flag.prologue_maker_mark_incident"
const FLAG_MART_MISSING := &"flag.mart_missing"

const SITE_CISTERN := &"interact.bitter_brew.cistern"
const SITE_BREWERY := &"interact.bitter_brew.brewery"
const SITE_SUPPLY := &"interact.bitter_brew.supply"
const SITE_CHECKPOINT := &"interact.bitter_brew.checkpoint"


func _reset_fresh_session() -> void:
	SessionState.state = GameState.new()
	SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS)
	SessionState.state.bag.set_content_db(SessionState.content_db)
	SessionState.state.bag.try_add(ITEM_HAMMER)
	SessionState.state.equip_from_bag(&"right_hand", ITEM_HAMMER)
	SessionState.state.set_phase(GameState.PHASE_PROLOGUE_DAY)
	if Engine.get_main_loop().root.get_node_or_null("PhaseDirector") != null:
		PhaseDirector.rebind_session_state()


func _complete_prologue() -> void:
	var forge := await _spawn_forge()
	var controller = forge.get_node_or_null("ForgePrologueController")
	assert_true(controller != null)

	await _complete_watch_buckle_commission(forge)
	await _advance_prologue_dialogue(controller)
	await _complete_chest_discovery(controller, forge)
	await _complete_ledger_choice(controller, forge, "preserve_ledger")

	assert_eq(SessionState.state.get_quest_state(FlowModel.QUEST_MAKERS_MARK), &"ledger_committed")
	_free_scene(forge)


func _complete_watch_buckle_commission(forge: Node2D) -> void:
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
	while feedback_overlay.is_open():
		feedback_overlay._unhandled_input(_accept_event())
		await _settle_frames(1)

	assert_true(SessionState.state.has_forged_record(RECORD_HONEST))


func _advance_prologue_dialogue(controller) -> void:
	var runner: DialogueRunner = controller.get_dialogue_runner()
	var guard := 0
	while not runner.is_active() and guard < 20:
		await _settle_frames(1)
		guard += 1
	assert_true(runner.is_active())
	runner.advance_for_test()
	assert_true(runner.select_choice("ask_where_found"))
	runner.advance_for_test()
	assert_false(runner.is_active())
	assert_true(SessionState.state.get_flag(FLAG_INCIDENT))


func _complete_chest_discovery(controller, forge: Node2D) -> void:
	var chest: Interactable = controller.get_chest_interactable()
	var player := forge.get_node("Actors/Player") as Player
	_activate_interactable(player, chest)
	assert_true(chest.interact(player))
	var runner: DialogueRunner = controller.get_dialogue_runner()
	runner.advance_for_test()
	runner.advance_for_test()
	assert_true(SessionState.state.get_flag(FLAG_MART_MISSING))


func _complete_ledger_choice(controller, forge: Node2D, choice_id: String) -> void:
	var ledger: Interactable = controller.get_ledger_choice_interactable()
	var player := forge.get_node("Actors/Player") as Player
	_activate_interactable(player, ledger)
	assert_true(ledger.interact(player))
	var runner: DialogueRunner = controller.get_dialogue_runner()
	runner.advance_for_test()
	assert_true(runner.select_choice(choice_id))
	runner.advance_for_test()


func _rest_in_forge(expected_phase: StringName) -> void:
	var forge := await _spawn_forge()
	var rest := _find_rest_interactable(forge)
	var player := forge.get_node("Actors/Player") as Player
	assert_true(rest != null and rest.is_enabled(), "bed must be available before %s" % String(expected_phase))
	_activate_interactable(player, rest)
	assert_true(rest.interact(player))
	assert_eq(SessionState.state.get_phase(), expected_phase)
	_free_scene(forge)


func _complete_investigation() -> void:
	var east := await _spawn_lower_town()
	var investigation := east.get_node_or_null("BitterBrewInvestigation") as InvestigationScript
	assert_true(investigation != null)
	for site_id in [SITE_CISTERN, SITE_BREWERY, SITE_SUPPLY, SITE_CHECKPOINT]:
		await _inspect_site(investigation, site_id)
	assert_eq(SessionState.state.get_quest_state(FlowModel.QUEST_BITTER_BREW), &"investigation_ready")
	_free_scene(east)


func _complete_bitter_brew_commission(option_id: String) -> void:
	var forge := await _spawn_forge()
	var player := forge.get_node("Actors/Player") as Player
	var commission_controller := player.get_node("ForgeCommissionController") as ForgeCommissionController
	var ledger := _find_commission_interactable(forge)
	assert_true(ledger != null)
	assert_eq(ledger.get_interactable_id(), &"interact.commission.bitter_brew")
	_activate_interactable(player, ledger)
	assert_true(ledger.interact(player))

	var overlay := player.find_child("ForgeCommissionOverlay", true, false) as ForgeCommissionOverlay
	overlay.option_selected.emit(option_id)
	var feedback_overlay := commission_controller.get_node("ForgeFeedbackOverlay") as ForgeFeedbackOverlay
	while feedback_overlay.is_open():
		feedback_overlay._unhandled_input(_accept_event())
		await _settle_frames(1)

	var branch := _branch_for_forge_option(option_id)
	assert_true(SessionState.state.has_forged_record(branch["forged_record"] as StringName))
	_free_scene(forge)


func _resolve_night_encounter(route: StringName) -> void:
	var east := await _spawn_lower_town()
	var consequence := east.get_node_or_null("BitterBrewNightConsequence") as NightConsequenceScript
	assert_true(consequence != null)
	consequence.arm_encounter_for_test()
	assert_true(consequence.resolve_encounter_outcome(route))
	_free_scene(east)


func _complete_reflection() -> void:
	assert_true(ReflectionModel.is_available(SessionState.state))
	var evaluator := StateRuleEvaluator.new()
	assert_true(ReflectionModel.apply_conviction(SessionState.state, "duty", evaluator))
	assert_true(FlowModel.is_slice_complete(SessionState.state))


func _branch_for_forge_option(option_id: String) -> Dictionary:
	for branch: Dictionary in FlowModel.BRANCHES:
		if String(branch["forge_option"]) == option_id:
			return branch
	return {}


func _inspect_site(investigation: InvestigationScript, site_id: StringName) -> void:
	assert_true(investigation.inspect_site_for_test(site_id))
	var runner := investigation.get_node("BitterBrewDialogueRunner") as DialogueRunner
	var guard := 0
	while runner.is_active() and guard < 12:
		investigation.advance_dialogue_for_test()
		guard += 1
	assert_false(runner.is_active())


func _spawn_forge() -> Node2D:
	var tree := Engine.get_main_loop() as SceneTree
	var forge: Node2D = FORGE_SCENE.instantiate()
	tree.root.add_child(forge)
	await _settle_frames(2)
	return forge


func _spawn_lower_town() -> Node:
	var east: Node = LOWER_TOWN_SCENE.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(east)
	await east.ready
	await _settle_frames(2)
	return east


func _find_commission_interactable(forge: Node) -> Interactable:
	for node in forge.find_children("*", "Area2D", true, false):
		var interactable := node as Interactable
		if interactable != null \
				and interactable.get_interaction_kind() == InteractionKinds.USE \
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

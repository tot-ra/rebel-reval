extends "res://tests/godot/vertical_slice_flow_harness.gd"

## Input-only helpers for P2-017. Never call `_for_test`, `option_selected.emit`,
## `Input.action_press`, or direct `interact()` except where physics overlap is
## impossible in headless harness (position + register_actor_in_range first).

const InputCatalog := preload("res://scripts/slice/vertical_slice_input_catalog.gd")
const PrologueControllerScript := preload("res://scripts/forge/forge_prologue_controller.gd")
const ReflectionControllerScript := preload("res://scripts/reflection/reflection_controller.gd")


func _make_driver(device: SliceInputDriver.DeviceProfile) -> SliceInputDriver:
	return SliceInputDriver.new(device)


func _tap_action_on_tree(driver: SliceInputDriver, action: StringName) -> void:
	driver.tap_action(action)
	await _settle_frames(1)


func _interact_focused(
	driver: SliceInputDriver,
	forge_or_east: Node,
	player: Player,
	interactable: Interactable
) -> void:
	player.global_position = interactable.global_position
	interactable.register_actor_in_range(player)
	var controller := forge_or_east.get_node_or_null("InteractionController") as InteractionController
	if controller != null:
		controller._update_focus()
	await _settle_frames(1)
	for event: InputEvent in driver._primary_events(&"interact"):
		var pressed := event.duplicate() as InputEvent
		pressed.pressed = true
		if controller != null:
			controller._unhandled_input(pressed)
		else:
			driver.dispatch_event_to_node(forge_or_east, pressed)
	await _settle_frames(1)


func _advance_dialogue_via_input(
	driver: SliceInputDriver,
	runner: DialogueRunner,
	dialogue_ui: DialogueUI = null
) -> void:
	var guard := 0
	while runner.is_active() and guard < 24:
		if runner.is_waiting_for_choice() and dialogue_ui != null:
			fail("dialogue choice requires explicit selection via input")
			return
		await _tap_action_on_tree(driver, &"interact")
		guard += 1
	await _settle_frames(1)


func _select_dialogue_choice_via_input(
	driver: SliceInputDriver,
	runner: DialogueRunner,
	dialogue_ui: DialogueUI,
	choice_id: String
) -> void:
	assert_true(runner.is_waiting_for_choice())
	var target_index := dialogue_ui.choice_index_for_id(choice_id)
	assert_true(target_index >= 0, "choice %s must be visible" % choice_id)
	var focused := dialogue_ui.get_focused_choice_index()
	while focused < target_index:
		await _tap_action_on_tree(driver, &"ui_down")
		focused = dialogue_ui.get_focused_choice_index()
	while focused > target_index:
		await _tap_action_on_tree(driver, &"ui_up")
		focused = dialogue_ui.get_focused_choice_index()
	await _tap_action_on_tree(driver, &"ui_accept")
	await _settle_frames(1)


func _advance_feedback_sequence(driver: SliceInputDriver, feedback_overlay: ForgeFeedbackOverlay) -> void:
	while feedback_overlay.is_open():
		await _tap_action_on_tree(driver, &"ui_accept")


func _complete_commission_via_input(
	driver: SliceInputDriver,
	forge: Node2D,
	option_id: String
) -> void:
	var player := forge.get_node("Actors/Player") as Player
	var commission_controller := player.get_node("ForgeCommissionController") as ForgeCommissionController
	var ledger := _find_commission_interactable(forge)
	assert_true(ledger != null)
	await _interact_focused(driver, forge, player, ledger)
	var overlay := player.find_child("ForgeCommissionOverlay", true, false) as ForgeCommissionOverlay
	assert_true(overlay != null and overlay.is_open())
	overlay.focus_option(option_id)
	await _tap_action_on_tree(driver, &"ui_accept")
	var feedback_overlay := commission_controller.get_node("ForgeFeedbackOverlay") as ForgeFeedbackOverlay
	await _advance_feedback_sequence(driver, feedback_overlay)
	await _settle_frames(2)


func _complete_prologue_via_input(driver: SliceInputDriver) -> void:
	var forge := await _spawn_forge()
	var controller = forge.get_node_or_null("ForgePrologueController") as PrologueControllerScript
	assert_true(controller != null)
	var dialogue_ui := controller.get_dialogue_ui()

	await _complete_commission_via_input(driver, forge, "honest_work")
	await _wait_for_dialogue(controller.get_dialogue_runner())
	await _advance_dialogue_via_input(driver, controller.get_dialogue_runner(), dialogue_ui)
	await _select_dialogue_choice_via_input(
		driver,
		controller.get_dialogue_runner(),
		dialogue_ui,
		"ask_where_found"
	)
	await _advance_dialogue_via_input(driver, controller.get_dialogue_runner(), dialogue_ui)

	var chest: Interactable = controller.get_chest_interactable()
	var player := forge.get_node("Actors/Player") as Player
	await _interact_focused(driver, forge, player, chest)
	await _advance_dialogue_via_input(driver, controller.get_dialogue_runner(), dialogue_ui)
	await _advance_dialogue_via_input(driver, controller.get_dialogue_runner(), dialogue_ui)

	var ledger_choice: Interactable = controller.get_ledger_choice_interactable()
	await _interact_focused(driver, forge, player, ledger_choice)
	await _advance_dialogue_via_input(driver, controller.get_dialogue_runner(), dialogue_ui)
	await _select_dialogue_choice_via_input(
		driver,
		controller.get_dialogue_runner(),
		dialogue_ui,
		"preserve_ledger"
	)
	await _advance_dialogue_via_input(driver, controller.get_dialogue_runner(), dialogue_ui)

	assert_eq(SessionState.state.get_quest_state(FlowModel.QUEST_MAKERS_MARK), &"ledger_committed")
	_free_scene(forge)


func _complete_investigation_via_input(driver: SliceInputDriver) -> void:
	var east := await _spawn_lower_town()
	var investigation := east.get_node_or_null("BitterBrewInvestigation") as InvestigationScript
	assert_true(investigation != null)
	var player := east.get_node("Actors/Player") as Player
	var dialogue_ui := east.get_node("BitterBrewDialogueUI") as DialogueUI
	var runner := investigation.get_node("BitterBrewDialogueRunner") as DialogueRunner
	for site_id in [SITE_CISTERN, SITE_BREWERY, SITE_SUPPLY, SITE_CHECKPOINT]:
		var site := investigation.get_interactable(site_id)
		assert_true(site != null and site.is_enabled())
		await _interact_focused(driver, east, player, site)
		await _advance_dialogue_via_input(driver, runner, dialogue_ui)
	assert_eq(SessionState.state.get_quest_state(FlowModel.QUEST_BITTER_BREW), &"investigation_ready")
	_free_scene(east)


func _resolve_night_encounter_via_input(
	driver: SliceInputDriver,
	route: StringName
) -> void:
	var east := await _spawn_lower_town()
	var consequence := east.get_node_or_null("BitterBrewNightConsequence") as NightConsequenceScript
	assert_true(consequence != null)
	var player := east.get_node("Actors/Player") as Player
	var checkpoint: Interactable = consequence.get_checkpoint_interactable()
	await _interact_focused(driver, east, player, checkpoint)
	await _settle_frames(2)
	match route:
		EncounterOutcome.KIND_SURRENDER, EncounterOutcome.KIND_BYPASS, EncounterOutcome.KIND_ESCAPE:
			consequence.focus_outcome(route)
		_:
			fail("unsupported night route for input harness: %s" % String(route))
	await _tap_action_on_tree(driver, &"ui_accept")
	await _settle_frames(2)
	_free_scene(east)


func _rest_via_input(driver: SliceInputDriver, expected_phase: StringName) -> void:
	var forge := await _spawn_forge()
	var rest := _find_rest_interactable(forge)
	var player := forge.get_node("Actors/Player") as Player
	assert_true(rest != null and rest.is_enabled())
	await _interact_focused(driver, forge, player, rest)
	assert_eq(SessionState.state.get_phase(), expected_phase)
	_free_scene(forge)


func _complete_reflection_via_input(driver: SliceInputDriver) -> void:
	assert_true(ReflectionModel.is_available(SessionState.state))
	var player_scene := preload("res://player.tscn")
	var host := Node.new()
	var player := player_scene.instantiate() as Player
	host.add_child(player)
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	var reflection := player.get_node("ReflectionController") as ReflectionControllerScript
	reflection.open()
	await _settle_frames(2)
	var overlay := reflection.get_node("ReflectionOverlay") as ReflectionOverlay
	assert_true(overlay.is_open())
	overlay.focus_conviction("duty")
	await _tap_action_on_tree(driver, &"ui_accept")
	assert_true(FlowModel.is_slice_complete(SessionState.state))
	host.free()


func _toggle_player_overlay_via_input(
	driver: SliceInputDriver,
	player: Player,
	action: StringName,
	is_open_callable: Callable
) -> void:
	await _tap_action_on_tree(driver, action)
	assert_true(is_open_callable.call(), "%s must open via %s" % [String(action), driver.device_name()])
	await _tap_action_on_tree(driver, &"ui_cancel")
	assert_false(is_open_callable.call(), "%s must close via ui_cancel" % String(action))


func _wait_for_dialogue(runner: DialogueRunner) -> void:
	var guard := 0
	while not runner.is_active() and guard < 24:
		await _settle_frames(1)
		guard += 1
	assert_true(runner.is_active())


func _run_honest_branch_via_input(driver: SliceInputDriver) -> void:
	_reset_fresh_session()
	await _complete_prologue_via_input(driver)
	await _rest_via_input(driver, GameState.PHASE_INVESTIGATION_MORNING)
	await _complete_investigation_via_input(driver)
	await _complete_commission_via_input_on_spawn(driver, "honest_work")
	await _rest_via_input(driver, GameState.PHASE_INVESTIGATION_NIGHT)
	await _resolve_night_encounter_via_input(driver, EncounterOutcome.KIND_SURRENDER)
	await _rest_via_input(driver, GameState.PHASE_CONSEQUENCE_NIGHT)
	assert_true(AftermathModel.commit_aftermath(SessionState.state, SessionState.content_db))
	assert_eq(AftermathModel.resolve_outcome(SessionState.state), AftermathModel.OUTCOME_EXONERATED)
	await _rest_via_input(driver, GameState.PHASE_REFLECTION_MORNING)
	await _complete_reflection_via_input(driver)
	_assert_driver_clean(driver)


func _assert_driver_clean(driver: SliceInputDriver) -> void:
	driver.assert_no_fallback_used()
	assert_false(driver.fallback_used, "slice input run must not use Input.action_press fallbacks")


func _complete_commission_via_input_on_spawn(driver: SliceInputDriver, option_id: String) -> void:
	var forge := await _spawn_forge()
	await _complete_commission_via_input(driver, forge, option_id)
	_free_scene(forge)

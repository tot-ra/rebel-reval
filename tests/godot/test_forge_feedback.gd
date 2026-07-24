extends "res://tests/godot/test_case.gd"

const FORGE_SCENE := preload("res://scenes/reval_east/forge/forge.tscn")
const EXPECTED_PHASES: Array[StringName] = [
	&"heat",
	&"hammer_rhythm",
	&"quench",
	&"maker_stamp",
	&"object_reveal",
]
const FORBIDDEN_FORGE_STATE := [
	"temperature",
	"strike_accuracy",
	"timing_score",
]


func test_feedback_sequence_emits_five_phases_in_order() -> void:
	var trace := ForgeFeedbackSequence.trace_phases("honest_work", {"object_name": "Watchman's buckle"})
	assert_eq(trace.size(), EXPECTED_PHASES.size())
	for index in EXPECTED_PHASES.size():
		assert_eq(trace[index], EXPECTED_PHASES[index])


func test_feedback_sequence_signal_trace_matches_phase_order() -> void:
	var sequence := ForgeFeedbackSequence.new()
	sequence.reset("honest_work", {})
	var trace: Array[StringName] = []
	sequence.feedback_event.connect(func(phase: StringName) -> void:
		trace.append(phase)
	)
	while true:
		var phase := sequence.advance()
		if phase.is_empty():
			break
	assert_eq(trace, EXPECTED_PHASES)


func test_forge_scene_trace_emits_five_feedback_events_in_order() -> void:
	_prepare_forge_commission_state()
	var tree := Engine.get_main_loop() as SceneTree
	var forge: Node2D = FORGE_SCENE.instantiate()
	tree.root.add_child(forge)

	var player := forge.get_node("Actors/Player") as Player
	var commission_controller := player.get_node("ForgeCommissionController") as ForgeCommissionController
	var feedback_overlay := commission_controller.get_node("ForgeFeedbackOverlay") as ForgeFeedbackOverlay
	var ledger := _find_ledger_interactable(forge)
	assert_true(ledger != null)
	assert_true(feedback_overlay != null)

	_activate_interactable(player, ledger)
	assert_true(ledger.interact(player))

	var commission_overlay := player.find_child("ForgeCommissionOverlay", true, false) as ForgeCommissionOverlay
	assert_true(commission_overlay != null)

	var trace: Array[StringName] = []
	feedback_overlay.get_sequence().feedback_event.connect(func(phase: StringName) -> void:
		trace.append(phase)
	)
	commission_overlay.option_selected.emit("honest_work")
	assert_true(feedback_overlay.is_open())

	for _phase_index in EXPECTED_PHASES.size() - 1:
		feedback_overlay._unhandled_input(_accept_event())
		await tree.process_frame

	assert_eq(trace, EXPECTED_PHASES)
	assert_false(commission_controller.is_open())
	assert_true(SessionState.state.has_forged_record(&"forged.watch_buckle_repair.honest_work"))
	forge.queue_free()


func test_forge_scene_exposes_no_timing_minigame_state() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var forge: Node2D = FORGE_SCENE.instantiate()
	tree.root.add_child(forge)

	for node in forge.find_children("*", "", true, false):
		for property_name in _forbidden_property_names(node):
			assert_true(
				false,
				"forbidden forge state property %s on %s" % [property_name, node.get_path()]
			)

	for script_path in [
		"res://scenes/reval_east/forge/forge.gd",
		"res://scripts/forge/forge_feedback_sequence.gd",
		"res://scripts/forge/forge_feedback_overlay.gd",
	]:
		var script := load(script_path) as Script
		assert_true(script != null, "script should load: %s" % script_path)
		for property_name in _forbidden_property_names_from_script(script):
			assert_true(
				false,
				"forbidden forge state property %s in %s" % [property_name, script_path]
			)

	forge.queue_free()


func _prepare_forge_commission_state() -> void:
	SessionState.state = GameState.new()
	SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS)
	SessionState.state.bag.set_content_db(SessionState.content_db)


func _find_ledger_interactable(forge: Node) -> Interactable:
	for node in forge.find_children("*", "Area2D", true, false):
		var interactable := node as Interactable
		if interactable == null:
			continue
		if interactable.get_interaction_kind() == InteractionKinds.USE \
				and String(interactable.get_interactable_id()).begins_with("interact.commission."):
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


func _forbidden_property_names(node: Object) -> Array[String]:
	var names: Array[String] = []
	for property_info in node.get_property_list():
		var property_name := String(property_info.get("name", ""))
		if property_name in FORBIDDEN_FORGE_STATE:
			names.append(property_name)
	return names


func _forbidden_property_names_from_script(script: Script) -> Array[String]:
	var names: Array[String] = []
	for property_info in script.get_script_property_list():
		var property_name := String(property_info.get("name", ""))
		if property_name in FORBIDDEN_FORGE_STATE:
			names.append(property_name)
	return names

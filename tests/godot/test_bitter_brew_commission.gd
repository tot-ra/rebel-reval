extends "res://tests/godot/test_case.gd"

const VALID_DIR := "res://content/examples/valid"
const SUPPORT_DIR := "res://content/examples/support"
const FORGE_SCENE := preload("res://scenes/reval_east/forge/forge.tscn")
const RunnerScript := preload("res://scripts/forge/forge_commission_runner.gd")
const PresenterScript := preload("res://scripts/forge/forge_commission_presenter.gd")

const COMMISSION_ID := &"commission.bitter_brew"
const QUEST_ID := &"quest.bitter_brew"
const OBJECT_ID := &"item.bitter_brew_work"
const RECORD_HONEST := &"forged.bitter_brew.honest_work"
const RECORD_SUBTLE := &"forged.bitter_brew.subtle_defect"
const RECORD_SECRET := &"forged.bitter_brew.secret_feature"
const FLAG_SECURED := &"flag.bitter_brew_brewery_secured"
const FLAG_SEAL := &"flag.bitter_brew_seal_tampered"
const FLAG_LOCK := &"flag.bitter_brew_cart_lock_flawed"
const FACT_CHECKPOINT := &"fact.bitter_brew.checkpoint_neglect"
const FACT_BREWERY := &"fact.bitter_brew.brewery_ale_sound"
const FACT_SUPPLY := &"fact.bitter_brew.merchant_supply_spoiled"

var db: ContentDB
var state: GameState


func before_each() -> void:
	db = ContentDB.new()
	assert_true(db.load_from_directories([VALID_DIR, SUPPORT_DIR]))
	state = GameState.new()
	state.set_phase(GameState.PHASE_INVESTIGATION_MORNING)
	state.set_quest_state(QUEST_ID, &"investigation_ready")


func test_commission_content_exposes_three_forging_options() -> void:
	var commission := db.get_commission(COMMISSION_ID)
	assert_false(commission.is_empty())
	assert_eq(String(commission.get("client_id", "")), "char.aita")
	assert_eq(String(commission.get("object_item_id", "")), String(OBJECT_ID))
	var options: Array = commission.get("forging_options", [])
	assert_eq(options.size(), 3)


func test_snapshot_unlocks_defect_and_secret_after_investigation_facts() -> void:
	var snapshot := ForgeCommissionModel.build_snapshot(COMMISSION_ID, state, db)
	var options: Array = snapshot.get("forging_options", [])
	assert_true(_option_enabled(options, "honest_work"))
	assert_false(_option_enabled(options, "subtle_defect"))
	assert_false(_option_enabled(options, "secret_feature"))

	state.set_fact(FACT_CHECKPOINT, true)
	snapshot = ForgeCommissionModel.build_snapshot(COMMISSION_ID, state, db)
	options = snapshot.get("forging_options", [])
	assert_true(_option_enabled(options, "subtle_defect"))

	state.set_fact(FACT_BREWERY, true)
	state.set_fact(FACT_SUPPLY, true)
	snapshot = ForgeCommissionModel.build_snapshot(COMMISSION_ID, state, db)
	options = snapshot.get("forging_options", [])
	assert_true(_option_enabled(options, "secret_feature"))


func test_selecting_each_option_creates_forged_record_and_flag() -> void:
	_assert_option_commits("honest_work", RECORD_HONEST, FLAG_SECURED, [])
	state = GameState.new()
	state.set_phase(GameState.PHASE_INVESTIGATION_MORNING)
	state.set_quest_state(QUEST_ID, &"investigation_ready")
	state.set_fact(FACT_CHECKPOINT, true)
	_assert_option_commits("subtle_defect", RECORD_SUBTLE, FLAG_SEAL, [FACT_CHECKPOINT])
	state = GameState.new()
	state.set_phase(GameState.PHASE_INVESTIGATION_MORNING)
	state.set_quest_state(QUEST_ID, &"investigation_ready")
	state.set_fact(FACT_BREWERY, true)
	state.set_fact(FACT_SUPPLY, true)
	_assert_option_commits(
		"secret_feature",
		RECORD_SECRET,
		FLAG_LOCK,
		[FACT_BREWERY, FACT_SUPPLY]
	)


func test_feedback_object_reveal_varies_by_commission_and_option() -> void:
	var sequence := ForgeFeedbackSequence.new()
	sequence.reset(
		"honest_work",
		{
			"commission_id": COMMISSION_ID,
			"object_name": "Crisis forge work",
		}
	)
	while not sequence.is_finished():
		var phase := sequence.advance()
		if phase == &"object_reveal":
			assert_true(
				sequence.body_for(phase).contains("bands"),
				"honest bitter brew reveal should describe brewery bands"
			)
			return
	assert_true(false, "object_reveal phase missing")


func test_forge_scene_commits_bitter_brew_commission_with_feedback() -> void:
	_prepare_forge_commission_state()
	var tree := Engine.get_main_loop() as SceneTree
	var forge: Node2D = FORGE_SCENE.instantiate()
	tree.root.add_child(forge)

	var player := forge.get_node("Actors/Player") as Player
	var commission_controller := player.get_node("ForgeCommissionController") as ForgeCommissionController
	var feedback_overlay := commission_controller.get_node("ForgeFeedbackOverlay") as ForgeFeedbackOverlay
	var ledger := _find_ledger_interactable(forge)
	assert_true(ledger != null)
	assert_eq(ledger.get_interactable_id(), &"interact.commission.bitter_brew")

	_activate_interactable(player, ledger)
	assert_true(ledger.interact(player))

	var commission_overlay := player.find_child("ForgeCommissionOverlay", true, false) as ForgeCommissionOverlay
	assert_true(commission_overlay != null)
	commission_overlay.option_selected.emit("honest_work")

	var reveal_text := ""
	while feedback_overlay.is_open():
		var phase := feedback_overlay.get_sequence().current_phase()
		if phase == &"object_reveal":
			reveal_text = feedback_overlay.get_sequence().body_for(phase)
		feedback_overlay._unhandled_input(_accept_event())
		await tree.process_frame

	assert_true(reveal_text.contains("bands"))
	assert_true(SessionState.state.has_forged_record(RECORD_HONEST))
	assert_true(SessionState.state.get_flag(FLAG_SECURED))
	forge.queue_free()


func test_bed_rest_stays_disabled_until_commission_resolves() -> void:
	_prepare_forge_commission_state()
	var tree := Engine.get_main_loop() as SceneTree
	var forge: Node2D = FORGE_SCENE.instantiate()
	tree.root.add_child(forge)

	var rest := forge.get_node("PhaseRestAnchor") as PhaseRestAnchor
	var bed := rest.get_interactable()
	assert_true(bed != null)
	assert_false(bed.is_enabled(), "bed must stay locked until the crisis commission resolves")

	var player := forge.get_node("Actors/Player") as Player
	var commission_controller := player.get_node("ForgeCommissionController") as ForgeCommissionController
	var ledger := _find_ledger_interactable(forge)
	_activate_interactable(player, ledger)
	assert_true(ledger.interact(player))
	var commission_overlay := player.find_child("ForgeCommissionOverlay", true, false) as ForgeCommissionOverlay
	commission_overlay.option_selected.emit("honest_work")
	var feedback_overlay := commission_controller.get_node("ForgeFeedbackOverlay") as ForgeFeedbackOverlay
	while feedback_overlay.is_open():
		feedback_overlay._unhandled_input(_accept_event())
		await tree.process_frame
	await tree.process_frame

	assert_true(bed.is_enabled(), "bed should unlock after the commission resolves")
	forge.queue_free()


func _assert_option_commits(
	option_id: String,
	record_id: StringName,
	flag_id: StringName,
	required_facts: Array[StringName]
) -> void:
	for fact_id in required_facts:
		state.set_fact(fact_id, true)
	var setup := _make_runner_setup()
	assert_true(setup.runner.open(COMMISSION_ID))
	assert_true(setup.runner.select_option(option_id))
	assert_true(state.has_forged_record(record_id))
	assert_true(state.get_flag(flag_id))
	var record := state.get_forged_record(record_id)
	assert_eq(record.modification_id, StringName(option_id))
	_cleanup_setup(setup)


func _prepare_forge_commission_state() -> void:
	SessionState.state = GameState.new()
	SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS)
	SessionState.state.bag.set_content_db(SessionState.content_db)
	SessionState.state.set_phase(GameState.PHASE_INVESTIGATION_MORNING)
	SessionState.state.set_quest_state(QUEST_ID, &"investigation_ready")
	for fact_id in [
		FACT_CHECKPOINT,
		FACT_BREWERY,
		FACT_SUPPLY,
		&"fact.bitter_brew.cistern_contaminated",
	]:
		SessionState.state.set_fact(fact_id, true)


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


func _make_runner_setup() -> Dictionary:
	var presenter := _RecordingPresenter.new()
	var runner := RunnerScript.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(runner)
	runner.configure(db, state, presenter)
	return {"runner": runner, "presenter": presenter}


func _cleanup_setup(setup: Dictionary) -> void:
	var runner: Node = setup.get("runner")
	if runner != null and is_instance_valid(runner):
		runner.queue_free()


func _option_enabled(options: Array, option_id: String) -> bool:
	for option_value in options:
		if typeof(option_value) != TYPE_DICTIONARY:
			continue
		var option := option_value as Dictionary
		if String(option.get("id", "")) == option_id:
			return bool(option.get("enabled", false))
	return false


class _RecordingPresenter extends PresenterScript:
	var last_snapshot: Dictionary = {}

	func present_commission(snapshot: Dictionary) -> void:
		last_snapshot = snapshot.duplicate(true)

	func close() -> void:
		last_snapshot = {}

extends "res://tests/godot/test_case.gd"

const VALID_DIR := "res://content/examples/valid"
const SUPPORT_DIR := "res://content/examples/support"
const FORGE_SCENE := preload("res://scenes/reval_east/forge/forge.tscn")
const RunnerScript := preload("res://scripts/forge/forge_commission_runner.gd")
const PresenterScript := preload("res://scripts/forge/forge_commission_presenter.gd")

const COMMISSION_ID := &"commission.watch_buckle_repair"
const CLIENT_ID := &"char.henning"
const OBJECT_ID := &"item.watch_buckle"
const RECORD_HONEST := &"forged.watch_buckle_repair.honest_work"
const RECORD_SUBTLE := &"forged.watch_buckle_repair.subtle_defect"
const RECORD_SECRET := &"forged.watch_buckle_repair.secret_feature"
const FACT_SPEARHEAD := &"fact.seized_spearhead_seen"
const FACT_REJECTS := &"fact.rejected_blanks_missing"
const ITEM_SPEARHEAD := &"item.seized_spearhead"
const REL_HENNING_TRUST := &"rel.henning_trust"
const FLAG_WEAKENED := &"flag.watch_buckle_weakened"
const FLAG_HIDDEN_RELEASE := &"flag.watch_buckle_hidden_release"

var db: ContentDB
var state: GameState


func before_each() -> void:
	db = ContentDB.new()
	assert_true(db.load_from_directories([VALID_DIR, SUPPORT_DIR]))
	state = GameState.new()


func test_snapshot_exposes_commission_fields() -> void:
	var snapshot := ForgeCommissionModel.build_snapshot(COMMISSION_ID, state, db)
	assert_eq(snapshot.get("customer_name", ""), "Henning")
	assert_eq(snapshot.get("customer_id", &""), CLIENT_ID)
	assert_eq(snapshot.get("object_name", ""), "Watchman's buckle")
	assert_eq(snapshot.get("object_item_id", &""), OBJECT_ID)
	assert_true(String(snapshot.get("known_purpose", "")).contains("buckle"))
	assert_eq(snapshot.get("materials", ""), "Common iron")
	assert_eq((snapshot.get("discovered_leverage", []) as Array).size(), 0)


func test_discovered_leverage_appears_when_facts_are_known() -> void:
	state.set_fact(FACT_SPEARHEAD, true)
	var snapshot := ForgeCommissionModel.build_snapshot(COMMISSION_ID, state, db)
	var leverage: Array = snapshot.get("discovered_leverage", [])
	assert_eq(leverage.size(), 1)
	assert_true(String(leverage[0]).contains("spearhead"))

	state.set_fact(FACT_REJECTS, true)
	snapshot = ForgeCommissionModel.build_snapshot(COMMISSION_ID, state, db)
	leverage = snapshot.get("discovered_leverage", [])
	assert_eq(leverage.size(), 3)
	assert_true(String(leverage[2]).contains("rebel-marked iron"))


func test_runner_opens_content_defined_commission() -> void:
	var setup := _make_runner_setup()
	assert_true(setup.runner.open(COMMISSION_ID))
	assert_true(setup.runner.is_active())
	assert_eq(setup.presenter.last_snapshot.get("customer_name", ""), "Henning")
	assert_eq((setup.presenter.last_snapshot.get("forging_options", []) as Array).size(), 3)
	var enabled_count := 0
	for option_value in setup.presenter.last_snapshot.get("forging_options", []) as Array:
		if bool((option_value as Dictionary).get("enabled", false)):
			enabled_count += 1
	assert_eq(enabled_count, 1, "only honest_work should be available without facts or materials")
	_cleanup_setup(setup)


func test_forging_options_lock_until_facts_and_materials_are_known() -> void:
	var snapshot := ForgeCommissionModel.build_snapshot(COMMISSION_ID, state, db)
	var options: Array = snapshot.get("forging_options", [])
	assert_eq(options.size(), 3)
	assert_true(_option_enabled(options, "honest_work"))
	assert_false(_option_enabled(options, "subtle_defect"))
	assert_eq(_option_disabled_reason(options, "subtle_defect"), "Requires discovered leverage.")
	assert_false(_option_enabled(options, "secret_feature"))
	assert_eq(_option_disabled_reason(options, "secret_feature"), "Requires discovered leverage.")

	state.set_fact(FACT_REJECTS, true)
	snapshot = ForgeCommissionModel.build_snapshot(COMMISSION_ID, state, db)
	options = snapshot.get("forging_options", [])
	assert_true(_option_enabled(options, "subtle_defect"))

	state.set_fact(FACT_SPEARHEAD, true)
	snapshot = ForgeCommissionModel.build_snapshot(COMMISSION_ID, state, db)
	options = snapshot.get("forging_options", [])
	assert_false(_option_enabled(options, "secret_feature"))
	assert_eq(_option_disabled_reason(options, "secret_feature"), "Requires materials on hand.")

	state.add_item(ITEM_SPEARHEAD)
	snapshot = ForgeCommissionModel.build_snapshot(COMMISSION_ID, state, db)
	options = snapshot.get("forging_options", [])
	assert_true(_option_enabled(options, "secret_feature"))


func test_locked_subtle_defect_returns_option_locked() -> void:
	var setup := _make_runner_setup()
	assert_true(setup.runner.open(COMMISSION_ID))
	assert_false(setup.runner.select_option("subtle_defect"))
	assert_eq(setup.runner.get_last_result(), RunnerScript.Result.OPTION_LOCKED)
	assert_true(setup.runner.is_active())
	_cleanup_setup(setup)


func test_selecting_subtle_defect_creates_forged_record_and_applies_effects() -> void:
	state.set_fact(FACT_REJECTS, true)
	var setup := _make_runner_setup()
	assert_true(setup.runner.open(COMMISSION_ID))
	assert_true(setup.runner.select_option("subtle_defect"))
	assert_true(state.has_forged_record(RECORD_SUBTLE))
	assert_true(state.get_flag(FLAG_WEAKENED))
	var record := state.get_forged_record(RECORD_SUBTLE)
	assert_eq(record.modification_id, &"subtle_defect")
	_cleanup_setup(setup)


func test_selecting_secret_feature_creates_forged_record_and_applies_effects() -> void:
	state.set_fact(FACT_SPEARHEAD, true)
	state.add_item(ITEM_SPEARHEAD)
	var setup := _make_runner_setup()
	assert_true(setup.runner.open(COMMISSION_ID))
	assert_true(setup.runner.select_option("secret_feature"))
	assert_true(state.has_forged_record(RECORD_SECRET))
	assert_true(state.get_flag(FLAG_HIDDEN_RELEASE))
	var record := state.get_forged_record(RECORD_SECRET)
	assert_eq(record.modification_id, &"secret_feature")
	_cleanup_setup(setup)


func test_selecting_honest_work_creates_forged_record_and_applies_effects() -> void:
	var setup := _make_runner_setup()
	assert_true(setup.runner.open(COMMISSION_ID))
	assert_true(setup.runner.select_option("honest_work"))
	assert_false(setup.runner.is_active())
	assert_true(state.has_forged_record(RECORD_HONEST))
	assert_eq(state.get_relationship(REL_HENNING_TRUST), 1)

	var record := state.get_forged_record(RECORD_HONEST)
	assert_eq(record.commission_id, COMMISSION_ID)
	assert_eq(record.item_id, OBJECT_ID)
	assert_eq(record.modification_id, &"honest_work")
	_cleanup_setup(setup)


func test_resolved_commission_cannot_be_forged_again() -> void:
	var setup := _make_runner_setup()
	assert_true(setup.runner.open(COMMISSION_ID))
	assert_true(setup.runner.select_option("honest_work"))
	assert_true(setup.runner.open(COMMISSION_ID))
	assert_false(setup.runner.select_option("subtle_defect"))
	assert_eq(setup.runner.get_last_result(), RunnerScript.Result.ALREADY_RESOLVED)
	_cleanup_setup(setup)


func test_record_id_matches_save_fixture_contract() -> void:
	assert_eq(
		ForgeCommissionModel.record_id_for(COMMISSION_ID, "honest_work"),
		RECORD_HONEST
	)


func test_forge_ledger_interactable_opens_commission_overlay() -> void:
	_prepare_forge_commission_state()
	var tree := Engine.get_main_loop() as SceneTree
	var forge: Node2D = FORGE_SCENE.instantiate()
	tree.root.add_child(forge)

	var player := forge.get_node("Actors/Player") as Player
	var commission_controller := player.get_node("ForgeCommissionController") as ForgeCommissionController
	var ledger := _find_ledger_interactable(forge)
	assert_true(ledger != null, "forge needs a ledger commission interactable")

	_activate_interactable(player, ledger)
	assert_true(ledger.interact(player))
	assert_true(commission_controller.is_open())

	forge.queue_free()


func test_forge_ledger_commission_resolves_to_forged_record() -> void:
	_prepare_forge_commission_state()
	var tree := Engine.get_main_loop() as SceneTree
	var forge: Node2D = FORGE_SCENE.instantiate()
	tree.root.add_child(forge)

	var player := forge.get_node("Actors/Player") as Player
	var commission_controller := player.get_node("ForgeCommissionController") as ForgeCommissionController
	var ledger := _find_ledger_interactable(forge)
	assert_true(ledger != null)

	_activate_interactable(player, ledger)
	assert_true(ledger.interact(player))

	var overlay := player.find_child("ForgeCommissionOverlay", true, false) as ForgeCommissionOverlay
	assert_true(overlay != null)
	overlay.option_selected.emit("honest_work")

	assert_false(commission_controller.is_open())
	assert_true(SessionState.state.has_forged_record(RECORD_HONEST))
	assert_false(ledger.is_enabled(), "resolved commission should disable the ledger interactable")
	forge.queue_free()


func test_interaction_controller_blocks_while_commission_open() -> void:
	_prepare_forge_commission_state()
	var tree := Engine.get_main_loop() as SceneTree
	var forge: Node2D = FORGE_SCENE.instantiate()
	tree.root.add_child(forge)

	var player := forge.get_node("Actors/Player") as Player
	var controller := forge.get_node("InteractionController") as InteractionController
	var ledger := _find_ledger_interactable(forge)
	assert_true(ledger != null)

	_activate_interactable(player, ledger)
	assert_true(ledger.interact(player))
	controller._update_focus()
	assert_false(controller.try_interact(), "interact should stay blocked while commission overlay is open")

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


func _option_disabled_reason(options: Array, option_id: String) -> String:
	for option_value in options:
		if typeof(option_value) != TYPE_DICTIONARY:
			continue
		var option := option_value as Dictionary
		if String(option.get("id", "")) == option_id:
			return String(option.get("disabled_reason", ""))
	return ""


class _RecordingPresenter extends PresenterScript:
	var last_snapshot: Dictionary = {}

	func present_commission(snapshot: Dictionary) -> void:
		last_snapshot = snapshot.duplicate(true)

	func close() -> void:
		last_snapshot = {}

extends "res://tests/godot/test_case.gd"

## ADR 0033 / SD-12: the apprentice may do a forging option behind the master's
## back (quiet modification, substitution, concealment). The forged record and the
## option's own effects are exactly the ones the master's version writes.

const RunnerScript := preload("res://scripts/forge/forge_commission_runner.gd")
const PresenterScript := preload("res://scripts/forge/forge_commission_presenter.gd")
const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]
const BUCKLE := &"commission.watch_buckle_repair"
const LANTERN := &"commission.lantern_hook_rush"
const APPRENTICED := &"flag.prologue.apprenticed"

var db: ContentDB
var state: GameState
var runner: Node


func before_each() -> void:
	super.before_each()
	db = ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))
	state = GameState.new()
	runner = RunnerScript.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(runner)
	runner.configure(db, state, PresenterScript.new())


func after_each() -> void:
	runner.queue_free()
	super.after_each()


func _unlock_buckle_options() -> void:
	state.set_fact(&"fact.rejected_blanks_missing", true)
	state.set_fact(&"fact.seized_spearhead_seen", true)
	state.add_item(&"item.seized_spearhead")


func test_snapshot_offers_the_secret_path_only_once_apprenticed() -> void:
	var before := ForgeCommissionModel.build_snapshot(BUCKLE, state, db)
	assert_false(before["apprentice_secret_available"])
	state.set_flag(APPRENTICED, true)
	var after := ForgeCommissionModel.build_snapshot(BUCKLE, state, db)
	assert_true(after["apprentice_secret_available"])
	var methods: Dictionary = {}
	for option: Dictionary in after["forging_options"]:
		methods[option["id"]] = option["apprentice_method"]
	assert_eq(
		methods,
		{"honest_work": "", "subtle_defect": "quiet_modification", "secret_feature": "concealment"}
	)


func test_a_secret_attempt_is_refused_without_the_flag_or_a_method() -> void:
	_unlock_buckle_options()
	assert_true(runner.open(BUCKLE))
	assert_false(runner.select_option("subtle_defect", true))
	assert_eq(runner.get_last_result(), ForgeCommissionRunner.Result.SECRET_NOT_POSSIBLE)
	state.set_flag(APPRENTICED, true)
	assert_false(runner.select_option("honest_work", true), "honest work has no secret form")
	assert_eq(runner.get_last_result(), ForgeCommissionRunner.Result.SECRET_NOT_POSSIBLE)
	assert_false(ForgeCommissionModel.is_commission_resolved(state, BUCKLE))


func test_a_quiet_modification_writes_the_same_record_and_effects() -> void:
	_unlock_buckle_options()
	state.set_flag(APPRENTICED, true)
	assert_true(runner.open(BUCKLE))
	assert_true(runner.select_option("subtle_defect", true))
	var records := state.get_forged_records()
	assert_eq(records.size(), 1)
	assert_eq(records[0].record_id, &"forged.watch_buckle_repair.subtle_defect")
	assert_eq(records[0].modification_id, &"subtle_defect")
	assert_true(state.get_flag(&"flag.watch_buckle_weakened"), "same downstream consequence")
	assert_true(state.get_flag(&"flag.forge.secret.watch_buckle_repair.quiet_modification"))


func test_the_master_version_leaves_no_secret_mark() -> void:
	_unlock_buckle_options()
	state.set_flag(APPRENTICED, true)
	assert_true(runner.open(BUCKLE))
	assert_true(runner.select_option("subtle_defect"))
	assert_true(state.get_flag(&"flag.watch_buckle_weakened"))
	assert_false(state.get_flag(&"flag.forge.secret.watch_buckle_repair.quiet_modification"))


func test_substitution_and_concealment_are_authored_on_other_commissions() -> void:
	state.set_flag(APPRENTICED, true)
	var lantern := ForgeCommissionModel.build_snapshot(LANTERN, state, db)
	var by_id: Dictionary = {}
	for option: Dictionary in lantern["forging_options"]:
		by_id[option["id"]] = option["apprentice_method"]
	assert_eq(by_id["subtle_defect"], "substitution")
	assert_eq(
		ForgeCommissionModel.secret_flag_for(LANTERN, "substitution"),
		&"flag.forge.secret.lantern_hook_rush.substitution"
	)
	var brew := ForgeCommissionModel.build_snapshot(&"commission.bitter_brew", state, db)
	var brew_methods: Array = []
	for option: Dictionary in brew["forging_options"]:
		brew_methods.append(option["apprentice_method"])
	assert_eq(brew_methods, ["", "quiet_modification", "concealment"])


func test_the_overlay_offers_a_quiet_button_only_when_available() -> void:
	var overlay := ForgeCommissionOverlay.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(overlay)
	var secret_calls: Array[String] = []
	overlay.secret_option_selected.connect(func(option_id: String) -> void: secret_calls.append(option_id))
	_unlock_buckle_options()
	overlay.present_commission(ForgeCommissionModel.build_snapshot(BUCKLE, state, db))
	var plain := overlay._option_buttons.size()
	state.set_flag(APPRENTICED, true)
	overlay.present_commission(ForgeCommissionModel.build_snapshot(BUCKLE, state, db))
	assert_eq(overlay._option_buttons.size(), plain + 2, "one quiet button for each secret-capable option")
	var quiet: Button
	for button: Button in overlay._option_buttons:
		if String(button.get_meta(&"option_id", "")) == "subtle_defect.secret":
			quiet = button
	assert_true(quiet != null)
	quiet.pressed.emit()
	assert_eq(secret_calls, ["subtle_defect"])
	overlay.free()


func test_the_ui_presenter_routes_the_quiet_button_to_the_runner() -> void:
	var overlay := ForgeCommissionOverlay.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(overlay)
	var presenter := ForgeCommissionUiPresenter.new()
	presenter.configure(overlay, runner)
	runner.configure(db, state, presenter)
	_unlock_buckle_options()
	state.set_flag(APPRENTICED, true)
	assert_true(runner.open(BUCKLE))
	overlay.secret_option_selected.emit("secret_feature")
	assert_true(state.get_flag(&"flag.forge.secret.watch_buckle_repair.concealment"))
	assert_true(state.get_flag(&"flag.watch_buckle_hidden_release"))
	overlay.free()

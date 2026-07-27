extends "res://tests/godot/test_case.gd"

const ModelScript := preload("res://scripts/quest/st_georges_night_quest_model.gd")
const AftermathModelScript := preload(
	"res://scripts/investigation/st_georges_night_aftermath_model.gd"
)
const ClimaxScript := preload("res://scripts/investigation/st_georges_night_climax.gd")
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const LOWER_TOWN_SCENE := preload("res://scenes/reval_east/reval_east.tscn")
const LOWER_TOWN_DEFINITION := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const PLAYER_SCENE := preload("res://player.tscn")

const FLAG_SEAL_BIAS := &"flag.act_climax_viru_seal"
const FLAG_BREAK_BIAS := &"flag.act_climax_viru_break"
const FLAG_OPEN_BIAS := &"flag.act_climax_viru_open"


func before_each() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(ModelScript.CONTENT_DIRS))
	SessionState.content_db = db
	SessionState.state = GameState.new()
	SessionState.state.bag.set_content_db(db)


func test_branch_matrix_sets_three_act_boundary_flags() -> void:
	_assert_branch(
		FLAG_SEAL_BIAS,
		ModelScript.STATE_AFTERMATH_SEAL,
		&"flag.act_boundary.viru_seal",
		ModelScript.TRANSITION_COMMIT_SEAL
	)
	_assert_branch(
		FLAG_BREAK_BIAS,
		ModelScript.STATE_AFTERMATH_BREAK,
		&"flag.act_boundary.viru_break",
		ModelScript.TRANSITION_COMMIT_BREAK
	)
	_assert_branch(
		FLAG_OPEN_BIAS,
		ModelScript.STATE_AFTERMATH_OPEN,
		&"flag.act_boundary.viru_open",
		ModelScript.TRANSITION_COMMIT_OPEN
	)


func test_mechanism_maps_climax_bias_to_gate_behavior() -> void:
	_assert_mechanism_behavior(FLAG_SEAL_BIAS, "hold")
	_assert_mechanism_behavior(FLAG_BREAK_BIAS, "fail")
	_assert_mechanism_behavior(FLAG_OPEN_BIAS, "release")


func test_climax_choice_records_act_transition_for_each_family() -> void:
	_assert_climax_choice(&"seal", &"flag.act_boundary.viru_seal")
	_assert_climax_choice(&"break", &"flag.act_boundary.viru_break")
	_assert_climax_choice(&"open", &"flag.act_boundary.viru_open")


func test_aftermath_barks_differ_by_act_boundary_family() -> void:
	_prepare_terminal_state(FLAG_SEAL_BIAS, ModelScript.STATE_AFTERMATH_SEAL)
	var runner := RunnerScript.new()
	runner.configure(SessionState.content_db, SessionState.state, null)
	var seal_bark := runner.resolve_bark(
		AftermathModelScript.BARK_POOL,
		ModelScript.PHASE_ACT1_CLIMAX,
		&"loc.lower_town_slice"
	)

	_prepare_terminal_state(FLAG_BREAK_BIAS, ModelScript.STATE_AFTERMATH_BREAK)
	runner.configure(SessionState.content_db, SessionState.state, null)
	var break_bark := runner.resolve_bark(
		AftermathModelScript.BARK_POOL,
		ModelScript.PHASE_ACT1_CLIMAX,
		&"loc.lower_town_slice"
	)

	assert_ne(String(seal_bark.get("text", "")), String(break_bark.get("text", "")))


func _assert_branch(
	bias_flag: StringName,
	expected_state: StringName,
	expected_boundary_flag: StringName,
	transition_id: StringName
) -> void:
	var state := GameState.new()
	var manager := QuestManager.new(SessionState.content_db, state, StateRuleEvaluator.new())
	assert_true(manager.start_quest(ModelScript.QUEST_ID))
	assert_true(manager.transition(ModelScript.QUEST_ID, ModelScript.TRANSITION_BEGIN_APPROACH))
	state.set_flag(bias_flag, true)
	assert_true(
		AftermathModelScript.commit_climax_choice(
			state, SessionState.content_db, transition_id
		)
	)
	assert_eq(state.get_quest_state(ModelScript.QUEST_ID), expected_state)
	assert_true(state.get_flag(expected_boundary_flag))
	assert_true(state.get_flag(&"flag.act_transition.act1_recorded"))


func _assert_mechanism_behavior(bias_flag: StringName, expected_behavior: String) -> void:
	var state := GameState.new()
	state.set_flag(bias_flag, true)
	var resolver := MechanismResolver.new(SessionState.content_db, state)
	var snapshot := resolver.resolve(&"mechanism.st_georges_night_gate")
	assert_eq(String(snapshot.get("behavior", "")), expected_behavior)


func _assert_climax_choice(choice: StringName, expected_boundary_flag: StringName) -> void:
	_prepare_approach_state(choice)
	var climax := _make_climax_host()
	climax.arm_choice_for_test()
	assert_true(climax.commit_choice_for_test(choice))
	assert_true(SessionState.state.get_flag(expected_boundary_flag))
	assert_true(SessionState.state.get_flag(&"flag.act_transition.act1_recorded"))
	_free_scene(climax.get_parent())


func _prepare_approach_state(choice: StringName) -> void:
	SessionState.state = GameState.new()
	SessionState.state.bag.set_content_db(SessionState.content_db)
	SessionState.state.set_phase(ModelScript.PHASE_ACT1_CLIMAX)
	match choice:
		&"seal":
			SessionState.state.set_flag(FLAG_SEAL_BIAS, true)
		&"break":
			SessionState.state.set_flag(FLAG_BREAK_BIAS, true)
		&"open":
			SessionState.state.set_flag(FLAG_OPEN_BIAS, true)


func _prepare_terminal_state(bias_flag: StringName, terminal_state: StringName) -> void:
	SessionState.state = GameState.new()
	SessionState.state.bag.set_content_db(SessionState.content_db)
	SessionState.state.set_phase(ModelScript.PHASE_ACT1_CLIMAX)
	SessionState.state.set_flag(bias_flag, true)
	SessionState.state.set_quest_state(ModelScript.QUEST_ID, terminal_state)
	match bias_flag:
		FLAG_SEAL_BIAS:
			SessionState.state.set_flag(&"flag.act_boundary.viru_seal", true)
		FLAG_BREAK_BIAS:
			SessionState.state.set_flag(&"flag.act_boundary.viru_break", true)
		FLAG_OPEN_BIAS:
			SessionState.state.set_flag(&"flag.act_boundary.viru_open", true)


func _make_climax_host() -> Node:
	var host := Node2D.new()
	host.name = "StGeorgesClimaxTestHost"
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(host)
	var climax := ClimaxScript.new()
	host.add_child(climax)
	climax.setup(host, LOWER_TOWN_DEFINITION.create())
	return climax


func _free_scene(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.free()

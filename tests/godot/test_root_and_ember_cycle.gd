extends "res://tests/godot/test_case.gd"

const ModelScript := preload("res://scripts/quest/root_and_ember_quest_model.gd")
const AftermathModelScript := preload(
	"res://scripts/investigation/root_and_ember_aftermath_model.gd"
)
const InvestigationScript := preload(
	"res://scripts/investigation/root_and_ember_investigation.gd"
)
const InstallScript := preload(
	"res://scripts/investigation/root_and_ember_install_consequence.gd"
)
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const LOWER_TOWN_SCENE := preload("res://scenes/reval_east/reval_east.tscn")
const LOWER_TOWN_DEFINITION := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)

const FACT_ELLEN := &"fact.root_and_ember.ellen_summoned"
const FACT_HEARTH := &"fact.root_and_ember.soot_updraft"
const FACT_HERBS := &"fact.root_and_ember.herb_lane_roots"

const SITE_ELLEN := &"interact.root_and_ember.ellen_request"
const SITE_HEARTH := &"interact.root_and_ember.disturbed_hearth"
const SITE_HERBS := &"interact.root_and_ember.herb_lane"

const RECORD_EMBER := &"forged.root_and_ember.ember_rite"
const RECORD_ROOT := &"forged.root_and_ember.root_ward"
const RECORD_IRON := &"forged.root_and_ember.iron_bracket"


func before_each() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(ModelScript.CONTENT_DIRS))
	SessionState.content_db = db
	SessionState.state = GameState.new()
	SessionState.state.bag.set_content_db(db)


func test_branch_matrix_sets_three_ellen_flags() -> void:
	_assert_branch(
		RECORD_EMBER,
		ModelScript.STATE_AFTERMATH_EMBER,
		&"flag.ellen.belief_honored"
	)
	_assert_branch(
		RECORD_ROOT,
		ModelScript.STATE_AFTERMATH_ROOT,
		&"flag.ellen.remedy_trusted"
	)
	_assert_branch(
		RECORD_IRON,
		ModelScript.STATE_AFTERMATH_IRON,
		&"flag.ellen.skepticism_respected"
	)


func test_technique_mapping_for_ember_and_root() -> void:
	assert_eq(ModelScript.technique_for_modification(&"ember_rite"), ForgeTechnique.ID_EMBER)
	assert_eq(ModelScript.technique_for_modification(&"root_ward"), ForgeTechnique.ID_ROOT)
	assert_true(ModelScript.technique_for_modification(&"iron_bracket").is_empty())


func test_investigation_records_facts_and_completes_quest() -> void:
	_prepare_investigation_state()
	var east := await _spawn_lower_town()
	var investigation := east.get_node_or_null("RootAndEmberInvestigation")
	assert_true(investigation != null)

	_inspect_site(investigation, SITE_ELLEN, FACT_ELLEN)
	_inspect_site(investigation, SITE_HEARTH, FACT_HEARTH)
	_inspect_site(investigation, SITE_HERBS, FACT_HERBS)

	assert_eq(
		SessionState.state.get_quest_state(ModelScript.QUEST_ID),
		ModelScript.STATE_INVESTIGATION_READY
	)
	_free_scene(east)


func test_install_commits_mechanism_and_aftermath_barks_differ() -> void:
	_prepare_aftermath_state(RECORD_EMBER)
	var install := _make_install_host()
	assert_true(install.commit_install_for_test())
	assert_true(SessionState.state.get_flag(&"flag.ellen.belief_honored"))

	var runner := RunnerScript.new()
	runner.configure(SessionState.content_db, SessionState.state, null)
	var ember_bark := runner.resolve_bark(
		AftermathModelScript.BARK_POOL,
		GameState.PHASE_REFLECTION_MORNING,
		&"loc.lower_town_slice"
	)

	_prepare_aftermath_state(RECORD_IRON)
	install = _make_install_host()
	assert_true(install.commit_install_for_test())
	runner.configure(SessionState.content_db, SessionState.state, null)
	var iron_bark := runner.resolve_bark(
		AftermathModelScript.BARK_POOL,
		GameState.PHASE_REFLECTION_MORNING,
		&"loc.lower_town_slice"
	)
	assert_ne(String(ember_bark.get("text", "")), String(iron_bark.get("text", "")))
	_free_scene(install.get_parent())


func _assert_branch(
	record_id: StringName,
	expected_state: StringName,
	expected_flag: StringName
) -> void:
	var state := GameState.new()
	var manager := QuestManager.new(SessionState.content_db, state, StateRuleEvaluator.new())
	assert_true(manager.start_quest(ModelScript.QUEST_ID))
	assert_true(manager.transition(ModelScript.QUEST_ID, ModelScript.TRANSITION_COMPLETE))
	var modification := StringName(String(record_id).get_slice(".", 2))
	var transition_id := ModelScript.transition_for_modification(modification)
	assert_true(manager.transition(ModelScript.QUEST_ID, transition_id))
	assert_eq(state.get_quest_state(ModelScript.QUEST_ID), expected_state)
	assert_true(state.get_flag(expected_flag))


func _prepare_investigation_state() -> void:
	SessionState.state = GameState.new()
	SessionState.state.bag.set_content_db(SessionState.content_db)
	SessionState.state.set_flag(ModelScript.UNLOCK_FLAG, true)
	SessionState.state.set_phase(GameState.PHASE_REFLECTION_MORNING)


func _prepare_aftermath_state(record_id: StringName) -> void:
	SessionState.state = GameState.new()
	SessionState.state.bag.set_content_db(SessionState.content_db)
	SessionState.state.set_flag(ModelScript.UNLOCK_FLAG, true)
	SessionState.state.set_phase(GameState.PHASE_REFLECTION_MORNING)
	var modification := StringName(String(record_id).get_slice(".", 2))
	SessionState.state.add_forged_record(
		ForgedRecord.new(
			record_id,
			ModelScript.COMMISSION_ID,
			&"item.root_and_ember_work",
			modification
		)
	)
	match modification:
		&"ember_rite":
			SessionState.state.set_quest_state(
				ModelScript.QUEST_ID, ModelScript.STATE_AFTERMATH_EMBER
			)
			SessionState.state.set_flag(&"flag.root_and_ember_ember_rite", true)
			SessionState.state.set_flag(&"flag.ellen.belief_honored", true)
		&"root_ward":
			SessionState.state.set_quest_state(
				ModelScript.QUEST_ID, ModelScript.STATE_AFTERMATH_ROOT
			)
			SessionState.state.set_flag(&"flag.root_and_ember_root_ward", true)
			SessionState.state.set_flag(&"flag.ellen.remedy_trusted", true)
		&"iron_bracket":
			SessionState.state.set_quest_state(
				ModelScript.QUEST_ID, ModelScript.STATE_AFTERMATH_IRON
			)
			SessionState.state.set_flag(&"flag.root_and_ember_iron_bracket", true)
			SessionState.state.set_flag(&"flag.ellen.skepticism_respected", true)


func _spawn_lower_town() -> Node:
	var east: Node = LOWER_TOWN_SCENE.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(east)
	await east.ready
	return east


func _inspect_site(
	investigation: Node,
	site_id: StringName,
	expected_fact: StringName
) -> void:
	assert_true(investigation.inspect_site_for_test(site_id))
	var runner := investigation.get_node("RootAndEmberDialogueRunner")
	while runner.is_active():
		investigation.advance_dialogue_for_test()
	assert_true(SessionState.state.get_fact(expected_fact))


func _make_install_host() -> Node:
	var host := Node2D.new()
	host.name = "RootInstallTestHost"
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(host)
	var install := InstallScript.new()
	host.add_child(install)
	install.setup(host, LOWER_TOWN_DEFINITION.create())
	return install


func _free_scene(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.free()

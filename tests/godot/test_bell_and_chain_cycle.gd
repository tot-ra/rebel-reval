extends "res://tests/godot/test_case.gd"

const ModelScript := preload("res://scripts/quest/bell_and_chain_quest_model.gd")
const AftermathModelScript := preload(
	"res://scripts/investigation/bell_and_chain_aftermath_model.gd"
)
const InvestigationScript := preload(
	"res://scripts/investigation/bell_and_chain_investigation.gd"
)
const NightScript := preload(
	"res://scripts/investigation/bell_and_chain_night_consequence.gd"
)
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const LOWER_TOWN_SCENE := preload("res://scenes/reval_east/reval_east.tscn")
const LOWER_TOWN_DEFINITION := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const PLAYER_SCENE := preload("res://player.tscn")

const FACT_PORTCULLIS := &"fact.bell_and_chain.portcullis_wear"
const FACT_PATROL := &"fact.bell_and_chain.patrol_rotation"
const FACT_STRIKER := &"fact.bell_and_chain.striker_stress"
const FACT_REBEL := &"fact.bell_and_chain.rebel_gate_map"

const SITE_PORTCULLIS := &"interact.bell_and_chain.portcullis"
const SITE_PATROL := &"interact.bell_and_chain.patrol_log"
const SITE_STRIKER := &"interact.bell_and_chain.striker"
const SITE_REBEL := &"interact.bell_and_chain.rebel_marks"

const RECORD_HONEST := &"forged.bell_and_chain.honest_work"
const RECORD_DEFECT := &"forged.bell_and_chain.subtle_defect"
const RECORD_RELEASE := &"forged.bell_and_chain.secret_feature"


func before_each() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(ModelScript.CONTENT_DIRS))
	SessionState.content_db = db
	SessionState.state = GameState.new()
	SessionState.state.bag.set_content_db(db)


func test_branch_matrix_sets_three_act_climax_flags() -> void:
	_assert_branch(
		RECORD_HONEST,
		ModelScript.STATE_AFTERMATH_HONEST,
		&"flag.act_climax_viru_seal"
	)
	_assert_branch(
		RECORD_DEFECT,
		ModelScript.STATE_AFTERMATH_DEFECT,
		&"flag.act_climax_viru_break"
	)
	_assert_branch(
		RECORD_RELEASE,
		ModelScript.STATE_AFTERMATH_RELEASE,
		&"flag.act_climax_viru_open"
	)


func test_mechanism_maps_forged_modifications_to_gate_behavior() -> void:
	_assert_mechanism_behavior(RECORD_HONEST, "hold")
	_assert_mechanism_behavior(RECORD_DEFECT, "fail")
	_assert_mechanism_behavior(RECORD_RELEASE, "release")


func test_investigation_records_facts_and_completes_quest() -> void:
	_prepare_investigation_state()
	var east := await _spawn_lower_town()
	var investigation := east.get_node_or_null("BellAndChainInvestigation")
	assert_true(investigation != null)

	await _inspect_site(investigation, SITE_PORTCULLIS, FACT_PORTCULLIS)
	await _inspect_site(investigation, SITE_PATROL, FACT_PATROL)
	await _inspect_site(investigation, SITE_STRIKER, FACT_STRIKER)
	await _inspect_site(investigation, SITE_REBEL, FACT_REBEL)

	assert_eq(
		SessionState.state.get_quest_state(ModelScript.QUEST_ID),
		ModelScript.STATE_INVESTIGATION_READY
	)
	_free_scene(east)


func test_night_install_commits_mechanism_and_aftermath_barks_differ() -> void:
	_prepare_aftermath_state(RECORD_HONEST)
	var night := _make_night_host()
	night.arm_encounter_for_test()
	assert_true(night.resolve_encounter_outcome(EncounterOutcome.KIND_SURRENDER))
	assert_true(SessionState.state.get_flag(&"flag.act_climax_viru_seal"))

	var runner := RunnerScript.new()
	runner.configure(SessionState.content_db, SessionState.state, null)
	var honest_bark := runner.resolve_bark(
		AftermathModelScript.BARK_POOL,
		GameState.PHASE_CONSEQUENCE_NIGHT,
		&"loc.lower_town_slice"
	)

	_prepare_aftermath_state(RECORD_DEFECT)
	night = _make_night_host()
	night.arm_encounter_for_test()
	assert_true(night.resolve_encounter_outcome(EncounterOutcome.KIND_SURRENDER))
	runner.configure(SessionState.content_db, SessionState.state, null)
	var defect_bark := runner.resolve_bark(
		AftermathModelScript.BARK_POOL,
		GameState.PHASE_CONSEQUENCE_NIGHT,
		&"loc.lower_town_slice"
	)
	assert_ne(String(honest_bark.get("text", "")), String(defect_bark.get("text", "")))
	_free_scene(night.get_parent())


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


func _assert_mechanism_behavior(record_id: StringName, expected_behavior: String) -> void:
	var state := GameState.new()
	state.add_forged_record(
		ForgedRecord.new(
			record_id,
			ModelScript.COMMISSION_ID,
			&"item.bell_and_chain_work",
			StringName(String(record_id).get_slice(".", 2))
		)
	)
	var resolver := MechanismResolver.new(SessionState.content_db, state)
	var snapshot := resolver.resolve(&"mechanism.bell_and_chain_gate")
	assert_eq(String(snapshot.get("behavior", "")), expected_behavior)


func _prepare_investigation_state() -> void:
	SessionState.state = GameState.new()
	SessionState.state.bag.set_content_db(SessionState.content_db)
	SessionState.state.set_flag(ModelScript.UNLOCK_FLAG, true)
	SessionState.state.set_phase(GameState.PHASE_CONSEQUENCE_NIGHT)


func _prepare_aftermath_state(record_id: StringName) -> void:
	SessionState.state = GameState.new()
	SessionState.state.bag.set_content_db(SessionState.content_db)
	SessionState.state.set_flag(ModelScript.UNLOCK_FLAG, true)
	SessionState.state.set_phase(GameState.PHASE_CONSEQUENCE_NIGHT)
	var modification := StringName(String(record_id).get_slice(".", 2))
	SessionState.state.add_forged_record(
		ForgedRecord.new(
			record_id,
			ModelScript.COMMISSION_ID,
			&"item.bell_and_chain_work",
			modification
		)
	)
	match modification:
		&"honest_work":
			SessionState.state.set_quest_state(
				ModelScript.QUEST_ID, ModelScript.STATE_AFTERMATH_HONEST
			)
			SessionState.state.set_flag(&"flag.gate_chain_honest_work", true)
		&"subtle_defect":
			SessionState.state.set_quest_state(
				ModelScript.QUEST_ID, ModelScript.STATE_AFTERMATH_DEFECT
			)
			SessionState.state.set_flag(&"flag.gate_chain_subtle_defect", true)
		&"secret_feature":
			SessionState.state.set_quest_state(
				ModelScript.QUEST_ID, ModelScript.STATE_AFTERMATH_RELEASE
			)
			SessionState.state.set_flag(&"flag.gate_chain_secret_feature", true)


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
	var runner := investigation.get_node("BellAndChainDialogueRunner")
	while runner.is_active():
		investigation.advance_dialogue_for_test()
	assert_true(SessionState.state.get_fact(expected_fact))


func _make_night_host() -> Node:
	var host := Node2D.new()
	host.name = "BellNightTestHost"
	var actors := Node2D.new()
	actors.name = "Actors"
	host.add_child(actors)
	var player := PLAYER_SCENE.instantiate() as Player
	actors.add_child(player)
	var definition: MapDefinition = LOWER_TOWN_DEFINITION.create()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(host)
	var night := NightScript.new()
	host.add_child(night)
	night.setup(host, definition, player, actors)
	return night


func _free_scene(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.free()

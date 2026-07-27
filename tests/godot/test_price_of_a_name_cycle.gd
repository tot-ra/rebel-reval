extends "res://tests/godot/test_case.gd"

const ModelScript := preload("res://scripts/quest/price_of_a_name_quest_model.gd")
const AftermathModelScript := preload(
	"res://scripts/investigation/price_of_a_name_aftermath_model.gd"
)
const InvestigationScript := preload(
	"res://scripts/investigation/price_of_a_name_investigation.gd"
)
const InstallScript := preload(
	"res://scripts/investigation/price_of_a_name_install_consequence.gd"
)
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const LOWER_TOWN_SCENE := preload("res://scenes/reval_east/reval_east.tscn")
const LOWER_TOWN_DEFINITION := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const PLAYER_SCENE := preload("res://player.tscn")

const FACT_WATCH_TOWER := &"fact.price_of_a_name.dispatch_name"
const FACT_SALT_WAREHOUSE := &"fact.price_of_a_name.salt_warehouse_drop"
const FACT_PACKHOUSE := &"fact.price_of_a_name.packhouse_spears"
const FACT_ROPEWALK := &"fact.price_of_a_name.ropewalk_route"

const SITE_WATCH_TOWER := &"interact.price_of_a_name.watch_tower"
const SITE_SALT_WAREHOUSE := &"interact.price_of_a_name.salt_warehouse"
const SITE_PACKHOUSE := &"interact.price_of_a_name.packhouse_lane"
const SITE_ROPEWALK := &"interact.price_of_a_name.ropewalk_lane"

const RECORD_HONEST := &"forged.price_of_a_name.honest_work"
const RECORD_DEFECT := &"forged.price_of_a_name.subtle_defect"
const RECORD_RELEASE := &"forged.price_of_a_name.secret_feature"


func before_each() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(ModelScript.CONTENT_DIRS))
	SessionState.content_db = db
	SessionState.state = GameState.new()
	SessionState.state.bag.set_content_db(db)


func test_branch_matrix_sets_three_mart_name_flags() -> void:
	_assert_branch(
		RECORD_HONEST,
		ModelScript.STATE_AFTERMATH_CLEARED,
		&"flag.mart.name_cleared"
	)
	_assert_branch(
		RECORD_DEFECT,
		ModelScript.STATE_AFTERMATH_REDIRECTED,
		&"flag.mart.name_redirected"
	)
	_assert_branch(
		RECORD_RELEASE,
		ModelScript.STATE_AFTERMATH_CONCEALED,
		&"flag.mart.name_concealed"
	)


func test_mechanism_maps_forged_modifications_to_detention_behavior() -> void:
	_assert_mechanism_behavior(RECORD_HONEST, "hold")
	_assert_mechanism_behavior(RECORD_DEFECT, "jam")
	_assert_mechanism_behavior(RECORD_RELEASE, "release")


func test_investigation_records_facts_and_completes_quest() -> void:
	_prepare_investigation_state()
	var east := await _spawn_lower_town()
	var investigation := east.get_node_or_null("PriceOfANameInvestigation")
	assert_true(investigation != null)

	await _inspect_site(investigation, SITE_WATCH_TOWER, FACT_WATCH_TOWER)
	await _inspect_site(investigation, SITE_SALT_WAREHOUSE, FACT_SALT_WAREHOUSE)
	await _inspect_site(investigation, SITE_PACKHOUSE, FACT_PACKHOUSE)
	await _inspect_site(investigation, SITE_ROPEWALK, FACT_ROPEWALK)

	assert_eq(
		SessionState.state.get_quest_state(ModelScript.QUEST_ID),
		ModelScript.STATE_INVESTIGATION_READY
	)
	_free_scene(east)


func test_install_commits_mechanism_and_aftermath_barks_differ() -> void:
	_prepare_aftermath_state(RECORD_HONEST)
	var install := _make_install_host()
	install.arm_encounter_for_test()
	assert_true(install.resolve_encounter_outcome(EncounterOutcome.KIND_SURRENDER))
	assert_true(SessionState.state.get_flag(&"flag.mart.name_cleared"))

	var runner := RunnerScript.new()
	runner.configure(SessionState.content_db, SessionState.state, null)
	var honest_bark := runner.resolve_bark(
		AftermathModelScript.BARK_POOL,
		GameState.PHASE_REFLECTION_MORNING,
		&"loc.lower_town_slice"
	)

	_prepare_aftermath_state(RECORD_DEFECT)
	install = _make_install_host()
	install.arm_encounter_for_test()
	assert_true(install.resolve_encounter_outcome(EncounterOutcome.KIND_SURRENDER))
	runner.configure(SessionState.content_db, SessionState.state, null)
	var defect_bark := runner.resolve_bark(
		AftermathModelScript.BARK_POOL,
		GameState.PHASE_REFLECTION_MORNING,
		&"loc.lower_town_slice"
	)
	assert_ne(String(honest_bark.get("text", "")), String(defect_bark.get("text", "")))
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


func _assert_mechanism_behavior(record_id: StringName, expected_behavior: String) -> void:
	var state := GameState.new()
	state.add_forged_record(
		ForgedRecord.new(
			record_id,
			ModelScript.COMMISSION_ID,
			&"item.price_of_a_name_work",
			StringName(String(record_id).get_slice(".", 2))
		)
	)
	var resolver := MechanismResolver.new(SessionState.content_db, state)
	var snapshot := resolver.resolve(&"mechanism.price_of_a_name_detention")
	assert_eq(String(snapshot.get("behavior", "")), expected_behavior)


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
			&"item.price_of_a_name_work",
			modification
		)
	)
	match modification:
		&"honest_work":
			SessionState.state.set_quest_state(
				ModelScript.QUEST_ID, ModelScript.STATE_AFTERMATH_CLEARED
			)
			SessionState.state.set_flag(&"flag.price_of_a_name_honest_work", true)
			SessionState.state.set_flag(&"flag.mart.name_cleared", true)
		&"subtle_defect":
			SessionState.state.set_quest_state(
				ModelScript.QUEST_ID, ModelScript.STATE_AFTERMATH_REDIRECTED
			)
			SessionState.state.set_flag(&"flag.price_of_a_name_subtle_defect", true)
			SessionState.state.set_flag(&"flag.mart.name_redirected", true)
		&"secret_feature":
			SessionState.state.set_quest_state(
				ModelScript.QUEST_ID, ModelScript.STATE_AFTERMATH_CONCEALED
			)
			SessionState.state.set_flag(&"flag.price_of_a_name_secret_feature", true)
			SessionState.state.set_flag(&"flag.mart.name_concealed", true)


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
	var runner := investigation.get_node("PriceOfANameDialogueRunner")
	while runner.is_active():
		investigation.advance_dialogue_for_test()
	assert_true(SessionState.state.get_fact(expected_fact))


func _make_install_host() -> Node:
	var host := Node2D.new()
	host.name = "PriceInstallTestHost"
	var actors := Node2D.new()
	actors.name = "Actors"
	host.add_child(actors)
	var player := PLAYER_SCENE.instantiate() as Player
	actors.add_child(player)
	var definition: MapDefinition = LOWER_TOWN_DEFINITION.create()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(host)
	var install := InstallScript.new()
	host.add_child(install)
	install.setup(host, definition, player, actors)
	return install


func _free_scene(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.free()

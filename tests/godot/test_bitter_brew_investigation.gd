extends "res://tests/godot/test_case.gd"

const VALID_DIR := "res://content/examples/valid"
const SUPPORT_DIR := "res://content/examples/support"
const LOWER_TOWN_SCENE := preload("res://scenes/reval_east/reval_east.tscn")
const InvestigationScript := preload("res://scripts/investigation/bitter_brew_investigation.gd")

const QUEST_ID := &"quest.bitter_brew"
const STATE_INVESTIGATING := &"investigating"
const STATE_INVESTIGATION_READY := &"investigation_ready"

const FACT_CISTERN := &"fact.bitter_brew.cistern_contaminated"
const FACT_BREWERY := &"fact.bitter_brew.brewery_ale_sound"
const FACT_SUPPLY := &"fact.bitter_brew.merchant_supply_spoiled"
const FACT_CHECKPOINT := &"fact.bitter_brew.checkpoint_neglect"

const SITE_CISTERN := &"interact.bitter_brew.cistern"
const SITE_BREWERY := &"interact.bitter_brew.brewery"
const SITE_SUPPLY := &"interact.bitter_brew.supply"
const SITE_CHECKPOINT := &"interact.bitter_brew.checkpoint"


func test_bitter_brew_quest_content_defines_four_evidence_facts() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories([VALID_DIR, SUPPORT_DIR]))
	var quest := db.get_quest(QUEST_ID)
	assert_false(quest.is_empty())
	assert_eq(String(quest.get("initial_state", "")), "investigating")
	var evidence: Array = quest.get("journal_evidence", [])
	assert_eq(evidence.size(), 4)
	for dialogue_id in [
		&"dialogue.bitter_brew.inspect_cistern",
		&"dialogue.bitter_brew.inspect_brewery",
		&"dialogue.bitter_brew.inspect_supply",
		&"dialogue.bitter_brew.inspect_checkpoint",
	]:
		assert_false(db.get_dialogue(dialogue_id).is_empty())


func test_investigation_records_each_site_and_completes_quest() -> void:
	_prepare_investigation_state()
	var east := await _spawn_lower_town()
	var investigation := _find_investigation(east)
	assert_true(investigation != null)
	assert_eq(SessionState.state.get_quest_state(QUEST_ID), STATE_INVESTIGATING)

	await _inspect_site(investigation, SITE_CISTERN, FACT_CISTERN)
	await _inspect_site(investigation, SITE_BREWERY, FACT_BREWERY)
	await _inspect_site(investigation, SITE_SUPPLY, FACT_SUPPLY)
	await _inspect_site(investigation, SITE_CHECKPOINT, FACT_CHECKPOINT)

	assert_eq(SessionState.state.get_quest_state(QUEST_ID), STATE_INVESTIGATION_READY)

	var snapshot := JournalModel.build_snapshot(SessionState.state, SessionState.content_db)
	assert_eq((snapshot.get("evidence", []) as Array).size(), 4)
	_free_scene(east)


func test_inspected_sites_disable_until_quest_resets() -> void:
	_prepare_investigation_state()
	var east := await _spawn_lower_town()
	var investigation := _find_investigation(east)
	await _inspect_site(investigation, SITE_CISTERN, FACT_CISTERN)

	var cistern: Interactable = investigation.get_interactable(SITE_CISTERN)
	assert_true(cistern != null)
	assert_false(cistern.is_enabled(), "inspected site must disable re-use")
	_free_scene(east)


func _prepare_investigation_state() -> void:
	if not SessionState.content_db.is_loaded():
		assert_true(SessionState.content_db.load_from_directories([VALID_DIR, SUPPORT_DIR]))
	SessionState.state = GameState.new()
	SessionState.state.bag.set_content_db(SessionState.content_db)
	SessionState.state.set_phase(GameState.PHASE_INVESTIGATION_MORNING)


func _spawn_lower_town() -> Node:
	var east: Node = LOWER_TOWN_SCENE.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(east)
	await east.ready
	return east


func _find_investigation(east: Node) -> Node:
	return east.get_node_or_null("BitterBrewInvestigation")


func _inspect_site(
	investigation: Node,
	site_id: StringName,
	expected_fact: StringName
) -> void:
	assert_true(investigation.inspect_site_for_test(site_id))
	var runner := investigation.get_node("BitterBrewDialogueRunner")
	while runner.is_active():
		investigation.advance_dialogue_for_test()
	assert_true(SessionState.state.get_fact(expected_fact))


func _free_scene(node: Node) -> void:
	node.free()

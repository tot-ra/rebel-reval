extends "res://tests/godot/test_case.gd"

const VALID_DIR := "res://content/examples/valid"
const SUPPORT_DIR := "res://content/examples/support"
const LOWER_TOWN_DEFINITION := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const PLAYER_SCENE := preload("res://player.tscn")
const MODEL := preload("res://scripts/investigation/bitter_brew_aftermath_model.gd")
const AftermathScript := preload("res://scripts/investigation/bitter_brew_aftermath.gd")
const NightConsequenceScript := preload(
	"res://scripts/investigation/bitter_brew_night_consequence.gd"
)
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")

const QUEST_ID := &"quest.bitter_brew"
const COMMISSION_ID := &"commission.bitter_brew"
const RECORD_HONEST := &"forged.bitter_brew.honest_work"
const RECORD_SUBTLE := &"forged.bitter_brew.subtle_defect"
const RECORD_SECRET := &"forged.bitter_brew.secret_feature"


func test_mechanism_commits_three_distinct_aftermath_families() -> void:
	_assert_aftermath_family(RECORD_HONEST, MODEL.OUTCOME_EXONERATED, &"brewery_independent", true)
	_assert_aftermath_family(RECORD_SECRET, MODEL.OUTCOME_ESCAPED, &"brewery_confiscated", false)
	_assert_aftermath_family(RECORD_SUBTLE, MODEL.OUTCOME_MONOPOLIZED, &"brewery_corporatized", false)


func test_mart_brewery_and_patrol_content_differ_by_outcome() -> void:
	_prepare_aftermath_state(RECORD_HONEST)
	assert_true(MODEL.commit_aftermath(SessionState.state, SessionState.content_db))
	assert_ne(
		MODEL.mart_dialogue_id(SessionState.state),
		MODEL.mart_dialogue_id(_state_with_record(RECORD_SECRET))
	)
	assert_ne(
		MODEL.brewery_dialogue_id(SessionState.state),
		MODEL.brewery_dialogue_id(_state_with_record(RECORD_SUBTLE))
	)
	var runner := RunnerScript.new()
	runner.configure(SessionState.content_db, SessionState.state, null)
	var exonerated_bark := runner.resolve_bark(
		MODEL.BARK_POOL,
		GameState.PHASE_CONSEQUENCE_NIGHT,
		&"loc.lower_town_slice"
	)
	_prepare_aftermath_state(RECORD_SECRET)
	runner.configure(SessionState.content_db, SessionState.state, null)
	var escaped_bark := runner.resolve_bark(
		MODEL.BARK_POOL,
		GameState.PHASE_CONSEQUENCE_NIGHT,
		&"loc.lower_town_slice"
	)
	assert_ne(String(exonerated_bark.get("text", "")), String(escaped_bark.get("text", "")))


func test_aftermath_controller_exposes_aita_only_when_exonerated() -> void:
	var aftermath := _make_aftermath(RECORD_HONEST)
	_prepare_aftermath_state(RECORD_HONEST)
	aftermath.commit_aftermath_for_test()
	SessionState.state.set_phase(GameState.PHASE_CONSEQUENCE_NIGHT)
	aftermath._sync_aftermath()
	assert_true(aftermath.get_aita().visible)
	assert_true(aftermath.get_brewery_interactable().is_enabled())
	_free_aftermath(aftermath)

	aftermath = _make_aftermath(RECORD_SECRET)
	_prepare_aftermath_state(RECORD_SECRET)
	aftermath.commit_aftermath_for_test()
	SessionState.state.set_phase(GameState.PHASE_CONSEQUENCE_NIGHT)
	aftermath._sync_aftermath()
	assert_false(aftermath.get_aita().visible)
	assert_true(aftermath.get_brewery_interactable().is_enabled())
	_free_aftermath(aftermath)


func _assert_aftermath_family(
	record_id: StringName,
	expected_outcome: StringName,
	expected_location_state: StringName,
	aita_visible: bool
) -> void:
	_prepare_aftermath_state(record_id)
	assert_true(MODEL.commit_aftermath(SessionState.state, SessionState.content_db))
	assert_eq(MODEL.resolve_outcome(SessionState.state), expected_outcome)
	assert_eq(
		SessionState.state.get_location_state(MODEL.LOC_BREWERY),
		expected_location_state
	)
	assert_eq(MODEL.aita_visible(SessionState.state), aita_visible)


func _prepare_aftermath_state(record_id: StringName) -> void:
	if not SessionState.content_db.is_loaded():
		assert_true(SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	SessionState.state = GameState.new()
	SessionState.state.bag.set_content_db(SessionState.content_db)
	SessionState.state.set_phase(GameState.PHASE_INVESTIGATION_NIGHT)
	SessionState.state.set_quest_state(QUEST_ID, &"night_bypassed")
	SessionState.state.add_forged_record(
		ForgedRecord.new(
			record_id,
			COMMISSION_ID,
			&"item.bitter_brew_work",
			StringName(String(record_id).get_slice(".", 2))
		)
	)


func _state_with_record(record_id: StringName) -> GameState:
	var state := GameState.new()
	state.set_phase(GameState.PHASE_CONSEQUENCE_NIGHT)
	state.set_quest_state(QUEST_ID, &"night_bypassed")
	state.add_forged_record(
		ForgedRecord.new(
			record_id,
			COMMISSION_ID,
			&"item.bitter_brew_work",
			StringName(String(record_id).get_slice(".", 2))
		)
	)
	MODEL.commit_aftermath(state, SessionState.content_db)
	return state


func _make_aftermath(record_id: StringName) -> Node:
	var host := Node2D.new()
	host.name = "AftermathTestHost"
	var actors := Node2D.new()
	actors.name = "Actors"
	host.add_child(actors)
	var player := PLAYER_SCENE.instantiate() as Player
	actors.add_child(player)
	var definition: MapDefinition = LOWER_TOWN_DEFINITION.create()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(host)

	var night := NightConsequenceScript.new()
	host.add_child(night)
	night.setup(host, definition, player, null, actors)

	var aftermath := AftermathScript.new()
	host.add_child(aftermath)
	aftermath.setup(
		host,
		definition,
		player,
		null,
		null,
		null,
		null,
		night,
		actors
	)
	_prepare_aftermath_state(record_id)
	return aftermath


func _free_aftermath(aftermath: Node) -> void:
	if aftermath == null or not is_instance_valid(aftermath):
		return
	var host := aftermath.get_parent()
	aftermath.queue_free()
	if host != null and is_instance_valid(host):
		host.queue_free()

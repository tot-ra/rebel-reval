extends "res://tests/godot/vertical_slice_flow_harness.gd"

## P3-001: traversal report covering every valid slice ending and deliberate
## invalid transitions that must be rejected without mutating quest state.

const TraversalModel := preload("res://scripts/slice/vertical_slice_traversal_model.gd")
const CommissionControllerScript := preload(
	"res://scripts/forge/bitter_brew_commission_controller.gd"
)
const LOWER_TOWN_DEFINITION := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const PLAYER_SCENE := preload("res://player.tscn")

const COMMISSION_ID := &"commission.bitter_brew"
const ENCOUNTER_ID := &"encounter.watch_checkpoint"


func test_traversal_report_lists_reachable_endings_and_rejected_invalid_states() -> void:
	var reachable: Array[String] = []
	for branch_id in FlowModel.branch_ids():
		var branch := FlowModel.branch_for_id(branch_id)
		await _run_full_slice_branch(branch)
		assert_true(
			FlowModel.validate_branch_terminal_state(SessionState.state, branch),
			"branch %s must finish with a valid terminal slice state" % String(branch_id)
		)
		var aftermath := String(AftermathModel.resolve_outcome(SessionState.state))
		reachable.append("%s:%s" % [String(branch_id), aftermath])

	var rejected := await _collect_rejected_invalid_transitions()
	var report := TraversalModel.build_report(reachable, rejected)
	assert_true(
		report["all_intended_endings_reachable"],
		"missing endings: %s" % str(report["missing_endings"])
	)
	assert_true(
		report["all_invalid_transitions_rejected"],
		"accepted invalid transitions: %s" % str(report["accepted_invalid_transitions"])
	)
	_maybe_write_report(report)


func test_invalid_night_route_pairs_reject_without_terminal_quest_state() -> void:
	for entry: Dictionary in TraversalModel.INVALID_NIGHT_ROUTE_PAIRS:
		var consequence := _make_night_consequence()
		_prepare_night_state(entry["record_id"] as StringName)
		consequence.arm_encounter_for_test()
		var route: StringName = entry["route"] as StringName
		assert_false(
			consequence.is_outcome_available(route),
			"%s must not offer route %s" % [String(entry["id"]), String(route)]
		)
		assert_false(
			consequence.resolve_encounter_outcome(route),
			"%s must reject route %s" % [String(entry["id"]), String(route)]
		)
		assert_false(
			AftermathModel.is_quest_terminal(SessionState.state),
			"%s must not reach a terminal quest state" % String(entry["id"])
		)
		_free_night_consequence(consequence)


func test_premature_aftermath_commit_is_rejected() -> void:
	_reset_fresh_session()
	SessionState.state.set_phase(GameState.PHASE_INVESTIGATION_MORNING)
	SessionState.state.set_quest_state(FlowModel.QUEST_BITTER_BREW, &"investigating")
	assert_false(
		AftermathModel.commit_aftermath(SessionState.state, SessionState.content_db),
		"aftermath must not commit before the night route resolves"
	)
	assert_true(AftermathModel.resolve_outcome(SessionState.state).is_empty())


func test_reflection_is_unavailable_before_reflection_morning() -> void:
	_reset_fresh_session()
	SessionState.state.set_phase(GameState.PHASE_INVESTIGATION_MORNING)
	assert_false(ReflectionModel.is_available(SessionState.state))


func test_unknown_encounter_outcome_rejects_without_mutating_quest_state() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	var definition := EncounterOutcomeDefinition.from_content_db(db, ENCOUNTER_ID)
	var state := GameState.new()
	state.set_quest_state(FlowModel.QUEST_BITTER_BREW, &"active")
	var resolver := EncounterOutcomeResolver.new()
	assert_false(resolver.resolve(state, definition, &"bribe", []))
	assert_eq(state.get_quest_state(FlowModel.QUEST_BITTER_BREW), &"active")
	assert_false(state.get_flag(&"flag.watch_checkpoint_resolved"))


func test_investigation_sites_reject_outside_investigation_morning() -> void:
	_reset_fresh_session()
	SessionState.state.set_phase(GameState.PHASE_PROLOGUE_DAY)
	var east := await _spawn_lower_town()
	var investigation := east.get_node_or_null("BitterBrewInvestigation") as BitterBrewInvestigation
	assert_true(investigation != null)
	assert_false(investigation.inspect_site_for_test(SITE_CISTERN))
	_free_scene(east)


func test_bitter_brew_commission_gate_rejects_before_investigation_ready() -> void:
	_reset_fresh_session()
	SessionState.state.set_phase(GameState.PHASE_INVESTIGATION_MORNING)
	SessionState.state.set_quest_state(FlowModel.QUEST_BITTER_BREW, &"investigating")
	var controller := CommissionControllerScript.new()
	assert_false(controller.call("_commission_flow_gate"))


func _collect_rejected_invalid_transitions() -> Array[String]:
	var rejected: Array[String] = []
	for entry: Dictionary in TraversalModel.INVALID_NIGHT_ROUTE_PAIRS:
		var consequence := _make_night_consequence()
		_prepare_night_state(entry["record_id"] as StringName)
		consequence.arm_encounter_for_test()
		var route: StringName = entry["route"] as StringName
		if (
			not consequence.is_outcome_available(route)
			and not consequence.resolve_encounter_outcome(route)
			and not AftermathModel.is_quest_terminal(SessionState.state)
		):
			rejected.append(String(entry["id"]))
		_free_night_consequence(consequence)

	_reset_fresh_session()
	SessionState.state.set_phase(GameState.PHASE_INVESTIGATION_MORNING)
	SessionState.state.set_quest_state(FlowModel.QUEST_BITTER_BREW, &"investigating")
	if not AftermathModel.commit_aftermath(SessionState.state, SessionState.content_db):
		rejected.append("invalid.aftermath.premature")

	_reset_fresh_session()
	SessionState.state.set_phase(GameState.PHASE_INVESTIGATION_MORNING)
	if not ReflectionModel.is_available(SessionState.state):
		rejected.append("invalid.reflection.wrong_phase")

	var db := ContentDB.new()
	assert_true(db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	var definition := EncounterOutcomeDefinition.from_content_db(db, ENCOUNTER_ID)
	var unknown_state := GameState.new()
	unknown_state.set_quest_state(FlowModel.QUEST_BITTER_BREW, &"active")
	var resolver := EncounterOutcomeResolver.new()
	if not resolver.resolve(unknown_state, definition, &"bribe", []):
		rejected.append("invalid.encounter.unknown_kind")

	_reset_fresh_session()
	SessionState.state.set_phase(GameState.PHASE_PROLOGUE_DAY)
	var east := await _spawn_lower_town()
	var investigation := east.get_node_or_null("BitterBrewInvestigation") as BitterBrewInvestigation
	if investigation != null and not investigation.inspect_site_for_test(SITE_CISTERN):
		rejected.append("invalid.investigation.wrong_phase")
	_free_scene(east)

	_reset_fresh_session()
	SessionState.state.set_phase(GameState.PHASE_INVESTIGATION_MORNING)
	SessionState.state.set_quest_state(FlowModel.QUEST_BITTER_BREW, &"investigating")
	var controller := CommissionControllerScript.new()
	if not controller.call("_commission_flow_gate"):
		rejected.append("invalid.commission.before_investigation_ready")

	return rejected


func _prepare_night_state(record_id: StringName) -> void:
	if not SessionState.content_db.is_loaded():
		assert_true(SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	SessionState.state = GameState.new()
	SessionState.state.bag.set_content_db(SessionState.content_db)
	SessionState.state.set_phase(GameState.PHASE_INVESTIGATION_NIGHT)
	SessionState.state.set_quest_state(FlowModel.QUEST_BITTER_BREW, &"investigation_ready")
	SessionState.state.set_flag(&"flag.watch_checkpoint_resolved", false)
	SessionState.state.add_forged_record(
		ForgedRecord.new(
			record_id,
			COMMISSION_ID,
			&"item.bitter_brew_work",
			StringName(String(record_id).get_slice(".", 2))
		)
	)


func _make_night_consequence() -> Node:
	var host := Node2D.new()
	host.name = "TraversalNightConsequenceHost"
	var actors := Node2D.new()
	actors.name = "Actors"
	host.add_child(actors)
	var player := PLAYER_SCENE.instantiate() as Player
	actors.add_child(player)
	var definition: MapDefinition = LOWER_TOWN_DEFINITION.create()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(host)
	var consequence := NightConsequenceScript.new()
	host.add_child(consequence)
	consequence.setup(host, definition, player, null, actors)
	return consequence


func _free_night_consequence(consequence: Node) -> void:
	if consequence == null or not is_instance_valid(consequence):
		return
	var host := consequence.get_parent()
	consequence.queue_free()
	if host != null and is_instance_valid(host):
		host.queue_free()


func _maybe_write_report(report: Dictionary) -> void:
	var path := OS.get_environment("SLICE_TRAVERSAL_REPORT_PATH")
	if path.is_empty():
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_true(file != null, "unable to write traversal report to %s" % path)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()

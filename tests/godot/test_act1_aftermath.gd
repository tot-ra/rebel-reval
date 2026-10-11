extends "res://tests/godot/test_case.gd"

## P4-009: Act 1 transition envelope must cover every core character, forge,
## and active district without a universal morality score.

const ModelScript := preload("res://scripts/quest/act1_aftermath_model.gd")
const StGeorgesModel := preload("res://scripts/quest/st_georges_night_quest_model.gd")
const AftermathModelScript := preload(
	"res://scripts/investigation/st_georges_night_aftermath_model.gd"
)
const BitterBrewModel := preload("res://scripts/investigation/bitter_brew_aftermath_model.gd")
const PriceOfANameModel := preload(
	"res://scripts/investigation/price_of_a_name_aftermath_model.gd"
)
const RootAndEmberModel := preload("res://scripts/investigation/root_and_ember_aftermath_model.gd")
const ReflectionModel := preload("res://scripts/reflection/reflection_model.gd")

const FLAG_SEAL_BIAS := &"flag.act_climax_viru_seal"
const FLAG_BREAK_BIAS := &"flag.act_climax_viru_break"
const FLAG_OPEN_BIAS := &"flag.act_climax_viru_open"


func before_each() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(StGeorgesModel.CONTENT_DIRS))
	SessionState.content_db = db
	SessionState.state = GameState.new()
	SessionState.state.bag.set_content_db(db)


func test_manifest_matches_model() -> void:
	var report := ModelScript.validate_manifest()
	assert_true(report["valid"], str(report["errors"]))
	assert_eq(report["scenario_count"], 3)


func test_climax_commit_records_act1_transition_envelope() -> void:
	for branch: Dictionary in _boundary_branches():
		var state := _rich_act1_state(branch)
		assert_true(
			AftermathModelScript.commit_climax_choice(
				state,
				SessionState.content_db,
				branch["transition"] as StringName
			)
		)
		assert_true(state.has_act1_transition())
		var validation := ModelScript.validate_envelope(state.get_act1_transition())
		assert_true(validation["valid"], str(validation["errors"]))
		assert_eq(
			String(state.get_act1_transition().get("act_boundary", "")),
			branch["boundary"]
		)


func test_matrix_covers_core_characters_without_morality_score() -> void:
	for branch: Dictionary in _boundary_branches():
		var state := _rich_act1_state(branch)
		_apply_boundary_flag(state, String(branch["boundary"]))
		var envelope := ModelScript.build_envelope(state)
		var validation := ModelScript.validate_envelope(envelope)
		assert_true(validation["valid"], str(validation["errors"]))
		var characters: Dictionary = envelope["characters"]
		for character_id in ModelScript.CORE_CHARACTERS:
			assert_true(characters.has(character_id))
			assert_false(String(characters[character_id]).is_empty())
		assert_false(envelope.has("morality"))
		assert_false((envelope.get("forge", {}) as Dictionary).has("alignment"))


func test_save_payload_round_trips_act1_transition() -> void:
	var state := _rich_act1_state(_boundary_branches()[0])
	assert_true(
		AftermathModelScript.commit_climax_choice(
			state,
			SessionState.content_db,
			_boundary_branches()[0]["transition"] as StringName
		)
	)

	var payload := state.save_payload()
	var restored := GameState.new()
	var errors := restored.load_payload(payload)
	assert_eq(errors.size(), 0)
	assert_eq(
		restored.get_act1_transition(),
		state.get_act1_transition()
	)


func _boundary_branches() -> Array[Dictionary]:
	return [
		{
			"bias": FLAG_SEAL_BIAS,
			"transition": StGeorgesModel.TRANSITION_COMMIT_SEAL,
			"boundary": "seal",
		},
		{
			"bias": FLAG_BREAK_BIAS,
			"transition": StGeorgesModel.TRANSITION_COMMIT_BREAK,
			"boundary": "break",
		},
		{
			"bias": FLAG_OPEN_BIAS,
			"transition": StGeorgesModel.TRANSITION_COMMIT_OPEN,
			"boundary": "open",
		},
	]


func _rich_act1_state(branch: Dictionary) -> GameState:
	var state := GameState.new()
	state.set_phase(StGeorgesModel.PHASE_ACT1_CLIMAX)
	state.set_flag(branch["bias"] as StringName, true)
	state.set_flag(&"flag.forge_ledger_preserved", true)
	state.set_flag(ReflectionModel.FLAG_DUTY, true)
	state.set_flag(BitterBrewModel.FLAG_EXONERATED, true)
	state.set_flag(PriceOfANameModel.FLAG_CLEARED, true)
	state.set_flag(RootAndEmberModel.FLAG_ROOT, true)
	state.set_relationship(&"rel.henning_trust", 2)
	state.set_relationship(&"rel.mart_trust", 1)
	state.set_equipped_forge_technique(ForgeTechnique.ID_IRON)

	var manager := QuestManager.new(SessionState.content_db, state, StateRuleEvaluator.new())
	assert_true(manager.start_quest(StGeorgesModel.QUEST_ID))
	assert_true(
		manager.transition(StGeorgesModel.QUEST_ID, StGeorgesModel.TRANSITION_BEGIN_APPROACH)
	)
	return state


func _apply_boundary_flag(state: GameState, boundary: String) -> void:
	match boundary:
		"seal":
			state.set_flag(&"flag.act_boundary.viru_seal", true)
		"break":
			state.set_flag(&"flag.act_boundary.viru_break", true)
		"open":
			state.set_flag(&"flag.act_boundary.viru_open", true)

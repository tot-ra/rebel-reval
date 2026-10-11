class_name VerticalSliceFlowModel
extends RefCounted

## Documents the authored vertical-slice branch matrix and terminal-state checks.
## WHY: P2-012 needs one place to assert that prologue, investigation, forge,
## night consequence, aftermath, and reflection all line up per branch.

const QUEST_MAKERS_MARK := &"quest.makers_mark"
const QUEST_BITTER_BREW := &"quest.bitter_brew"
const COMMISSION_WATCH_BUCKLE := &"commission.watch_buckle_repair"
const COMMISSION_BITTER_BREW := &"commission.bitter_brew"

const RECORD_HONEST := &"forged.bitter_brew.honest_work"
const RECORD_SUBTLE := &"forged.bitter_brew.subtle_defect"
const RECORD_SECRET := &"forged.bitter_brew.secret_feature"

const AftermathModel := preload("res://scripts/investigation/bitter_brew_aftermath_model.gd")
const ReflectionModel := preload("res://scripts/reflection/reflection_model.gd")

const BRANCHES: Array[Dictionary] = [
	{
		"id": &"honest",
		"forge_option": "honest_work",
		"forged_record": RECORD_HONEST,
		"night_route": EncounterOutcome.KIND_SURRENDER,
		"night_quest_state": &"night_surrendered",
		"aftermath_outcome": AftermathModel.OUTCOME_EXONERATED,
	},
	{
		"id": &"subtle",
		"forge_option": "subtle_defect",
		"forged_record": RECORD_SUBTLE,
		"night_route": EncounterOutcome.KIND_BYPASS,
		"night_quest_state": &"night_bypassed",
		"aftermath_outcome": AftermathModel.OUTCOME_MONOPOLIZED,
	},
	{
		"id": &"secret",
		"forge_option": "secret_feature",
		"forged_record": RECORD_SECRET,
		"night_route": EncounterOutcome.KIND_ESCAPE,
		"night_quest_state": &"night_escaped",
		"aftermath_outcome": AftermathModel.OUTCOME_ESCAPED,
	},
]


static func branch_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for branch: Dictionary in BRANCHES:
		ids.append(branch["id"] as StringName)
	return ids


static func branch_for_id(branch_id: StringName) -> Dictionary:
	for branch: Dictionary in BRANCHES:
		if branch["id"] == branch_id:
			return branch
	return {}


static func is_slice_complete(state: GameState) -> bool:
	if state == null:
		return false
	if state.get_phase() != GameState.PHASE_REFLECTION_MORNING:
		return false
	if not state.get_flag(ReflectionModel.FLAG_COMPLETED):
		return false
	if state.get_quest_state(QUEST_MAKERS_MARK) != &"ledger_committed":
		return false
	if AftermathModel.resolve_outcome(state).is_empty():
		return false
	return true


static func validate_branch_terminal_state(state: GameState, branch: Dictionary) -> bool:
	if branch.is_empty() or state == null:
		return false
	if not is_slice_complete(state):
		return false
	var record_id: StringName = branch["forged_record"] as StringName
	if not state.has_forged_record(record_id):
		return false
	if AftermathModel.resolve_outcome(state) != branch["aftermath_outcome"]:
		return false
	return state.get_quest_state(QUEST_BITTER_BREW) == branch["night_quest_state"]

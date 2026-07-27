class_name StGeorgesNightAftermathModel
extends RefCounted

## Resolves St. George's Night act-boundary families and patrol bark pools.

const MECHANISM_ID := &"mechanism.st_georges_night_gate"
const QUEST_ID := &"quest.st_georges_night"
const PHASE_ACT1_CLIMAX := &"phase.act1_climax"

const OUTCOME_SEAL := &"seal"
const OUTCOME_BREAK := &"break"
const OUTCOME_OPEN := &"open"

const FLAG_BOUNDARY_SEAL := &"flag.act_boundary.viru_seal"
const FLAG_BOUNDARY_BREAK := &"flag.act_boundary.viru_break"
const FLAG_BOUNDARY_OPEN := &"flag.act_boundary.viru_open"

const BARK_POOL := &"bark.st_georges_night.aftermath_watch"

const AFTERMATH_PHASES: Array[StringName] = [
	PHASE_ACT1_CLIMAX,
]

const TERMINAL_STATES: Array[StringName] = [
	&"aftermath_seal",
	&"aftermath_break",
	&"aftermath_open",
]


static func resolve_outcome(state: GameState) -> StringName:
	if state == null:
		return &""
	if state.get_flag(FLAG_BOUNDARY_SEAL):
		return OUTCOME_SEAL
	if state.get_flag(FLAG_BOUNDARY_BREAK):
		return OUTCOME_BREAK
	if state.get_flag(FLAG_BOUNDARY_OPEN):
		return OUTCOME_OPEN
	return &""


static func is_aftermath_visible(state: GameState) -> bool:
	if state == null:
		return false
	if not state.get_phase() in AFTERMATH_PHASES:
		return false
	if not state.get_quest_state(QUEST_ID) in TERMINAL_STATES:
		return false
	return not resolve_outcome(state).is_empty()


static func commit_climax_choice(
	state: GameState,
	content_db: ContentDB,
	transition_id: StringName
) -> bool:
	if state == null or content_db == null or transition_id.is_empty():
		return false
	var manager := QuestManager.new(content_db, state)
	if not manager.transition(QUEST_ID, transition_id):
		return false
	var resolver := MechanismResolver.new(content_db, state)
	resolver.trigger(MECHANISM_ID)
	return true

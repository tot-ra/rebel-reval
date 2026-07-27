class_name BellAndChainAftermathModel
extends RefCounted

## Resolves the three Bell and the Chain aftermath families from forged records
## and maps them to patrol bark pools and act-climax bias flags.

const MECHANISM_ID := &"mechanism.bell_and_chain_gate"
const QUEST_ID := &"quest.bell_and_chain"
const COMMISSION_ID := &"commission.bell_and_chain"

const OUTCOME_HONEST := &"honest"
const OUTCOME_DEFECT := &"defect"
const OUTCOME_RELEASE := &"release"

const FLAG_HONEST := &"flag.gate_chain_honest_work"
const FLAG_DEFECT := &"flag.gate_chain_subtle_defect"
const FLAG_RELEASE := &"flag.gate_chain_secret_feature"
const FLAG_SEAL := &"flag.act_climax_viru_seal"
const FLAG_BREAK := &"flag.act_climax_viru_break"
const FLAG_OPEN := &"flag.act_climax_viru_open"

const BARK_POOL := &"bark.bell_and_chain.aftermath_watch"

const AFTERMATH_PHASES: Array[StringName] = [
	GameState.PHASE_CONSEQUENCE_NIGHT,
	GameState.PHASE_REFLECTION_MORNING,
]

const TERMINAL_STATES: Array[StringName] = [
	&"aftermath_honest",
	&"aftermath_defect",
	&"aftermath_release",
]


static func resolve_outcome(state: GameState) -> StringName:
	if state == null:
		return &""
	if state.get_flag(FLAG_HONEST) or state.get_flag(FLAG_SEAL):
		return OUTCOME_HONEST
	if state.get_flag(FLAG_DEFECT) or state.get_flag(FLAG_BREAK):
		return OUTCOME_DEFECT
	if state.get_flag(FLAG_RELEASE) or state.get_flag(FLAG_OPEN):
		return OUTCOME_RELEASE
	return &""


static func is_aftermath_visible(state: GameState) -> bool:
	if state == null:
		return false
	if not state.get_phase() in AFTERMATH_PHASES:
		return false
	if not state.get_quest_state(QUEST_ID) in TERMINAL_STATES:
		return false
	return not resolve_outcome(state).is_empty()


static func commit_install(state: GameState, content_db: ContentDB) -> bool:
	if state == null or content_db == null:
		return false
	if not ForgeCommissionModel.is_commission_resolved(state, COMMISSION_ID):
		return false
	var resolver := MechanismResolver.new(content_db, state)
	return resolver.trigger(MECHANISM_ID)


static func act_climax_flag(state: GameState) -> StringName:
	match resolve_outcome(state):
		OUTCOME_HONEST:
			return FLAG_SEAL
		OUTCOME_DEFECT:
			return FLAG_BREAK
		OUTCOME_RELEASE:
			return FLAG_OPEN
		_:
			return &""

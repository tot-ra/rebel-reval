class_name RootAndEmberAftermathModel
extends RefCounted

## Resolves Root and Ember aftermath families from Ellen and household flags.

const MECHANISM_ID := &"mechanism.root_and_ember_hearth"
const QUEST_ID := &"quest.root_and_ember"
const COMMISSION_ID := &"commission.root_and_ember"

const OUTCOME_EMBER := &"ember"
const OUTCOME_ROOT := &"root"
const OUTCOME_IRON := &"iron"

const FLAG_EMBER := &"flag.ellen.belief_honored"
const FLAG_ROOT := &"flag.ellen.remedy_trusted"
const FLAG_IRON := &"flag.ellen.skepticism_respected"

const BARK_POOL := &"bark.root_and_ember.aftermath_watch"

const AFTERMATH_PHASES: Array[StringName] = [
	GameState.PHASE_REFLECTION_MORNING,
]

const TERMINAL_STATES: Array[StringName] = [
	&"aftermath_ember",
	&"aftermath_root",
	&"aftermath_iron",
]


static func resolve_outcome(state: GameState) -> StringName:
	if state == null:
		return &""
	if state.get_flag(FLAG_EMBER):
		return OUTCOME_EMBER
	if state.get_flag(FLAG_ROOT):
		return OUTCOME_ROOT
	if state.get_flag(FLAG_IRON):
		return OUTCOME_IRON
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

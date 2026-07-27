class_name BreadAndIronAftermathModel
extends RefCounted

## Resolves Bread and Iron aftermath families from forged records and Raide flags.

const MECHANISM_ID := &"mechanism.bread_and_iron_scales"
const QUEST_ID := &"quest.bread_and_iron"
const COMMISSION_ID := &"commission.bread_and_iron"

const OUTCOME_SUPPLIED := &"supplied"
const OUTCOME_RATIONED := &"rationed"
const OUTCOME_DEBT := &"debt"

const FLAG_SUPPLIED := &"flag.family.raide_supplied"
const FLAG_RATIONED := &"flag.family.raide_rationed"
const FLAG_DEBT := &"flag.family.raide_debt"

const BARK_POOL := &"bark.bread_and_iron.aftermath_watch"

const AFTERMATH_PHASES: Array[StringName] = [
	GameState.PHASE_REFLECTION_MORNING,
]

const TERMINAL_STATES: Array[StringName] = [
	&"aftermath_supplied",
	&"aftermath_rationed",
	&"aftermath_debt",
]


static func resolve_outcome(state: GameState) -> StringName:
	if state == null:
		return &""
	if state.get_flag(FLAG_SUPPLIED):
		return OUTCOME_SUPPLIED
	if state.get_flag(FLAG_RATIONED):
		return OUTCOME_RATIONED
	if state.get_flag(FLAG_DEBT):
		return OUTCOME_DEBT
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
	var ok := resolver.trigger(MECHANISM_ID)
	if ok:
		state.set_flag(&"flag.act1_price_of_a_name_unlocked", true)
	return ok

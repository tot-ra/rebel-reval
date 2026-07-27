class_name PriceOfANameAftermathModel
extends RefCounted

## Resolves Price of a Name aftermath families from forged records and Mart flags.

const MECHANISM_ID := &"mechanism.price_of_a_name_detention"
const QUEST_ID := &"quest.price_of_a_name"
const COMMISSION_ID := &"commission.price_of_a_name"

const OUTCOME_CLEARED := &"cleared"
const OUTCOME_REDIRECTED := &"redirected"
const OUTCOME_CONCEALED := &"concealed"

const FLAG_CLEARED := &"flag.mart.name_cleared"
const FLAG_REDIRECTED := &"flag.mart.name_redirected"
const FLAG_CONCEALED := &"flag.mart.name_concealed"

const BARK_POOL := &"bark.price_of_a_name.aftermath_watch"
const BARK_LOCATION := &"loc.north_quarter.merchant_court"

const AFTERMATH_PHASES: Array[StringName] = [
	GameState.PHASE_REFLECTION_MORNING,
]

const TERMINAL_STATES: Array[StringName] = [
	&"aftermath_cleared",
	&"aftermath_redirected",
	&"aftermath_concealed",
]


static func resolve_outcome(state: GameState) -> StringName:
	if state == null:
		return &""
	if state.get_flag(FLAG_CLEARED):
		return OUTCOME_CLEARED
	if state.get_flag(FLAG_REDIRECTED):
		return OUTCOME_REDIRECTED
	if state.get_flag(FLAG_CONCEALED):
		return OUTCOME_CONCEALED
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

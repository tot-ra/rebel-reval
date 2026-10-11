class_name NunnatornEvidenceModel
extends RefCounted

## R-626: outcome-aware loot and evidence collection for the Nunnatorn encounter.
## WHY: QuestManager already validates and applies item/fact effects atomically;
## this adapter only selects the authored branch and prevents re-entry duplicates.

const QUEST_ID := &"quest.nunnatorn_evidence"
const PENDING_STATE := &"awaiting_collection"
const LETHAL_STATE := &"collected_lethal"
const ALTERNATE_STATE := &"collected_alternate"
const TRANSITION_LETHAL := &"collect_lethal"
const TRANSITION_ALTERNATE := &"collect_alternate"
const LOOT_ITEM_ID := &"item.nunnatorn_evidence"
const LEDGER_FACT_ID := &"fact.nunnatorn.evidence.ledger"
const WITNESS_FACT_ID := &"fact.nunnatorn.evidence.witness_account"
const LOOT_COLLECTED_FLAG := &"flag.nunnatorn_loot_collected"
const EVIDENCE_RECORDED_FLAG := &"flag.nunnatorn_evidence_recorded"
const DEFEATED_FLAG := &"flag.nunnatorn_boss_defeated"
const ALTERNATE_FLAG := &"flag.nunnatorn_boss_alternate_resolution"


static func collection_state(state: GameState) -> StringName:
	if state == null:
		return &""
	return state.get_quest_state(QUEST_ID)


static func is_collected(state: GameState) -> bool:
	var current := collection_state(state)
	return current == LETHAL_STATE or current == ALTERNATE_STATE


static func transition_for_outcome(state: GameState) -> StringName:
	if state == null or is_collected(state):
		return &""
	var lethal := state.get_flag(DEFEATED_FLAG)
	var alternate := state.get_flag(ALTERNATE_FLAG)
	# Both branch flags at once indicate corrupted encounter state. Fail closed
	# rather than awarding a branch selected by dictionary or flag ordering.
	if lethal == alternate:
		return &""
	if lethal:
		return TRANSITION_LETHAL
	return TRANSITION_ALTERNATE


## Collect the one authored outcome record. A second call returns false and does
## not re-add the item or alter the already-visible journal fact.
static func collect(state: GameState, content_db: ContentDB) -> bool:
	if state == null or content_db == null:
		return false
	var transition_id := transition_for_outcome(state)
	if transition_id.is_empty():
		return false

	var manager := QuestManager.new(content_db, state, StateRuleEvaluator.new())
	if collection_state(state).is_empty() and not manager.start_quest(QUEST_ID):
		return false
	if collection_state(state) != PENDING_STATE:
		return false
	return manager.transition(QUEST_ID, transition_id)

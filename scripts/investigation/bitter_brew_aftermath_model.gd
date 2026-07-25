class_name BitterBrewAftermathModel
extends RefCounted

## Resolves the three Bitter Brew aftermath families from forged commission records
## and maps them to player-visible brewery, Aita, Mart, and patrol bark content.

const MECHANISM_ID := &"mechanism.bitter_brew_crisis"
const QUEST_ID := &"quest.bitter_brew"

const OUTCOME_EXONERATED := &"exonerated"
const OUTCOME_ESCAPED := &"escaped"
const OUTCOME_MONOPOLIZED := &"monopolized"

const FLAG_EXONERATED := &"flag.bitter_brew_outcome_exonerated"
const FLAG_ESCAPED := &"flag.bitter_brew_outcome_escaped"
const FLAG_MONOPOLIZED := &"flag.bitter_brew_outcome_monopolized"

const LOC_BREWERY := &"loc.lower_town_slice"

const BARK_POOL := &"bark.bitter_brew.aftermath_watch"

const MART_DIALOGUE_EXONERATED := &"dialogue.bitter_brew.mart_exonerated"
const MART_DIALOGUE_ESCAPED := &"dialogue.bitter_brew.mart_escaped"
const MART_DIALOGUE_MONOPOLIZED := &"dialogue.bitter_brew.mart_monopolized"

const BREWERY_DIALOGUE_EXONERATED := &"dialogue.bitter_brew.brewery_exonerated"
const BREWERY_DIALOGUE_ESCAPED := &"dialogue.bitter_brew.brewery_confiscated"
const BREWERY_DIALOGUE_MONOPOLIZED := &"dialogue.bitter_brew.brewery_monopolized"

const TERMINAL_QUEST_STATES: Array[StringName] = [
	&"night_surrendered",
	&"night_escaped",
	&"night_bypassed",
	&"night_fought",
]

const AFTERMATH_PHASES: Array[StringName] = [
	GameState.PHASE_CONSEQUENCE_NIGHT,
	GameState.PHASE_REFLECTION_MORNING,
]


static func is_quest_terminal(state: GameState) -> bool:
	if state == null:
		return false
	return state.get_quest_state(QUEST_ID) in TERMINAL_QUEST_STATES


static func is_aftermath_visible(state: GameState) -> bool:
	if state == null:
		return false
	if not state.get_phase() in AFTERMATH_PHASES:
		return false
	return not resolve_outcome(state).is_empty()


static func resolve_outcome(state: GameState) -> StringName:
	if state == null:
		return &""
	if state.get_flag(FLAG_EXONERATED):
		return OUTCOME_EXONERATED
	if state.get_flag(FLAG_ESCAPED):
		return OUTCOME_ESCAPED
	if state.get_flag(FLAG_MONOPOLIZED):
		return OUTCOME_MONOPOLIZED
	return &""


static func commit_aftermath(state: GameState, content_db: ContentDB) -> bool:
	if state == null or content_db == null:
		return false
	if not is_quest_terminal(state):
		return false
	if not resolve_outcome(state).is_empty():
		return true
	var resolver := MechanismResolver.new(content_db, state)
	if not resolver.trigger(MECHANISM_ID):
		return false
	_apply_brewery_location_state(state)
	return not resolve_outcome(state).is_empty()


static func mart_dialogue_id(state: GameState) -> StringName:
	match resolve_outcome(state):
		OUTCOME_EXONERATED:
			return MART_DIALOGUE_EXONERATED
		OUTCOME_ESCAPED:
			return MART_DIALOGUE_ESCAPED
		OUTCOME_MONOPOLIZED:
			return MART_DIALOGUE_MONOPOLIZED
		_:
			return &""


static func brewery_dialogue_id(state: GameState) -> StringName:
	match resolve_outcome(state):
		OUTCOME_EXONERATED:
			return BREWERY_DIALOGUE_EXONERATED
		OUTCOME_ESCAPED:
			return BREWERY_DIALOGUE_ESCAPED
		OUTCOME_MONOPOLIZED:
			return BREWERY_DIALOGUE_MONOPOLIZED
		_:
			return &""


static func aita_visible(state: GameState) -> bool:
	return resolve_outcome(state) == OUTCOME_EXONERATED


static func brewery_yard_active(state: GameState) -> bool:
	var outcome := resolve_outcome(state)
	return outcome == OUTCOME_EXONERATED or outcome == OUTCOME_MONOPOLIZED


static func brewery_status_label(state: GameState) -> String:
	match resolve_outcome(state):
		OUTCOME_EXONERATED:
			return "Open brewery yard"
		OUTCOME_ESCAPED:
			return "Boarded brewery"
		OUTCOME_MONOPOLIZED:
			return "Contract brewery"
		_:
			return ""


static func _apply_brewery_location_state(state: GameState) -> void:
	match resolve_outcome(state):
		OUTCOME_EXONERATED:
			state.set_location_state(LOC_BREWERY, &"brewery_independent")
		OUTCOME_ESCAPED:
			state.set_location_state(LOC_BREWERY, &"brewery_confiscated")
		OUTCOME_MONOPOLIZED:
			state.set_location_state(LOC_BREWERY, &"brewery_corporatized")

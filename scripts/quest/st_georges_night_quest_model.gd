class_name StGeorgesNightQuestModel
extends RefCounted

## Act 1 climax gating for quest.st_georges_night (P4-008).

const QUEST_ID := &"quest.st_georges_night"
const PHASE_ACT1_CLIMAX := &"phase.act1_climax"

const STATE_LATENT := &"latent"
const STATE_APPROACHING := &"approaching"
const STATE_AFTERMATH_SEAL := &"aftermath_seal"
const STATE_AFTERMATH_BREAK := &"aftermath_break"
const STATE_AFTERMATH_OPEN := &"aftermath_open"

const TRANSITION_BEGIN_APPROACH := &"begin_approach"
const TRANSITION_COMMIT_SEAL := &"commit_seal_choice"
const TRANSITION_COMMIT_BREAK := &"commit_break_choice"
const TRANSITION_COMMIT_OPEN := &"commit_open_choice"

const FLAG_SEAL_BIAS := &"flag.act_climax_viru_seal"
const FLAG_BREAK_BIAS := &"flag.act_climax_viru_break"
const FLAG_OPEN_BIAS := &"flag.act_climax_viru_open"

const FACTION_STANDING_FALLBACK := 2

const TERMINAL_STATES: Array[StringName] = [
	STATE_AFTERMATH_SEAL,
	STATE_AFTERMATH_BREAK,
	STATE_AFTERMATH_OPEN,
]

const CONTENT_DIRS: Array[String] = [
	"res://content/packages/st_georges_night/content",
	"res://content/examples/support",
	"res://content/packages/bell_and_chain/content",
]


static func is_quest_terminal(state: GameState) -> bool:
	if state == null:
		return false
	return state.get_quest_state(QUEST_ID) in TERMINAL_STATES


static func is_climax_phase(state: GameState) -> bool:
	if state == null:
		return false
	return state.get_phase() == PHASE_ACT1_CLIMAX


static func is_gate_choice_active(state: GameState) -> bool:
	if state == null or not is_climax_phase(state):
		return false
	if is_quest_terminal(state):
		return false
	return state.get_quest_state(QUEST_ID) == STATE_APPROACHING


static func can_choose_seal(state: GameState) -> bool:
	if state == null:
		return false
	return (
		state.get_flag(FLAG_SEAL_BIAS)
		or state.get_faction_standing(FactionLedger.LIVONIAN_ORDER) >= FACTION_STANDING_FALLBACK
	)


static func can_choose_break(state: GameState) -> bool:
	if state == null:
		return false
	return (
		state.get_flag(FLAG_BREAK_BIAS)
		or state.get_faction_standing(FactionLedger.HARJU_KINGS) >= FACTION_STANDING_FALLBACK
	)


static func can_choose_open(state: GameState) -> bool:
	if state == null:
		return false
	return (
		state.get_flag(FLAG_OPEN_BIAS)
		or state.get_faction_standing(FactionLedger.BLACK_CLOAKS) >= FACTION_STANDING_FALLBACK
	)


static func transition_for_choice(choice: StringName) -> StringName:
	match choice:
		&"seal":
			return TRANSITION_COMMIT_SEAL
		&"break":
			return TRANSITION_COMMIT_BREAK
		&"open":
			return TRANSITION_COMMIT_OPEN
		_:
			return &""

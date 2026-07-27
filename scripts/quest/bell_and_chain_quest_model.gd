class_name BellAndChainQuestModel
extends RefCounted

## Act 1 gate-chain cycle gating for quest.bell_and_chain (P4-002).

const QUEST_ID := &"quest.bell_and_chain"
const COMMISSION_ID := &"commission.bell_and_chain"
const UNLOCK_FLAG := &"flag.act1_bell_and_chain_unlocked"

const STATE_INVESTIGATING := &"investigating"
const STATE_INVESTIGATION_READY := &"investigation_ready"
const STATE_AFTERMATH_HONEST := &"aftermath_honest"
const STATE_AFTERMATH_DEFECT := &"aftermath_defect"
const STATE_AFTERMATH_RELEASE := &"aftermath_release"

const TRANSITION_COMPLETE := &"complete_investigation"
const TRANSITION_HONEST := &"commit_honest_forge"
const TRANSITION_DEFECT := &"commit_defect_forge"
const TRANSITION_RELEASE := &"commit_release_forge"

const TERMINAL_STATES: Array[StringName] = [
	STATE_AFTERMATH_HONEST,
	STATE_AFTERMATH_DEFECT,
	STATE_AFTERMATH_RELEASE,
]

const INVESTIGATION_PHASES: Array[StringName] = [
	GameState.PHASE_CONSEQUENCE_NIGHT,
	GameState.PHASE_REFLECTION_MORNING,
]

const FORGE_PHASES: Array[StringName] = [
	GameState.PHASE_CONSEQUENCE_NIGHT,
	GameState.PHASE_REFLECTION_MORNING,
]

const NIGHT_INSTALL_PHASES: Array[StringName] = [
	GameState.PHASE_CONSEQUENCE_NIGHT,
	GameState.PHASE_REFLECTION_MORNING,
]

const CONTENT_DIRS: Array[String] = [
	"res://content/packages/bell_and_chain/content",
	"res://content/examples/support",
]


static func is_cycle_unlocked(state: GameState) -> bool:
	if state == null:
		return false
	if state.get_flag(UNLOCK_FLAG):
		return true
	return BitterBrewAftermathModel.is_quest_terminal(state)


static func is_quest_terminal(state: GameState) -> bool:
	if state == null:
		return false
	return state.get_quest_state(QUEST_ID) in TERMINAL_STATES


static func is_investigation_active(state: GameState) -> bool:
	if state == null or not is_cycle_unlocked(state):
		return false
	if not state.get_phase() in INVESTIGATION_PHASES:
		return false
	if is_quest_terminal(state):
		return false
	return state.get_quest_state(QUEST_ID) in [STATE_INVESTIGATING, &""]


static func is_forge_flow_active(state: GameState) -> bool:
	if state == null or not is_cycle_unlocked(state):
		return false
	if not state.get_phase() in FORGE_PHASES:
		return false
	return state.get_quest_state(QUEST_ID) == STATE_INVESTIGATION_READY


static func is_night_install_active(state: GameState) -> bool:
	if state == null or not is_cycle_unlocked(state):
		return false
	if not state.get_phase() in NIGHT_INSTALL_PHASES:
		return false
	if not ForgeCommissionModel.is_commission_resolved(state, COMMISSION_ID):
		return false
	return is_quest_terminal(state)


static func transition_for_modification(modification_id: StringName) -> StringName:
	match modification_id:
		&"honest_work":
			return TRANSITION_HONEST
		&"subtle_defect":
			return TRANSITION_DEFECT
		&"secret_feature":
			return TRANSITION_RELEASE
		_:
			return &""


static func act_climax_flag_for_modification(modification_id: StringName) -> StringName:
	match modification_id:
		&"honest_work":
			return &"flag.act_climax_viru_seal"
		&"subtle_defect":
			return &"flag.act_climax_viru_break"
		&"secret_feature":
			return &"flag.act_climax_viru_open"
		_:
			return &""

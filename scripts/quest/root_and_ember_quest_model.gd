class_name RootAndEmberQuestModel
extends RefCounted

## Act 1 folklore hearth cycle gating for quest.root_and_ember (P4-007).

const QUEST_ID := &"quest.root_and_ember"
const COMMISSION_ID := &"commission.root_and_ember"
const UNLOCK_FLAG := &"flag.act1_root_and_ember_unlocked"

const STATE_INVESTIGATING := &"investigating"
const STATE_INVESTIGATION_READY := &"investigation_ready"
const STATE_AFTERMATH_EMBER := &"aftermath_ember"
const STATE_AFTERMATH_ROOT := &"aftermath_root"
const STATE_AFTERMATH_IRON := &"aftermath_iron"

const TRANSITION_COMPLETE := &"complete_investigation"
const TRANSITION_EMBER := &"commit_ember_forge"
const TRANSITION_ROOT := &"commit_root_forge"
const TRANSITION_IRON := &"commit_iron_forge"

const TERMINAL_STATES: Array[StringName] = [
	STATE_AFTERMATH_EMBER,
	STATE_AFTERMATH_ROOT,
	STATE_AFTERMATH_IRON,
]

const INVESTIGATION_PHASES: Array[StringName] = [
	GameState.PHASE_REFLECTION_MORNING,
]

const FORGE_PHASES: Array[StringName] = [
	GameState.PHASE_REFLECTION_MORNING,
]

const INSTALL_PHASES: Array[StringName] = [
	GameState.PHASE_REFLECTION_MORNING,
]

const CONTENT_DIRS: Array[String] = [
	"res://content/packages/root_and_ember/content",
	"res://content/examples/support",
]


static func is_cycle_unlocked(state: GameState) -> bool:
	if state == null:
		return false
	if state.get_flag(UNLOCK_FLAG):
		return true
	return PriceOfANameQuestModel.is_quest_terminal(state)


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


static func is_install_active(state: GameState) -> bool:
	if state == null or not is_cycle_unlocked(state):
		return false
	if not state.get_phase() in INSTALL_PHASES:
		return false
	if not ForgeCommissionModel.is_commission_resolved(state, COMMISSION_ID):
		return false
	return is_quest_terminal(state)


static func transition_for_modification(modification_id: StringName) -> StringName:
	match modification_id:
		&"ember_rite":
			return TRANSITION_EMBER
		&"root_ward":
			return TRANSITION_ROOT
		&"iron_bracket":
			return TRANSITION_IRON
		_:
			return &""


static func ellen_flag_for_modification(modification_id: StringName) -> StringName:
	match modification_id:
		&"ember_rite":
			return &"flag.ellen.belief_honored"
		&"root_ward":
			return &"flag.ellen.remedy_trusted"
		&"iron_bracket":
			return &"flag.ellen.skepticism_respected"
		_:
			return &""


static func technique_for_modification(modification_id: StringName) -> StringName:
	match modification_id:
		&"ember_rite":
			return ForgeTechnique.ID_EMBER
		&"root_ward":
			return ForgeTechnique.ID_ROOT
		_:
			return &""

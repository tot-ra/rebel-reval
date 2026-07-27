class_name BreadAndIronQuestModel
extends RefCounted

## Act 1 civic grain cycle gating for quest.bread_and_iron (P4-004).

const QUEST_ID := &"quest.bread_and_iron"
const COMMISSION_ID := &"commission.bread_and_iron"
const UNLOCK_FLAG := &"flag.act1_bread_and_iron_unlocked"
const SUPPLIER_ITEM_ID := &"item.supplier_iron_stock"

const STATE_INVESTIGATING := &"investigating"
const STATE_INVESTIGATION_READY := &"investigation_ready"
const STATE_AFTERMATH_SUPPLIED := &"aftermath_supplied"
const STATE_AFTERMATH_RATIONED := &"aftermath_rationed"
const STATE_AFTERMATH_DEBT := &"aftermath_debt"

const TRANSITION_COMPLETE := &"complete_investigation"
const TRANSITION_HONEST := &"commit_honest_forge"
const TRANSITION_DEFECT := &"commit_defect_forge"
const TRANSITION_RELEASE := &"commit_release_forge"

const TERMINAL_STATES: Array[StringName] = [
	STATE_AFTERMATH_SUPPLIED,
	STATE_AFTERMATH_RATIONED,
	STATE_AFTERMATH_DEBT,
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
	"res://content/packages/bread_and_iron/content",
	"res://content/examples/support",
]


static func is_cycle_unlocked(state: GameState) -> bool:
	if state == null:
		return false
	if state.get_flag(UNLOCK_FLAG):
		return true
	return BellAndChainQuestModel.is_quest_terminal(state)


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
		&"honest_work":
			return TRANSITION_HONEST
		&"subtle_defect":
			return TRANSITION_DEFECT
		&"secret_feature":
			return TRANSITION_RELEASE
		_:
			return &""


static func family_flag_for_modification(modification_id: StringName) -> StringName:
	match modification_id:
		&"honest_work":
			return &"flag.family.raide_supplied"
		&"subtle_defect":
			return &"flag.family.raide_rationed"
		&"secret_feature":
			return &"flag.family.raide_debt"
		_:
			return &""

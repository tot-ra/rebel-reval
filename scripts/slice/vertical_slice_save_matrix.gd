class_name VerticalSliceSaveMatrix
extends RefCounted

## Checkpoint IDs for vertical-slice save/reload regression (P2-016).
## WHY: slice flow spans multiple phases and branch-specific quest states; this
## matrix names each boundary so tests can save, load, and assert preservation.

const FlowModel := preload("res://scripts/slice/vertical_slice_flow_model.gd")
const AftermathModel := preload("res://scripts/investigation/bitter_brew_aftermath_model.gd")
const ReflectionModel := preload("res://scripts/reflection/reflection_model.gd")

const CHECKPOINT_PROLOGUE_COMPLETE := &"checkpoint.prologue_complete"
const CHECKPOINT_INVESTIGATION_MORNING := &"checkpoint.investigation_morning"
const CHECKPOINT_INVESTIGATION_READY := &"checkpoint.investigation_ready"
const CHECKPOINT_COMMISSION_RESOLVED := &"checkpoint.commission_resolved"
const CHECKPOINT_INVESTIGATION_NIGHT := &"checkpoint.investigation_night"
const CHECKPOINT_NIGHT_ROUTE_RESOLVED := &"checkpoint.night_route_resolved"
const CHECKPOINT_CONSEQUENCE_NIGHT := &"checkpoint.consequence_night"
const CHECKPOINT_AFTERMATH_COMMITTED := &"checkpoint.aftermath_committed"
const CHECKPOINT_REFLECTION_MORNING := &"checkpoint.reflection_morning"
const CHECKPOINT_SLICE_COMPLETE := &"checkpoint.slice_complete"

const CHECKPOINT_ORDER: Array[StringName] = [
	CHECKPOINT_PROLOGUE_COMPLETE,
	CHECKPOINT_INVESTIGATION_MORNING,
	CHECKPOINT_INVESTIGATION_READY,
	CHECKPOINT_COMMISSION_RESOLVED,
	CHECKPOINT_INVESTIGATION_NIGHT,
	CHECKPOINT_NIGHT_ROUTE_RESOLVED,
	CHECKPOINT_CONSEQUENCE_NIGHT,
	CHECKPOINT_AFTERMATH_COMMITTED,
	CHECKPOINT_REFLECTION_MORNING,
	CHECKPOINT_SLICE_COMPLETE,
]


static func checkpoint_ids() -> Array[StringName]:
	return CHECKPOINT_ORDER.duplicate()


static func validate_checkpoint(
	state: GameState, checkpoint_id: StringName, branch: Dictionary = {}
) -> bool:
	if state == null:
		return false
	match checkpoint_id:
		CHECKPOINT_PROLOGUE_COMPLETE:
			return state.get_quest_state(FlowModel.QUEST_MAKERS_MARK) == &"ledger_committed"
		CHECKPOINT_INVESTIGATION_MORNING:
			return state.get_phase() == GameState.PHASE_INVESTIGATION_MORNING
		CHECKPOINT_INVESTIGATION_READY:
			return state.get_quest_state(FlowModel.QUEST_BITTER_BREW) == &"investigation_ready"
		CHECKPOINT_COMMISSION_RESOLVED:
			if branch.is_empty():
				return false
			return state.has_forged_record(branch["forged_record"] as StringName)
		CHECKPOINT_INVESTIGATION_NIGHT:
			return state.get_phase() == GameState.PHASE_INVESTIGATION_NIGHT
		CHECKPOINT_NIGHT_ROUTE_RESOLVED:
			if branch.is_empty():
				return false
			return state.get_quest_state(FlowModel.QUEST_BITTER_BREW) == branch["night_quest_state"]
		CHECKPOINT_CONSEQUENCE_NIGHT:
			return state.get_phase() == GameState.PHASE_CONSEQUENCE_NIGHT
		CHECKPOINT_AFTERMATH_COMMITTED:
			if branch.is_empty():
				return false
			return AftermathModel.resolve_outcome(state) == branch["aftermath_outcome"]
		CHECKPOINT_REFLECTION_MORNING:
			return state.get_phase() == GameState.PHASE_REFLECTION_MORNING
		CHECKPOINT_SLICE_COMPLETE:
			return FlowModel.validate_branch_terminal_state(state, branch)
	return false

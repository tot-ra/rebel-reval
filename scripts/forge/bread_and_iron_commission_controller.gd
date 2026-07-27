class_name BreadAndIronCommissionController
extends Node

## Wires commission.bread_and_iron after the civic market investigation completes.

const ModelScript := preload("res://scripts/quest/bread_and_iron_quest_model.gd")
const PROLOGUE_COMMISSION_ID := &"commission.watch_buckle_repair"
const BITTER_BREW_COMMISSION_ID := &"commission.bitter_brew"
const BELL_AND_CHAIN_COMMISSION_ID := &"commission.bell_and_chain"

const PhaseProfileModelScript := preload("res://scripts/phase/phase_profile_model.gd")

var _commission_anchor: ForgeCommissionAnchor
var _rest_anchor: PhaseRestAnchor
var _commission_controller: ForgeCommissionController


func setup(
	commission_anchor: ForgeCommissionAnchor,
	rest_anchor: PhaseRestAnchor,
	player: Player
) -> void:
	_commission_anchor = commission_anchor
	_rest_anchor = rest_anchor
	if player != null:
		_commission_controller = player.get_node_or_null(
			"ForgeCommissionController"
		) as ForgeCommissionController

	if _commission_anchor != null:
		_commission_anchor.set_flow_gate(Callable(self, "_commission_flow_gate"))
	if _commission_controller != null \
			and not _commission_controller.commission_finished.is_connected(
				_on_commission_finished
			):
		_commission_controller.commission_finished.connect(_on_commission_finished)
	if not SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.connect(_on_state_replaced)
	if SessionState.state != null \
			and not SessionState.state.phase_changed.is_connected(_on_phase_changed):
		SessionState.state.phase_changed.connect(_on_phase_changed)
	_sync_stage()


func _exit_tree() -> void:
	if _commission_controller != null \
			and _commission_controller.commission_finished.is_connected(
				_on_commission_finished
			):
		_commission_controller.commission_finished.disconnect(_on_commission_finished)
	if SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.disconnect(_on_state_replaced)
	if SessionState.state != null \
			and SessionState.state.phase_changed.is_connected(_on_phase_changed):
		SessionState.state.phase_changed.disconnect(_on_phase_changed)


func _on_state_replaced(_previous: GameState, current: GameState, _reason: StringName) -> void:
	if current != null and not current.phase_changed.is_connected(_on_phase_changed):
		current.phase_changed.connect(_on_phase_changed)
	_sync_stage()


func _on_phase_changed(_previous: StringName, _next: StringName) -> void:
	_sync_stage()


func _on_commission_finished(commission_id: StringName) -> void:
	if commission_id != ModelScript.COMMISSION_ID:
		return
	_apply_quest_transition()
	_remove_supplier_stock()
	_sync_stage()


func _commission_flow_gate() -> bool:
	return ModelScript.is_forge_flow_active(SessionState.state)


func _sync_stage() -> void:
	if _commission_anchor == null or SessionState.state == null:
		return

	var commission_id := PROLOGUE_COMMISSION_ID
	if ModelScript.is_forge_flow_active(SessionState.state):
		commission_id = ModelScript.COMMISSION_ID
	elif BellAndChainQuestModel.is_forge_flow_active(SessionState.state):
		commission_id = BELL_AND_CHAIN_COMMISSION_ID
	elif _bitter_brew_commission_active():
		commission_id = BITTER_BREW_COMMISSION_ID

	_commission_anchor.set_commission_id(commission_id)
	_commission_anchor.sync_interactable_identity()
	_sync_rest_enabled()


func _sync_rest_enabled() -> void:
	if _rest_anchor == null or SessionState.state == null:
		return
	if SessionState.state.get_phase() == GameState.PHASE_PROLOGUE_DAY:
		return
	var interactable := _rest_anchor.get_interactable()
	if interactable == null:
		return
	var has_next_phase := not PhaseProfileModelScript.next_phase_id(
		SessionState.state.get_phase(),
		SessionState.content_db
	).is_empty()
	var allow_rest := has_next_phase
	if ModelScript.is_forge_flow_active(SessionState.state):
		allow_rest = (
			has_next_phase
			and ForgeCommissionModel.is_commission_resolved(SessionState.state, ModelScript.COMMISSION_ID)
		)
	interactable.enabled = allow_rest


func _apply_quest_transition() -> void:
	if SessionState.state == null:
		return
	var record := _latest_bread_record()
	if record == null:
		return
	var transition_id := ModelScript.transition_for_modification(record.modification_id)
	if transition_id.is_empty():
		return
	var manager := QuestManager.new(SessionState.content_db, SessionState.state)
	manager.transition(ModelScript.QUEST_ID, transition_id)


func _remove_supplier_stock() -> void:
	if SessionState.state == null:
		return
	if SessionState.state.has_item(ModelScript.SUPPLIER_ITEM_ID):
		SessionState.state.remove_item(ModelScript.SUPPLIER_ITEM_ID)


func _latest_bread_record() -> ForgedRecord:
	if SessionState.state == null:
		return null
	for record in SessionState.state.get_forged_records():
		if record.commission_id == ModelScript.COMMISSION_ID:
			return record
	return null


func _bitter_brew_commission_active() -> bool:
	if SessionState.state == null:
		return false
	if SessionState.state.get_phase() != GameState.PHASE_INVESTIGATION_MORNING:
		return false
	return SessionState.state.get_quest_state(&"quest.bitter_brew") == &"investigation_ready"

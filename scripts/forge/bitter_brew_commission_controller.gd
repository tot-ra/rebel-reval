class_name BitterBrewCommissionController
extends Node

## Wires the Bitter Brew forge commission after daytime investigation completes.
## Switches the shared ledger anchor to commission.bitter_brew and gates bed rest
## until Kalev commits a forged response.

const BellAndChainModelScript := preload("res://scripts/quest/bell_and_chain_quest_model.gd")
const BreadAndIronModelScript := preload("res://scripts/quest/bread_and_iron_quest_model.gd")
const PriceOfANameModelScript := preload("res://scripts/quest/price_of_a_name_quest_model.gd")

const QUEST_ID := &"quest.bitter_brew"
const COMMISSION_ID := &"commission.bitter_brew"
const PROLOGUE_COMMISSION_ID := &"commission.watch_buckle_repair"

const STATE_INVESTIGATION_READY := &"investigation_ready"

const PhaseProfileModelScript := preload("res://scripts/phase/phase_profile_model.gd")

var _commission_anchor: ForgeCommissionAnchor
var _rest_anchor: PhaseRestAnchor
var _commission_controller: ForgeCommissionController


func setup(
	commission_anchor: ForgeCommissionAnchor, rest_anchor: PhaseRestAnchor, player: Player
) -> void:
	_commission_anchor = commission_anchor
	_rest_anchor = rest_anchor
	if player != null:
		_commission_controller = (
			player.get_node_or_null("ForgeCommissionController") as ForgeCommissionController
		)

	if _commission_anchor != null:
		_commission_anchor.set_flow_gate(Callable(self, "_commission_flow_gate"))
	if (
		_commission_controller != null
		and not _commission_controller.commission_finished.is_connected(_on_commission_finished)
	):
		_commission_controller.commission_finished.connect(_on_commission_finished)
	if not SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.connect(_on_state_replaced)
	if (
		SessionState.state != null
		and not SessionState.state.phase_changed.is_connected(_on_phase_changed)
	):
		SessionState.state.phase_changed.connect(_on_phase_changed)
	_sync_stage()


func _exit_tree() -> void:
	if (
		_commission_controller != null
		and _commission_controller.commission_finished.is_connected(_on_commission_finished)
	):
		_commission_controller.commission_finished.disconnect(_on_commission_finished)
	if SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.disconnect(_on_state_replaced)
	if (
		SessionState.state != null
		and SessionState.state.phase_changed.is_connected(_on_phase_changed)
	):
		SessionState.state.phase_changed.disconnect(_on_phase_changed)


func _on_state_replaced(_previous: GameState, current: GameState, _reason: StringName) -> void:
	if current != null and not current.phase_changed.is_connected(_on_phase_changed):
		current.phase_changed.connect(_on_phase_changed)
	_sync_stage()


func _on_phase_changed(_previous: StringName, _next: StringName) -> void:
	_sync_stage()


func _on_commission_finished(commission_id: StringName) -> void:
	if commission_id != COMMISSION_ID:
		return
	_sync_stage()


func _process(_delta: float) -> void:
	_sync_stage()


func _commission_flow_gate() -> bool:
	if SessionState.state == null:
		return false
	var phase := SessionState.state.get_phase()
	if phase == GameState.PHASE_PROLOGUE_DAY:
		return true
	if phase != GameState.PHASE_INVESTIGATION_MORNING:
		return false
	return _quest_state() == STATE_INVESTIGATION_READY


func _sync_stage() -> void:
	if _commission_anchor == null or SessionState.state == null:
		return
	if BellAndChainModelScript.is_forge_flow_active(SessionState.state):
		return
	if BreadAndIronModelScript.is_forge_flow_active(SessionState.state):
		return
	if PriceOfANameModelScript.is_forge_flow_active(SessionState.state):
		return

	if SessionState.state.get_phase() == GameState.PHASE_INVESTIGATION_MORNING:
		_commission_anchor.set_commission_id(COMMISSION_ID)
	else:
		_commission_anchor.set_commission_id(PROLOGUE_COMMISSION_ID)

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
	var has_next_phase := not (
		PhaseProfileModelScript
		. next_phase_id(SessionState.state.get_phase(), SessionState.content_db)
		. is_empty()
	)
	var allow_rest := has_next_phase
	if _is_investigation_commission_flow():
		allow_rest = (
			has_next_phase
			and ForgeCommissionModel.is_commission_resolved(SessionState.state, COMMISSION_ID)
		)
	interactable.enabled = allow_rest


func _is_investigation_commission_flow() -> bool:
	return (
		SessionState.state.get_phase() == GameState.PHASE_INVESTIGATION_MORNING
		and _quest_state() == STATE_INVESTIGATION_READY
	)


func _quest_state() -> StringName:
	if SessionState.state == null:
		return &""
	return SessionState.state.get_quest_state(QUEST_ID)

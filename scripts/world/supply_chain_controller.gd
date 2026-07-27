class_name SupplyChainController
extends Node

## Spawns the north-quarter iron convoy, records observation, and resolves quest branches.

const ModelScript := preload("res://scripts/world/supply_chain_model.gd")
const ConvoyScript := preload("res://scripts/world/supply_chain_convoy.gd")
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const UiPresenterScript := preload("res://scripts/dialogue/dialogue_ui_presenter.gd")
const UiScript := preload("res://scripts/dialogue/dialogue_ui.gd")
const INTERACTABLE_SCENE := preload("res://scenes/interaction/interactable.tscn")

var location_id: StringName = &""

var _scene_root: Node2D
var _definition: MapDefinition
var _player: Player
var _actors_parent: Node2D
var _interaction_controller: InteractionController
var _view_binder: InteractableViewBinder
var _runner: DialogueRunner
var _presenter: RefCounted
var _dialogue_ui: DialogueUI
var _convoy: CharacterBody2D
var _convoy_interactable: Interactable
var _merchant_interactable: Interactable
var _state: GameState
var _convoy_active := false
var _arrival_committed := false


func setup(
	scene_root: Node2D,
	definition: MapDefinition,
	player: Player,
	view_runtime: MapViewRuntime,
	actors_parent: Node2D,
	interaction_controller: InteractionController,
	map_location_id: StringName
) -> void:
	location_id = map_location_id
	_scene_root = scene_root
	_definition = definition
	_player = player
	_actors_parent = actors_parent
	_interaction_controller = interaction_controller
	_build_dialogue_stack()
	_build_view_binder(view_runtime, definition)
	_spawn_convoy()
	_spawn_merchant_interactable()
	_connect_state(SessionState.state)
	if not SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.connect(_on_state_replaced)


func _exit_tree() -> void:
	if SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.disconnect(_on_state_replaced)
	_disconnect_state(_state)


func _physics_process(_delta: float) -> void:
	_sync_convoy_presence()
	_track_observation()


func is_convoy_active() -> bool:
	return _convoy_active


func get_convoy() -> CharacterBody2D:
	return _convoy


func get_merchant_interactable() -> Interactable:
	return _merchant_interactable


func sync_for_test(phase_id: StringName) -> void:
	if _state == null:
		return
	_state.set_phase(phase_id)
	_ensure_quest_started()
	_sync_convoy_presence()
	_track_observation()


func commit_convoy_arrival_for_test() -> void:
	if _state == null:
		return
	_state.set_fact(ModelScript.FACT_ARRIVED, true)
	_commit_arrival()


func apply_disruption_for_test() -> void:
	if _state == null:
		return
	_state.set_flag(ModelScript.FLAG_DISRUPTED, true)
	_disable_convoy()
	_quest_manager().transition(ModelScript.QUEST_ID, ModelScript.TRANSITION_DISRUPTED)


func _on_state_replaced(_previous: GameState, current: GameState, _reason: StringName) -> void:
	_connect_state(current)


func _connect_state(state: GameState) -> void:
	_disconnect_state(_state)
	_state = state
	_arrival_committed = false
	if _state != null and not _state.phase_changed.is_connected(_on_phase_changed):
		_state.phase_changed.connect(_on_phase_changed)
	_sync_convoy_presence()


func _quest_manager() -> QuestManager:
	return QuestManager.new(SessionState.content_db, _state)


func _disconnect_state(state: GameState) -> void:
	if state != null and state.phase_changed.is_connected(_on_phase_changed):
		state.phase_changed.disconnect(_on_phase_changed)


func _on_phase_changed(_previous: StringName, _next: StringName) -> void:
	_arrival_committed = false
	_sync_convoy_presence()


func _ensure_quest_started() -> void:
	if _state == null or not ModelScript.convoy_active_for_phase(_state.get_phase()):
		return
	if _state.get_quest_state(ModelScript.QUEST_ID).is_empty():
		_quest_manager().start_quest(ModelScript.QUEST_ID)


func _sync_convoy_presence() -> void:
	if _convoy == null or _state == null:
		return
	_ensure_quest_started()
	var should_run := (
		ModelScript.convoy_active_for_phase(_state.get_phase())
		and not ModelScript.is_route_disrupted(_state)
		and _state.get_quest_state(ModelScript.QUEST_ID) == &"awaiting_convoy"
	)
	_convoy_active = should_run
	_convoy.set_route_enabled(should_run)
	if _convoy_interactable != null:
		_convoy_interactable.enabled = should_run
	if should_run and _convoy.has_completed_lap():
		_commit_arrival()


func _track_observation() -> void:
	if _player == null or _state == null or not _convoy_active:
		return
	if _state.get_fact(ModelScript.FACT_OBSERVED):
		return
	if _player.global_position.distance_squared_to(_convoy.global_position) <= ModelScript.OBSERVE_RADIUS_SQ:
		_state.set_fact(ModelScript.FACT_OBSERVED, true)


func _commit_arrival() -> void:
	if _state == null or _arrival_committed:
		return
	_arrival_committed = true
	_state.set_fact(ModelScript.FACT_ARRIVED, true)
	_disable_convoy()
	_quest_manager().transition(ModelScript.QUEST_ID, ModelScript.TRANSITION_DELIVERED)


func _disable_convoy() -> void:
	_convoy_active = false
	if _convoy != null:
		_convoy.set_route_enabled(false)
	if _convoy_interactable != null:
		_convoy_interactable.enabled = false


func _build_dialogue_stack() -> void:
	_dialogue_ui = UiScript.new()
	_dialogue_ui.name = "SupplyChainDialogueUI"
	_scene_root.add_child(_dialogue_ui)

	_runner = RunnerScript.new()
	_runner.name = "SupplyChainDialogueRunner"
	add_child(_runner)
	_presenter = UiPresenterScript.new()
	_presenter.configure(_dialogue_ui, _runner)
	_runner.configure(SessionState.content_db, SessionState.state, _presenter)
	_runner.finished.connect(_on_dialogue_finished)


func _build_view_binder(view_runtime: MapViewRuntime, definition: MapDefinition) -> void:
	_view_binder = InteractableViewBinder.new()
	_view_binder.name = "SupplyChainInteractableViewBinder"
	add_child(_view_binder)
	_view_binder.setup(view_runtime, definition)


func _spawn_convoy() -> void:
	var points := ModelScript.resolve_patrol_points(_definition)
	_convoy = ConvoyScript.new()
	_convoy.name = "IronConvoy"
	_actors_parent.add_child(_convoy)
	_convoy.configure(points)

	_convoy_interactable = INTERACTABLE_SCENE.instantiate()
	_convoy_interactable.name = "IronConvoyInteractable"
	_convoy_interactable.interactable_id = ModelScript.CONVOY_INTERACTABLE_ID
	_convoy_interactable.interaction_kind = InteractionKinds.TALK
	_convoy_interactable.prompt = "Stop the porter"
	_convoy_interactable.set_interact_callback(Callable(self, "_on_convoy_pressed"))
	_convoy.add_child(_convoy_interactable)
	_view_binder.bind(_convoy_interactable)


func _spawn_merchant_interactable() -> void:
	var position := MapVerification.anchor_position(_definition, ModelScript.MERCHANT_ANCHOR_ID)
	if position == Vector2.ZERO:
		return
	_merchant_interactable = INTERACTABLE_SCENE.instantiate()
	_merchant_interactable.name = "IronShipmentMerchant"
	_merchant_interactable.interactable_id = ModelScript.MERCHANT_INTERACTABLE_ID
	_merchant_interactable.interaction_kind = InteractionKinds.TALK
	_merchant_interactable.prompt = "Ask about the iron shipment"
	_merchant_interactable.global_position = position
	_merchant_interactable.set_interact_callback(Callable(self, "_on_merchant_pressed"))
	_scene_root.add_child(_merchant_interactable)
	_view_binder.bind(_merchant_interactable)


func _on_convoy_pressed(_actor: Node) -> void:
	if _runner == null or _runner.is_active():
		return
	_runner.configure(SessionState.content_db, _state, _presenter)
	if not _runner.start(ModelScript.CONVOY_DIALOGUE_ID):
		return
	_set_interaction_enabled(false)


func _on_merchant_pressed(_actor: Node) -> void:
	if _runner == null or _runner.is_active():
		return
	_runner.configure(SessionState.content_db, _state, _presenter)
	if not _runner.start(ModelScript.MERCHANT_DIALOGUE_ID):
		return
	_set_interaction_enabled(false)


func _on_dialogue_finished(finished_id: StringName) -> void:
	_set_interaction_enabled(true)
	if _state == null:
		return
	if finished_id == ModelScript.CONVOY_DIALOGUE_ID and ModelScript.is_route_disrupted(_state):
		_quest_manager().transition(ModelScript.QUEST_ID, ModelScript.TRANSITION_DISRUPTED)
		_disable_convoy()
	_sync_convoy_presence()


func _set_interaction_enabled(enabled: bool) -> void:
	if _interaction_controller == null:
		return
	_interaction_controller.set_process(enabled)
	_interaction_controller.set_process_unhandled_input(enabled)
	if _interaction_controller.prompt_label != null:
		_interaction_controller.prompt_label.visible = (
			enabled and _interaction_controller.get_focused_interactable() != null
		)

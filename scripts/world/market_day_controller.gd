class_name MarketDayController
extends Node

## Toggles market stall density and merchant trade dialogue from the campaign calendar.

const ModelScript := preload("res://scripts/world/market_day_model.gd")
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const UiPresenterScript := preload("res://scripts/dialogue/dialogue_ui_presenter.gd")
const UiScript := preload("res://scripts/dialogue/dialogue_ui.gd")
const FeedbackScript := preload("res://scripts/world/world_item_pickup_feedback.gd")
const INTERACTABLE_SCENE := preload("res://scenes/interaction/interactable.tscn")
const KEEPER_NPC_SCRIPT := preload("res://scripts/world/static_npc_actor.gd")
const KEEPER_RIG_SCENE := preload("res://assets/characters/variants/innkeeper.tscn")
const CROWD_BARK_POOL := &"bark.market_day.crowd"
## Logic-pixel offset placing the keeper beside the stall counter (stall rect is
## 2x1 cells of 32 px) so the body does not sit inside the prop footprint.
const KEEPER_STALL_OFFSET := Vector2(-48.0, 0.0)

var location_id: StringName = &""

var _scene_root: Node2D
var _definition: MapDefinition
var _player: Player
var _view_runtime: MapViewRuntime
var _interaction_controller: InteractionController
var _view_binder: InteractableViewBinder
var _runner: DialogueRunner
var _presenter: RefCounted
var _dialogue_ui: DialogueUI
var _merchant_interactable: Interactable
var _stall_keeper: StaticNpcActor
var _state: GameState
var _synced_date_key := ""
var _market_day_active := false
var _crowd_layer: CanvasLayer
var _crowd_label: Label
var _crowd_timer := 0.0


func setup(
	scene_root: Node2D,
	definition: MapDefinition,
	player: Player,
	view_runtime: MapViewRuntime,
	interaction_controller: InteractionController,
	map_location_id: StringName
) -> void:
	location_id = map_location_id
	_scene_root = scene_root
	_definition = definition
	_player = player
	_view_runtime = view_runtime
	_interaction_controller = interaction_controller
	_build_dialogue_stack()
	_build_crowd_ui()
	_build_view_binder(view_runtime, definition)
	_spawn_merchant_interactable()
	_connect_state(SessionState.state)
	if not SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.connect(_on_state_replaced)


func _exit_tree() -> void:
	if SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.disconnect(_on_state_replaced)
	_disconnect_state(_state)


func _process(delta: float) -> void:
	_sync_from_calendar()
	if _crowd_timer > 0.0 and _crowd_label != null:
		_crowd_timer = maxf(0.0, _crowd_timer - delta)
		if _crowd_timer <= 0.0:
			_crowd_label.visible = false
			_crowd_label.text = ""


func is_market_day_active() -> bool:
	return _market_day_active


func get_merchant_interactable() -> Interactable:
	return _merchant_interactable


func get_stall_keeper() -> Node2D:
	return _stall_keeper


func sync_for_test(phase_id: StringName, elapsed_days: int) -> void:
	if _state == null:
		return
	var previous_active := _market_day_active
	_market_day_active = ModelScript.sync_flag(_state, phase_id, elapsed_days)
	_apply_market_presence(previous_active)
	_synced_date_key = _date_key_for(phase_id, elapsed_days)


func _on_state_replaced(_previous: GameState, current: GameState, _reason: StringName) -> void:
	_connect_state(current)


func _connect_state(state: GameState) -> void:
	_disconnect_state(_state)
	_state = state
	if _state != null and not _state.phase_changed.is_connected(_on_phase_changed):
		_state.phase_changed.connect(_on_phase_changed)
	_sync_from_calendar()


func _disconnect_state(state: GameState) -> void:
	if state != null and state.phase_changed.is_connected(_on_phase_changed):
		state.phase_changed.disconnect(_on_phase_changed)


func _on_phase_changed(_previous: StringName, _next: StringName) -> void:
	_synced_date_key = ""
	_sync_from_calendar()


func _sync_from_calendar() -> void:
	if _state == null:
		return
	var phase_id := _state.get_phase()
	var elapsed_days := _elapsed_days()
	var date_key := _date_key_for(phase_id, elapsed_days)
	if date_key == _synced_date_key:
		return
	_synced_date_key = date_key
	var previous_active := _market_day_active
	_market_day_active = ModelScript.sync_flag(_state, phase_id, elapsed_days)
	_apply_market_presence(previous_active)


func _elapsed_days() -> int:
	if _view_runtime != null:
		return _view_runtime.cycle_elapsed_days
	return 0


func _date_key_for(phase_id: StringName, elapsed_days: int) -> String:
	var date := ModelScript.resolve_date(phase_id, elapsed_days)
	return GameCalendar.format_date(date)


func _apply_market_presence(previous_active: bool) -> void:
	_set_expanded_stalls_visible(_market_day_active)
	if _merchant_interactable != null:
		_merchant_interactable.enabled = true
		_merchant_interactable.prompt = (
			"Talk to the stall keeper"
			if _market_day_active
			else "Ask about the closed stall"
		)
	if _market_day_active and not previous_active:
		_present_crowd_bark()


func _build_crowd_ui() -> void:
	if _scene_root == null:
		return
	_crowd_layer = CanvasLayer.new()
	_crowd_layer.name = "MarketDayCrowdPresenter"
	_crowd_layer.layer = 22
	_scene_root.add_child(_crowd_layer)
	_crowd_label = Label.new()
	_crowd_label.anchor_left = 0.5
	_crowd_label.anchor_right = 0.5
	_crowd_label.anchor_top = 1.0
	_crowd_label.anchor_bottom = 1.0
	_crowd_label.offset_left = -380.0
	_crowd_label.offset_right = 380.0
	_crowd_label.offset_top = -210.0
	_crowd_label.offset_bottom = -162.0
	_crowd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crowd_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_crowd_label.add_theme_color_override("font_color", Color(0.92, 0.9, 0.78, 1.0))
	_crowd_label.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.08, 1.0))
	_crowd_label.add_theme_constant_override("outline_size", 5)
	_crowd_label.visible = false
	_crowd_layer.add_child(_crowd_label)


func _present_crowd_bark() -> void:
	if _runner == null or _crowd_label == null or _state == null:
		return
	_runner.configure(SessionState.content_db, _state, _presenter)
	var bark := _runner.resolve_bark(CROWD_BARK_POOL, _state.get_phase(), location_id)
	if bark.is_empty():
		return
	_crowd_timer = FeedbackScript.show_bark(_crowd_label, bark)


func _set_expanded_stalls_visible(visible_state: bool) -> void:
	if _view_runtime == null or _view_runtime.view == null:
		return
	for prop_id: StringName in ModelScript.EXPANDED_STALL_PROP_IDS:
		_view_runtime.view.set_prop_visible(prop_id, visible_state)


func _build_dialogue_stack() -> void:
	_dialogue_ui = UiScript.new()
	_dialogue_ui.name = "MarketDayDialogueUI"
	_scene_root.add_child(_dialogue_ui)

	_runner = RunnerScript.new()
	_runner.name = "MarketDayDialogueRunner"
	add_child(_runner)
	_presenter = UiPresenterScript.new()
	_presenter.configure(_dialogue_ui, _runner)
	_runner.configure(SessionState.content_db, SessionState.state, _presenter)
	_runner.finished.connect(_on_dialogue_finished)


func _build_view_binder(view_runtime: MapViewRuntime, definition: MapDefinition) -> void:
	_view_binder = InteractableViewBinder.new()
	_view_binder.name = "MarketDayInteractableViewBinder"
	add_child(_view_binder)
	_view_binder.setup(view_runtime, definition)


func _spawn_merchant_interactable() -> void:
	var position := MapVerification.prop_position(_definition, ModelScript.MERCHANT_PROP_ID)
	if position == Vector2.ZERO:
		return
	_spawn_stall_keeper(position + KEEPER_STALL_OFFSET)
	_merchant_interactable = INTERACTABLE_SCENE.instantiate()
	_merchant_interactable.name = "MarketDayMerchant"
	_merchant_interactable.interactable_id = ModelScript.MERCHANT_INTERACTABLE_ID
	_merchant_interactable.interaction_kind = InteractionKinds.TALK
	_merchant_interactable.prompt = "Talk to the stall keeper"
	_merchant_interactable.set_interact_callback(Callable(self, "_on_merchant_pressed"))
	if _stall_keeper != null:
		# Parenting to the keeper keeps the talk prompt and the 3D focus marker on
		# the person instead of floating over an empty stall.
		_stall_keeper.add_child(_merchant_interactable)
	else:
		_merchant_interactable.global_position = position
		_scene_root.add_child(_merchant_interactable)
	_view_binder.bind(_merchant_interactable)


func _spawn_stall_keeper(position: Vector2) -> void:
	if _scene_root == null:
		return
	_stall_keeper = KEEPER_NPC_SCRIPT.new()
	_stall_keeper.name = "MarketStallKeeper"
	_stall_keeper.rig_scene = KEEPER_RIG_SCENE
	var actors := _scene_root.get_node_or_null("Actors")
	if actors != null:
		actors.add_child(_stall_keeper)
	else:
		_scene_root.add_child(_stall_keeper)
	# Face east toward the stall counter until the player comes close enough for
	# view_facing() to turn the keeper toward them.
	_stall_keeper.configure(_player, position, Vector2.RIGHT)
	if _view_runtime != null:
		# Controllers run after MapViewRuntime.install(), so the boot-time actor
		# scan already happened and the rig must be registered explicitly.
		_view_runtime.register_view_actor(_stall_keeper)


func _on_merchant_pressed(_actor: Node) -> void:
	if _runner == null or _runner.is_active():
		return
	_runner.configure(SessionState.content_db, _state, _presenter)
	if not _runner.start(ModelScript.MERCHANT_DIALOGUE_ID):
		return
	_set_interaction_enabled(false)


func _on_dialogue_finished(_dialogue_id: StringName) -> void:
	_set_interaction_enabled(true)


func _set_interaction_enabled(enabled: bool) -> void:
	if _interaction_controller == null:
		return
	_interaction_controller.set_process(enabled)
	_interaction_controller.set_process_unhandled_input(enabled)
	if _interaction_controller.prompt_label != null:
		_interaction_controller.prompt_label.visible = (
			enabled and _interaction_controller.get_focused_interactable() != null
		)

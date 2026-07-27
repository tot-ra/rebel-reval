class_name PriceOfANameInvestigation
extends Node

## Daytime north-quarter harbor evidence loop for quest.price_of_a_name (P4-006).

const ModelScript := preload("res://scripts/quest/price_of_a_name_quest_model.gd")

const INTERACTABLE_SCENE := preload("res://scenes/interaction/interactable.tscn")
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const UiPresenterScript := preload("res://scripts/dialogue/dialogue_ui_presenter.gd")
const UiScript := preload("res://scripts/dialogue/dialogue_ui.gd")

const SITES: Array[Dictionary] = [
	{
		"interactable_id": &"interact.price_of_a_name.watch_tower",
		"position_kind": &"anchor",
		"position_id": &"checkpoint_east",
		"dialogue_id": &"dialogue.price_of_a_name.inspect_watch_tower",
		"fact_id": &"fact.price_of_a_name.dispatch_name",
		"prompt": "Inspect the harbor watch tower log",
	},
	{
		"interactable_id": &"interact.price_of_a_name.salt_warehouse",
		"position_kind": &"prop",
		"position_id": &"merchants_house",
		"dialogue_id": &"dialogue.price_of_a_name.inspect_salt_warehouse",
		"fact_id": &"fact.price_of_a_name.salt_warehouse_drop",
		"prompt": "Search the salt warehouses",
	},
	{
		"interactable_id": &"interact.price_of_a_name.packhouse_lane",
		"position_kind": &"prop",
		"position_id": &"market_stall_turg_south",
		"dialogue_id": &"dialogue.price_of_a_name.inspect_packhouse_lane",
		"fact_id": &"fact.price_of_a_name.packhouse_spears",
		"prompt": "Inspect the packhouse barrel returns",
	},
	{
		"interactable_id": &"interact.price_of_a_name.ropewalk_lane",
		"position_kind": &"prop",
		"position_id": &"ropeyard_rope",
		"dialogue_id": &"dialogue.price_of_a_name.inspect_ropewalk_lane",
		"fact_id": &"fact.price_of_a_name.ropewalk_route",
		"prompt": "Read the ropewalk requisition",
	},
]

var _scene_root: Node2D
var _definition: MapDefinition
var _interaction_controller: InteractionController
var _view_binder: InteractableViewBinder
var _quest_manager: QuestManager
var _runner: DialogueRunner
var _presenter: RefCounted
var _dialogue_ui: DialogueUI
var _interactables: Dictionary[StringName, Interactable] = {}
var _pending_dialogue_id := &""
var _dispatch_granted := false


func setup(
	scene_root: Node2D,
	definition: MapDefinition,
	view_runtime: MapViewRuntime,
	interaction_controller: InteractionController
) -> void:
	_scene_root = scene_root
	_definition = definition
	_interaction_controller = interaction_controller
	_build_dialogue_stack()
	_build_view_binder(view_runtime, definition)
	_spawn_inspection_sites()
	_quest_manager = QuestManager.new(SessionState.content_db, SessionState.state)
	if not SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.connect(_on_state_replaced)
	if SessionState.state != null and not SessionState.state.phase_changed.is_connected(_on_phase_changed):
		SessionState.state.phase_changed.connect(_on_phase_changed)
	_sync_quest_and_sites()


func get_interactable(site_interactable_id: StringName) -> Interactable:
	return _interactables.get(site_interactable_id, null)


func inspect_site_for_test(site_interactable_id: StringName) -> bool:
	var interactable := get_interactable(site_interactable_id)
	if interactable == null or not interactable.is_enabled():
		return false
	_on_site_pressed(interactable, site_interactable_id)
	return true


func advance_dialogue_for_test() -> void:
	if _runner != null and _runner.is_active():
		_runner.advance_for_test()


func _exit_tree() -> void:
	if SessionState.state != null and SessionState.state.phase_changed.is_connected(_on_phase_changed):
		SessionState.state.phase_changed.disconnect(_on_phase_changed)
	if SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.disconnect(_on_state_replaced)


func _on_state_replaced(_previous: GameState, current: GameState, _reason: StringName) -> void:
	_quest_manager = QuestManager.new(SessionState.content_db, current)
	_runner.configure(SessionState.content_db, current, _presenter)
	if current != null and not current.phase_changed.is_connected(_on_phase_changed):
		current.phase_changed.connect(_on_phase_changed)
	_sync_quest_and_sites()


func _on_phase_changed(_previous: StringName, _next: StringName) -> void:
	_sync_quest_and_sites()


func _build_dialogue_stack() -> void:
	_dialogue_ui = UiScript.new()
	_dialogue_ui.name = "PriceOfANameDialogueUI"
	_scene_root.add_child(_dialogue_ui)

	_runner = RunnerScript.new()
	_runner.name = "PriceOfANameDialogueRunner"
	add_child(_runner)
	_presenter = UiPresenterScript.new()
	_presenter.configure(_dialogue_ui, _runner)
	_runner.configure(SessionState.content_db, SessionState.state, _presenter)
	_runner.finished.connect(_on_dialogue_finished)


func _build_view_binder(view_runtime: MapViewRuntime, definition: MapDefinition) -> void:
	_view_binder = InteractableViewBinder.new()
	_view_binder.name = "PriceOfANameInteractableViewBinder"
	add_child(_view_binder)
	_view_binder.setup(view_runtime, definition)


func _spawn_inspection_sites() -> void:
	for site in SITES:
		var interactable_id: StringName = site["interactable_id"]
		var position: Vector2 = _site_position(site)
		if position == Vector2.ZERO:
			continue

		var interactable: Interactable = INTERACTABLE_SCENE.instantiate()
		interactable.name = String(interactable_id)
		interactable.interactable_id = interactable_id
		interactable.interaction_kind = InteractionKinds.USE
		interactable.prompt = String(site["prompt"])
		interactable.global_position = position
		interactable.enabled = false
		interactable.set_interact_callback(
			Callable(self, "_on_site_pressed").bind(interactable_id)
		)
		_scene_root.add_child(interactable)
		_interactables[interactable_id] = interactable
		_view_binder.bind(interactable)


func _site_position(site: Dictionary) -> Vector2:
	var position_id: StringName = site["position_id"]
	if site["position_kind"] == &"anchor":
		return MapVerification.anchor_position(_definition, position_id)
	return MapVerification.prop_position(_definition, position_id)


func _sync_quest_and_sites() -> void:
	if SessionState.state == null:
		return
	var investigation_active := ModelScript.is_investigation_active(SessionState.state)
	var quest_state := _quest_state()

	if investigation_active and quest_state.is_empty():
		_quest_manager.start_quest(ModelScript.QUEST_ID)
		quest_state = _quest_state()
		_grant_seized_dispatch()

	investigation_active = investigation_active and quest_state == ModelScript.STATE_INVESTIGATING
	for site in SITES:
		var interactable_id: StringName = site["interactable_id"]
		var fact_id: StringName = site["fact_id"]
		var interactable: Interactable = _interactables.get(interactable_id, null) as Interactable
		if interactable == null:
			continue
		interactable.enabled = investigation_active and not SessionState.state.get_fact(fact_id)

	if investigation_active and _all_facts_known():
		_quest_manager.transition(ModelScript.QUEST_ID, ModelScript.TRANSITION_COMPLETE)


func _grant_seized_dispatch() -> void:
	if _dispatch_granted or SessionState.state == null:
		return
	if SessionState.state.has_item(ModelScript.DISPATCH_ITEM_ID):
		_dispatch_granted = true
		return
	SessionState.state.add_item(ModelScript.DISPATCH_ITEM_ID)
	_dispatch_granted = true


func _on_site_pressed(_actor: Node, interactable_id: StringName) -> void:
	if _runner != null and _runner.is_active():
		return
	var site: Dictionary = _site_for_interactable(interactable_id)
	if site.is_empty():
		return
	var dialogue_id: StringName = site["dialogue_id"]
	if not _start_dialogue(dialogue_id):
		return
	_pending_dialogue_id = dialogue_id


func _on_dialogue_finished(dialogue_id: StringName) -> void:
	_set_interaction_enabled(true)
	if dialogue_id != _pending_dialogue_id:
		return
	_pending_dialogue_id = &""
	_sync_quest_and_sites()


func _start_dialogue(dialogue_id: StringName) -> bool:
	if _runner == null:
		return false
	_runner.configure(SessionState.content_db, SessionState.state, _presenter)
	if not _runner.start(dialogue_id):
		return false
	_set_interaction_enabled(false)
	return true


func _set_interaction_enabled(enabled: bool) -> void:
	if _interaction_controller == null:
		return
	_interaction_controller.set_process(enabled)
	_interaction_controller.set_process_unhandled_input(enabled)
	if _interaction_controller.prompt_label != null:
		_interaction_controller.prompt_label.visible = (
			enabled and _interaction_controller.get_focused_interactable() != null
		)


func _site_for_interactable(interactable_id: StringName) -> Dictionary:
	for site in SITES:
		if site["interactable_id"] == interactable_id:
			return site
	return {}


func _quest_state() -> StringName:
	if SessionState.state == null:
		return &""
	return SessionState.state.get_quest_state(ModelScript.QUEST_ID)


func _all_facts_known() -> bool:
	if SessionState.state == null:
		return false
	for site in SITES:
		if not SessionState.state.get_fact(site["fact_id"]):
			return false
	return true

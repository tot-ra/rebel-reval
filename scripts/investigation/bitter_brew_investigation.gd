class_name BitterBrewInvestigation
extends Node

## Daytime A Bitter Brew investigation: four authored inspection sites that record
## evidence facts and advance quest.bitter_brew to investigation_ready.

const QUEST_ID := &"quest.bitter_brew"
const TRANSITION_COMPLETE := &"complete_investigation"

const STATE_INVESTIGATING := &"investigating"
const STATE_INVESTIGATION_READY := &"investigation_ready"

const INTERACTABLE_SCENE := preload("res://scenes/interaction/interactable.tscn")
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const UiPresenterScript := preload("res://scripts/dialogue/dialogue_ui_presenter.gd")
const UiScript := preload("res://scripts/dialogue/dialogue_ui.gd")

const SITES: Array[Dictionary] = [
	{
		"interactable_id": &"interact.bitter_brew.cistern",
		"position_kind": &"prop",
		"position_id": &"cistern",
		"dialogue_id": &"dialogue.bitter_brew.inspect_cistern",
		"fact_id": &"fact.bitter_brew.cistern_contaminated",
		"prompt": "Inspect the public well",
	},
	{
		"interactable_id": &"interact.bitter_brew.brewery",
		"position_kind": &"anchor",
		"position_id": &"brewery_door",
		"dialogue_id": &"dialogue.bitter_brew.inspect_brewery",
		"fact_id": &"fact.bitter_brew.brewery_ale_sound",
		"prompt": "Inspect the brewery yard",
	},
	{
		"interactable_id": &"interact.bitter_brew.supply",
		"position_kind": &"prop",
		"position_id": &"evidence_barrels",
		"dialogue_id": &"dialogue.bitter_brew.inspect_supply",
		"fact_id": &"fact.bitter_brew.merchant_supply_spoiled",
		"prompt": "Inspect the merchant barrels",
	},
	{
		"interactable_id": &"interact.bitter_brew.checkpoint",
		"position_kind": &"anchor",
		"position_id": &"checkpoint_west",
		"dialogue_id": &"dialogue.bitter_brew.inspect_checkpoint",
		"fact_id": &"fact.bitter_brew.checkpoint_neglect",
		"prompt": "Inspect the watch cistern",
	},
]

var _scene_root: Node2D
var _definition: MapDefinition
var _player: Player
var _interaction_controller: InteractionController
var _view_binder: InteractableViewBinder
var _quest_manager: QuestManager
var _runner: DialogueRunner
var _presenter: RefCounted
var _dialogue_ui: DialogueUI
var _interactables: Dictionary[StringName, Interactable] = {}
var _pending_dialogue_id := &""


func setup(
	scene_root: Node2D,
	definition: MapDefinition,
	player: Player,
	view_runtime: MapViewRuntime,
	interaction_controller: InteractionController
) -> void:
	_scene_root = scene_root
	_definition = definition
	_player = player
	_interaction_controller = interaction_controller
	_build_dialogue_stack()
	_build_view_binder(view_runtime, definition)
	_spawn_inspection_sites()
	_quest_manager = QuestManager.new(SessionState.content_db, SessionState.state)
	if not SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.connect(_on_state_replaced)
	if not SessionState.state.phase_changed.is_connected(_on_phase_changed):
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
	if (
		SessionState.state != null
		and SessionState.state.phase_changed.is_connected(_on_phase_changed)
	):
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
	_dialogue_ui.name = "BitterBrewDialogueUI"
	_scene_root.add_child(_dialogue_ui)

	_runner = RunnerScript.new()
	_runner.name = "BitterBrewDialogueRunner"
	add_child(_runner)
	_presenter = UiPresenterScript.new()
	_presenter.configure(_dialogue_ui, _runner)
	_runner.configure(SessionState.content_db, SessionState.state, _presenter)
	_runner.finished.connect(_on_dialogue_finished)


func _build_view_binder(view_runtime: MapViewRuntime, definition: MapDefinition) -> void:
	_view_binder = InteractableViewBinder.new()
	_view_binder.name = "BitterBrewInteractableViewBinder"
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
		interactable.set_interact_callback(Callable(self, "_on_site_pressed").bind(interactable_id))
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
	var active_phase := SessionState.state.get_phase() == GameState.PHASE_INVESTIGATION_MORNING
	var quest_state := _quest_state()

	if active_phase and quest_state.is_empty():
		_quest_manager.start_quest(QUEST_ID)
		quest_state = _quest_state()

	var investigation_active := active_phase and quest_state == STATE_INVESTIGATING
	for site in SITES:
		var interactable_id: StringName = site["interactable_id"]
		var fact_id: StringName = site["fact_id"]
		var interactable: Interactable = _interactables.get(interactable_id, null) as Interactable
		if interactable == null:
			continue
		interactable.enabled = investigation_active and not SessionState.state.get_fact(fact_id)

	if investigation_active and _all_facts_known():
		_quest_manager.transition(QUEST_ID, TRANSITION_COMPLETE)


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
	return SessionState.state.get_quest_state(QUEST_ID)


func _all_facts_known() -> bool:
	if SessionState.state == null:
		return false
	for site in SITES:
		if not SessionState.state.get_fact(site["fact_id"]):
			return false
	return true

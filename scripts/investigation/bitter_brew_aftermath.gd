class_name BitterBrewAftermath
extends Node

## P2-010: applies the three Bitter Brew aftermath families after the night
## encounter resolves and exposes brewery, Aita, Mart, and patrol differences.

const MODEL := preload("res://scripts/investigation/bitter_brew_aftermath_model.gd")
const AITA_NPC_SCRIPT := preload("res://scripts/demo/demo_aita_npc.gd")
const PATROL_BARK_SCRIPT := preload("res://scripts/phase/map_patrol_bark_presenter.gd")
const INTERACTABLE_SCENE := preload("res://scenes/interaction/interactable.tscn")
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const UiPresenterScript := preload("res://scripts/dialogue/dialogue_ui_presenter.gd")
const UiScript := preload("res://scripts/dialogue/dialogue_ui.gd")

var _scene_root: Node2D
var _definition: MapDefinition
var _player: Player
var _interaction_controller: InteractionController
var _mart_encounter: DemoMartEncounter
var _phase_binder: MapPhaseBinder
var _patrol_controller: MapPatrolController
var _night_consequence: BitterBrewNightConsequence

var _aita: Node2D
var _brewery_interactable: Interactable
var _patrol_bark: Node
var _runner: DialogueRunner
var _presenter: RefCounted
var _dialogue_ui: DialogueUI
var _pending_dialogue_id := &""


func setup(
	scene_root: Node2D,
	definition: MapDefinition,
	player: Player,
	interaction_controller: InteractionController,
	mart_encounter: DemoMartEncounter,
	phase_binder: MapPhaseBinder,
	patrol_controller: MapPatrolController,
	night_consequence: BitterBrewNightConsequence,
	actors: Node2D
) -> void:
	_scene_root = scene_root
	_definition = definition
	_player = player
	_interaction_controller = interaction_controller
	_mart_encounter = mart_encounter
	_phase_binder = phase_binder
	_patrol_controller = patrol_controller
	_night_consequence = night_consequence

	_build_dialogue_stack()
	_spawn_aita(definition, player, actors)
	_spawn_brewery_interactable(definition)
	_spawn_patrol_bark(scene_root, player, patrol_controller)

	if _phase_binder != null:
		_phase_binder.register_npc(&"aita", _aita, &"brewery_door")

	if _night_consequence != null:
		_night_consequence.encounter_resolver.resolved.connect(_on_encounter_resolved)

	if not SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.connect(_on_state_replaced)
	if SessionState.state != null and not SessionState.state.phase_changed.is_connected(_on_phase_changed):
		SessionState.state.phase_changed.connect(_on_phase_changed)
	_sync_aftermath()


func get_aita() -> Node2D:
	return _aita


func get_brewery_interactable() -> Interactable:
	return _brewery_interactable


func get_patrol_bark_presenter() -> Node:
	return _patrol_bark


func commit_aftermath_for_test() -> bool:
	return _commit_aftermath()


func _exit_tree() -> void:
	if _night_consequence != null \
			and _night_consequence.encounter_resolver.resolved.is_connected(_on_encounter_resolved):
		_night_consequence.encounter_resolver.resolved.disconnect(_on_encounter_resolved)
	if SessionState.state != null \
			and SessionState.state.phase_changed.is_connected(_on_phase_changed):
		SessionState.state.phase_changed.disconnect(_on_phase_changed)
	if SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.disconnect(_on_state_replaced)


func _on_state_replaced(_previous: GameState, current: GameState, _reason: StringName) -> void:
	_runner.configure(SessionState.content_db, current, _presenter)
	if current != null and not current.phase_changed.is_connected(_on_phase_changed):
		current.phase_changed.connect(_on_phase_changed)
	_sync_aftermath()


func _on_phase_changed(_previous: StringName, _next: StringName) -> void:
	_sync_aftermath()


func _on_encounter_resolved(
	_kind: StringName,
	_quest_id: StringName,
	_quest_state: StringName,
	_encounter_id: StringName
) -> void:
	_commit_aftermath()
	_sync_aftermath()


func _commit_aftermath() -> bool:
	if SessionState.state == null:
		return false
	return MODEL.commit_aftermath(SessionState.state, SessionState.content_db)


func _sync_aftermath() -> void:
	if SessionState.state == null:
		return
	if MODEL.is_quest_terminal(SessionState.state):
		_commit_aftermath()

	var visible := MODEL.is_aftermath_visible(SessionState.state)
	var outcome := MODEL.resolve_outcome(SessionState.state)

	if _mart_encounter != null:
		_mart_encounter.set_aftermath_dialogue_id(MODEL.mart_dialogue_id(SessionState.state))

	if _aita != null:
		_aita.visible = visible and MODEL.aita_visible(SessionState.state)

	if _brewery_interactable != null:
		_brewery_interactable.enabled = visible and not outcome.is_empty()
		var label := MODEL.brewery_status_label(SessionState.state)
		_brewery_interactable.prompt = (
			"Inspect the %s" % label.to_lower() if not label.is_empty() else "Inspect the brewery"
		)

	if _patrol_bark != null:
		_patrol_bark.set_enabled(visible and _patrol_controller != null and _patrol_controller.is_enabled())


func _spawn_aita(definition: MapDefinition, player: Player, actors: Node2D) -> void:
	if actors == null:
		return
	var position := MapVerification.anchor_position(definition, &"brewery_door")
	_aita = AITA_NPC_SCRIPT.new()
	_aita.name = "Aita"
	actors.add_child(_aita)
	_aita.configure(player, position + Vector2(-24, 0), Vector2.LEFT)
	_aita.visible = false


func _spawn_brewery_interactable(definition: MapDefinition) -> void:
	var position := MapVerification.anchor_position(definition, &"brewery_door")
	_brewery_interactable = INTERACTABLE_SCENE.instantiate() as Interactable
	_brewery_interactable.name = "BitterBrewBreweryAftermath"
	_brewery_interactable.interactable_id = &"interact.bitter_brew.brewery_aftermath"
	_brewery_interactable.interaction_kind = InteractionKinds.USE
	_brewery_interactable.prompt = "Inspect the brewery"
	_brewery_interactable.global_position = position
	_brewery_interactable.enabled = false
	_brewery_interactable.set_interact_callback(Callable(self, "_on_brewery_pressed"))
	_scene_root.add_child(_brewery_interactable)


func _spawn_patrol_bark(
	scene_root: Node,
	player: Player,
	patrol_controller: MapPatrolController
) -> void:
	_patrol_bark = PATROL_BARK_SCRIPT.new()
	_patrol_bark.name = "BitterBrewPatrolBark"
	add_child(_patrol_bark)
	_patrol_bark.setup(
		scene_root,
		&"loc.lower_town_slice",
		MODEL.BARK_POOL,
		player,
		patrol_controller.get_body() if patrol_controller != null else null
	)
	_patrol_bark.set_enabled(false)


func _build_dialogue_stack() -> void:
	_dialogue_ui = UiScript.new()
	_dialogue_ui.name = "BitterBrewAftermathDialogueUI"
	_scene_root.add_child(_dialogue_ui)

	_runner = RunnerScript.new()
	_runner.name = "BitterBrewAftermathDialogueRunner"
	add_child(_runner)
	_presenter = UiPresenterScript.new()
	_presenter.configure(_dialogue_ui, _runner)
	_runner.configure(SessionState.content_db, SessionState.state, _presenter)
	_runner.finished.connect(_on_dialogue_finished)


func _on_brewery_pressed(_actor: Node) -> void:
	if _runner != null and _runner.is_active():
		return
	var dialogue_id := MODEL.brewery_dialogue_id(SessionState.state)
	if dialogue_id.is_empty():
		return
	if not _start_dialogue(dialogue_id):
		return
	_pending_dialogue_id = dialogue_id


func _on_dialogue_finished(dialogue_id: StringName) -> void:
	_set_interaction_enabled(true)
	if dialogue_id != _pending_dialogue_id:
		return
	_pending_dialogue_id = &""


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

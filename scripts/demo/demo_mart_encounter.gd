class_name DemoMartEncounter
extends Node

## Wires Mart, proximity talk prompt, and the demo dialogue box on the Lower Town slice.

const INTERACTABLE_SCENE := preload("res://scenes/interaction/interactable.tscn")
const DIALOGUE_ID := &"dialogue.demo.mart_street"
const ANCHOR_ID := &"mart_street"
const INTERACTABLE_ID := &"interact.demo.mart_talk"

var _player: Player
var _mart: DemoMartNpc
var _interactable: Interactable
var _interaction_controller: InteractionController
var _dialogue_runner: DemoDialogueRunner
var _dialogue_box: DemoDialogueBox
var _view_binder: InteractableViewBinder
var _prompt_layer: CanvasLayer
var _prompt_label: Label


func spawn_mart(actors: Node2D, definition: MapDefinition) -> DemoMartNpc:
	var anchor_position := MapVerification.anchor_position(definition, ANCHOR_ID)
	_mart = DemoMartNpc.new()
	_mart.name = "Mart"
	actors.add_child(_mart)
	_mart.configure(null, anchor_position, Vector2.RIGHT)
	return _mart


func wire(
	scene_root: Node,
	definition: MapDefinition,
	player: Player,
	view_runtime: MapViewRuntime = null
) -> void:
	_player = player
	if _mart != null and player != null:
		_mart.configure(player, _mart.global_position, Vector2.RIGHT)

	_build_ui(scene_root)
	_build_interaction()
	_build_view_binder(view_runtime, definition)
	_dialogue_runner = DemoDialogueRunner.new()
	_dialogue_runner.name = "DemoDialogueRunner"
	add_child(_dialogue_runner)
	_dialogue_runner.configure(
		SessionState.content_db,
		SessionState.state,
		_dialogue_box,
		_interaction_controller
	)
	if not SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.connect(_on_state_replaced)


func _exit_tree() -> void:
	if SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.disconnect(_on_state_replaced)


func _on_state_replaced(_previous: GameState, current: GameState, _reason: StringName) -> void:
	if _dialogue_runner == null:
		return
	# Replacement invalidates an in-flight conversation rather than allowing its
	# remaining effects to mutate the retired GameState.
	if _dialogue_runner.is_active():
		_dialogue_runner.cancel()
	_dialogue_runner.configure(
		SessionState.content_db,
		current,
		_dialogue_box,
		_interaction_controller
	)


func get_mart() -> DemoMartNpc:
	return _mart


func get_interactable() -> Interactable:
	return _interactable


func register_phase_binder(binder: MapPhaseBinder, definition: MapDefinition) -> void:
	if _mart == null:
		return
	binder.register_npc(&"mart", _mart, &"mart_street")


func get_dialogue_runner() -> DemoDialogueRunner:
	return _dialogue_runner


func get_interaction_controller() -> InteractionController:
	return _interaction_controller


func _build_ui(scene_root: Node) -> void:
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.name = "DemoInteractionPrompt"
	_prompt_layer.layer = 25
	scene_root.add_child(_prompt_layer)

	_prompt_label = Label.new()
	_prompt_label.position = Vector2(24, 24)
	_prompt_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9, 1.0))
	_prompt_label.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.08, 1.0))
	_prompt_label.add_theme_constant_override("outline_size", 4)
	_prompt_label.visible = false
	_prompt_layer.add_child(_prompt_label)

	_dialogue_box = DemoDialogueBox.new()
	_dialogue_box.name = "DemoDialogueBox"
	scene_root.add_child(_dialogue_box)


func _build_interaction() -> void:
	# Parent to Mart so click-near-actor lookup and 3D markers track the NPC.
	_interactable = INTERACTABLE_SCENE.instantiate()
	_interactable.name = "MartTalk"
	_interactable.interactable_id = INTERACTABLE_ID
	_interactable.interaction_kind = InteractionKinds.TALK
	_interactable.prompt = "Talk to Mart"
	_mart.add_child(_interactable)
	_interactable.set_interact_callback(Callable(self, "_on_talk_pressed"))

	_interaction_controller = InteractionController.new()
	_interaction_controller.name = "InteractionController"
	_interaction_controller.actor = _player
	_interaction_controller.prompt_label = _prompt_label
	add_child(_interaction_controller)


func _build_view_binder(view_runtime: MapViewRuntime, definition: MapDefinition) -> void:
	# Without the binder, focus shows the 2D yellow ColorRect over the 3D map.
	_view_binder = InteractableViewBinder.new()
	_view_binder.name = "InteractableViewBinder"
	add_child(_view_binder)
	_view_binder.setup(view_runtime, definition)
	if _interactable != null:
		_view_binder.bind(_interactable)


func _on_talk_pressed(_actor: Node) -> void:
	if _dialogue_runner == null or _dialogue_runner.is_active():
		return
	_dialogue_runner.start(DIALOGUE_ID, _mart)

class_name ForgeDialogueEncounter
extends Node

## Forge demo dialogue wiring: moving Henning and the forge cat expose talk
## interactables with 3D markers and the shared demo dialogue box.

const INTERACTABLE_SCENE := preload("res://scenes/interaction/interactable.tscn")

const HENNING_DIALOGUE_ID := &"dialogue.demo.forge_henning"
const CAT_DIALOGUE_ID := &"dialogue.demo.forge_cat"
const HENNING_INTERACTABLE_ID := &"interact.demo.forge_henning_talk"
const CAT_INTERACTABLE_ID := &"interact.demo.forge_cat_talk"

var _player: Player
var _henning: SmithyHenning
var _cat: ForgeCat
var _interaction_controller: InteractionController
var _dialogue_runner: DemoDialogueRunner
var _dialogue_box: DemoDialogueBox
var _view_binder: InteractableViewBinder
var _henning_interactable: Interactable
var _cat_interactable: Interactable


func wire(
	scene_root: Node,
	player: Player,
	henning: SmithyHenning,
	cat: ForgeCat,
	view_runtime: MapViewRuntime,
	definition: MapDefinition,
	interaction_controller: InteractionController
) -> void:
	_player = player
	_henning = henning
	_cat = cat
	_interaction_controller = interaction_controller

	_build_ui(scene_root)
	_build_interactables()
	_build_view_binder(view_runtime, definition)
	_build_dialogue_runner()


func get_dialogue_runner() -> DemoDialogueRunner:
	return _dialogue_runner


func get_henning_interactable() -> Interactable:
	return _henning_interactable


func get_cat_interactable() -> Interactable:
	return _cat_interactable


func _build_ui(scene_root: Node) -> void:
	_dialogue_box = DemoDialogueBox.new()
	_dialogue_box.name = "ForgeDialogueBox"
	scene_root.add_child(_dialogue_box)


func _build_interactables() -> void:
	if _henning != null:
		_henning_interactable = _spawn_talk_interactable(
			_henning,
			"HenningTalk",
			HENNING_INTERACTABLE_ID,
			"Talk to Henning [E]",
			HENNING_DIALOGUE_ID
		)
	if _cat != null:
		_cat_interactable = _spawn_talk_interactable(
			_cat,
			"CatTalk",
			CAT_INTERACTABLE_ID,
			"Pet the forge cat [E]",
			CAT_DIALOGUE_ID
		)


func _spawn_talk_interactable(
	host: Node2D,
	node_name: String,
	interactable_id: StringName,
	prompt: String,
	dialogue_id: StringName
) -> Interactable:
	var interactable: Interactable = INTERACTABLE_SCENE.instantiate()
	interactable.name = node_name
	interactable.interactable_id = interactable_id
	interactable.interaction_kind = InteractionKinds.TALK
	interactable.prompt = prompt
	interactable.interaction_radius = 96.0
	host.add_child(interactable)
	interactable.set_interact_callback(_on_talk_pressed.bind(dialogue_id, host))
	return interactable


func _build_view_binder(view_runtime: MapViewRuntime, definition: MapDefinition) -> void:
	_view_binder = InteractableViewBinder.new()
	_view_binder.name = "InteractableViewBinder"
	add_child(_view_binder)
	_view_binder.setup(view_runtime, definition)
	if _henning_interactable != null:
		_view_binder.bind(_henning_interactable)
	if _cat_interactable != null:
		_view_binder.bind(_cat_interactable)


func _build_dialogue_runner() -> void:
	_dialogue_runner = DemoDialogueRunner.new()
	_dialogue_runner.name = "ForgeDialogueRunner"
	add_child(_dialogue_runner)
	_dialogue_runner.configure(
		SessionState.content_db,
		SessionState.state,
		_dialogue_box,
		_interaction_controller
	)


func _on_talk_pressed(_actor: Node, dialogue_id: StringName, host: Node2D) -> void:
	if _dialogue_runner == null or _dialogue_runner.is_active():
		return
	_dialogue_runner.start(dialogue_id, host)

extends Node2D

const INTERACTABLE_SCENE := preload("res://scenes/interaction/interactable.tscn")

var actor: CharacterBody2D
var controller: InteractionController
var prompt_label: Label
var status_label: Label

var activated_kinds: Array[StringName] = []


func _ready() -> void:
	_build_scene()
	_update_status("Move near a target. Press E or gamepad A to interact.")


func get_activated_kinds() -> Array[StringName]:
	return activated_kinds.duplicate()


func _build_scene() -> void:
	name = "InteractionTest"

	var camera := Camera2D.new()
	camera.position = Vector2(640, 360)
	add_child(camera)

	_add_rect(Vector2.ZERO, Vector2(1280, 720), Color(0.12, 0.14, 0.16, 1.0))

	actor = CharacterBody2D.new()
	actor.name = "Actor"
	actor.position = Vector2(640, 360)
	var actor_shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 12.0
	capsule.height = 24.0
	actor_shape.shape = capsule
	actor.add_child(actor_shape)
	var actor_visual := ColorRect.new()
	actor_visual.offset_left = -12.0
	actor_visual.offset_top = -24.0
	actor_visual.color = Color(0.21, 0.52, 0.92, 1.0)
	actor.add_child(actor_visual)
	add_child(actor)

	prompt_label = Label.new()
	prompt_label.position = Vector2(24, 24)
	prompt_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9, 1.0))
	add_child(prompt_label)

	status_label = Label.new()
	status_label.position = Vector2(24, 56)
	status_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9, 1.0))
	add_child(status_label)

	controller = InteractionController.new()
	controller.name = "InteractionController"
	controller.actor = actor
	controller.prompt_label = prompt_label
	add_child(controller)

	_spawn_interactable(
		&"interact.test_talk",
		InteractionKinds.TALK,
		"Talk to Mart",
		Vector2(640, 250)
	)
	_spawn_interactable(
		&"interact.test_pickup",
		InteractionKinds.PICKUP,
		"Pick up hammer",
		Vector2(520, 360)
	)
	_spawn_interactable(
		&"interact.test_use",
		InteractionKinds.USE,
		"Inspect ledger",
		Vector2(760, 360)
	)

	_update_status("Move near a target. Press E or gamepad A to interact.")


func _spawn_interactable(
	interactable_id: StringName,
	kind: StringName,
	prompt: String,
	position: Vector2
) -> Interactable:
	var interactable: Interactable = INTERACTABLE_SCENE.instantiate()
	interactable.name = String(interactable_id).replace(".", "_")
	interactable.interactable_id = interactable_id
	interactable.interaction_kind = kind
	interactable.prompt = prompt
	interactable.position = position
	interactable.set_interact_callback(Callable(self, "_on_interacted").bind(kind))
	add_child(interactable)
	return interactable


func _on_interacted(kind: StringName, _actor: Node) -> void:
	if not activated_kinds.has(kind):
		activated_kinds.append(kind)
	_update_status("Activated kinds: %s" % ", ".join(activated_kinds.map(func(value: StringName) -> String: return String(value))))


func _move_actor_near(interactable_id: StringName) -> void:
	var target := get_node_or_null(String(interactable_id).replace(".", "_")) as Interactable
	if target == null:
		return
	actor.global_position = target.global_position


func _update_status(message: String) -> void:
	status_label.text = message


func _add_rect(position: Vector2, size: Vector2, color: Color) -> void:
	var rect := ColorRect.new()
	rect.position = position
	rect.size = size
	rect.color = color
	add_child(rect)

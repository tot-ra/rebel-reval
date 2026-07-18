class_name Interactable
extends Area2D

signal focused()
signal unfocused()
signal interacted(actor: Node)

@export var interactable_id: StringName = &""
@export var prompt: String = "Interact"
@export var interaction_kind: StringName = InteractionKinds.USE
@export var enabled: bool = true
@export var interaction_radius: float = 115.0
## 2D greybox marker for harness scenes only. Gameplay maps use 3D props and prompt UI.
@export var show_debug_body: bool = false

var _callback: Callable = Callable()
var _focused: bool = false
var _suppress_flat_markers := false
var _actors_in_range: Dictionary[int, Node2D] = {}

@onready var _body: CanvasItem = $Body
@onready var _focus_highlight: CanvasItem = $FocusHighlight


func _ready() -> void:
	add_to_group(&"interactable")
	monitorable = false
	monitoring = true
	collision_mask = collision_mask if collision_mask != 0 else 1
	_apply_collision_radius()
	if _body != null:
		_body.visible = show_debug_body
	_set_focused(false)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func get_interactable_id() -> StringName:
	return interactable_id


func get_prompt() -> String:
	return prompt


func get_interaction_kind() -> StringName:
	return interaction_kind


func is_enabled() -> bool:
	return enabled


func is_focused() -> bool:
	return _focused


## MapViewRuntime owns focus feedback in 3D; keep the harness rectangles hidden.
func suppress_flat_markers(value: bool) -> void:
	_suppress_flat_markers = value
	if not value:
		return
	if _body != null:
		_body.visible = false
	if _focus_highlight != null:
		_focus_highlight.visible = false


func set_interact_callback(callback: Callable) -> void:
	_callback = callback


func clear_interact_callback() -> void:
	_callback = Callable()


func is_actor_in_range(actor: Node2D) -> bool:
	if actor == null:
		return false
	return _actors_in_range.has(actor.get_instance_id())


func register_actor_in_range(actor: Node2D) -> void:
	if actor == null:
		return
	_actors_in_range[actor.get_instance_id()] = actor


func unregister_actor_in_range(actor: Node2D) -> void:
	if actor == null:
		return
	_actors_in_range.erase(actor.get_instance_id())


func get_closest_actor_in_range() -> Node2D:
	var closest: Node2D = null
	var closest_distance := INF
	for actor in _actors_in_range.values():
		if not is_instance_valid(actor):
			continue
		var distance := global_position.distance_squared_to(actor.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = actor
	return closest


func set_focused(value: bool) -> void:
	if _focused == value:
		return
	_focused = value
	_set_focused(value)
	if value:
		focused.emit()
	else:
		unfocused.emit()


func interact(actor: Node) -> bool:
	if not enabled or actor == null:
		return false
	if not is_actor_in_range(actor as Node2D):
		return false

	interacted.emit(actor)
	if _callback.is_valid():
		_callback.call(actor)
	return true


func disable_interaction() -> void:
	enabled = false
	if _focused:
		set_focused(false)
	visible = false
	monitoring = false


func _apply_collision_radius() -> void:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		return
	var shape := collision.shape as CircleShape2D
	if shape == null:
		shape = CircleShape2D.new()
		collision.shape = shape
	shape.radius = maxf(16.0, interaction_radius)


func _set_focused(value: bool) -> void:
	if _focus_highlight != null and not _suppress_flat_markers:
		_focus_highlight.visible = value


func _on_body_entered(body: Node2D) -> void:
	if body == null:
		return
	_actors_in_range[body.get_instance_id()] = body


func _on_body_exited(body: Node2D) -> void:
	if body == null:
		return
	_actors_in_range.erase(body.get_instance_id())

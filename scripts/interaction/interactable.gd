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
	collision_mask = collision_mask if collision_mask != 0 else CollisionLayers.MASK_ACTORS
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
	if _actors_in_range.has(actor.get_instance_id()):
		return true
	# Area2D overlap can lag behind gameplay proximity, especially for sensors
	# parented to moving NPC logic bodies in the 3D presentation maps.
	return _is_within_interaction_radius(actor.global_position)


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


## Returns the enabled interactable whose radius contains logic_position, preferring
## the closest center when several overlap.
static func find_at_logic_position(logic_position: Vector2, tree: SceneTree) -> Interactable:
	if tree == null:
		return null
	var best: Interactable = null
	var best_distance := INF
	for node in tree.get_nodes_in_group(&"interactable"):
		var interactable := node as Interactable
		if interactable == null or not interactable.is_enabled():
			continue
		var distance_sq := interactable.global_position.distance_squared_to(logic_position)
		var radius := interactable.interaction_radius
		if distance_sq > radius * radius:
			continue
		if distance_sq < best_distance:
			best_distance = distance_sq
			best = interactable
	if best != null:
		return best
	return find_talk_interactable_near_actor(logic_position, tree)


## Isometric clicks often land on the ground in front of a character instead of
## on the talk sensor centered at the actor's feet.
static func find_talk_interactable_near_actor(logic_position: Vector2, tree: SceneTree) -> Interactable:
	if tree == null:
		return null
	var best: Interactable = null
	var best_distance := INF
	const ACTOR_CLICK_RADIUS := 72.0
	for node in tree.get_nodes_in_group(&"map_view_actor"):
		if not node is Node2D:
			continue
		var actor := node as Node2D
		var actor_distance_sq := actor.global_position.distance_squared_to(logic_position)
		if actor_distance_sq > ACTOR_CLICK_RADIUS * ACTOR_CLICK_RADIUS:
			continue
		for child in actor.get_children():
			var talk := child as Interactable
			if talk == null or not talk.is_enabled():
				continue
			if talk.get_interaction_kind() != InteractionKinds.TALK:
				continue
			if actor_distance_sq < best_distance:
				best_distance = actor_distance_sq
				best = talk
	return best


func disable_interaction() -> void:
	enabled = false
	if _focused:
		set_focused(false)
	visible = false
	monitoring = false


func _is_within_interaction_radius(position: Vector2) -> bool:
	var radius := interaction_radius
	return global_position.distance_squared_to(position) <= radius * radius


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

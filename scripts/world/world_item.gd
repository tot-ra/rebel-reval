class_name WorldItem
extends Area2D

## Pickable world object on the logic plane. Collision stays authoritative for
## cursor hit tests; the 3D view rig is mirrored by WorldItemController.

signal picked_up(item_id: StringName)
signal dropped(item_id: StringName)

@export var world_object_id: StringName = &""
@export var item_id: StringName = &""
@export var location_id: StringName = &""
@export var pickup_radius: float = 28.0

const OUTLINE_COLOR_IDLE := Color(0.95, 0.82, 0.35, 0.9)
const OUTLINE_COLOR_HOVER := Color(1.0, 0.93, 0.5, 1.0)
const OUTLINE_WIDTH_IDLE := 1.0
const OUTLINE_WIDTH_HOVER := 2.0

var _hovered := false
var _suppress_flat_outline := false

@onready var _outline: Line2D = $FocusOutline


func _ready() -> void:
	add_to_group(&"world_item")
	monitorable = false
	monitoring = false
	_apply_collision_radius()
	_set_hovered(false)


func get_world_object_id() -> StringName:
	return world_object_id


func get_item_id() -> StringName:
	return item_id


func is_hovered() -> bool:
	return _hovered


func set_hovered(value: bool) -> void:
	if _hovered == value:
		return
	_hovered = value
	_set_hovered(value)


func contains_logic_point(point: Vector2) -> bool:
	var local := to_local(point)
	var half := pickup_radius
	return absf(local.x) <= half and absf(local.y) <= half


func configure(
	object_id: StringName,
	carried_item_id: StringName,
	map_location_id: StringName,
	position: Vector2
) -> void:
	world_object_id = object_id
	item_id = carried_item_id
	location_id = map_location_id
	global_position = position
	name = "WorldItem_%s" % String(object_id).replace(".", "_")


## MapViewRuntime mirrors pickups in 3D; hide the flat harness outline so it
## does not draw yellow rectangles over the orthographic presentation.
func set_3d_presentation(enabled: bool) -> void:
	_suppress_flat_outline = enabled
	_apply_outline_visibility()


func _apply_collision_radius() -> void:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		return
	var shape := collision.shape as CircleShape2D
	if shape == null:
		shape = CircleShape2D.new()
		collision.shape = shape
	shape.radius = maxf(16.0, pickup_radius)


func _set_hovered(value: bool) -> void:
	_apply_outline_visibility()
	if _outline == null or _suppress_flat_outline:
		return
	_outline.default_color = OUTLINE_COLOR_HOVER if value else OUTLINE_COLOR_IDLE
	_outline.width = OUTLINE_WIDTH_HOVER if value else OUTLINE_WIDTH_IDLE


func _apply_outline_visibility() -> void:
	if _outline == null:
		_outline = get_node_or_null("FocusOutline") as Line2D
	if _outline == null:
		return
	_outline.visible = not _suppress_flat_outline

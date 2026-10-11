class_name SupplyChainConvoy
extends CharacterBody2D

## Visible porter hauling bar stock along an authored patrol path.

const ModelScript := preload("res://scripts/world/supply_chain_model.gd")

@export var rig_scene: PackedScene = preload("res://assets/characters/variants/townswoman.tscn")

var _points: PackedVector2Array = PackedVector2Array()
var _point_index := 0
var _enabled := false
var _lap_completed := false


func configure(points: PackedVector2Array) -> void:
	_points = points
	_point_index = 0
	_lap_completed = false
	if not _points.is_empty():
		global_position = _points[0]


func set_route_enabled(enabled: bool) -> void:
	_enabled = enabled and not _points.is_empty() and not _lap_completed
	visible = _enabled
	if not _enabled:
		velocity = Vector2.ZERO


func is_route_enabled() -> bool:
	return _enabled


func has_completed_lap() -> bool:
	return _lap_completed


func complete_route_for_test() -> void:
	if _points.is_empty():
		return
	global_position = _points[_points.size() - 1]
	_point_index = _points.size() - 1
	_lap_completed = true
	_enabled = false
	velocity = Vector2.ZERO


func view_facing() -> Vector2:
	if velocity.length_squared() > 1.0:
		return velocity.normalized()
	return Vector2.DOWN


func view_animation() -> StringName:
	return &"walk" if velocity.length_squared() > 25.0 else &"idle"


func _ready() -> void:
	CollisionLayers.apply_npc(self)
	add_to_group(&"map_view_actor")
	add_to_group(NpcPush.PUSH_GROUP)
	_ensure_collision_shape()


func is_pushable_by_player() -> bool:
	return true


func _physics_process(delta: float) -> void:
	if NpcPush.apply_queued_push(self, delta):
		return
	if not _enabled or _points.is_empty() or _lap_completed:
		return
	var target := _points[_point_index]
	var offset := target - global_position
	while offset.length_squared() < 16.0:
		if _point_index >= _points.size() - 1:
			_lap_completed = true
			_enabled = false
			velocity = Vector2.ZERO
			return
		_point_index += 1
		target = _points[_point_index]
		offset = target - global_position
	if offset.is_zero_approx():
		return
	velocity = offset.normalized() * ModelScript.CONVOY_SPEED
	if not NpcPush.player_blocks_body(self):
		move_and_slide()
	else:
		velocity = Vector2.ZERO


func _ensure_collision_shape() -> void:
	if get_child_count() > 0:
		return
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 10.0
	capsule.height = 20.0
	shape.shape = capsule
	add_child(shape)

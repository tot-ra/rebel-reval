class_name MapPatrolController
extends Node

## Walks a map patrol path when the active phase profile enables it.

const PATROL_SPEED := 48.0

var patrol_id: StringName = &""
var _definition: MapDefinition
var _body: CharacterBody2D
var _points: PackedVector2Array = PackedVector2Array()
var _point_index := 0
var _enabled := false


func setup(definition: MapDefinition, patrol: StringName, parent: Node2D) -> void:
	patrol_id = patrol
	_definition = definition
	_points = _resolve_points(definition, patrol)
	_body = CharacterBody2D.new()
	_body.name = "Patrol_%s" % String(patrol)
	_body.add_to_group(&"map_view_actor")
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 10.0
	capsule.height = 20.0
	shape.shape = capsule
	_body.add_child(shape)
	parent.add_child(_body)
	if not _points.is_empty():
		_body.global_position = _points[0]
	set_enabled(false)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled and not _points.is_empty()
	_body.visible = _enabled
	if not _enabled:
		_body.velocity = Vector2.ZERO


func is_enabled() -> bool:
	return _enabled


func _physics_process(delta: float) -> void:
	if not _enabled or _points.is_empty():
		return
	var target := _points[_point_index]
	var offset := target - _body.global_position
	if offset.length_squared() < 16.0:
		_point_index = (_point_index + 1) % _points.size()
		target = _points[_point_index]
		offset = target - _body.global_position
	if offset.is_zero_approx():
		return
	_body.velocity = offset.normalized() * PATROL_SPEED
	_body.move_and_slide()


static func _resolve_points(definition: MapDefinition, patrol: StringName) -> PackedVector2Array:
	if definition == null:
		return PackedVector2Array()
	for entry in definition.patrols:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if StringName(String(entry.get("id", ""))) != patrol:
			continue
		var packed := PackedVector2Array()
		for value in entry.get("points", []) as Array:
			if value is Vector2:
				packed.append(value)
		return packed
	return PackedVector2Array()

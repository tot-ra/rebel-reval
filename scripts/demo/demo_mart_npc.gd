class_name DemoMartNpc
extends CharacterBody2D

## Static demo NPC for D-002. Logic body only; MapViewRuntime mirrors the Mart rig.

@export var rig_scene: PackedScene = preload("res://assets/characters/variants/mart.tscn")

var _player: Node2D
var _facing := Vector2.DOWN


func _ready() -> void:
	add_to_group(&"map_view_actor")
	_ensure_collision_shape()


func configure(player: Node2D, position: Vector2, facing: Vector2 = Vector2.DOWN) -> void:
	_player = player
	global_position = position
	_facing = facing if not facing.is_zero_approx() else Vector2.DOWN


func view_facing() -> Vector2:
	if _player != null and is_instance_valid(_player):
		var toward_player := _player.global_position - global_position
		if toward_player.length_squared() > 1.0:
			return toward_player.normalized()
	return _facing


func view_animation() -> StringName:
	return &"idle"


func _ensure_collision_shape() -> void:
	if get_node_or_null("CollisionShape2D") != null:
		return
	var shape_node := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 12.0
	capsule.height = 24.0
	shape_node.shape = capsule
	add_child(shape_node)

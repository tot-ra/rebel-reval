extends Area2D

class_name Door

@export var destination_level_tag: String
@export var destination_door_tag: String
@export var spawn_direction = "up"

@onready var spawn = $Spawn


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		pass

extends Area2D

class_name Door

@export var destination_level_tag: String
@export var destination_door_tag: String
@export var spawn_direction = "up"

@onready var spawn = $Spawn
@onready var sound = $OpenSound

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		sound.play()
		await sound.finished
		DoorNavigator.go_to_scene(destination_level_tag, destination_door_tag)

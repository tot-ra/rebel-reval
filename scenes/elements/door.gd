extends Area2D

class_name Door

@export var transition_enabled := true
@export var spawn_id: StringName
@export var destination_scene_id: StringName
@export var destination_spawn_id: StringName

# Deprecated compatibility fields for old scene instances. New active doors must use
# stable destination_scene_id and destination_spawn_id values from the manifest.
@export var destination_level_tag: String
@export var destination_door_tag: String
@export var spawn_direction = "up"

@onready var spawn = $Spawn
@onready var sound = get_node_or_null("OpenSound") as AudioStreamPlayer

func _on_body_entered(body: Node2D) -> void:
	if not transition_enabled:
		return
	if body is Player:
		# P0-029 quarantines unknown-rights door SFX. Keep transitions working
		# silently until an approved replacement sound is documented.
		if sound != null and sound.stream != null:
			sound.play()
			await sound.finished
		DoorNavigator.go_to_scene(_resolved_destination_scene_id(), _resolved_destination_spawn_id())

func _resolved_destination_scene_id() -> StringName:
	if not String(destination_scene_id).is_empty():
		return destination_scene_id
	return StringName(destination_level_tag)

func _resolved_destination_spawn_id() -> StringName:
	if not String(destination_spawn_id).is_empty():
		return destination_spawn_id
	return StringName(destination_door_tag)

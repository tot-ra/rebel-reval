extends Area2D

class_name Door

const AudioBusService := preload("res://scripts/settings/audio_bus_service.gd")
const SfxPlayerScript := preload("res://scripts/audio/sfx_player.gd")
## ADR 0035: the door asks the catalog for a sound ID, never for a file. Legacy
## scene instances may still carry an OpenSound child with a stream; that one
## wins so a hand-placed clip is not silently replaced.
const DOOR_SOUND_ID := &"sfx.door.wood.use"

@export var transition_enabled := true
@export var spawn_id: StringName
@export var destination_scene_id: StringName
@export var destination_spawn_id: StringName

# Deprecated compatibility fields for old scene instances. New active doors must use
# stable destination_scene_id and destination_spawn_id values from the manifest.
@export var destination_level_tag: String
@export var destination_door_tag: String
@export var spawn_direction = "up"

var _sfx: SfxPlayer

@onready var spawn = $Spawn
@onready var sound = get_node_or_null("OpenSound") as AudioStreamPlayer


func _ready() -> void:
	collision_mask = CollisionLayers.PLAYER
	if sound != null:
		AudioBusService.assign_bus(sound, AudioBusService.BUS_SFX)
	_sfx = SfxPlayerScript.new()
	_sfx.name = "DoorSfxPlayer"
	add_child(_sfx)
	_sfx.setup(SfxCatalog.load_default(), hash("door"))


func _on_body_entered(body: Node2D) -> void:
	if not transition_enabled:
		return
	if body is Player:
		if sound != null and sound.stream != null:
			sound.play()
			await sound.finished
		else:
			# Let the leaf creak finish before the scene swap, as the legacy
			# OpenSound path did; a missing or cooled-down sound must not stall
			# the transition.
			var voice := _sfx.play(DOOR_SOUND_ID, global_position)
			if voice != null:
				await voice.finished
		DoorNavigator.go_to_scene(_resolved_destination_scene_id(), _resolved_destination_spawn_id())

func _resolved_destination_scene_id() -> StringName:
	if not String(destination_scene_id).is_empty():
		return destination_scene_id
	return StringName(destination_level_tag)

func _resolved_destination_spawn_id() -> StringName:
	if not String(destination_spawn_id).is_empty():
		return destination_spawn_id
	return StringName(destination_door_tag)

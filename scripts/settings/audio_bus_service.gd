class_name AudioBusService
extends RefCounted

## Routes runtime audio players onto dedicated buses and applies persisted volumes.

const AudioSettingsScript := preload("res://scripts/settings/audio_settings.gd")

const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
const BUS_VOICE := &"Voice"


static func apply_settings(settings) -> void:
	if settings == null:
		return
	settings.normalize()
	_set_bus_linear_volume(BUS_MUSIC, settings.music_volume)
	_set_bus_linear_volume(BUS_SFX, settings.sfx_volume)
	_set_bus_linear_volume(BUS_VOICE, settings.voice_volume)


static func assign_bus(player: Node, bus_name: StringName) -> void:
	if player == null:
		return
	if player is AudioStreamPlayer:
		(player as AudioStreamPlayer).bus = String(bus_name)
	elif player is AudioStreamPlayer3D:
		(player as AudioStreamPlayer3D).bus = String(bus_name)


static func _set_bus_linear_volume(bus_name: StringName, linear_volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(String(bus_name))
	if bus_index < 0:
		return
	var clamped := clampf(
		linear_volume, AudioSettingsScript.MIN_LINEAR, AudioSettingsScript.MAX_LINEAR
	)
	if clamped <= AudioSettingsScript.MIN_LINEAR:
		AudioServer.set_bus_volume_db(bus_index, -80.0)
	else:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(clamped))

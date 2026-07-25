class_name AudioSettings
extends RefCounted

## Player-facing music and SFX volume settings persisted by UserSettingsStore.

const SelfScript := preload("res://scripts/settings/audio_settings.gd")

const MIN_LINEAR := 0.0
const MAX_LINEAR := 1.0
const DEFAULT_LINEAR := 1.0

var music_volume: float = DEFAULT_LINEAR
var sfx_volume: float = DEFAULT_LINEAR


static func default_settings() -> AudioSettings:
	return SelfScript.new()


func duplicate_settings() -> AudioSettings:
	var copy := SelfScript.new()
	copy.music_volume = music_volume
	copy.sfx_volume = sfx_volume
	return copy


func normalize() -> void:
	music_volume = clampf(music_volume, MIN_LINEAR, MAX_LINEAR)
	sfx_volume = clampf(sfx_volume, MIN_LINEAR, MAX_LINEAR)


func to_dict() -> Dictionary:
	normalize()
	return {
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
	}


static func from_dict(data: Dictionary) -> AudioSettings:
	var settings := SelfScript.new()
	settings.music_volume = float(data.get("music_volume", DEFAULT_LINEAR))
	settings.sfx_volume = float(data.get("sfx_volume", DEFAULT_LINEAR))
	settings.normalize()
	return settings

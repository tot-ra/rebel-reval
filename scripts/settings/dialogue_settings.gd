class_name DialogueSettings
extends RefCounted

## Player-facing dialogue accessibility settings persisted by UserSettingsStore (P1-013).

const SelfScript := preload("res://scripts/settings/dialogue_settings.gd")
const TextScaleScript := preload("res://scripts/dialogue/dialogue_text_scale.gd")

const TEXT_SPEEDS: Array[String] = ["slow", "normal", "fast", "instant"]

const CHARS_PER_SECOND := {
	"slow": 18.0,
	"normal": 36.0,
	"fast": 72.0,
	"instant": 99999.0,
}

var text_scale: String = "normal"
var text_speed: String = "normal"
var high_contrast: bool = false
var subtitle_background: bool = true
var reduced_motion: bool = false
var pseudo_localization: bool = false


static func default_settings():
	return SelfScript.new()


func duplicate_settings():
	var copy := SelfScript.new()
	copy.text_scale = text_scale
	copy.text_speed = text_speed
	copy.high_contrast = high_contrast
	copy.subtitle_background = subtitle_background
	copy.reduced_motion = reduced_motion
	copy.pseudo_localization = pseudo_localization
	return copy


func normalize() -> void:
	if not TextScaleScript.is_supported(text_scale):
		text_scale = "normal"
	if not TEXT_SPEEDS.has(text_speed):
		text_speed = "normal"


func chars_per_second() -> float:
	normalize()
	if reduced_motion or text_speed == "instant":
		return float(CHARS_PER_SECOND["instant"])
	return float(CHARS_PER_SECOND.get(text_speed, CHARS_PER_SECOND["normal"]))


func reveal_instantly() -> bool:
	normalize()
	return reduced_motion or text_speed == "instant"


func to_dict() -> Dictionary:
	normalize()
	return {
		"text_scale": text_scale,
		"text_speed": text_speed,
		"high_contrast": high_contrast,
		"subtitle_background": subtitle_background,
		"reduced_motion": reduced_motion,
		"pseudo_localization": pseudo_localization,
	}


static func from_dict(data: Dictionary):
	var settings := SelfScript.new()
	settings.text_scale = String(data.get("text_scale", "normal"))
	settings.text_speed = String(data.get("text_speed", "normal"))
	settings.high_contrast = bool(data.get("high_contrast", false))
	settings.subtitle_background = bool(data.get("subtitle_background", true))
	settings.reduced_motion = bool(data.get("reduced_motion", false))
	settings.pseudo_localization = bool(data.get("pseudo_localization", false))
	settings.normalize()
	return settings

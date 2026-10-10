class_name GraphicsSettings
extends RefCounted

## User-selected rendering quality, persisted independently from campaign saves.

const SelfScript := preload("res://scripts/settings/graphics_settings.gd")

const QUALITY_LOW := "low"
const QUALITY_MID := "mid"
const QUALITY_HIGH := "high"
const QUALITIES: Array[String] = [QUALITY_LOW, QUALITY_MID, QUALITY_HIGH]

var quality: String = QUALITY_MID


static func default_settings() -> GraphicsSettings:
	return SelfScript.new()


func duplicate_settings() -> GraphicsSettings:
	var copy := SelfScript.new()
	copy.quality = quality
	return copy


func normalize() -> void:
	if not QUALITIES.has(quality):
		quality = QUALITY_MID


func msaa_3d_level() -> int:
	normalize()
	match quality:
		QUALITY_LOW:
			return Viewport.MSAA_DISABLED
		QUALITY_HIGH:
			return Viewport.MSAA_4X
		_:
			return Viewport.MSAA_2X


func to_dict() -> Dictionary:
	normalize()
	return {"quality": quality}


static func from_dict(data: Dictionary) -> GraphicsSettings:
	var settings := SelfScript.new()
	settings.quality = String(data.get("quality", QUALITY_MID))
	settings.normalize()
	return settings

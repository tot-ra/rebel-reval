class_name GameplayAccessibilitySettings
extends RefCounted

## Gameplay accessibility persisted outside save slots (P3-007).

const SelfScript := preload("res://scripts/settings/gameplay_accessibility_settings.gd")

const GUARD_MODE_HOLD := "hold"
const GUARD_MODE_TOGGLE := "toggle"
const GUARD_MODES: Array[String] = [GUARD_MODE_HOLD, GUARD_MODE_TOGGLE]

const REDUCED_FLASH_LIGHTNING_SCALE := 0.25

var guard_mode: String = GUARD_MODE_HOLD
var enhanced_focus_contrast: bool = false
var screenshake_enabled: bool = true
var reduced_flashing: bool = false


static func default_settings() -> GameplayAccessibilitySettings:
	return SelfScript.new()


func duplicate_settings() -> GameplayAccessibilitySettings:
	var copy := SelfScript.new()
	copy.guard_mode = guard_mode
	copy.enhanced_focus_contrast = enhanced_focus_contrast
	copy.screenshake_enabled = screenshake_enabled
	copy.reduced_flashing = reduced_flashing
	return copy


func normalize() -> void:
	if not GUARD_MODES.has(guard_mode):
		guard_mode = GUARD_MODE_HOLD


func guard_uses_hold() -> bool:
	normalize()
	return guard_mode == GUARD_MODE_HOLD


func allows_screenshake(reduced_motion: bool = false) -> bool:
	normalize()
	return screenshake_enabled and not reduced_motion


func lightning_flash_scale() -> float:
	normalize()
	if reduced_flashing:
		return REDUCED_FLASH_LIGHTNING_SCALE
	return 1.0


func focus_border_width() -> int:
	normalize()
	return 4 if enhanced_focus_contrast else 1


func to_dict() -> Dictionary:
	normalize()
	return {
		"guard_mode": guard_mode,
		"enhanced_focus_contrast": enhanced_focus_contrast,
		"screenshake_enabled": screenshake_enabled,
		"reduced_flashing": reduced_flashing,
	}


static func from_dict(data: Dictionary) -> GameplayAccessibilitySettings:
	var settings := SelfScript.new()
	settings.guard_mode = String(data.get("guard_mode", GUARD_MODE_HOLD))
	settings.enhanced_focus_contrast = bool(data.get("enhanced_focus_contrast", false))
	settings.screenshake_enabled = bool(
		data.get("screenshake_enabled", data.get("screen_shake_enabled", true))
	)
	settings.reduced_flashing = bool(data.get("reduced_flashing", false))
	settings.normalize()
	return settings

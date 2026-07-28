class_name CandleLight3D
extends Node

## Warm local fill for candle props. Stronger after dusk so interiors stay
## readable when window daylight fades.

const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")

const DEFAULT_PROFILE := {
	"color": Color8(255, 196, 112),
	"day_energy": 0.18,
	"night_energy": 1.35,
	"range": 3.2,
}

var _light: OmniLight3D
var _flame_material: StandardMaterial3D
var _base_flame_color := Color.WHITE
var _light_color: Color = DEFAULT_PROFILE["color"]
var _day_energy := float(DEFAULT_PROFILE["day_energy"])
var _night_energy := float(DEFAULT_PROFILE["night_energy"])


func configure(light: OmniLight3D, flame: MeshInstance3D, profile: Dictionary = {}) -> void:
	name = "CandleLight"
	_light = light
	_light_color = profile.get("color", DEFAULT_PROFILE["color"])
	_day_energy = float(profile.get("day_energy", DEFAULT_PROFILE["day_energy"]))
	_night_energy = float(profile.get("night_energy", DEFAULT_PROFILE["night_energy"]))
	_light.light_color = _light_color
	_light.omni_range = float(profile.get("range", DEFAULT_PROFILE["range"]))
	_light.shadow_enabled = false
	_flame_material = flame.material_override as StandardMaterial3D
	if _flame_material == null:
		_flame_material = flame.get_active_material(0) as StandardMaterial3D
	if _flame_material != null:
		_base_flame_color = _flame_material.albedo_color


func apply_cycle_progress(progress: float) -> void:
	if _light == null:
		return
	var night := 1.0 - DayNightCycle.day_blend(progress)
	var energy := lerpf(_day_energy, _night_energy, night)
	_light.light_energy = energy
	if _flame_material != null:
		_flame_material.emission_enabled = true
		_flame_material.emission = _light_color
		_flame_material.emission_energy_multiplier = lerpf(0.4, 1.8, night)
		_flame_material.albedo_color = _base_flame_color.lerp(_light_color, night * 0.35)

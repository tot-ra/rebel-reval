class_name CandleLight3D
extends Node

## Warm local fill for candle props. Stronger after dusk so interiors stay
## readable when window daylight fades.

const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")

const CANDLE_COLOR := Color8(255, 196, 112)
const DAY_ENERGY := 0.18
const NIGHT_ENERGY := 1.35

var _light: OmniLight3D
var _flame_material: StandardMaterial3D
var _base_flame_color := Color.WHITE


func configure(light: OmniLight3D, flame: MeshInstance3D) -> void:
	name = "CandleLight"
	_light = light
	_light.light_color = CANDLE_COLOR
	_light.omni_range = 3.2
	_light.shadow_enabled = false
	_flame_material = flame.material_override as StandardMaterial3D
	if _flame_material != null:
		_base_flame_color = _flame_material.albedo_color


func apply_cycle_progress(progress: float) -> void:
	if _light == null:
		return
	var night := 1.0 - DayNightCycle.day_blend(progress)
	var energy := lerpf(DAY_ENERGY, NIGHT_ENERGY, night)
	_light.light_energy = energy
	if _flame_material != null:
		_flame_material.emission_enabled = true
		_flame_material.emission = CANDLE_COLOR
		_flame_material.emission_energy_multiplier = lerpf(0.4, 1.8, night)
		_flame_material.albedo_color = _base_flame_color.lerp(CANDLE_COLOR, night * 0.35)

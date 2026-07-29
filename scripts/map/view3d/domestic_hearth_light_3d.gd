class_name DomesticHearthLight3D
extends Node

## Day/night and flicker controller for domestic cooking hearths. Smaller and
## warmer than the industrial forge fill so food fire reads separately from hot work.

const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")

const FIRE_COLOR := Color8(255, 148, 72)

var _light: OmniLight3D
var _flame: GPUParticles3D
var _smoke: GPUParticles3D
var _profile: Dictionary = {}
var _base_energy := 0.0
var _time := 0.0


func configure(
	light: OmniLight3D,
	flame: GPUParticles3D,
	smoke: GPUParticles3D,
	profile: Dictionary
) -> void:
	name = "DomesticHearthLight"
	_light = light
	_flame = flame
	_smoke = smoke
	_profile = profile.duplicate()
	if _light != null:
		_light.light_color = FIRE_COLOR
		_light.omni_range = float(_profile.get("range", 0.0))
		_light.shadow_enabled = false
	apply_cycle_progress(DayNightCycle.DEFAULT_PROGRESS)


func apply_cycle_progress(progress: float) -> void:
	if _light == null:
		return
	var night := 1.0 - DayNightCycle.day_blend(progress)
	var day_energy := float(_profile.get("day_energy", 0.0))
	var night_energy := float(_profile.get("night_energy", 0.0))
	_base_energy = lerpf(day_energy, night_energy, night)
	_light.light_energy = _base_energy
	if _flame != null:
		_flame.emitting = _base_energy > 0.0 and float(_profile.get("flame_size", 0.0)) > 0.0
	if _smoke != null:
		_smoke.emitting = int(_profile.get("smoke_amount", 0)) > 0 and _base_energy > 0.0


func _process(delta: float) -> void:
	if _light == null or _base_energy <= 0.0:
		return
	_time += delta
	var phase := float(_profile.get("flicker_phase", 0.0))
	var flicker := 1.0 \
		+ 0.1 * sin((_time + phase) * 9.4) \
		+ 0.06 * sin((_time + phase) * 14.2 + 0.8)
	_light.light_energy = _base_energy * flicker

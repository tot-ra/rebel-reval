class_name ForgeFireLight3D
extends Node

## Warm forge fill for furnace props. Stronger than candles so the hearth reads
## as the bay's heat source after window daylight fades. Flicker drives the
## light, the flame tongue emission, and the tongue playback speed together so
## glow, shape, and motion pulse as one living fire instead of a static lamp.

const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")

const FIRE_COLOR := Color8(255, 140, 52)
const DAY_ENERGY := 0.95
const NIGHT_ENERGY := 2.8

var _light: OmniLight3D
var _flames: Node3D
var _sparks: GPUParticles3D
var _smoke: GPUParticles3D
var _base_energy := DAY_ENERGY
var _time := 0.0


func configure(
	light: OmniLight3D,
	flames: Node3D,
	sparks: GPUParticles3D,
	smoke: GPUParticles3D = null
) -> void:
	name = "ForgeFireLight"
	_light = light
	_light.light_color = FIRE_COLOR
	_light.omni_range = 6.2
	_light.shadow_enabled = false
	_flames = flames
	_sparks = sparks
	_smoke = smoke


func _process(delta: float) -> void:
	_time += delta
	if _light == null:
		return
	# Uneven flicker so the open mouth reads as living fire, not a lamp.
	var flicker := 1.0 \
		+ 0.12 * sin(_time * 11.3) \
		+ 0.08 * sin(_time * 17.7 + 1.3) \
		+ 0.05 * sin(_time * 29.1 + 0.4)
	_light.light_energy = _base_energy * flicker
	if _flames != null:
		# Flame tongues breathe with the light: emission and playback speed
		# rise and fall together, like a bellows draft feeding the coals.
		_flames.set_flicker(flicker)


func apply_cycle_progress(progress: float) -> void:
	if _light == null:
		return
	var night := 1.0 - DayNightCycle.day_blend(progress)
	_base_energy = lerpf(DAY_ENERGY, NIGHT_ENERGY, night)
	_light.light_energy = _base_energy
	if _flames != null:
		_flames.set_night_blend(night)
		_flames.set_flicker(lerpf(0.96, 1.08, night))
	if _sparks != null:
		_sparks.amount = 34 if night > 0.45 else 24

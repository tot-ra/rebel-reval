class_name ForgeFireLight3D
extends Node

## Warm forge fill for furnace props. Stronger than candles so the hearth reads
## as the bay's heat source after window daylight fades. Flicker keeps the open
## firebox alive instead of a static spark sprinkle.

const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")

const FIRE_COLOR := Color8(255, 140, 52)
const DAY_ENERGY := 0.95
const NIGHT_ENERGY := 2.8

var _light: OmniLight3D
var _flame_meshes: Array[MeshInstance3D] = []
var _flame_materials: Array[StandardMaterial3D] = []
var _particles: GPUParticles3D
var _base_energy := DAY_ENERGY
var _time := 0.0


func configure(light: OmniLight3D, flame_meshes: Array[MeshInstance3D], particles: GPUParticles3D = null) -> void:
	name = "ForgeFireLight"
	_light = light
	_light.light_color = FIRE_COLOR
	_light.omni_range = 6.2
	_light.shadow_enabled = false
	_particles = particles
	_flame_meshes.clear()
	_flame_materials.clear()
	for flame in flame_meshes:
		_flame_meshes.append(flame)
		var material := flame.material_override as StandardMaterial3D
		if material != null:
			_flame_materials.append(material)


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
	for index in _flame_meshes.size():
		var flame := _flame_meshes[index]
		var pulse := 1.0 + 0.1 * sin(_time * (9.0 + float(index) * 2.7) + float(index))
		flame.scale = Vector3(pulse, 1.0 + (pulse - 1.0) * 1.6, pulse)
	for material in _flame_materials:
		material.emission_enabled = true
		material.emission = FIRE_COLOR
		material.emission_energy_multiplier = lerpf(2.2, 3.6, clampf((flicker - 0.9) / 0.3, 0.0, 1.0))


func apply_cycle_progress(progress: float) -> void:
	if _light == null:
		return
	var night := 1.0 - DayNightCycle.day_blend(progress)
	_base_energy = lerpf(DAY_ENERGY, NIGHT_ENERGY, night)
	_light.light_energy = _base_energy
	for material in _flame_materials:
		material.emission_enabled = true
		material.emission = FIRE_COLOR
		material.emission_energy_multiplier = lerpf(2.2, 3.8, night)
	if _particles != null:
		_particles.amount = 34 if night > 0.45 else 24

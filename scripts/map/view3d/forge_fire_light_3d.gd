class_name ForgeFireLight3D
extends Node

## Warm forge fill for furnace props. Stronger than candles so the hearth reads
## as the bay's heat source after window daylight fades.

const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")

const FIRE_COLOR := Color8(255, 148, 64)
const DAY_ENERGY := 0.55
const NIGHT_ENERGY := 2.4

var _light: OmniLight3D
var _flame_materials: Array[StandardMaterial3D] = []
var _particles: GPUParticles3D


func configure(light: OmniLight3D, flame_meshes: Array[MeshInstance3D], particles: GPUParticles3D = null) -> void:
	name = "ForgeFireLight"
	_light = light
	_light.light_color = FIRE_COLOR
	_light.omni_range = 5.5
	_light.shadow_enabled = false
	_particles = particles
	_flame_materials.clear()
	for flame in flame_meshes:
		var material := flame.material_override as StandardMaterial3D
		if material != null:
			_flame_materials.append(material)


func apply_cycle_progress(progress: float) -> void:
	if _light == null:
		return
	var night := 1.0 - DayNightCycle.day_blend(progress)
	_light.light_energy = lerpf(DAY_ENERGY, NIGHT_ENERGY, night)
	for material in _flame_materials:
		material.emission_enabled = true
		material.emission = FIRE_COLOR
		material.emission_energy_multiplier = lerpf(0.85, 2.6, night)
	if _particles != null:
		_particles.amount = 18 if night > 0.45 else 12

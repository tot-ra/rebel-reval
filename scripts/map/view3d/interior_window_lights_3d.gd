class_name InteriorWindowLights3D
extends Node

## Daylight glow through interior window glass. Inverse of house evening lights:
## bright while the sun is up, fading out after dusk.

const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")

const DAYLIGHT_COLOR := Color8(214, 228, 255)
const GLOW_ENERGY_MIN := 0.25
const GLOW_ENERGY_MAX := 2.1

var _materials: Array[StandardMaterial3D] = []
var _base_albedos: Array[Color] = []


func configure_from(root: Node3D) -> void:
	name = "InteriorWindowLights"
	_materials.clear()
	_base_albedos.clear()
	for child in root.get_children():
		if not child is MeshInstance3D:
			continue
		var mesh := child as MeshInstance3D
		if not mesh.name.begins_with("Window"):
			continue
		var source := mesh.material_override as StandardMaterial3D
		if source == null:
			continue
		var material := source.duplicate() as StandardMaterial3D
		mesh.material_override = material
		_materials.append(material)
		_base_albedos.append(material.albedo_color)
		_apply_strength(_materials.size() - 1, 0.0)


func apply_cycle_progress(progress: float) -> void:
	if _materials.is_empty():
		return
	var strength := DayNightCycle.day_blend(progress)
	for index in _materials.size():
		_apply_strength(index, strength)


func _apply_strength(index: int, strength: float) -> void:
	var material := _materials[index]
	var base := _base_albedos[index]
	if strength <= 0.001:
		material.emission_enabled = false
		material.emission_energy_multiplier = 0.0
		material.albedo_color = base
		return
	material.emission_enabled = true
	material.emission = DAYLIGHT_COLOR
	material.emission_energy_multiplier = lerpf(GLOW_ENERGY_MIN, GLOW_ENERGY_MAX, strength)
	material.albedo_color = base.lerp(DAYLIGHT_COLOR.lightened(0.12), strength * 0.55)

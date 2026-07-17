class_name BuildingWindowLights3D
extends Node

## Per-house evening window glow: warm emissive panes on a building-specific
## schedule so the city reads lived-in after dusk without lighting every facade.

const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")

const GLOW_FADE_HOURS := 0.45
const GLOW_ENERGY_MIN := 0.35
const GLOW_ENERGY_MAX := 2.4

var _building_seed: int = 0
var _participates := false
var _start_hour := 19.0
var _end_hour := 23.0
var _glow_color := Color8(255, 196, 112)
var _materials: Array[StandardMaterial3D] = []
var _base_albedos: Array[Color] = []
var _window_lit: Array[bool] = []


static func evening_schedule_for(building_seed: int) -> Dictionary:
	# Roughly one in twelve houses stays dark - workshops, empty rooms, etc.
	if building_seed % 12 == 0:
		return {"participates": false}
	var start := 18.5 + float((building_seed >> 1) % 7) * 0.25
	var end := 22.0 + float((building_seed >> 4) % 9) * 0.33
	end = minf(end, 23.75)
	if end <= start + 1.0:
		end = start + 2.5
	return {
		"participates": true,
		"start_hour": start,
		"end_hour": end,
	}


func configure(building_id: StringName) -> void:
	name = "WindowLights"
	_building_seed = String(building_id).hash()
	var schedule: Dictionary = evening_schedule_for(_building_seed)
	_participates = bool(schedule.get("participates", false))
	if not _participates:
		return
	_start_hour = float(schedule["start_hour"])
	_end_hour = float(schedule["end_hour"])
	var warmth := float((_building_seed >> 6) % 100) / 100.0
	_glow_color = Color(
		lerpf(0.98, 1.0, warmth),
		lerpf(0.72, 0.82, warmth),
		lerpf(0.38, 0.48, warmth)
	)

	var parent := get_parent()
	if parent == null:
		return
	var window_index := 0
	for child in parent.get_children():
		if not child is MeshInstance3D:
			continue
		var mesh := child as MeshInstance3D
		if not _is_glass_window_name(mesh.name):
			continue
		_register_window(mesh, window_index)
		window_index += 1


func apply_cycle_progress(progress: float) -> void:
	if not _participates or _materials.is_empty():
		return
	var hour := DayNightCycle.progress_to_hour(progress)
	var building_strength := DayNightCycle.evening_glow_strength(
		hour,
		_start_hour,
		_end_hour,
		GLOW_FADE_HOURS
	)
	for index in _materials.size():
		var strength := building_strength if _window_lit[index] else 0.0
		_apply_strength(index, strength)


func _register_window(mesh: MeshInstance3D, index: int) -> void:
	var lit := ((_building_seed >> (index * 2 + 1)) % 5) != 0
	_window_lit.append(lit)
	var source := mesh.material_override as StandardMaterial3D
	if source == null:
		return
	var material := source.duplicate() as StandardMaterial3D
	mesh.material_override = material
	_materials.append(material)
	_base_albedos.append(material.albedo_color)
	_apply_strength(_materials.size() - 1, 0.0)


func _apply_strength(index: int, strength: float) -> void:
	var material := _materials[index]
	var base := _base_albedos[index]
	if strength <= 0.001:
		material.emission_enabled = false
		material.emission_energy_multiplier = 0.0
		material.albedo_color = base
		return
	material.emission_enabled = true
	material.emission = _glow_color
	material.emission_energy_multiplier = lerpf(GLOW_ENERGY_MIN, GLOW_ENERGY_MAX, strength)
	material.albedo_color = base.lerp(_glow_color.lightened(0.18), strength * 0.42)


static func _is_glass_window_name(node_name: String) -> bool:
	if not node_name.begins_with("Window"):
		return false
	var suffix := node_name.substr(6)
	return not suffix.is_empty() and suffix.is_valid_int()

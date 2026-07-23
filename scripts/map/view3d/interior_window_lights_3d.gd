class_name InteriorWindowLights3D
extends Node3D

## Composite daylight for enclosed rooms. Emissive glazing keeps the opening
## readable while a fixed shadow-casting spot projects light inward from each
## window. The outdoor sun remains free to light exterior wall faces.

const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")

const DAYLIGHT_COLOR := Color8(214, 228, 255)
const GLOW_ENERGY_MIN := 0.25
const GLOW_ENERGY_MAX := 2.1
const WINDOW_LIGHT_ENERGY := 2.4
const WINDOW_LIGHT_RANGE := 8.0
const WINDOW_LIGHT_ANGLE := 48.0
const WINDOW_LIGHT_ATTENUATION := 0.72
const WINDOW_LIGHT_SOURCE_OFFSET := 0.12
const WINDOW_LIGHT_TARGET_DISTANCE := 2.8

var _materials: Array[StandardMaterial3D] = []
var _base_albedos: Array[Color] = []
var _window_lights: Array[SpotLight3D] = []


func configure_from(root: Node3D) -> void:
	name = "InteriorWindowLights"
	_materials.clear()
	_base_albedos.clear()
	_window_lights.clear()
	for child in root.get_children():
		if not child is MeshInstance3D:
			continue
		var mesh := child as MeshInstance3D
		if not _is_glass_window_name(mesh.name):
			continue
		# Transparent glazing should color the opening, not seal it in the sun's
		# shadow map. The frame and mullion remain ordinary shadow casters.
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var source := mesh.material_override as StandardMaterial3D
		if source == null:
			continue
		var material := source.duplicate() as StandardMaterial3D
		mesh.material_override = material
		_materials.append(material)
		_base_albedos.append(material.albedo_color)
		_apply_strength(_materials.size() - 1, 0.0)
		_add_window_light(mesh)


func apply_cycle_progress(progress: float) -> void:
	var strength := DayNightCycle.day_blend(progress)
	for index in _materials.size():
		_apply_strength(index, strength)
	for light in _window_lights:
		light.light_energy = WINDOW_LIGHT_ENERGY * strength
		light.visible = strength > 0.001


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


func _add_window_light(mesh: MeshInstance3D) -> void:
	# Landmark glass is offset toward the exterior side of its perimeter wall, so
	# the inverse radial direction points into the room. This keeps the beam tied
	# to the authored opening instead of to the moving sun or the camera mode.
	var inward := Vector3(-mesh.position.x, 0.0, -mesh.position.z).normalized()
	if inward.is_zero_approx():
		return
	var light := SpotLight3D.new()
	light.name = "WindowDaylight%d" % _window_lights.size()
	light.position = mesh.position + inward * WINDOW_LIGHT_SOURCE_OFFSET
	light.light_color = DAYLIGHT_COLOR
	light.light_energy = 0.0
	light.spot_range = WINDOW_LIGHT_RANGE
	light.spot_angle = WINDOW_LIGHT_ANGLE
	light.spot_attenuation = WINDOW_LIGHT_ATTENUATION
	light.shadow_enabled = true
	light.basis = Basis.looking_at(inward * WINDOW_LIGHT_TARGET_DISTANCE, Vector3.UP)
	add_child(light)
	_window_lights.append(light)


static func _is_glass_window_name(node_name: String) -> bool:
	if not node_name.begins_with("Window"):
		return false
	var suffix := node_name.substr(6)
	return not suffix.is_empty() and suffix.is_valid_int()

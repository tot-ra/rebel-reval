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

## Floating dust motes suspended in the daylight shaft. They are lit like ordinary
## geometry, so the shadow-casting window spot brightens only the motes inside the
## cone and leaves the rest of the room's motes dim - a god-ray without volumetric
## fog, which the GL Compatibility renderer cannot provide.
const DUST_PARTICLE_COUNT := 34
const DUST_LIFETIME := 12.0
const DUST_SHAFT_HALF_LENGTH := WINDOW_LIGHT_TARGET_DISTANCE * 0.55
const DUST_SHAFT_HALF_WIDTH := 0.9
const DUST_SHAFT_TOP_MARGIN := 0.3
const DUST_SHAFT_FLOOR := 0.05
const DUST_VISIBLE_STRENGTH := 0.02

var _materials: Array[StandardMaterial3D] = []
var _base_albedos: Array[Color] = []
var _window_lights: Array[SpotLight3D] = []
var _dust_shafts: Array[GPUParticles3D] = []


func configure_from(root: Node3D) -> void:
	name = "InteriorWindowLights"
	_materials.clear()
	_base_albedos.clear()
	_window_lights.clear()
	_dust_shafts.clear()
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
	var dust_visible := strength > DUST_VISIBLE_STRENGTH
	for shaft in _dust_shafts:
		shaft.visible = dust_visible
		shaft.emitting = dust_visible
		# Thin the mote field toward dawn/dusk so the shaft grows with the daylight
		# instead of snapping to a full swarm the instant the sun clears the horizon.
		shaft.amount_ratio = clampf(strength, 0.0, 1.0)


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
	_add_window_dust(mesh, inward)


func _add_window_dust(mesh: MeshInstance3D, inward: Vector3) -> void:
	# The mote volume is a floor-to-window box hugging the beam axis. It stays
	# world-aligned so gravity drifts motes gently downward; the spot's shadow map
	# then does the shaping, lighting only the motes that fall inside the cone.
	var top := mesh.position.y + DUST_SHAFT_TOP_MARGIN
	var half_height := maxf((top - DUST_SHAFT_FLOOR) * 0.5, 0.2)
	var center_y := DUST_SHAFT_FLOOR + half_height
	var center_distance := WINDOW_LIGHT_SOURCE_OFFSET + DUST_SHAFT_HALF_LENGTH
	var perpendicular := Vector3(-inward.z, 0.0, inward.x)
	var extents := Vector3(
		absf(inward.x) * DUST_SHAFT_HALF_LENGTH + absf(perpendicular.x) * DUST_SHAFT_HALF_WIDTH,
		half_height,
		absf(inward.z) * DUST_SHAFT_HALF_LENGTH + absf(perpendicular.z) * DUST_SHAFT_HALF_WIDTH
	)

	var shaft := GPUParticles3D.new()
	shaft.name = "WindowDust%d" % _dust_shafts.size()
	shaft.position = Vector3(
		mesh.position.x + inward.x * center_distance,
		center_y,
		mesh.position.z + inward.z * center_distance
	)
	shaft.amount = DUST_PARTICLE_COUNT
	shaft.lifetime = DUST_LIFETIME
	shaft.preprocess = DUST_LIFETIME
	shaft.randomness = 1.0
	shaft.fixed_fps = 20
	shaft.visibility_aabb = AABB(-extents, extents * 2.0)
	shaft.process_material = _dust_process_material(extents)
	shaft.draw_pass_1 = _dust_draw_mesh()
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shaft.visible = false
	shaft.emitting = false
	add_child(shaft)
	_dust_shafts.append(shaft)


static func _dust_process_material(extents: Vector3) -> ParticleProcessMaterial:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = extents
	# Motes barely fall: airborne dust hangs and swirls far more than it settles.
	process.direction = Vector3(0.0, -1.0, 0.0)
	process.spread = 30.0
	process.initial_velocity_min = 0.004
	process.initial_velocity_max = 0.03
	process.gravity = Vector3(0.0, -0.012, 0.0)
	process.damping_min = 0.0
	process.damping_max = 0.04
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.14
	process.turbulence_noise_scale = 1.3
	process.turbulence_influence_min = 0.02
	process.turbulence_influence_max = 0.06
	process.scale_min = 0.006
	process.scale_max = 0.02
	process.color_ramp = _dust_alpha_ramp()
	return process


static func _dust_alpha_ramp() -> GradientTexture1D:
	# Motes fade in and out over their lifetime so they never pop at the box edges.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.18, Color(1.0, 1.0, 1.0, 1.0))
	gradient.add_point(0.8, Color(1.0, 1.0, 1.0, 1.0))
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


static func _dust_draw_mesh() -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	mesh.material = _dust_material()
	return mesh


static func _dust_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Lit, not unshaded: the warm daylight spot is what makes in-beam motes glint
	# while motes in shadow or ambient-only room light stay dim. A muted albedo
	# keeps the ambient contribution low so the shaft reads as the bright band.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.albedo_color = Color(0.72, 0.68, 0.58, 0.72)
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.metallic = 0.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	return material


static func _is_glass_window_name(node_name: String) -> bool:
	if not node_name.begins_with("Window"):
		return false
	var suffix := node_name.substr(6)
	return not suffix.is_empty() and suffix.is_valid_int()

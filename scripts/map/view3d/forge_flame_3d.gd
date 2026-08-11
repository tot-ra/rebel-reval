class_name ForgeFlame3D
extends Node3D

## Layered furnace flame built from short-lived, tapered GPU particles. The hot
## core and cooler outer tongues move at different rates so the fire continually
## breaks and reforms instead of pulsing as a few solid primitive meshes.

const OUTER_DAY_RATIO := 0.82
const OUTER_NIGHT_RATIO := 1.0
const CORE_DAY_RATIO := 0.72
const CORE_NIGHT_RATIO := 0.92

var _outer_flames: GPUParticles3D
var _hot_core: GPUParticles3D


func configure() -> void:
	name = "ForgeFlames"
	_outer_flames = _create_layer(
		"OuterFlames",
		34,
		0.72,
		Vector3(0.39, 0.025, 0.20),
		Vector2(0.38, 0.92),
		Vector2(0.74, 1.22),
		Vector2(0.24, 0.64),
		Color(1.0, 0.25, 0.025),
		_outer_color_ramp()
	)
	add_child(_outer_flames)

	_hot_core = _create_layer(
		"HotCore",
		24,
		0.46,
		Vector3(0.30, 0.018, 0.15),
		Vector2(0.18, 0.58),
		Vector2(0.68, 1.02),
		Vector2(0.18, 0.42),
		Color(1.0, 0.64, 0.08),
		_core_color_ramp()
	)
	_hot_core.position = Vector3(0.0, -0.015, 0.025)
	add_child(_hot_core)
	set_night_blend(0.0)


func set_flicker(flicker: float) -> void:
	var response := clampf((flicker - 0.85) / 0.4, 0.0, 1.0)
	var playback_speed := lerpf(0.92, 1.1, response)
	var emission_energy := lerpf(2.3, 3.4, response)
	for layer in [_outer_flames, _hot_core]:
		if layer == null:
			continue
		layer.speed_scale = playback_speed
		var mesh := layer.draw_pass_1 as ArrayMesh
		if mesh != null:
			var material := mesh.surface_get_material(0) as StandardMaterial3D
			if material != null:
				material.emission_energy_multiplier = emission_energy


func set_night_blend(night: float) -> void:
	var blend := clampf(night, 0.0, 1.0)
	if _outer_flames != null:
		_outer_flames.amount_ratio = lerpf(OUTER_DAY_RATIO, OUTER_NIGHT_RATIO, blend)
	if _hot_core != null:
		_hot_core.amount_ratio = lerpf(CORE_DAY_RATIO, CORE_NIGHT_RATIO, blend)


static func _create_layer(
	node_name: String,
	particle_count: int,
	particle_lifetime: float,
	emission_extents: Vector3,
	velocity_range: Vector2,
	scale_range: Vector2,
	flame_size: Vector2,
	emission_color: Color,
	color_ramp: GradientTexture1D
) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = node_name
	particles.amount = particle_count
	particles.lifetime = particle_lifetime
	particles.preprocess = particle_lifetime
	particles.explosiveness = 0.0
	particles.randomness = 0.76
	particles.local_coords = true
	particles.fixed_fps = 30
	particles.visibility_aabb = AABB(Vector3(-0.8, -0.12, -0.55), Vector3(1.6, 1.7, 1.1))

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = emission_extents
	process.direction = Vector3.UP
	process.spread = 17.0
	process.initial_velocity_min = velocity_range.x
	process.initial_velocity_max = velocity_range.y
	# Buoyancy and turbulence make neighboring tongues curl apart instead of
	# following the same mechanically straight trajectory.
	process.gravity = Vector3(0.0, 0.34, 0.0)
	process.damping_min = 0.12
	process.damping_max = 0.42
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.78
	process.turbulence_noise_scale = 2.35
	process.turbulence_influence_min = 0.16
	process.turbulence_influence_max = 0.34
	process.angle_min = -7.0
	process.angle_max = 7.0
	process.angular_velocity_min = -10.0
	process.angular_velocity_max = 10.0
	process.scale_min = scale_range.x
	process.scale_max = scale_range.y
	process.scale_curve = _flame_scale_curve()
	process.color_ramp = color_ramp
	particles.process_material = process

	var mesh := _flame_mesh(flame_size)
	mesh.surface_set_material(0, _flame_material(emission_color))
	particles.draw_pass_1 = mesh
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.emitting = true
	return particles


static func _flame_scale_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.18))
	curve.add_point(Vector2(0.12, 1.0))
	curve.add_point(Vector2(0.55, 0.78))
	curve.add_point(Vector2(0.82, 0.42))
	curve.add_point(Vector2(1.0, 0.04))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


static func _outer_color_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.78, 0.22, 0.0))
	gradient.set_color(1, Color(0.82, 0.055, 0.005, 0.0))
	gradient.add_point(0.08, Color(1.0, 0.82, 0.24, 0.92))
	gradient.add_point(0.34, Color(1.0, 0.42, 0.055, 0.86))
	gradient.add_point(0.72, Color(0.96, 0.16, 0.012, 0.48))
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


static func _core_color_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.98, 0.72, 0.0))
	gradient.set_color(1, Color(1.0, 0.19, 0.012, 0.0))
	gradient.add_point(0.08, Color(1.0, 0.97, 0.65, 0.96))
	gradient.add_point(0.40, Color(1.0, 0.71, 0.17, 0.90))
	gradient.add_point(0.78, Color(1.0, 0.33, 0.025, 0.38))
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


static func _flame_mesh(size: Vector2) -> ArrayMesh:
	# A soft-edged asymmetric fan gives each particle a recognisable lick shape.
	# Transparent perimeter vertex colors feather overlap without a texture asset.
	var half_width := size.x * 0.5
	var height := size.y
	var vertices := PackedVector3Array(
		[
			Vector3(0.0, height * 0.36, 0.0),
			Vector3(-half_width * 0.30, 0.0, 0.0),
			Vector3(half_width * 0.32, 0.0, 0.0),
			Vector3(half_width * 0.82, height * 0.08, 0.0),
			Vector3(half_width, height * 0.23, 0.0),
			Vector3(half_width * 0.64, height * 0.43, 0.0),
			Vector3(half_width * 0.44, height * 0.62, 0.0),
			Vector3(half_width * 0.12, height * 0.78, 0.0),
			Vector3(0.0, height, 0.0),
			Vector3(-half_width * 0.22, height * 0.76, 0.0),
			Vector3(-half_width * 0.48, height * 0.58, 0.0),
			Vector3(-half_width * 0.72, height * 0.42, 0.0),
			Vector3(-half_width, height * 0.22, 0.0),
			Vector3(-half_width * 0.76, height * 0.07, 0.0),
		]
	)
	var colors := PackedColorArray([Color.WHITE])
	for index in range(1, vertices.size()):
		colors.append(Color(1.0, 0.48, 0.06, 0.0))
	var indices := PackedInt32Array()
	for point in range(1, vertices.size()):
		indices.append(0)
		indices.append(point)
		indices.append(1 if point == vertices.size() - 1 else point + 1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _flame_material(emission_color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.emission_enabled = true
	material.emission = emission_color
	material.emission_energy_multiplier = 2.8
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	return material

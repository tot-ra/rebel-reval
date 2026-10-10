class_name ForgeFlame3D
extends Node3D

## Layered furnace flame: slow, overlapping GPU particle billboards whose shape
## comes from forge_flame.gdshader (noise-torn translucent tongues), so the fire
## reads as a soft sheet of flame licking off the coals, not as solid spikes.
## The hot core and cooler outer tongues move at different rates.

const OUTER_DAY_RATIO := 0.82
const OUTER_NIGHT_RATIO := 1.0
const CORE_DAY_RATIO := 0.72
const CORE_NIGHT_RATIO := 0.92
const BASE_ENERGY := 1.05
const FLAME_SHADER := preload("res://scripts/map/view3d/forge_flame.gdshader")

static var _noise: NoiseTexture2D

var _outer_flames: GPUParticles3D
var _hot_core: GPUParticles3D


func configure() -> void:
	name = "ForgeFlames"
	_outer_flames = _create_layer(
		"OuterFlames",
		22,
		0.95,
		Vector3(0.27, 0.02, 0.15),
		Vector2(0.16, 0.38),
		Vector2(0.8, 1.2),
		Vector2(0.38, 0.62),
		Color(1.0, 0.25, 0.025),
		_outer_color_ramp()
	)
	add_child(_outer_flames)

	_hot_core = _create_layer(
		"HotCore",
		16,
		0.62,
		Vector3(0.19, 0.015, 0.11),
		Vector2(0.1, 0.26),
		Vector2(0.75, 1.05),
		Vector2(0.26, 0.38),
		Color(1.0, 0.64, 0.08),
		_core_color_ramp()
	)
	_hot_core.position = Vector3(0.0, -0.015, 0.025)
	add_child(_hot_core)
	set_night_blend(0.0)


func set_flicker(flicker: float) -> void:
	var response := clampf((flicker - 0.85) / 0.4, 0.0, 1.0)
	var playback_speed := lerpf(0.92, 1.1, response)
	var emission_energy := lerpf(BASE_ENERGY * 0.85, BASE_ENERGY * 1.25, response)
	for layer in [_outer_flames, _hot_core]:
		if layer == null:
			continue
		layer.speed_scale = playback_speed
		var material := layer.material_override as ShaderMaterial
		if material != null:
			material.set_shader_parameter("energy", emission_energy)


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
	# The shader billboard ignores spin; anim_offset is its per-particle seed.
	process.anim_offset_min = 0.0
	process.anim_offset_max = 1.0
	process.scale_min = scale_range.x
	process.scale_max = scale_range.y
	process.scale_curve = _flame_scale_curve()
	process.color_ramp = color_ramp
	particles.process_material = process

	particles.draw_pass_1 = _flame_mesh(flame_size)
	particles.material_override = _flame_material(emission_color)
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
	gradient.add_point(0.1, Color(1.0, 0.62, 0.16, 0.62))
	gradient.add_point(0.4, Color(1.0, 0.36, 0.05, 0.55))
	gradient.add_point(0.75, Color(0.85, 0.14, 0.01, 0.28))
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


static func _core_color_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.98, 0.72, 0.0))
	gradient.set_color(1, Color(1.0, 0.19, 0.012, 0.0))
	gradient.add_point(0.1, Color(1.0, 0.86, 0.5, 0.7))
	gradient.add_point(0.42, Color(1.0, 0.62, 0.16, 0.6))
	gradient.add_point(0.8, Color(1.0, 0.3, 0.03, 0.22))
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


static func _flame_mesh(size: Vector2) -> QuadMesh:
	# Plain quad; forge_flame.gdshader carves the torn tongue out of it. The
	# pivot sits at the quad base so scale-over-life grows the flame upward.
	var mesh := QuadMesh.new()
	mesh.size = size
	mesh.center_offset = Vector3(0.0, size.y * 0.5, 0.0)
	return mesh


static func _flame_material(emission_color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FLAME_SHADER
	material.set_shader_parameter("noise_tex", flame_noise())
	material.set_shader_parameter("energy", BASE_ENERGY)
	# Hotter layers climb faster through their own noise.
	material.set_shader_parameter("rise_speed", lerpf(1.1, 1.6, emission_color.g))
	return material


## Shared seamless noise for flame and coal shaders: one small texture for every
## furnace in the city instead of one per prop.
static func flame_noise() -> NoiseTexture2D:
	if _noise != null:
		return _noise
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.035
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.seed = 4127
	_noise = NoiseTexture2D.new()
	_noise.width = 128
	_noise.height = 128
	_noise.seamless = true
	_noise.generate_mipmaps = true
	_noise.noise = noise
	return _noise

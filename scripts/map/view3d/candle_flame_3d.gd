class_name CandleFlame3D
extends GPUParticles3D

## Runtime flame effect attached to a wick marker from the lighting model. The
## authored GLB deliberately contains no fire geometry, so changing a holder or
## fuel never couples a static flame silhouette back into the prop mesh.

const DEFAULT_SIZE := 1.0
const BASE_WIDTH := 0.038
const BASE_HEIGHT := 0.15

static var _shared_draw_mesh: ArrayMesh


func configure(profile: Dictionary = {}) -> void:
	name = "CandleFlame"
	var flame_size := float(profile.get("flame_size", DEFAULT_SIZE))
	amount = int(profile.get("flame_particles", 7))
	lifetime = 0.34
	preprocess = lifetime
	explosiveness = 0.04
	randomness = 0.62
	local_coords = true
	visibility_aabb = AABB(
		Vector3(-0.16, -0.04, -0.16) * flame_size,
		Vector3(0.32, 0.38, 0.32) * flame_size
	)

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	process.direction = Vector3.UP
	process.spread = 11.0
	process.initial_velocity_min = 0.025
	process.initial_velocity_max = 0.11
	process.gravity = Vector3(0.0, 0.10, 0.0)
	process.damping_min = 0.04
	process.damping_max = 0.16
	process.angle_min = -4.0
	process.angle_max = 4.0
	process.angular_velocity_min = -9.0
	process.angular_velocity_max = 9.0
	process.scale_min = 0.72 * flame_size
	process.scale_max = 1.08 * flame_size
	process.scale_curve = _build_scale_curve()
	process.color_ramp = _build_color_ramp()
	process_material = process

	draw_pass_1 = _flame_draw_mesh()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	emitting = true


static func _build_scale_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.48))
	curve.add_point(Vector2(0.16, 1.0))
	curve.add_point(Vector2(0.62, 0.74))
	curve.add_point(Vector2(1.0, 0.10))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


static func _build_color_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.92, 0.52, 0.92))
	gradient.set_color(1, Color(1.0, 0.18, 0.02, 0.0))
	gradient.add_point(0.36, Color(1.0, 0.62, 0.12, 0.86))
	gradient.add_point(0.74, Color(1.0, 0.34, 0.035, 0.46))
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


static func _flame_draw_mesh() -> ArrayMesh:
	if _shared_draw_mesh != null:
		return _shared_draw_mesh

	# A tapered billboard gives every short-lived particle a lick-of-fire shape.
	# Overlap, upward drift, lifetime scaling, and alpha decay create the motion.
	var vertices := PackedVector3Array([
		Vector3(0.0, BASE_HEIGHT * 0.42, 0.0),
		Vector3(0.0, 0.0, 0.0),
		Vector3(BASE_WIDTH * 0.48, BASE_HEIGHT * 0.10, 0.0),
		Vector3(BASE_WIDTH, BASE_HEIGHT * 0.38, 0.0),
		Vector3(BASE_WIDTH * 0.52, BASE_HEIGHT * 0.69, 0.0),
		Vector3(0.0, BASE_HEIGHT, 0.0),
		Vector3(-BASE_WIDTH * 0.52, BASE_HEIGHT * 0.69, 0.0),
		Vector3(-BASE_WIDTH, BASE_HEIGHT * 0.38, 0.0),
		Vector3(-BASE_WIDTH * 0.48, BASE_HEIGHT * 0.10, 0.0),
	])
	var indices := PackedInt32Array()
	for point in range(1, vertices.size()):
		indices.append(0)
		indices.append(point)
		indices.append(1 if point == vertices.size() - 1 else point + 1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices

	_shared_draw_mesh = ArrayMesh.new()
	_shared_draw_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_shared_draw_mesh.surface_set_material(0, _flame_material())
	return _shared_draw_mesh


static func _flame_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.emission_enabled = true
	material.emission = Color(1.0, 0.38, 0.045)
	material.emission_energy_multiplier = 2.6
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	return material

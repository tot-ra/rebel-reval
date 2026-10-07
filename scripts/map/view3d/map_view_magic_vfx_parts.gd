extends RefCounted

## Static builders for MapViewMagicVfx (R-1198): soft particle materials,
## colour ramps, and procedural ground meshes (scorch, shock ring, cracks).
## No texture assets: every soft edge is a generated radial gradient or a
## vertex-alpha falloff, so P0-040 (no new element art) is untouched.

const IRON_WARD_SHADER := preload("res://scripts/map/view3d/map_view_iron_ward.gdshader")

static var _cache: Dictionary = {}


## Round soft sprite. Plain quads read as grey squares in close shots.
static func soft_dot_texture() -> Texture2D:
	if _cache.has("soft_dot"):
		return _cache["soft_dot"]
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.45, Color(1.0, 1.0, 1.0, 0.55))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	_cache["soft_dot"] = texture
	return texture


## Additive, self-lit billboard for flame tongues, flashes and sparks.
static func glow_material() -> StandardMaterial3D:
	if _cache.has("glow"):
		return _cache["glow"]
	var material := _billboard_material()
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_cache["glow"] = material
	return material


## Alpha-blended billboard for smoke, dust and steam; tint is the COLOR ramp.
static func soft_smoke_material() -> StandardMaterial3D:
	if _cache.has("soft_smoke"):
		return _cache["soft_smoke"]
	var material := _billboard_material()
	_cache["soft_smoke"] = material
	return material


## Lit stone chips so debris takes the scene's sun and shade like the cobbles.
static func debris_material() -> StandardMaterial3D:
	if _cache.has("debris"):
		return _cache["debris"]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.36, 0.31, 0.25)
	material.roughness = 1.0
	_cache["debris"] = material
	return material


## Unshaded vertex-alpha ground mesh material. Each burst owns its copy so
## fades never touch another burst.
static func ground_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = color
	return material


static func iron_ward_material(base_overlay: Material) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = IRON_WARD_SHADER
	# Keep the rig's own overlay (occlusion silhouette) as the next pass so a
	# ward never hides Kalev behind a building.
	material.next_pass = base_overlay
	return material


static func particles(
	node_name: String,
	amount: int,
	lifetime: float,
	process: ParticleProcessMaterial,
	quad_size: float,
	material: Material,
	world_space: bool = false
) -> GPUParticles3D:
	var emitter := GPUParticles3D.new()
	emitter.name = node_name
	emitter.amount = amount
	emitter.lifetime = lifetime
	emitter.local_coords = not world_space
	emitter.process_material = process
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	emitter.visibility_aabb = AABB(Vector3(-6.0, -1.0, -6.0), Vector3(12.0, 8.0, 12.0))
	var draw := QuadMesh.new()
	draw.size = Vector2(quad_size, quad_size)
	emitter.draw_pass_1 = draw
	emitter.material_override = material
	return emitter


static func burst_process(
	velocity: Vector2, gravity_y: float, scale_range: Vector2, ramp: GradientTexture1D
) -> ParticleProcessMaterial:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.1
	process.direction = Vector3.UP
	process.spread = 180.0
	process.initial_velocity_min = velocity.x
	process.initial_velocity_max = velocity.y
	process.gravity = Vector3(0.0, gravity_y, 0.0)
	process.scale_min = scale_range.x
	process.scale_max = scale_range.y
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.color_ramp = ramp
	return process


static func curve_texture(points: Array[Vector2]) -> CurveTexture:
	var curve := Curve.new()
	for point: Vector2 in points:
		curve.add_point(point)
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


static func ramp(stops: Array[float], colors: Array[Color]) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(stops)
	gradient.colors = PackedColorArray(colors)
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


## White-hot -> orange -> deep red -> gone. Alpha-premultiplied by fading,
## because additive blending turns any dark tint into transparency.
static func flame_ramp() -> GradientTexture1D:
	return ramp(
		[0.0, 0.12, 0.38, 0.7, 1.0],
		[
			Color(1.0, 0.95, 0.75, 0.0),
			Color(1.0, 0.86, 0.45, 0.95),
			Color(1.0, 0.45, 0.08, 0.8),
			Color(0.75, 0.13, 0.02, 0.35),
			Color(0.3, 0.04, 0.0, 0.0),
		]
	)


## Explosion body. Dozens of overlapping additive quads sum to flat white with
## `flame_ramp`, so this one peaks lower and turns red sooner: only the dense
## centre saturates and the billows keep orange-to-crimson shading.
static func explosion_ramp() -> GradientTexture1D:
	return ramp(
		[0.0, 0.08, 0.3, 0.6, 1.0],
		[
			Color(1.0, 0.9, 0.6, 0.0),
			Color(1.0, 0.66, 0.26, 0.3),
			Color(0.92, 0.3, 0.05, 0.24),
			Color(0.55, 0.08, 0.02, 0.1),
			Color(0.2, 0.03, 0.0, 0.0),
		]
	)


static func ember_ramp() -> GradientTexture1D:
	return ramp(
		[0.0, 0.5, 1.0],
		[Color(1.0, 0.9, 0.55, 1.0), Color(1.0, 0.5, 0.1, 0.9), Color(0.6, 0.12, 0.02, 0.0)]
	)


## Soot: invisible while the flame occupies the space, then dark and thinning.
static func soot_ramp(peak_alpha: float) -> GradientTexture1D:
	return ramp(
		[0.0, 0.18, 0.5, 1.0],
		[
			Color(0.16, 0.13, 0.11, 0.0),
			Color(0.17, 0.15, 0.13, peak_alpha),
			Color(0.26, 0.25, 0.24, peak_alpha * 0.6),
			Color(0.36, 0.36, 0.36, 0.0),
		]
	)


static func dust_ramp(peak_alpha: float) -> GradientTexture1D:
	return ramp(
		[0.0, 0.15, 0.6, 1.0],
		[
			Color(0.55, 0.47, 0.36, 0.0),
			Color(0.55, 0.47, 0.36, peak_alpha),
			Color(0.6, 0.54, 0.45, peak_alpha * 0.5),
			Color(0.64, 0.6, 0.53, 0.0),
		]
	)


## Flat disk, opaque centre feathering to nothing. Used for scorch marks.
static func soft_disk_mesh(radius: float, center: Color, segments: int = 24) -> ArrayMesh:
	var ring: Array[Vector3] = []
	for index: int in range(segments + 1):
		var angle := TAU * float(index) / float(segments)
		# Irregular rim so the scorch is not a perfect stamped circle.
		var wobble := 0.82 + 0.18 * sin(angle * 3.0 + 1.3) * cos(angle * 5.0)
		ring.append(Vector3(cos(angle), 0.0, sin(angle)) * radius * wobble)
	var verts := PackedVector3Array([Vector3.ZERO])
	var colors := PackedColorArray([center])
	var indices := PackedInt32Array()
	var mid := Color(center.r, center.g, center.b, center.a * 0.7)
	var rim := Color(center.r, center.g, center.b, 0.0)
	for point: Vector3 in ring:
		verts.append(point * 0.55)
		colors.append(mid)
	for point: Vector3 in ring:
		verts.append(point)
		colors.append(rim)
	var count := ring.size()
	for index: int in range(count - 1):
		indices.append_array(PackedInt32Array([0, 1 + index, 2 + index]))
		var inner := 1 + index
		var outer := 1 + count + index
		indices.append_array(
			PackedInt32Array([inner, outer, outer + 1, inner, outer + 1, inner + 1])
		)
	return _mesh(verts, colors, indices)


## Thin ring, solid in the middle of its width and feathered on both edges.
## Scaled up over time it reads as a shock front rolling across the ground.
static func soft_ring_mesh(radius: float, width: float, color: Color) -> ArrayMesh:
	var segments := 40
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var radii := [radius - width, radius - width * 0.35, radius, radius + width * 0.25]
	var alphas := [0.0, 1.0, 0.7, 0.0]
	for index: int in range(segments + 1):
		var angle := TAU * float(index) / float(segments)
		var heading := Vector3(cos(angle), 0.0, sin(angle))
		for band: int in range(4):
			verts.append(heading * maxf(float(radii[band]), 0.0))
			colors.append(Color(color.r, color.g, color.b, color.a * float(alphas[band])))
	for index: int in range(segments):
		var row := index * 4
		for band: int in range(3):
			var a := row + band
			var b := row + band + 4
			indices.append_array(PackedInt32Array([a, b, b + 1, a, b + 1, a + 1]))
	return _mesh(verts, colors, indices)


## Jagged branching cracks radiating from the centre. Deterministic per seed so
## two casts at one spot do not flicker between shapes.
static func crack_mesh(radius: float, seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var branch_count := 7
	for branch: int in range(branch_count):
		var angle := TAU * (float(branch) + rng.randf_range(-0.3, 0.3)) / float(branch_count)
		var length := radius * rng.randf_range(0.6, 0.95)
		_append_crack(verts, colors, indices, Vector3.ZERO, angle, length, 0.07, rng)
	return _mesh(verts, colors, indices)


static func _append_crack(
	verts: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	start: Vector3,
	angle: float,
	length: float,
	width: float,
	rng: RandomNumberGenerator
) -> void:
	var steps := 6
	var point := start
	var heading := angle
	var dark := Color(0.06, 0.045, 0.035, 0.9)
	for step: int in range(steps):
		var t := float(step) / float(steps)
		heading += rng.randf_range(-0.45, 0.45)
		var next := point + Vector3(cos(heading), 0.0, sin(heading)) * (length / float(steps))
		var side := Vector3(-sin(heading), 0.0, cos(heading))
		var w0 := width * (1.0 - t)
		var w1 := width * (1.0 - t - 1.0 / float(steps))
		var base := verts.size()
		verts.append_array(
			PackedVector3Array(
				[point - side * w0, point + side * w0, next + side * w1, next - side * w1]
			)
		)
		var tip := Color(dark.r, dark.g, dark.b, dark.a * (1.0 - t * 0.6))
		colors.append_array(PackedColorArray([tip, tip, tip, tip]))
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
		# Occasional side fork, thinner and shorter, like split paving.
		if step in [1, 3] and rng.randf() < 0.6:
			var fork := heading + rng.randf_range(0.6, 1.1) * (1.0 if rng.randf() < 0.5 else -1.0)
			_append_fork(verts, colors, indices, next, fork, length * 0.3, w1 * 0.7, dark)
		point = next


static func _append_fork(
	verts: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	start: Vector3,
	heading: float,
	length: float,
	width: float,
	color: Color
) -> void:
	var tip := start + Vector3(cos(heading), 0.0, sin(heading)) * length
	var side := Vector3(-sin(heading), 0.0, cos(heading)) * width
	var base := verts.size()
	verts.append_array(PackedVector3Array([start - side, start + side, tip]))
	colors.append_array(PackedColorArray([color, color, Color(color.r, color.g, color.b, 0.0)]))
	indices.append_array(PackedInt32Array([base, base + 1, base + 2]))


static func _billboard_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.albedo_texture = soft_dot_texture()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	# Soft-particle fade where a quad meets paving or a wall; without it big
	# flame and dust quads cut hard horizontal edges into the ground.
	material.proximity_fade_enabled = true
	material.proximity_fade_distance = 0.45
	return material


static func _mesh(
	verts: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array
) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

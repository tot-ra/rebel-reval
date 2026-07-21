class_name MapViewBarrelMeshes
extends RefCounted

const MeshMath := preload("res://scripts/map/view3d/map_view_mesh_builder_math.gd")

## Cached procedural meshes for coopered barrel props.
static var _mesh_cache: Dictionary = {}


## Coopered barrel body with a convex bilge and recessed seams between vertical
## staves. It intentionally has no caps: separate inset heads leave a visible lip.
static func barrel_stave_mesh(radius: float, height: float) -> ArrayMesh:
	var cache_key := "barrel_staves:%.4f:%.4f" % [radius, height]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]

	const STAVE_COUNT := 14
	const SEAM_FRACTION := 0.065
	const SEAM_RECESS := 0.965
	var profile: Array[Vector2] = [
		Vector2(0.0, 0.82),
		Vector2(0.08, 0.86),
		Vector2(0.23, 0.95),
		Vector2(0.42, 1.0),
		Vector2(0.58, 1.0),
		Vector2(0.77, 0.95),
		Vector2(0.92, 0.86),
		Vector2(1.0, 0.82),
	]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stave_step := TAU / float(STAVE_COUNT)
	var seam_width := stave_step * SEAM_FRACTION
	for stave_index in STAVE_COUNT:
		var sector_start := float(stave_index) * stave_step
		var face_start := sector_start + seam_width * 0.5
		var face_end := sector_start + stave_step - seam_width * 0.5
		var seam_start := face_end
		var seam_end := sector_start + stave_step + seam_width * 0.5
		# Gentle deterministic tone changes keep individual staves legible without
		# introducing per-instance resources or noisy randomized geometry.
		var tone := 0.86 + MeshMath.hash01(stave_index, 19, 617) * 0.18
		var stave_color := Color(tone, tone, tone)
		for profile_index in profile.size() - 1:
			var lower := profile[profile_index]
			var upper := profile[profile_index + 1]
			_barrel_profile_quad(
				surface,
				face_start,
				face_end,
				lower,
				upper,
				radius,
				height,
				1.0,
				stave_color
			)
			_barrel_profile_quad(
				surface,
				seam_start,
				seam_end,
				lower,
				upper,
				radius,
				height,
				SEAM_RECESS,
				Color(0.38, 0.34, 0.30)
			)
			_barrel_seam_bevel(
				surface,
				seam_start,
				lower,
				upper,
				radius,
				height,
				false
			)
			_barrel_seam_bevel(
				surface,
				seam_end,
				lower,
				upper,
				radius,
				height,
				true
			)
	var mesh := surface.commit()
	_mesh_cache[cache_key] = mesh
	return mesh


static func barrel_head_mesh(radius: float, thickness: float) -> CylinderMesh:
	var cache_key := "barrel_head:%.4f:%.4f" % [radius, thickness]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = thickness
	mesh.radial_segments = 14
	mesh.rings = 1
	_mesh_cache[cache_key] = mesh
	return mesh


static func barrel_hoop_mesh(radius: float) -> TorusMesh:
	var cache_key := "barrel_hoop:%.4f" % radius
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.003
	mesh.outer_radius = radius + 0.015
	mesh.rings = 14
	mesh.ring_segments = 4
	_mesh_cache[cache_key] = mesh
	return mesh


static func _barrel_profile_quad(
	surface: SurfaceTool,
	angle_start: float,
	angle_end: float,
	lower: Vector2,
	upper: Vector2,
	radius: float,
	height: float,
	radial_scale: float,
	color: Color
) -> void:
	var lower_radius := radius * lower.y * radial_scale
	var upper_radius := radius * upper.y * radial_scale
	var vertices := [
		_barrel_point(angle_start, lower.x * height, lower_radius),
		_barrel_point(angle_end, lower.x * height, lower_radius),
		_barrel_point(angle_end, upper.x * height, upper_radius),
		_barrel_point(angle_start, upper.x * height, upper_radius),
	]
	var mid_angle := (angle_start + angle_end) * 0.5
	var radial := Vector3(sin(mid_angle), 0.0, cos(mid_angle))
	var slope := (upper_radius - lower_radius) / ((upper.x - lower.x) * height)
	var normal := (radial - Vector3.UP * slope).normalized()
	# Rotating the plank pattern makes its grain and board boundaries run along
	# the vertical staves instead of wrapping around the vessel like masonry.
	var circumference_scale := 14.0 / TAU
	var uvs := [
		Vector2(lower.x * 1.6, angle_start * circumference_scale),
		Vector2(lower.x * 1.6, angle_end * circumference_scale),
		Vector2(upper.x * 1.6, angle_end * circumference_scale),
		Vector2(upper.x * 1.6, angle_start * circumference_scale),
	]
	_barrel_quad(surface, vertices, uvs, normal, color)


static func _barrel_seam_bevel(
	surface: SurfaceTool,
	angle: float,
	lower: Vector2,
	upper: Vector2,
	radius: float,
	height: float,
	reverse: bool
) -> void:
	var outer_lower := _barrel_point(angle, lower.x * height, radius * lower.y)
	var outer_upper := _barrel_point(angle, upper.x * height, radius * upper.y)
	var inner_lower := _barrel_point(angle, lower.x * height, radius * lower.y * 0.965)
	var inner_upper := _barrel_point(angle, upper.x * height, radius * upper.y * 0.965)
	var vertices := [outer_lower, inner_lower, inner_upper, outer_upper]
	if reverse:
		vertices = [inner_lower, outer_lower, outer_upper, inner_upper]
	var tangent := Vector3(cos(angle), 0.0, -sin(angle)) * (-1.0 if reverse else 1.0)
	_barrel_quad(
		surface,
		vertices,
		[Vector2.ZERO, Vector2.ONE, Vector2.ONE, Vector2.ZERO],
		tangent,
		Color(0.58, 0.52, 0.46)
	)


static func _barrel_quad(
	surface: SurfaceTool,
	vertices: Array,
	uvs: Array,
	normal: Vector3,
	color: Color
) -> void:
	for index in [0, 1, 2, 0, 2, 3]:
		surface.set_color(color)
		surface.set_normal(normal)
		surface.set_uv(uvs[index])
		surface.add_vertex(vertices[index])


static func _barrel_point(angle: float, y: float, radius: float) -> Vector3:
	return Vector3(sin(angle) * radius, y, cos(angle) * radius)

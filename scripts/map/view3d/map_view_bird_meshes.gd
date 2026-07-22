class_name MapViewBirdMeshes
extends RefCounted

## Cached low-poly reference geometry for the P0-117 bird catalog. Meshes are
## intentionally static: future runtime wing animation or flight paths belong to
## P0-105 and can reuse these proportions without changing catalog semantics.

const BirdSpecies := preload("res://scripts/map/view3d/map_view_bird_species.gd")
const RADIAL_SEGMENTS := 6
const BODY_SEGMENTS := 8
const BODY_RINGS := 5

static var _mesh_cache: Dictionary = {}


static func mesh_for(species: StringName, pose: StringName = &"") -> ArrayMesh:
	var resolved_pose := BirdSpecies.default_pose(species) if pose.is_empty() else pose
	if not BirdSpecies.is_known_species(species) or not BirdSpecies.is_known_pose(resolved_pose):
		return null
	var cache_key := "%s:%s" % [species, resolved_pose]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]
	var mesh := _build_mesh(species, resolved_pose)
	_mesh_cache[cache_key] = mesh
	return mesh


static func reset_cache() -> void:
	_mesh_cache.clear()


static func geometry_stats(species: StringName, pose: StringName = &"") -> Dictionary:
	var mesh := mesh_for(species, pose)
	if mesh == null or mesh.get_surface_count() == 0:
		return {}
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	return {
		"vertices": vertices.size(),
		"triangles": vertices.size() / 3,
		"aabb": mesh.get_aabb(),
		"group": BirdSpecies.group_for(species),
		"pose": BirdSpecies.default_pose(species) if pose.is_empty() else pose,
	}


static func _build_mesh(species: StringName, pose: StringName) -> ArrayMesh:
	var geometry := BirdSpecies.geometry_for(species)
	var colors := BirdSpecies.colors_for(species)
	var body_dims: Vector3 = geometry["body"]
	var scale_factor := BirdSpecies.scale_m(species) / maxf(body_dims.x, 0.01)
	var body_radius := Vector3(body_dims.z, body_dims.y, body_dims.x) * scale_factor * 0.5
	var head_radius := float(geometry["head"]) * scale_factor
	var neck_length := float(geometry["neck"]) * scale_factor
	var leg_length := float(geometry["legs"]) * scale_factor
	var beak_length := float(geometry["beak"]) * scale_factor
	var wing_span := float(geometry["wing_span"]) * scale_factor
	var wing_chord := float(geometry["wing_chord"]) * scale_factor
	var tail_length := float(geometry["tail"]) * scale_factor

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	var body_center := Vector3(0.0, leg_length + body_radius.y * 1.05, 0.0)
	_append_ellipsoid(surface, body_center, body_radius, colors[0], BODY_SEGMENTS, BODY_RINGS)

	var neck_start := body_center + Vector3(0.0, body_radius.y * 0.38, -body_radius.z * 0.58)
	var neck_end := neck_start + Vector3(0.0, neck_length * 0.86, -neck_length * 0.28)
	if neck_length > 0.015:
		_append_tapered_tube(
			surface,
			neck_start,
			neck_end,
			maxf(head_radius * 0.54, body_radius.x * 0.22),
			maxf(head_radius * 0.40, body_radius.x * 0.16),
			colors[0].darkened(0.04),
			RADIAL_SEGMENTS
		)
	else:
		neck_end = neck_start

	var head_center := neck_end + Vector3(0.0, head_radius * 0.48, -head_radius * 0.18)
	_append_ellipsoid(
		surface,
		head_center,
		Vector3(head_radius * 0.88, head_radius, head_radius * 0.92),
		colors[1],
		7,
		4
	)
	_append_beak(surface, head_center, head_radius, beak_length, colors[2])
	_append_eyes(surface, head_center, head_radius)

	if pose == BirdSpecies.POSE_GLIDING:
		_append_extended_wings(surface, body_center, body_radius, wing_span, wing_chord, colors[1])
	else:
		_append_folded_wings(surface, body_center, body_radius, wing_chord, colors[1])

	_append_tail(
		surface,
		body_center,
		body_radius,
		tail_length,
		colors[1],
		BirdSpecies.group_for(species) in [BirdSpecies.GROUP_TERN, BirdSpecies.GROUP_SWALLOW]
	)
	_append_legs(surface, body_center, body_radius, leg_length, colors[2], pose)

	surface.generate_normals()
	return surface.commit()


static func _append_extended_wings(
	surface: SurfaceTool,
	body_center: Vector3,
	body_radius: Vector3,
	wing_span: float,
	wing_chord: float,
	color: Color
) -> void:
	var half_span := maxf(wing_span * 0.5, body_radius.x * 1.4)
	for side_sign in [-1.0, 1.0]:
		var shoulder := body_center + Vector3(side_sign * body_radius.x * 0.58, body_radius.y * 0.32, -body_radius.z * 0.08)
		var elbow := shoulder + Vector3(side_sign * half_span * 0.44, half_span * 0.05, -wing_chord * 0.05)
		var tip := shoulder + Vector3(side_sign * half_span, half_span * 0.10, wing_chord * 0.14)
		var rear_tip := tip + Vector3(-side_sign * half_span * 0.12, -half_span * 0.035, wing_chord * 0.30)
		var rear_elbow := elbow + Vector3(-side_sign * half_span * 0.05, -half_span * 0.025, wing_chord * 0.72)
		var rear_shoulder := shoulder + Vector3(0.0, -half_span * 0.015, body_radius.z * 0.82)
		_append_quad(surface, shoulder, elbow, rear_elbow, rear_shoulder, color)
		_append_quad(surface, elbow, tip, rear_tip, rear_elbow, color.darkened(0.05))
		# Three separated outer primaries keep raptors, gulls, and swallows from
		# reading as a single rectangular aircraft wing at gameplay scale.
		for feather_index in 3:
			var feather_t := float(feather_index) / 3.0
			var root := elbow.lerp(tip, 0.38 + feather_t * 0.34)
			var feather_tip := tip + Vector3(
				-side_sign * half_span * feather_t * 0.08,
				-half_span * feather_t * 0.015,
				wing_chord * (0.18 + feather_t * 0.20)
			)
			var width := maxf(wing_chord * 0.10, 0.012)
			_append_feather(surface, root, feather_tip, width, color.darkened(0.03 * float(feather_index)))


static func _append_folded_wings(
	surface: SurfaceTool,
	body_center: Vector3,
	body_radius: Vector3,
	wing_chord: float,
	color: Color
) -> void:
	var wing_length := maxf(body_radius.z * 1.48, wing_chord * 0.88)
	for side_sign in [-1.0, 1.0]:
		var shoulder := body_center + Vector3(side_sign * body_radius.x * 0.82, body_radius.y * 0.20, -body_radius.z * 0.34)
		var top := shoulder + Vector3(0.0, body_radius.y * 0.22, wing_length * 0.22)
		var tip := shoulder + Vector3(-side_sign * body_radius.x * 0.10, -body_radius.y * 0.32, wing_length)
		var lower := shoulder + Vector3(0.0, -body_radius.y * 0.45, wing_length * 0.34)
		_append_colored_triangle(surface, shoulder, top, tip, color)
		_append_colored_triangle(surface, shoulder, tip, lower, color.darkened(0.08))


static func _append_tail(
	surface: SurfaceTool,
	body_center: Vector3,
	body_radius: Vector3,
	tail_length: float,
	color: Color,
	forked: bool
) -> void:
	var root := body_center + Vector3(0.0, 0.0, body_radius.z * 0.78)
	var half_width := body_radius.x * 0.48
	if forked:
		for side_sign in [-1.0, 1.0]:
			var feather_root := root + Vector3(side_sign * half_width * 0.25, 0.0, 0.0)
			var tip := feather_root + Vector3(side_sign * half_width * 0.74, -body_radius.y * 0.16, tail_length)
			_append_feather(surface, feather_root, tip, maxf(half_width * 0.38, 0.012), color)
	else:
		var end := root + Vector3(0.0, -body_radius.y * 0.12, tail_length)
		_append_quad(
			surface,
			root + Vector3(-half_width, 0.0, 0.0),
			root + Vector3(half_width, 0.0, 0.0),
			end + Vector3(half_width * 0.58, 0.0, 0.0),
			end + Vector3(-half_width * 0.58, 0.0, 0.0),
			color
		)


static func _append_legs(
	surface: SurfaceTool,
	body_center: Vector3,
	body_radius: Vector3,
	leg_length: float,
	color: Color,
	pose: StringName
) -> void:
	if leg_length <= 0.01:
		return
	var top_y := body_center.y - body_radius.y * 0.56
	for side_sign in [-1.0, 1.0]:
		var top := Vector3(side_sign * body_radius.x * 0.31, top_y, body_center.z + body_radius.z * 0.08)
		var backward := leg_length * 0.18 if pose == BirdSpecies.POSE_PERCHED else 0.0
		var bottom := top + Vector3(0.0, -leg_length, backward)
		_append_tapered_tube(surface, top, bottom, maxf(leg_length * 0.035, 0.006), maxf(leg_length * 0.028, 0.004), color, 5)
		for toe_index in 3:
			var spread := float(toe_index - 1) * leg_length * 0.16
			var toe_end := bottom + Vector3(spread, -leg_length * 0.02, -leg_length * 0.22)
			_append_tapered_tube(surface, bottom, toe_end, maxf(leg_length * 0.018, 0.003), 0.002, color.darkened(0.08), 4)


static func _append_beak(
	surface: SurfaceTool,
	head_center: Vector3,
	head_radius: float,
	beak_length: float,
	color: Color
) -> void:
	var root := head_center + Vector3(0.0, -head_radius * 0.04, -head_radius * 0.76)
	var tip := root + Vector3(0.0, -beak_length * 0.08, -beak_length)
	_append_tapered_tube(
		surface,
		root,
		tip,
		maxf(head_radius * 0.28, 0.008),
		0.001,
		color,
		5
	)


static func _append_eyes(surface: SurfaceTool, head_center: Vector3, head_radius: float) -> void:
	for side_sign in [-1.0, 1.0]:
		var center := head_center + Vector3(side_sign * head_radius * 0.74, head_radius * 0.18, -head_radius * 0.36)
		_append_ellipsoid(surface, center, Vector3.ONE * maxf(head_radius * 0.075, 0.004), Color("151719"), 5, 3)


static func _append_ellipsoid(
	surface: SurfaceTool,
	center: Vector3,
	radius: Vector3,
	color: Color,
	segments: int,
	rings: int
) -> void:
	for ring_index in rings:
		var latitude_a := -PI * 0.5 + PI * float(ring_index) / float(rings)
		var latitude_b := -PI * 0.5 + PI * float(ring_index + 1) / float(rings)
		for segment_index in segments:
			var longitude_a := TAU * float(segment_index) / float(segments)
			var longitude_b := TAU * float(segment_index + 1) / float(segments)
			var a := center + _ellipsoid_point(radius, latitude_a, longitude_a)
			var b := center + _ellipsoid_point(radius, latitude_a, longitude_b)
			var c := center + _ellipsoid_point(radius, latitude_b, longitude_b)
			var d := center + _ellipsoid_point(radius, latitude_b, longitude_a)
			_append_colored_triangle(surface, a, b, c, color)
			_append_colored_triangle(surface, a, c, d, color)


static func _ellipsoid_point(radius: Vector3, latitude: float, longitude: float) -> Vector3:
	var latitude_cos := cos(latitude)
	return Vector3(
		radius.x * latitude_cos * cos(longitude),
		radius.y * sin(latitude),
		radius.z * latitude_cos * sin(longitude)
	)


static func _append_tapered_tube(
	surface: SurfaceTool,
	start: Vector3,
	end: Vector3,
	start_radius: float,
	end_radius: float,
	color: Color,
	segments: int
) -> void:
	var direction := end - start
	if direction.length_squared() < 0.000001:
		return
	var axis := direction.normalized()
	var tangent := axis.cross(Vector3.UP)
	if tangent.length_squared() < 0.0001:
		tangent = axis.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var bitangent := axis.cross(tangent).normalized()
	for segment_index in segments:
		var angle_a := TAU * float(segment_index) / float(segments)
		var angle_b := TAU * float(segment_index + 1) / float(segments)
		var radial_a := tangent * cos(angle_a) + bitangent * sin(angle_a)
		var radial_b := tangent * cos(angle_b) + bitangent * sin(angle_b)
		var a := start + radial_a * start_radius
		var b := start + radial_b * start_radius
		var c := end + radial_b * end_radius
		var d := end + radial_a * end_radius
		_append_colored_triangle(surface, a, b, c, color)
		_append_colored_triangle(surface, a, c, d, color.darkened(0.035))


static func _append_feather(
	surface: SurfaceTool,
	root: Vector3,
	tip: Vector3,
	half_width: float,
	color: Color
) -> void:
	var axis := (tip - root).normalized()
	var side := axis.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = axis.cross(Vector3.FORWARD)
	side = side.normalized()
	var middle := root.lerp(tip, 0.48)
	_append_colored_triangle(surface, root, middle + side * half_width, tip, color)
	_append_colored_triangle(surface, root, tip, middle - side * half_width, color.darkened(0.04))


static func _append_quad(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	color: Color
) -> void:
	_append_colored_triangle(surface, a, b, c, color)
	_append_colored_triangle(surface, a, c, d, color.darkened(0.025))


static func _append_colored_triangle(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	color: Color
) -> void:
	for vertex in [a, b, c]:
		surface.set_color(color)
		surface.add_vertex(vertex)

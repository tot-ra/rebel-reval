class_name MapViewMammalMeshes
extends RefCounted

## Cached low-poly reference geometry for the P0-118 mammal catalog. Meshes are
## static silhouettes only; runtime wander, tether, and flee behavior belong to
## P2-024 and P0-106.

const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")
const RADIAL_SEGMENTS := 6
const BODY_SEGMENTS := 8
const BODY_RINGS := 5

static var _mesh_cache: Dictionary = {}


static func mesh_for(species: StringName, pose: StringName = &"") -> ArrayMesh:
	var resolved_pose := MammalSpecies.default_pose(species) if pose.is_empty() else pose
	if not MammalSpecies.is_known_species(species) or not MammalSpecies.is_known_pose(resolved_pose):
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
		"group": MammalSpecies.group_for(species),
		"pose": MammalSpecies.default_pose(species) if pose.is_empty() else pose,
	}


static func _build_mesh(species: StringName, pose: StringName) -> ArrayMesh:
	var group := MammalSpecies.group_for(species)
	if group == MammalSpecies.GROUP_BAT:
		return _build_bat_mesh(species, pose)
	if group == MammalSpecies.GROUP_SEAL:
		return _build_seal_mesh(species, pose)
	if group == MammalSpecies.GROUP_FOWL:
		return _build_fowl_mesh(species, pose)

	var geometry := MammalSpecies.geometry_for(species)
	var colors := MammalSpecies.colors_for(species)
	var body_dims: Vector3 = geometry["body"]
	var scale_factor := MammalSpecies.scale_m(species) / maxf(body_dims.x, 0.01)
	var body_radius := Vector3(body_dims.z, body_dims.y, body_dims.x) * scale_factor * 0.5
	var head_radius := float(geometry["head"]) * scale_factor
	var neck_length := float(geometry["neck"]) * scale_factor
	var leg_length := float(geometry["legs"]) * scale_factor
	var tail_length := float(geometry["tail"]) * scale_factor
	var ear_size := float(geometry.get("ears", 0.0)) * scale_factor
	var horn_length := float(geometry.get("horns", 0.0)) * scale_factor

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	var body_pitch := 0.0
	var head_drop := 0.0
	var leg_scale := 1.0
	var body_drop := 0.0
	if pose == MammalSpecies.POSE_GRAZING:
		body_pitch = 0.22
		head_drop = body_radius.y * 0.72
	elif pose == MammalSpecies.POSE_RESTING:
		leg_scale = 0.42
		body_drop = body_radius.y * 0.28

	var body_center := Vector3(0.0, leg_length * leg_scale + body_radius.y * 0.92 - body_drop, 0.0)
	_append_ellipsoid(surface, body_center, body_radius, colors[0], BODY_SEGMENTS, BODY_RINGS)

	var neck_start := body_center + Vector3(0.0, body_radius.y * 0.18, -body_radius.z * 0.72)
	var neck_end := neck_start + Vector3(
		0.0,
		neck_length * 0.42 - head_drop,
		-neck_length * 0.86 - body_radius.z * 0.18 - body_radius.z * body_pitch
	)
	if neck_length > 0.01:
		_append_tapered_tube(
			surface,
			neck_start,
			neck_end,
			maxf(body_radius.x * 0.28, 0.008),
			maxf(head_radius * 0.62, 0.006),
			colors[0].darkened(0.04),
			RADIAL_SEGMENTS
		)
	else:
		neck_end = neck_start + Vector3(0.0, -head_drop, -body_radius.z * 0.42)

	var head_center := neck_end + Vector3(0.0, head_radius * 0.42, -head_radius * 0.62)
	_append_ellipsoid(
		surface,
		head_center,
		Vector3(head_radius * 0.92, head_radius, head_radius * 0.88),
		colors[1],
		7,
		4
	)
	_append_snout(surface, head_center, head_radius, colors[2], group)
	if ear_size > 0.01:
		_append_ears(surface, head_center, head_radius, ear_size, colors[1], group)
	if horn_length > 0.01:
		_append_horns(surface, head_center, head_radius, horn_length, colors[2])

	_append_quadruped_legs(surface, body_center, body_radius, leg_length * leg_scale, colors[2], pose)
	if tail_length > 0.01:
		_append_tail(surface, body_center, body_radius, tail_length, colors[1], group)

	surface.generate_normals()
	return surface.commit()


static func _build_bat_mesh(species: StringName, pose: StringName) -> ArrayMesh:
	var geometry := MammalSpecies.geometry_for(species)
	var colors := MammalSpecies.colors_for(species)
	var scale_factor := MammalSpecies.scale_m(species) / maxf(float(geometry["body"].x), 0.01)
	var body_dims: Vector3 = geometry["body"]
	var wing_span := float(geometry.get("wing_span", 0.34)) * scale_factor
	var body_radius := Vector3(body_dims.z, body_dims.y, body_dims.x) * scale_factor * 0.5

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(0.0, body_radius.y * 1.2, 0.0)
	_append_ellipsoid(surface, center, body_radius, colors[0], 6, 4)
	var head_center := center + Vector3(0.0, body_radius.y * 0.2, -body_radius.z * 0.9)
	_append_ellipsoid(surface, head_center, Vector3.ONE * body_radius.x * 0.72, colors[1], 5, 3)
	for side_sign in [-1.0, 1.0]:
		var shoulder := center + Vector3(side_sign * body_radius.x * 0.4, 0.0, 0.0)
		var tip := shoulder + Vector3(side_sign * wing_span * 0.5, -wing_span * 0.08, wing_span * 0.12)
		var rear := shoulder + Vector3(-side_sign * wing_span * 0.08, -wing_span * 0.04, -wing_span * 0.18)
		_append_quad(surface, shoulder, tip, rear, center, colors[1])
	if pose == MammalSpecies.POSE_RESTING:
		center.y -= body_radius.y * 0.35
	surface.generate_normals()
	return surface.commit()


static func _build_seal_mesh(species: StringName, pose: StringName) -> ArrayMesh:
	var geometry := MammalSpecies.geometry_for(species)
	var colors := MammalSpecies.colors_for(species)
	var scale_factor := MammalSpecies.scale_m(species) / maxf(float(geometry["body"].x), 0.01)
	var body_dims: Vector3 = geometry["body"]
	var body_radius := Vector3(body_dims.z, body_dims.y, body_dims.x) * scale_factor * 0.5
	var flipper_length := float(geometry["legs"]) * scale_factor

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center_y := body_radius.y * 0.55
	if pose != MammalSpecies.POSE_STANDING:
		center_y -= body_radius.y * 0.18
	var center := Vector3(0.0, center_y, 0.0)
	_append_ellipsoid(surface, center, body_radius, colors[0], BODY_SEGMENTS, BODY_RINGS)
	var head_center := center + Vector3(0.0, body_radius.y * 0.08, -body_radius.z * 0.92)
	_append_ellipsoid(surface, head_center, Vector3(body_radius.x * 0.42, body_radius.y * 0.36, body_radius.z * 0.38), colors[1], 6, 4)
	for side_sign in [-1.0, 1.0]:
		var root := center + Vector3(side_sign * body_radius.x * 0.72, -body_radius.y * 0.18, body_radius.z * 0.12)
		var tip := root + Vector3(side_sign * flipper_length * 0.42, -flipper_length * 0.08, flipper_length * 0.62)
		_append_tapered_tube(surface, root, tip, flipper_length * 0.08, flipper_length * 0.04, colors[2], 5)
	var tail_root := center + Vector3(0.0, 0.0, body_radius.z * 0.82)
	var tail_tip := tail_root + Vector3(0.0, -body_radius.y * 0.12, float(geometry["tail"]) * scale_factor)
	_append_tapered_tube(surface, tail_root, tail_tip, body_radius.x * 0.22, body_radius.x * 0.08, colors[1], 5)
	surface.generate_normals()
	return surface.commit()


static func _build_fowl_mesh(species: StringName, pose: StringName) -> ArrayMesh:
	var geometry := MammalSpecies.geometry_for(species)
	var colors := MammalSpecies.colors_for(species)
	var scale_factor := MammalSpecies.scale_m(species) / maxf(float(geometry["body"].x), 0.01)
	var body_dims: Vector3 = geometry["body"]
	var body_radius := Vector3(body_dims.z, body_dims.y, body_dims.x) * scale_factor * 0.5
	var head_radius := float(geometry["head"]) * scale_factor
	var neck_length := float(geometry["neck"]) * scale_factor
	var leg_length := float(geometry["legs"]) * scale_factor

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grazing_drop := head_radius * 0.42 if pose == MammalSpecies.POSE_GRAZING else 0.0
	var body_center := Vector3(0.0, leg_length + body_radius.y * 0.88, 0.0)
	_append_ellipsoid(surface, body_center, body_radius, colors[0], BODY_SEGMENTS, BODY_RINGS)
	var neck_start := body_center + Vector3(0.0, body_radius.y * 0.22 - grazing_drop, -body_radius.z * 0.62)
	var neck_end := neck_start + Vector3(0.0, neck_length * 0.42 - grazing_drop, -neck_length * 0.72)
	_append_tapered_tube(surface, neck_start, neck_end, body_radius.x * 0.22, head_radius * 0.55, colors[0], 5)
	var head_center := neck_end + Vector3(0.0, head_radius * 0.28, -head_radius * 0.72)
	_append_ellipsoid(surface, head_center, Vector3.ONE * head_radius, colors[1], 6, 4)
	_append_beak(surface, head_center, head_radius, colors[2])
	_append_quadruped_legs(surface, body_center, body_radius, leg_length, colors[2], pose, true)
	surface.generate_normals()
	return surface.commit()


static func _append_snout(
	surface: SurfaceTool,
	head_center: Vector3,
	head_radius: float,
	color: Color,
	group: StringName
) -> void:
	var length := head_radius * (0.42 if group == MammalSpecies.GROUP_SWINE else 0.28)
	var root := head_center + Vector3(0.0, -head_radius * 0.08, -head_radius * 0.82)
	var tip := root + Vector3(0.0, -length * 0.12, -length)
	_append_tapered_tube(surface, root, tip, head_radius * 0.24, head_radius * 0.08, color, 5)


static func _append_beak(surface: SurfaceTool, head_center: Vector3, head_radius: float, color: Color) -> void:
	var root := head_center + Vector3(0.0, -head_radius * 0.04, -head_radius * 0.78)
	var tip := root + Vector3(0.0, -head_radius * 0.08, -head_radius * 0.62)
	_append_tapered_tube(surface, root, tip, head_radius * 0.16, 0.002, color, 4)


static func _append_ears(
	surface: SurfaceTool,
	head_center: Vector3,
	head_radius: float,
	ear_size: float,
	color: Color,
	group: StringName
) -> void:
	for side_sign in [-1.0, 1.0]:
		var base := head_center + Vector3(side_sign * head_radius * 0.62, head_radius * 0.42, -head_radius * 0.12)
		if group == MammalSpecies.GROUP_LAGOMORPH:
			var tip := base + Vector3(side_sign * ear_size * 0.08, ear_size, -ear_size * 0.12)
			_append_tapered_tube(surface, base, tip, ear_size * 0.10, ear_size * 0.04, color, 4)
		else:
			var tip := base + Vector3(side_sign * ear_size * 0.22, ear_size * 0.72, -ear_size * 0.08)
			_append_tapered_tube(surface, base, tip, ear_size * 0.14, ear_size * 0.06, color, 4)


static func _append_horns(
	surface: SurfaceTool,
	head_center: Vector3,
	head_radius: float,
	horn_length: float,
	color: Color
) -> void:
	for side_sign in [-1.0, 1.0]:
		var base := head_center + Vector3(side_sign * head_radius * 0.34, head_radius * 0.62, -head_radius * 0.18)
		var tip := base + Vector3(side_sign * horn_length * 0.18, horn_length, horn_length * 0.08)
		_append_tapered_tube(surface, base, tip, horn_length * 0.05, horn_length * 0.02, color, 4)


static func _append_quadruped_legs(
	surface: SurfaceTool,
	body_center: Vector3,
	body_radius: Vector3,
	leg_length: float,
	color: Color,
	pose: StringName,
	bird_like: bool = false
) -> void:
	if leg_length <= 0.01:
		return
	var offsets: Array[Vector3] = [
		Vector3(-body_radius.x * 0.42, 0.0, -body_radius.z * 0.34),
		Vector3(body_radius.x * 0.42, 0.0, -body_radius.z * 0.34),
		Vector3(-body_radius.x * 0.42, 0.0, body_radius.z * 0.34),
		Vector3(body_radius.x * 0.42, 0.0, body_radius.z * 0.34),
	]
	for offset: Vector3 in offsets:
		var top: Vector3 = body_center + offset + Vector3(0.0, -body_radius.y * 0.42, 0.0)
		var bend := leg_length * 0.18 if pose == MammalSpecies.POSE_RESTING else 0.0
		var bottom: Vector3 = top + Vector3(0.0, -leg_length + bend, bend * 0.4)
		_append_tapered_tube(surface, top, bottom, leg_length * 0.05, leg_length * 0.035, color, 5)
		if bird_like:
			for toe_index in 3:
				var spread := float(toe_index - 1) * leg_length * 0.12
				var toe_end: Vector3 = bottom + Vector3(spread, -leg_length * 0.02, -leg_length * 0.16)
				_append_tapered_tube(surface, bottom, toe_end, leg_length * 0.016, 0.002, color.darkened(0.06), 4)


static func _append_tail(
	surface: SurfaceTool,
	body_center: Vector3,
	body_radius: Vector3,
	tail_length: float,
	color: Color,
	group: StringName
) -> void:
	var root := body_center + Vector3(0.0, 0.0, body_radius.z * 0.82)
	var tip := root + Vector3(0.0, body_radius.y * 0.08, tail_length)
	if group == MammalSpecies.GROUP_RODENT or group == MammalSpecies.GROUP_MUSTELID:
		_append_tapered_tube(surface, root, tip, body_radius.x * 0.12, body_radius.x * 0.04, color, 5)
	else:
		_append_quad(
			surface,
			root + Vector3(-body_radius.x * 0.18, 0.0, 0.0),
			root + Vector3(body_radius.x * 0.18, 0.0, 0.0),
			tip + Vector3(body_radius.x * 0.10, 0.0, 0.0),
			tip + Vector3(-body_radius.x * 0.10, 0.0, 0.0),
			color
		)


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

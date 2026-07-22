class_name MapViewAncientOakMeshes
extends RefCounted

## Landmark hingepuu / sacred-oak geometry for Sacred Grove.
## WHY: MultiMesh woodland oaks stay cheap and generic. The grove's soul-tree is a
## single authored landmark, so it can carry a thicker trunk, buttress roots, long
## primary limbs, deeper branching, and hanging moss without exploding draw calls.
## Scale is intentionally huge next to a player (~11 m trunk) but far below Avatar
## Hometree fantasy - a veteran oak shrine, not a floating mountain.

const WOOD_RADIAL_SEGMENTS := 7
const MAX_WOOD_SEGMENTS := 320
const MAX_LEAF_SPRAYS := 180
const MAX_MOSS_STRANDS := 48
const MIN_BRANCH_TIP_RADIUS := 0.012
const TRUNK_BASE_FLARE := 1.18
const TRUNK_TIP_RATIO := 0.22

static var _geometry_cache: Dictionary = {}


static func wood_mesh() -> ArrayMesh:
	return _geometry()["wood"] as ArrayMesh


static func canopy_mesh() -> ArrayMesh:
	return _geometry()["canopy"] as ArrayMesh


static func moss_mesh() -> ArrayMesh:
	return _geometry().get("moss") as ArrayMesh


static func geometry_stats() -> Dictionary:
	return (_geometry()["stats"] as Dictionary).duplicate()


static func reset_cache() -> void:
	_geometry_cache.clear()


static func _geometry() -> Dictionary:
	if not _geometry_cache.is_empty():
		return _geometry_cache
	var skeleton := _build_skeleton()
	var wood := _build_wood_mesh(skeleton)
	var canopy_data := _build_canopy_mesh(skeleton)
	var moss := _build_moss_mesh(skeleton)
	var stats := {
		"wood_segments": (skeleton["segments"] as Array).size(),
		"leaf_sprays": int(canopy_data["sprays"]),
		"leaf_count": int(canopy_data["leaf_count"]),
		"moss_strands": int(skeleton["moss_anchors"].size()),
		"trunk_height": float(skeleton["trunk_height"]),
		"trunk_base_radius": float(skeleton["trunk_base_radius"]),
		"root_buttresses": int(skeleton["root_count"]),
	}
	_geometry_cache = {
		"wood": wood,
		"canopy": canopy_data["mesh"],
		"moss": moss,
		"stats": stats,
	}
	return _geometry_cache


static func _build_skeleton() -> Dictionary:
	var segments: Array[Dictionary] = []
	var leaf_candidates: Array[Dictionary] = []
	var moss_anchors: Array[Dictionary] = []
	var species_seed := 1343 + 9041
	var trunk_height := 11.2
	var trunk_radius := 0.92
	var trunk_points: Array[Vector3] = [Vector3.ZERO]
	for section in 5:
		var section_t := float(section + 1) / 5.0
		# Gentle spiral lean keeps the trunk from reading as a telephone pole.
		var lean_x := sin(section_t * 1.7) * trunk_radius * 0.18 * section_t
		var lean_z := cos(section_t * 1.3) * trunk_radius * 0.14 * section_t
		trunk_points.append(Vector3(lean_x, trunk_height * section_t, lean_z))
	var trunk_radii: Array[float] = []
	for section in 6:
		trunk_radii.append(_trunk_radius_at_height(trunk_radius, float(section) / 5.0))
	for section in 5:
		_append_segment(
			segments,
			trunk_points[section],
			trunk_points[section + 1],
			trunk_radii[section],
			trunk_radii[section + 1],
			0
		)

	# Buttress roots flare outward so the base feels ancient and grounded.
	var root_count := 8
	for root_index in root_count:
		var yaw := float(root_index) * TAU / float(root_count) + 0.17
		var reach := trunk_radius * lerpf(2.4, 3.6, _hash(root_index, species_seed, 11))
		var height := trunk_radius * lerpf(1.35, 2.1, _hash(root_index, species_seed, 19))
		var start := Vector3(cos(yaw) * trunk_radius * 0.55, height * 0.55, sin(yaw) * trunk_radius * 0.55)
		var mid := Vector3(cos(yaw) * reach * 0.62, height * 0.22, sin(yaw) * reach * 0.62)
		var tip := Vector3(cos(yaw) * reach, 0.02, sin(yaw) * reach)
		var root_radius := trunk_radius * lerpf(0.42, 0.58, _hash(root_index, species_seed, 29))
		_append_segment(segments, start, mid, root_radius, root_radius * 0.55, 1)
		_append_segment(segments, mid, tip, root_radius * 0.55, root_radius * 0.18, 1)

	# Giant primary limbs: long, thick, and mostly horizontal like an old oak hall.
	var primary_count := 11
	var crown_start := 3.4
	var crown_end := 10.4
	for branch_index in primary_count:
		if segments.size() >= MAX_WOOD_SEGMENTS:
			break
		var t := (float(branch_index) + 0.28) / float(primary_count)
		var attach_y := lerpf(crown_start, crown_end, t)
		var yaw := float(branch_index) * 2.399963 + (_hash(branch_index, species_seed, 37) - 0.5) * 0.55
		# Lower limbs sweep widest; upper ones shorten into the crown dome.
		var length := lerpf(7.4, 3.6, t) * lerpf(0.92, 1.12, _hash(branch_index, species_seed, 41))
		var rise := lerpf(0.08, 0.42, t) + (_hash(branch_index, species_seed, 53) - 0.5) * 0.12
		var horizontal := sqrt(maxf(1.0 - rise * rise, 0.08))
		var direction := Vector3(cos(yaw) * horizontal, rise, sin(yaw) * horizontal).normalized()
		var lean := trunk_points[mini(5, trunk_points.size() - 1)]
		var start := Vector3(
			(lean.x / trunk_height) * attach_y,
			attach_y,
			(lean.z / trunk_height) * attach_y
		)
		var attach_t := clampf(attach_y / trunk_height, 0.0, 1.0)
		var local_trunk_radius := _trunk_radius_at_height(trunk_radius, attach_t)
		_grow_branch(
			segments,
			leaf_candidates,
			moss_anchors,
			start,
			direction,
			length,
			local_trunk_radius * lerpf(0.62, 0.34, t),
			3,
			species_seed + branch_index * 131,
			branch_index,
			true
		)

	leaf_candidates.append({
		"position": trunk_points[trunk_points.size() - 1],
		"direction": Vector3.UP,
		"seed": species_seed + 997,
	})
	return {
		"segments": segments,
		"leaf_candidates": leaf_candidates,
		"moss_anchors": moss_anchors,
		"trunk_height": trunk_height,
		"trunk_base_radius": trunk_radius * TRUNK_BASE_FLARE,
		"root_count": root_count,
	}


static func _grow_branch(
	segments: Array[Dictionary],
	leaf_candidates: Array[Dictionary],
	moss_anchors: Array[Dictionary],
	start: Vector3,
	direction: Vector3,
	length: float,
	radius: float,
	depth: int,
	seed: int,
	branch_index: int,
	is_primary: bool
) -> void:
	if segments.size() >= MAX_WOOD_SEGMENTS or length < 0.22:
		leaf_candidates.append({"position": start, "direction": direction, "seed": seed})
		return
	var side := _perpendicular(direction)
	var bend := (_hash(branch_index, seed, 67) - 0.5) * length * (0.18 if is_primary else 0.12)
	# Ancient oak limbs droop slightly at the tips without collapsing into willow.
	var droop := 0.16 if is_primary else 0.28
	var end_direction := (direction + side * bend - Vector3.UP * droop * (1.0 - float(depth) / 4.0)).normalized()
	var end := start + (direction * 0.52 + end_direction * 0.48).normalized() * length
	var end_radius := maxf(radius * 0.58, MIN_BRANCH_TIP_RADIUS)
	_append_segment(segments, start, end, radius, end_radius, 4 - depth)
	leaf_candidates.append({"position": end, "direction": end_direction, "seed": seed})
	if is_primary or depth >= 2:
		moss_anchors.append({"position": end, "direction": end_direction, "seed": seed + 17})
	if depth <= 0:
		return
	var child_count := 3 if is_primary and depth >= 3 else 2
	for child_index in child_count:
		if segments.size() >= MAX_WOOD_SEGMENTS:
			break
		var split_yaw := float(child_index) * (TAU / float(child_count)) + (_hash(child_index, seed, 79) - 0.5) * 0.7
		var split_angle := lerpf(0.55, 0.95, _hash(child_index, seed, 83))
		var child_direction := _split_direction(end_direction, split_yaw, split_angle)
		child_direction = (child_direction + Vector3.UP * 0.18).normalized()
		var child_length := length * lerpf(0.52, 0.72, _hash(child_index, seed, 97))
		_grow_branch(
			segments,
			leaf_candidates,
			moss_anchors,
			end - end_direction * length * (0.06 + child_index * 0.05),
			child_direction,
			child_length,
			end_radius,
			depth - 1,
			seed + 211 + child_index * 43,
			branch_index * 5 + child_index + 1,
			false
		)


static func _trunk_radius_at_height(base_radius: float, height_t: float) -> float:
	var t := clampf(height_t, 0.0, 1.0)
	return base_radius * lerpf(TRUNK_BASE_FLARE, TRUNK_TIP_RATIO, pow(t, 0.72))


static func _append_segment(
	segments: Array[Dictionary],
	start: Vector3,
	end: Vector3,
	start_radius: float,
	end_radius: float,
	depth: int
) -> void:
	if segments.size() >= MAX_WOOD_SEGMENTS:
		return
	segments.append({
		"start": start,
		"end": end,
		"start_radius": start_radius,
		"end_radius": end_radius,
		"depth": depth,
	})


static func _build_wood_mesh(skeleton: Dictionary) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments: Array = skeleton["segments"]
	for segment_index in segments.size():
		var segment: Dictionary = segments[segment_index]
		var depth := int(segment["depth"])
		var shade := 1.0 if depth == 0 else lerpf(0.82, 1.06, _hash(segment_index, depth, 313))
		var wood_color := Color(shade * 0.92, shade * 0.84, shade * 0.72)
		_append_tapered_tube(
			surface,
			segment["start"],
			segment["end"],
			float(segment["start_radius"]),
			float(segment["end_radius"]),
			wood_color
		)
	return surface.commit()


static func _build_canopy_mesh(skeleton: Dictionary) -> Dictionary:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var candidates: Array = skeleton["leaf_candidates"]
	var spray_count := mini(MAX_LEAF_SPRAYS, candidates.size())
	var leaves_per_spray := 11
	var leaf_count := 0
	for spray_index in spray_count:
		var candidate_index := int(floor(float(spray_index) * float(candidates.size()) / float(spray_count)))
		var candidate: Dictionary = candidates[candidate_index]
		var anchor: Vector3 = candidate["position"]
		var branch_direction: Vector3 = candidate["direction"]
		var seed := int(candidate["seed"])
		for leaf_index in leaves_per_spray:
			var yaw := TAU * float(leaf_index) / float(leaves_per_spray) + _hash(leaf_index, seed, 401) * 0.8
			var radial := _radial_around(branch_direction, yaw)
			var spread := lerpf(0.28, 0.72, _hash(leaf_index, seed, 409))
			var center := anchor + radial * spread + branch_direction * spread * 0.22
			var leaf_direction := (radial * 0.68 + branch_direction * 0.38 + Vector3.UP * 0.22).normalized()
			var leaf_length := lerpf(0.28, 0.48, _hash(leaf_index, seed, 419))
			var light := lerpf(0.74, 1.08, _hash(leaf_index, seed, 431))
			# Slightly cooler, deeper greens for a sacred-grove canopy.
			var color := Color(light * 0.62, light * 0.86, light * 0.58)
			_append_leaf(surface, center, leaf_direction, leaf_length, leaf_length * 0.58, color)
			leaf_count += 1
	return {"mesh": surface.commit(), "sprays": spray_count, "leaf_count": leaf_count}


static func _build_moss_mesh(skeleton: Dictionary) -> ArrayMesh:
	var anchors: Array = skeleton["moss_anchors"]
	var strand_count := mini(MAX_MOSS_STRANDS, anchors.size())
	if strand_count <= 0:
		return null
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for strand_index in strand_count:
		var anchor_index := int(floor(float(strand_index) * float(anchors.size()) / float(strand_count)))
		var anchor: Dictionary = anchors[anchor_index]
		var seed := int(anchor["seed"])
		var origin: Vector3 = anchor["position"]
		var hang := lerpf(1.1, 2.6, _hash(strand_index, seed, 503))
		var sway := (_hash(strand_index, seed, 509) - 0.5) * 0.35
		var tip := origin + Vector3(sway, -hang, sway * 0.7)
		var radius := lerpf(0.018, 0.034, _hash(strand_index, seed, 521))
		var moss_color := Color(0.34, 0.48, 0.30).lerp(Color(0.46, 0.58, 0.34), _hash(strand_index, seed, 541))
		_append_tapered_tube(surface, origin, tip, radius, radius * 0.35, moss_color)
		# Soft leaf tufts at the hanging tip sell the Avatar-like drapery without
		# inventing bioluminescence.
		for tuft_index in 4:
			var tuft_yaw := float(tuft_index) * 0.5 * PI + _hash(tuft_index, seed, 557)
			var tuft_dir := _radial_around(Vector3.DOWN, tuft_yaw) * 0.7 + Vector3.DOWN * 0.3
			_append_leaf(
				surface,
				tip + tuft_dir.normalized() * 0.08,
				tuft_dir.normalized(),
				0.22,
				0.10,
				moss_color.lightened(0.08)
			)
	return surface.commit()


static func _append_tapered_tube(
	surface: SurfaceTool,
	start: Vector3,
	end: Vector3,
	start_radius: float,
	end_radius: float,
	color: Color
) -> void:
	var axis := end - start
	if axis.length_squared() < 0.000001:
		return
	axis = axis.normalized()
	var side := _perpendicular(axis)
	var forward := axis.cross(side).normalized()
	for radial_index in WOOD_RADIAL_SEGMENTS:
		var next_index := (radial_index + 1) % WOOD_RADIAL_SEGMENTS
		var angle_a := TAU * float(radial_index) / float(WOOD_RADIAL_SEGMENTS)
		var angle_b := TAU * float(next_index) / float(WOOD_RADIAL_SEGMENTS)
		var normal_a := (side * cos(angle_a) + forward * sin(angle_a)).normalized()
		var normal_b := (side * cos(angle_b) + forward * sin(angle_b)).normalized()
		var a0 := start + normal_a * start_radius
		var b0 := start + normal_b * start_radius
		var a1 := end + normal_a * end_radius
		var b1 := end + normal_b * end_radius
		_append_colored_triangle(
			surface, a0, a1, b1, normal_a, normal_a, normal_b, color,
			Vector2(float(radial_index) / WOOD_RADIAL_SEGMENTS, 0.0),
			Vector2(float(radial_index) / WOOD_RADIAL_SEGMENTS, 1.0),
			Vector2(float(next_index) / WOOD_RADIAL_SEGMENTS, 1.0)
		)
		_append_colored_triangle(
			surface, a0, b1, b0, normal_a, normal_b, normal_b, color,
			Vector2(float(radial_index) / WOOD_RADIAL_SEGMENTS, 0.0),
			Vector2(float(next_index) / WOOD_RADIAL_SEGMENTS, 1.0),
			Vector2(float(next_index) / WOOD_RADIAL_SEGMENTS, 0.0)
		)


static func _append_leaf(
	surface: SurfaceTool,
	center: Vector3,
	direction: Vector3,
	length: float,
	width: float,
	color: Color
) -> void:
	var leaf_axis := direction.normalized()
	var side := _perpendicular(leaf_axis)
	var normal := side.cross(leaf_axis).normalized()
	var root := center - leaf_axis * length * 0.48
	var tip := center + leaf_axis * length * 0.52
	var left := center - side * width * 0.5
	var right := center + side * width * 0.5
	_append_colored_triangle(surface, root, right, tip, normal, normal, normal, color * 0.88, Vector2(0.5, 0.0), Vector2(1.0, 0.48), Vector2(0.5, 1.0))
	_append_colored_triangle(surface, root, tip, left, normal, normal, normal, color, Vector2(0.5, 0.0), Vector2(0.5, 1.0), Vector2(0.0, 0.48))


static func _append_colored_triangle(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	normal_a: Vector3,
	normal_b: Vector3,
	normal_c: Vector3,
	color: Color,
	uv_a: Vector2,
	uv_b: Vector2,
	uv_c: Vector2
) -> void:
	for vertex in [[a, normal_a, uv_a], [b, normal_b, uv_b], [c, normal_c, uv_c]]:
		surface.set_color(color)
		surface.set_normal(vertex[1])
		surface.set_uv(vertex[2])
		surface.add_vertex(vertex[0])


static func _split_direction(direction: Vector3, yaw: float, angle: float) -> Vector3:
	var radial := _radial_around(direction, yaw)
	return (direction * cos(angle) + radial * sin(angle)).normalized()


static func _radial_around(axis: Vector3, angle: float) -> Vector3:
	var side := _perpendicular(axis)
	var forward := axis.cross(side).normalized()
	return (side * cos(angle) + forward * sin(angle)).normalized()


static func _perpendicular(direction: Vector3) -> Vector3:
	var side := direction.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = direction.cross(Vector3.RIGHT)
	return side.normalized()


static func _hash(x: int, y: int, seed: int) -> float:
	return MapViewMeshBuilderMath.hash01(x, y, seed)

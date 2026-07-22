class_name MapViewAncientOakMeshes
extends RefCounted

## Landmark hingepuu / sacred-oak geometry for Sacred Grove.
## WHY: MultiMesh woodland oaks stay cheap and generic. The grove's soul-tree is a
## single authored landmark, so it can carry a thicker trunk, buttress roots, long
## primary limbs, deeper branching, and hanging moss without exploding draw calls.
## Scale is intentionally huge next to a player (~22 m trunk) but far below Avatar
## Hometree fantasy - a veteran oak shrine, not a floating mountain.

const LANDMARK_SCALE := 2.0
const WOOD_RADIAL_SEGMENTS := 9
const MAX_WOOD_SEGMENTS := 900
const MAX_LEAF_SPRAYS := 280
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
		"visual_trunk_height": float(skeleton["trunk_height"]) * LANDMARK_SCALE,
		"trunk_base_radius": float(skeleton["trunk_base_radius"]),
		"visual_trunk_base_radius": float(skeleton["trunk_base_radius"]) * LANDMARK_SCALE,
		"landmark_scale": LANDMARK_SCALE,
		"root_buttresses": int(skeleton["root_count"]),
		"trunk_path_sections": int(skeleton["trunk_path_sections"]),
		"leader_segments": int(skeleton["leader_segments"]),
		"terminal_branch_tips": int(skeleton["terminal_branch_tips"]),
		"curved_branch_paths": int(skeleton["growth_stats"].get("curved_branch_paths", 0)),
		"interior_branch_junctions": int(skeleton["growth_stats"].get("interior_branch_junctions", 0)),
		"primary_attachment_heights": (skeleton["primary_attachment_heights"] as Array).duplicate(),
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
	var growth_stats := {
		"curved_branch_paths": 0,
		"interior_branch_junctions": 0,
	}
	var species_seed := 1343 + 9041
	var trunk_height := 11.2
	var trunk_radius := 0.92
	var trunk_section_count := 9
	var trunk_points: Array[Vector3] = [Vector3.ZERO]
	for section in trunk_section_count:
		var section_t := float(section + 1) / float(trunk_section_count)
		# Wind and crown weight bend the whole leader. The quadratic drift makes the
		# upper trunk visibly off-axis without moving the ancient root flare.
		var wind_drift := Vector3(-0.42, 0.0, 0.26) * pow(section_t, 1.65)
		var lean_x := sin(section_t * 2.15) * trunk_radius * 0.16 * section_t
		var lean_z := cos(section_t * 1.55) * trunk_radius * 0.12 * section_t
		trunk_points.append(Vector3(lean_x, trunk_height * section_t, lean_z) + wind_drift)
	var trunk_radii: Array[float] = []
	for section in trunk_section_count + 1:
		trunk_radii.append(_trunk_radius_at_height(trunk_radius, float(section) / float(trunk_section_count)))
	for section in trunk_section_count:
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

	# Primary limbs keep a loose phyllotaxis, but broad seeded offsets prevent the
	# crown from reading as evenly spaced spokes or a staircase up the trunk.
	var primary_count := 12
	var crown_start := 3.4
	var crown_end := 10.4
	var primary_attachment_heights: Array[float] = []
	for branch_index in primary_count:
		if segments.size() >= MAX_WOOD_SEGMENTS:
			break
		var nominal_t := (float(branch_index) + 0.5) / float(primary_count)
		var t := clampf(
			nominal_t + (_hash(branch_index, species_seed, 31) - 0.5) * 0.82 / float(primary_count),
			0.02,
			0.98
		)
		var attach_y := lerpf(crown_start, crown_end, t)
		primary_attachment_heights.append(attach_y)
		var yaw := float(branch_index) * 2.399963 + (_hash(branch_index, species_seed, 37) - 0.5) * 1.18
		# Lower limbs sweep widest; upper ones shorten into the crown dome.
		var length := lerpf(7.4, 3.6, t) * lerpf(0.88, 1.16, _hash(branch_index, species_seed, 41))
		var rise := lerpf(0.04, 0.40, t) + (_hash(branch_index, species_seed, 53) - 0.5) * 0.24
		var horizontal := sqrt(maxf(1.0 - rise * rise, 0.08))
		var direction := Vector3(cos(yaw) * horizontal, rise, sin(yaw) * horizontal).normalized()
		var start := _point_on_path_at_height(trunk_points, attach_y)
		var attach_t := clampf(attach_y / trunk_height, 0.0, 1.0)
		var local_trunk_radius := _trunk_radius_at_height(trunk_radius, attach_t)
		_grow_branch(
			segments,
			leaf_candidates,
			moss_anchors,
			growth_stats,
			start,
			direction,
			length,
			local_trunk_radius * lerpf(0.62, 0.34, t),
			2,
			species_seed + branch_index * 131,
			branch_index,
			true
		)

	# Continue the trunk into a narrowing, wind-shaped crown leader. Growing it through
	# the same recursive branch path avoids the blunt sawn-off "pipe" silhouette.
	var leader_start := trunk_points[trunk_points.size() - 1]
	var leader_direction := (
		(trunk_points[trunk_points.size() - 1] - trunk_points[trunk_points.size() - 2]).normalized()
		+ Vector3(-0.22, 0.18, 0.13)
	).normalized()
	var leader_start_segment := segments.size()
	_grow_branch(
		segments,
		leaf_candidates,
		moss_anchors,
		growth_stats,
		leader_start,
		leader_direction,
		3.4,
		trunk_radii[trunk_radii.size() - 1] * 1.05,
		3,
		species_seed + 997,
		primary_count + 1,
		true
	)
	var leader_segments := segments.size() - leader_start_segment
	return {
		"segments": segments,
		"leaf_candidates": leaf_candidates,
		"moss_anchors": moss_anchors,
		"trunk_height": trunk_height,
		"trunk_base_radius": trunk_radius * TRUNK_BASE_FLARE,
		"root_count": root_count,
		"trunk_path_sections": trunk_section_count,
		"leader_segments": leader_segments,
		"terminal_branch_tips": leaf_candidates.size(),
		"growth_stats": growth_stats,
		"primary_attachment_heights": primary_attachment_heights,
	}


static func _grow_branch(
	segments: Array[Dictionary],
	leaf_candidates: Array[Dictionary],
	moss_anchors: Array[Dictionary],
	growth_stats: Dictionary,
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

	# A branch is a flowing path, not one rigid cylinder. Persistent curvature gives
	# each limb a readable sweep, while smaller per-section changes avoid sharp,
	# mechanically repeated elbows.
	var piece_count := 6 if is_primary else (4 if depth >= 2 else 3)
	var path_points: Array[Vector3] = [start]
	var path_directions: Array[Vector3] = [direction.normalized()]
	var path_radii: Array[float] = [radius]
	var current_position := start
	var current_direction := direction.normalized()
	var curve_axis := _radial_around(direction, TAU * _hash(branch_index, seed, 61))
	var curve_strength := lerpf(-0.20, 0.20, _hash(branch_index, seed, 67))
	var end_radius := maxf(radius * 0.58, MIN_BRANCH_TIP_RADIUS)
	for piece_index in piece_count:
		if segments.size() >= MAX_WOOD_SEGMENTS:
			break
		var piece_t := float(piece_index + 1) / float(piece_count)
		var meander := _radial_around(current_direction, TAU * _hash(piece_index, seed, 71))
		var meander_strength := lerpf(-0.07, 0.07, _hash(piece_index, seed, 73))
		# Old oak limbs rise from the collar, settle under their own weight, and then
		# turn toward open light. The blend produces a soft arc instead of fixed pitch.
		var vertical_flow := lerpf(0.08, -0.14 if is_primary else -0.20, piece_t)
		vertical_flow += (_hash(piece_index, seed, 76) - 0.5) * 0.08
		var target_direction := (
			current_direction * 0.82
			+ curve_axis * curve_strength
			+ meander * meander_strength
			+ Vector3.UP * vertical_flow
		).normalized()
		var next_direction := (current_direction * 0.52 + target_direction * 0.48).normalized()
		var section_length := length / float(piece_count) * lerpf(0.92, 1.08, _hash(piece_index, seed, 77))
		var next_position := current_position + (current_direction + next_direction).normalized() * section_length
		var next_radius := lerpf(radius, end_radius, pow(piece_t, 0.82))
		_append_segment(segments, current_position, next_position, path_radii[path_radii.size() - 1], next_radius, 4 - depth)
		current_position = next_position
		current_direction = next_direction
		path_points.append(current_position)
		path_directions.append(current_direction)
		path_radii.append(next_radius)

	if path_points.size() <= 1:
		leaf_candidates.append({"position": start, "direction": direction, "seed": seed})
		return
	growth_stats["curved_branch_paths"] = int(growth_stats["curved_branch_paths"]) + 1
	leaf_candidates.append({"position": current_position, "direction": current_direction, "seed": seed})
	# Interior foliage pads the crown around fork shoulders instead of leaving all
	# leaves at the outermost tips.
	if depth >= 1 and path_points.size() >= 4:
		var foliage_index := clampi(int(round(float(path_points.size() - 1) * 0.62)), 1, path_points.size() - 2)
		leaf_candidates.append({
			"position": path_points[foliage_index],
			"direction": path_directions[foliage_index],
			"seed": seed + 11,
		})
	if is_primary:
		# A second spray along the giant limb avoids concentrating every leaf at a fork.
		var shoulder_index := maxi(1, path_points.size() - 2)
		leaf_candidates.append({
			"position": path_points[shoulder_index],
			"direction": path_directions[shoulder_index],
			"seed": seed + 13,
		})
		moss_anchors.append({
			"position": path_points[shoulder_index],
			"direction": path_directions[shoulder_index],
			"seed": seed + 19,
		})
	if is_primary or depth >= 2:
		moss_anchors.append({"position": current_position, "direction": current_direction, "seed": seed + 17})
	if depth <= 0:
		return

	var child_count := 4 if is_primary and depth >= 3 else (3 if depth >= 2 else 2)
	for child_index in child_count:
		if segments.size() >= MAX_WOOD_SEGMENTS:
			break
		var continuation := child_index == 0
		var attach_t := lerpf(0.88, 0.98, _hash(child_index, seed, 79)) if continuation else lerpf(
			0.24 + 0.15 * float(child_index - 1),
			0.58 + 0.13 * float(child_index - 1),
			_hash(child_index, seed, 81)
		)
		var path_position := attach_t * float(path_points.size() - 1)
		var path_index := mini(int(floor(path_position)), path_points.size() - 2)
		var path_t := path_position - float(path_index)
		var child_start := path_points[path_index].lerp(path_points[path_index + 1], path_t)
		var parent_direction := path_directions[path_index].lerp(path_directions[path_index + 1], path_t).normalized()
		var parent_radius := lerpf(path_radii[path_index], path_radii[path_index + 1], path_t)
		if attach_t < 0.90:
			growth_stats["interior_branch_junctions"] = int(growth_stats["interior_branch_junctions"]) + 1
		var split_yaw := TAU * _hash(child_index, seed, 83) + (_hash(branch_index, seed, 89) - 0.5) * 0.55
		var split_angle := lerpf(0.12, 0.34, _hash(child_index, seed, 97)) if continuation else lerpf(
			0.40,
			1.02,
			_hash(child_index, seed, 101)
		)
		var child_direction := _split_direction(parent_direction, split_yaw, split_angle)
		child_direction = (child_direction + Vector3.UP * lerpf(0.04, 0.20, _hash(child_index, seed, 103))).normalized()
		var child_length := length * (lerpf(0.54, 0.68, _hash(child_index, seed, 107)) if continuation else lerpf(
			0.42,
			0.62,
			_hash(child_index, seed, 109)
		))
		var child_radius := parent_radius * (0.72 if continuation else lerpf(0.46, 0.62, _hash(child_index, seed, 113)))
		# A short overlapping collar softens the Y-junction. It deliberately sinks into
		# the parent wood so primary/secondary limbs do not look glued onto cylinders.
		_append_segment(
			segments,
			child_start - parent_direction * parent_radius * 0.20,
			child_start + child_direction * child_radius * 0.32,
			child_radius * 1.16,
			child_radius,
			4 - depth
		)
		_grow_branch(
			segments,
			leaf_candidates,
			moss_anchors,
			growth_stats,
			child_start,
			child_direction,
			child_length,
			maxf(child_radius, MIN_BRANCH_TIP_RADIUS),
			depth - 1,
			seed + 211 + child_index * 43,
			branch_index * 5 + child_index + 1,
			false
		)

static func _trunk_radius_at_height(base_radius: float, height_t: float) -> float:
	var t := clampf(height_t, 0.0, 1.0)
	return base_radius * lerpf(TRUNK_BASE_FLARE, TRUNK_TIP_RATIO, pow(t, 0.72))


static func _point_on_path_at_height(points: Array[Vector3], target_y: float) -> Vector3:
	for index in points.size() - 1:
		var start := points[index]
		var end := points[index + 1]
		if target_y <= end.y:
			var span := maxf(end.y - start.y, 0.0001)
			return start.lerp(end, clampf((target_y - start.y) / span, 0.0, 1.0))
	return points[points.size() - 1]


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
	var leaves_per_spray := 15
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
			var spread := lerpf(0.30, 0.84, _hash(leaf_index, seed, 409))
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

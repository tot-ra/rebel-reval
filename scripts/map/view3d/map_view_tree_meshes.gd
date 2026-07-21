class_name MapViewTreeMeshes
extends RefCounted

## Deterministic species-aware tree geometry. A compact recursive skeleton replaces
## disconnected canopy blobs: tapered branch tubes carry explicit leaf sprays at
## their tips. Geometry is generated once per species and then reused by MultiMesh,
## so additional botanical detail does not multiply node or draw-call counts.

const WOOD_RADIAL_SEGMENTS := 5
const MAX_WOOD_SEGMENTS := 52
const MAX_LEAF_SPRAYS := 34
const MAX_FRUIT_COUNT := 18

static var _geometry_cache: Dictionary = {}


static func wood_mesh(species: StringName) -> ArrayMesh:
	return _geometry_for(species)["wood"] as ArrayMesh


static func canopy_mesh(species: StringName) -> ArrayMesh:
	return _geometry_for(species)["canopy"] as ArrayMesh


static func fruit_mesh(species: StringName) -> ArrayMesh:
	return _geometry_for(species).get("fruit") as ArrayMesh


static func geometry_stats(species: StringName) -> Dictionary:
	return (_geometry_for(species)["stats"] as Dictionary).duplicate()


static func reset_cache() -> void:
	_geometry_cache.clear()


static func _geometry_for(species: StringName) -> Dictionary:
	if _geometry_cache.has(species):
		return _geometry_cache[species]
	var profile := _profile_for(species)
	var skeleton := _build_skeleton(species, profile)
	var wood := _build_wood_mesh(species, skeleton)
	var canopy_data := _build_canopy_mesh(species, profile, skeleton)
	var fruit := _build_fruit_mesh(species, profile, canopy_data["anchors"])
	var stats := {
		"wood_segments": (skeleton["segments"] as Array).size(),
		"leaf_sprays": int(canopy_data["sprays"]),
		"leaf_count": int(canopy_data["leaf_count"]),
		"fruit_count": int(canopy_data["fruit_count"]),
		"wood_triangles": int(skeleton["segments"].size()) * WOOD_RADIAL_SEGMENTS * 2,
		"canopy_triangles": int(canopy_data["leaf_count"]) * 2,
	}
	var geometry := {"wood": wood, "canopy": canopy_data["mesh"], "fruit": fruit, "stats": stats}
	_geometry_cache[species] = geometry
	return geometry


## Profiles encode botanical growth habits rather than finished meshes. The same
## bounded recursion can therefore produce a whorled spruce, drooping birch,
## spreading oak, columnar aspen, or low open orchard crown.
static func _profile_for(species: StringName) -> Dictionary:
	match species:
		&"spruce":
			return _profile(3.0, 0.20, 0.48, 2.55, 12, 1, 1.18, -0.10, 0.48, 0.48, 0.52, 0.08, 32, 7, 0.15, 0.22)
		&"pine":
			return _profile(2.85, 0.19, 1.42, 2.58, 8, 1, 1.08, 0.12, 0.58, 0.56, 0.54, 0.02, 28, 7, 0.17, 0.20)
		&"birch":
			return _profile(2.82, 0.135, 0.84, 2.48, 9, 1, 0.72, 0.34, 0.56, 0.55, 0.50, 0.24, 32, 5, 0.18, 0.46)
		&"oak":
			return _profile(2.28, 0.235, 0.76, 1.88, 6, 2, 0.98, 0.20, 0.62, 0.59, 0.58, 0.08, 34, 6, 0.21, 0.40)
		&"alder":
			return _profile(2.42, 0.18, 0.62, 2.04, 7, 2, 0.78, 0.31, 0.56, 0.57, 0.53, 0.13, 32, 6, 0.18, 0.34)
		&"aspen":
			return _profile(2.92, 0.145, 1.05, 2.63, 8, 1, 0.58, 0.48, 0.48, 0.53, 0.49, 0.05, 30, 5, 0.16, 0.36)
		&"maple":
			return _profile(2.38, 0.205, 0.72, 2.02, 7, 2, 0.88, 0.27, 0.60, 0.58, 0.56, 0.06, 34, 6, 0.20, 0.42)
		&"linden":
			return _profile(2.55, 0.185, 0.68, 2.20, 8, 1, 0.78, 0.38, 0.54, 0.55, 0.52, 0.08, 32, 6, 0.19, 0.38)
		&"apple":
			return _profile(1.82, 0.21, 0.50, 1.47, 6, 2, 0.78, 0.18, 0.67, 0.61, 0.60, 0.12, 32, 6, 0.19, 0.44, 14)
		&"cherry":
			return _profile(2.02, 0.17, 0.58, 1.72, 7, 2, 0.72, 0.36, 0.62, 0.59, 0.57, 0.08, 32, 5, 0.17, 0.42, 18)
		_:
			return _profile(2.38, 0.19, 0.72, 2.02, 7, 2, 0.84, 0.28, 0.58, 0.58, 0.55, 0.08, 32, 6, 0.19, 0.40)


static func _profile(
	trunk_height: float,
	trunk_radius: float,
	crown_start: float,
	crown_end: float,
	primary_count: int,
	depth: int,
	primary_length: float,
	branch_rise: float,
	split_angle: float,
	length_decay: float,
	radius_decay: float,
	droop: float,
	leaf_sprays: int,
	leaves_per_spray: int,
	leaf_length: float,
	leaf_spread: float,
	fruit_count: int = 0
) -> Dictionary:
	return {
		"trunk_height": trunk_height,
		"trunk_radius": trunk_radius,
		"crown_start": crown_start,
		"crown_end": crown_end,
		"primary_count": primary_count,
		"depth": depth,
		"primary_length": primary_length,
		"branch_rise": branch_rise,
		"split_angle": split_angle,
		"length_decay": length_decay,
		"radius_decay": radius_decay,
		"droop": droop,
		"leaf_sprays": mini(leaf_sprays, MAX_LEAF_SPRAYS),
		"leaves_per_spray": leaves_per_spray,
		"leaf_length": leaf_length,
		"leaf_spread": leaf_spread,
		"fruit_count": mini(fruit_count, MAX_FRUIT_COUNT),
	}


static func _build_skeleton(species: StringName, profile: Dictionary) -> Dictionary:
	var segments: Array[Dictionary] = []
	var leaf_candidates: Array[Dictionary] = []
	var trunk_height := float(profile["trunk_height"])
	var trunk_radius := float(profile["trunk_radius"])
	var species_seed := absi(String(species).hash()) + 1709
	var trunk_points: Array[Vector3] = [Vector3.ZERO]
	for section in 3:
		var section_t := float(section + 1) / 3.0
		var lean_x := (_hash(section, species_seed, 11) - 0.5) * trunk_radius * section_t
		var lean_z := (_hash(section, species_seed, 23) - 0.5) * trunk_radius * section_t
		trunk_points.append(Vector3(lean_x, trunk_height * section_t, lean_z))
	for section in 3:
		_append_segment(
			segments,
			trunk_points[section],
			trunk_points[section + 1],
			trunk_radius * lerpf(1.12, 0.72, float(section) / 3.0),
			trunk_radius * lerpf(0.92, 0.48, float(section + 1) / 3.0),
			0
		)

	var primary_count := int(profile["primary_count"])
	var crown_start := float(profile["crown_start"])
	var crown_end := float(profile["crown_end"])
	for branch_index in primary_count:
		if segments.size() >= MAX_WOOD_SEGMENTS:
			break
		var t := (float(branch_index) + 0.35) / float(primary_count)
		var attach_y := lerpf(crown_start, crown_end, t)
		var yaw := float(branch_index) * 2.399963 + (_hash(branch_index, species_seed, 37) - 0.5) * 0.46
		var envelope := _crown_envelope(species, t)
		var length := float(profile["primary_length"]) * envelope * lerpf(
			0.86,
			1.12,
			_hash(branch_index, species_seed, 41)
		)
		var rise := float(profile["branch_rise"]) + (_hash(branch_index, species_seed, 53) - 0.5) * 0.16
		var horizontal := sqrt(maxf(1.0 - rise * rise, 0.05))
		var direction := Vector3(cos(yaw) * horizontal, rise, sin(yaw) * horizontal).normalized()
		var start := Vector3(
			(trunk_points[3].x / trunk_height) * attach_y,
			attach_y,
			(trunk_points[3].z / trunk_height) * attach_y
		)
		_grow_branch(
			segments,
			leaf_candidates,
			start,
			direction,
			length,
			trunk_radius * lerpf(0.42, 0.20, t),
			int(profile["depth"]),
			profile,
			species_seed + branch_index * 101,
			branch_index
		)

	# The leader tip closes columnar and conifer crowns without a spherical cap.
	leaf_candidates.append({"position": trunk_points[3], "direction": Vector3.UP, "seed": species_seed + 997})
	return {"segments": segments, "leaf_candidates": leaf_candidates}


static func _grow_branch(
	segments: Array[Dictionary],
	leaf_candidates: Array[Dictionary],
	start: Vector3,
	direction: Vector3,
	length: float,
	radius: float,
	depth: int,
	profile: Dictionary,
	seed: int,
	branch_index: int
) -> void:
	if segments.size() >= MAX_WOOD_SEGMENTS or length < 0.10:
		leaf_candidates.append({"position": start, "direction": direction, "seed": seed})
		return
	var side := _perpendicular(direction)
	var bend := (_hash(branch_index, seed, 67) - 0.5) * length * 0.12
	var droop := float(profile["droop"]) * lerpf(0.3, 1.0, 1.0 - float(depth) / 3.0)
	var end_direction := (direction + side * bend - Vector3.UP * droop).normalized()
	var end := start + (direction * 0.56 + end_direction * 0.44).normalized() * length
	var end_radius := maxf(radius * float(profile["radius_decay"]), 0.012)
	_append_segment(segments, start, end, radius, end_radius, depth + 1)
	leaf_candidates.append({"position": end, "direction": end_direction, "seed": seed})
	if depth <= 0:
		return
	for child_index in 2:
		if segments.size() >= MAX_WOOD_SEGMENTS:
			break
		var split_yaw := float(child_index) * PI + (_hash(child_index, seed, 79) - 0.5) * 0.65
		var split_angle := float(profile["split_angle"]) * lerpf(0.84, 1.14, _hash(child_index, seed, 83))
		var child_direction := _split_direction(end_direction, split_yaw, split_angle)
		# Deciduous branchlets seek light; spruce tips stay flatter and birch tips
		# are allowed to droop through the profile's stronger gravity term.
		child_direction = (child_direction + Vector3.UP * float(profile["branch_rise"]) * 0.28).normalized()
		var child_length := length * float(profile["length_decay"]) * lerpf(
			0.88,
			1.10,
			_hash(child_index, seed, 97)
		)
		_grow_branch(
			segments,
			leaf_candidates,
			end - end_direction * length * (0.08 + child_index * 0.07),
			child_direction,
			child_length,
			end_radius,
			depth - 1,
			profile,
			seed + 211 + child_index * 43,
			branch_index * 3 + child_index + 1
		)


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


static func _build_wood_mesh(species: StringName, skeleton: Dictionary) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments: Array = skeleton["segments"]
	for segment_index in segments.size():
		var segment: Dictionary = segments[segment_index]
		var depth := int(segment["depth"])
		var shade := 1.0 if depth == 0 else lerpf(0.84, 1.08, _hash(segment_index, depth, 313))
		var wood_color := Color(shade, shade * 0.98, shade * 0.94)
		_append_tapered_tube(
			surface,
			segment["start"],
			segment["end"],
			float(segment["start_radius"]),
			float(segment["end_radius"]),
			wood_color
		)
	return surface.commit()


static func _build_canopy_mesh(species: StringName, profile: Dictionary, skeleton: Dictionary) -> Dictionary:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var candidates: Array = skeleton["leaf_candidates"]
	var spray_count := mini(int(profile["leaf_sprays"]), candidates.size())
	var leaves_per_spray := int(profile["leaves_per_spray"])
	var leaf_count := 0
	var used_anchors: Array[Dictionary] = []
	for spray_index in spray_count:
		# Striding distributes foliage over the full recursion instead of filling
		# the first generated side of the crown when a profile hits its budget.
		var candidate_index := int(floor(float(spray_index) * float(candidates.size()) / float(spray_count)))
		var candidate: Dictionary = candidates[candidate_index]
		used_anchors.append(candidate)
		var anchor: Vector3 = candidate["position"]
		var branch_direction: Vector3 = candidate["direction"]
		var seed := int(candidate["seed"])
		for leaf_index in leaves_per_spray:
			var yaw := TAU * float(leaf_index) / float(leaves_per_spray) + _hash(leaf_index, seed, 401) * 0.72
			var radial := _radial_around(branch_direction, yaw)
			var spread := float(profile["leaf_spread"]) * lerpf(0.62, 1.08, _hash(leaf_index, seed, 409))
			var center := anchor + radial * spread + branch_direction * spread * 0.28
			var leaf_direction := (radial * 0.72 + branch_direction * 0.42 + Vector3.UP * 0.20).normalized()
			var leaf_length := float(profile["leaf_length"]) * lerpf(0.72, 1.16, _hash(leaf_index, seed, 419))
			var width_ratio := 0.16 if species in [&"spruce", &"pine"] else 0.52
			var light := lerpf(0.78, 1.12, _hash(leaf_index, seed, 431))
			var color := _leaf_vertex_color(species, light)
			_append_leaf(surface, center, leaf_direction, leaf_length, leaf_length * width_ratio, color)
			leaf_count += 1
	var fruit_count := mini(int(profile["fruit_count"]), used_anchors.size())
	return {
		"mesh": surface.commit(),
		"sprays": spray_count,
		"leaf_count": leaf_count,
		"fruit_count": fruit_count,
		"anchors": used_anchors,
	}


static func _build_fruit_mesh(species: StringName, profile: Dictionary, anchors: Array) -> ArrayMesh:
	var count := mini(int(profile["fruit_count"]), anchors.size())
	if count <= 0:
		return null
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for fruit_index in count:
		var anchor_index := posmod(fruit_index * 5 + 2, anchors.size())
		var anchor: Dictionary = anchors[anchor_index]
		var seed := int(anchor["seed"])
		var position: Vector3 = anchor["position"]
		var direction: Vector3 = anchor["direction"]
		var side := _radial_around(direction, _hash(fruit_index, seed, 449) * TAU)
		position += side * 0.10 + Vector3.DOWN * (0.07 + _hash(fruit_index, seed, 457) * 0.08)
		if species == &"cherry":
			_append_octahedron(surface, position, 0.038, Color(0.62, 0.035, 0.045))
			_append_octahedron(surface, position + side * 0.065 + Vector3.DOWN * 0.025, 0.035, Color(0.82, 0.055, 0.07))
		else:
			var apple_color := Color(0.76, 0.10, 0.055).lerp(Color(0.66, 0.72, 0.10), _hash(fruit_index, seed, 461) * 0.46)
			_append_octahedron(surface, position, 0.065, apple_color)
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
		_append_colored_triangle(surface, a0, a1, b1, normal_a, normal_a, normal_b, color, Vector2(float(radial_index) / WOOD_RADIAL_SEGMENTS, 0.0), Vector2(float(radial_index) / WOOD_RADIAL_SEGMENTS, 1.0), Vector2(float(next_index) / WOOD_RADIAL_SEGMENTS, 1.0))
		_append_colored_triangle(surface, a0, b1, b0, normal_a, normal_b, normal_b, color, Vector2(float(radial_index) / WOOD_RADIAL_SEGMENTS, 0.0), Vector2(float(next_index) / WOOD_RADIAL_SEGMENTS, 1.0), Vector2(float(next_index) / WOOD_RADIAL_SEGMENTS, 0.0))


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
	_append_colored_triangle(surface, root, right, tip, normal, normal, normal, color * 0.86, Vector2(0.5, 0.0), Vector2(1.0, 0.48), Vector2(0.5, 1.0))
	_append_colored_triangle(surface, root, tip, left, normal, normal, normal, color, Vector2(0.5, 0.0), Vector2(0.5, 1.0), Vector2(0.0, 0.48))


static func _append_octahedron(surface: SurfaceTool, center: Vector3, radius: float, color: Color) -> void:
	var points := [
		center + Vector3.UP * radius,
		center + Vector3.DOWN * radius,
		center + Vector3.RIGHT * radius,
		center + Vector3.LEFT * radius,
		center + Vector3.FORWARD * radius,
		center + Vector3.BACK * radius,
	]
	for triangle in [[0, 2, 4], [0, 5, 2], [0, 3, 5], [0, 4, 3], [1, 4, 2], [1, 2, 5], [1, 5, 3], [1, 3, 4]]:
		var a: Vector3 = points[triangle[0]]
		var b: Vector3 = points[triangle[1]]
		var c: Vector3 = points[triangle[2]]
		var normal := (b - a).cross(c - a).normalized()
		_append_colored_triangle(surface, a, b, c, normal, normal, normal, color, Vector2.ZERO, Vector2.RIGHT, Vector2.UP)


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


static func _crown_envelope(species: StringName, t: float) -> float:
	match species:
		&"spruce":
			return lerpf(1.15, 0.30, t)
		&"pine":
			return lerpf(0.66, 1.05, sin(t * PI * 0.72))
		&"birch", &"aspen":
			return 0.54 + sin(t * PI) * 0.42
		&"linden":
			return lerpf(1.0, 0.42, t) + sin(t * PI) * 0.16
		&"apple", &"cherry":
			return 0.80 + sin(t * PI) * 0.25
		_:
			return 0.68 + sin(t * PI) * 0.46


static func _leaf_vertex_color(species: StringName, light: float) -> Color:
	match species:
		&"spruce":
			return Color(light * 0.62, light * 0.84, light * 0.72)
		&"pine":
			return Color(light * 0.72, light * 0.90, light * 0.58)
		&"birch":
			return Color(light * 0.94, light, light * 0.68)
		&"alder":
			return Color(light * 0.76, light * 0.94, light * 0.72)
		&"aspen":
			return Color(light * 0.96, light, light * 0.66)
		&"apple":
			return Color(light * 0.74, light * 0.94, light * 0.62)
		&"cherry":
			return Color(light * 0.88, light * 0.96, light * 0.68)
		_:
			return Color(light * 0.88, light, light * 0.70)


static func _hash(x: int, y: int, seed: int) -> float:
	return MapViewMeshBuilderMath.hash01(x, y, seed)

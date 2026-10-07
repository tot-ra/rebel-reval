class_name MapViewTreeMeshes
extends RefCounted

## Deterministic species-aware tree geometry. A compact recursive skeleton replaces
## disconnected canopy blobs: tapered branch tubes carry explicit leaf sprays at
## their tips. Geometry is generated once per species and then reused by MultiMesh,
## so additional botanical detail does not multiply node or draw-call counts.
## Growth lives in MapViewTreeMeshSkeleton; species tuning in MapViewTreeMeshProfiles.

const LeafGeometry := preload("res://scripts/map/view3d/map_view_leaf_geometry.gd")
const TreeMeshProfiles := preload("res://scripts/map/view3d/map_view_tree_mesh_profiles.gd")
const TreeMeshSkeleton := preload("res://scripts/map/view3d/map_view_tree_mesh_skeleton.gd")

const WOOD_RADIAL_SEGMENTS := 5
const MAX_WOOD_SEGMENTS := TreeMeshSkeleton.MAX_WOOD_SEGMENTS
const MAX_LEAF_SPRAYS := 110
const MAX_FRUIT_COUNT := 18
const CONIFERS: Array[StringName] = [&"spruce", &"pine", &"juniper"]
## R-1194 cluster cards. Card edge length relative to the profile leaf length:
## one card holds a whole twig cluster of 7-12 leaves (or a needle fan).
# Cards were 3.4x / 3.8x the leaf length; against a human that read as head-sized
# leaves. Smaller cards, one more per tip, keep crown mass with believable leaves.
const CARD_SCALE := 2.3
const CONIFER_CARD_SCALE := 2.0
const CARDS_PER_TIP := 4
const CONIFER_CARDS_PER_TIP := 3
## Conifer needle fans: smaller than the old 3.0 scale (they read as flat plates)
## and pointed in many roll angles, with normals pulled toward the crown shell so
## light wraps around the tree instead of washing flat up-facing fans white.
const CONIFER_TRUNK_FAN_SCALE := 0.62
const CONIFER_NORMAL_OUTWARD := 0.85
## Conifers keep only a couple of folded needle shoots per spray (28 triangles
## each) as close-up detail; dense whorl cards replace the rest.
const CONIFER_FOLDED_SHOOTS := 2

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
	var profile := TreeMeshProfiles.profile_for(species)
	var skeleton := TreeMeshSkeleton.build(species, profile)
	var wood := _build_wood_mesh(species, skeleton)
	var canopy_data := _build_canopy_mesh(species, profile, skeleton)
	var fruit := _build_fruit_mesh(species, profile, canopy_data["anchors"])
	var stats := {
		"wood_segments": (skeleton["segments"] as Array).size(),
		"leaf_sprays": int(canopy_data["sprays"]),
		"leaf_count": int(canopy_data["leaf_count"]),
		"card_count": int(canopy_data["card_count"]),
		"fruit_count": int(canopy_data["fruit_count"]),
		"wood_triangles": int(skeleton["segments"].size()) * WOOD_RADIAL_SEGMENTS * 2,
		"canopy_triangles": (canopy_data["mesh"] as ArrayMesh).surface_get_array_len(0) / 3,
		"trunk_radii": (skeleton["trunk_radii"] as Array).duplicate(),
		"trunk_height": float(profile["trunk_height"]),
		"curved_branch_paths": int(skeleton["growth_stats"].get("curved_branch_paths", 0)),
		"interior_branch_junctions":
		int(skeleton["growth_stats"].get("interior_branch_junctions", 0)),
		"primary_attachment_heights": (skeleton["primary_attachment_heights"] as Array).duplicate(),
	}
	var geometry := {"wood": wood, "canopy": canopy_data["mesh"], "fruit": fruit, "stats": stats}
	_geometry_cache[species] = geometry
	return geometry


static func _build_wood_mesh(_species: StringName, skeleton: Dictionary) -> ArrayMesh:
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


static func _build_canopy_mesh(
	species: StringName, profile: Dictionary, skeleton: Dictionary
) -> Dictionary:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# CUSTOM0 carries petiole + per-leaf seed for seasonal leaf density, size and
	# autumn hue (see MapViewLeafGeometry.append_leaf and map_view_canopy.gdshader).
	surface.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var candidates: Array = skeleton["leaf_candidates"]
	var spray_count := mini(int(profile["leaf_sprays"]), candidates.size())
	var leaves_per_spray := int(profile["leaves_per_spray"])
	if species in CONIFERS:
		leaves_per_spray = mini(leaves_per_spray, CONIFER_FOLDED_SHOOTS)
	var leaf_count := 0
	var used_anchors: Array[Dictionary] = []
	var crown := _crown_bounds(candidates)
	for spray_index in spray_count:
		# Striding distributes foliage over the full recursion instead of filling
		# the first generated side of the crown when a profile hits its budget.
		var candidate_index := int(
			floor(float(spray_index) * float(candidates.size()) / float(spray_count))
		)
		var candidate: Dictionary = candidates[candidate_index]
		used_anchors.append(candidate)
		var anchor: Vector3 = candidate["position"]
		var branch_direction: Vector3 = candidate["direction"]
		var seed := int(candidate["seed"])
		for leaf_index in leaves_per_spray:
			var yaw := (
				TAU * float(leaf_index) / float(leaves_per_spray)
				+ _hash(leaf_index, seed, 401) * 0.72
			)
			var radial := TreeMeshSkeleton.radial_around(branch_direction, yaw)
			var spread := (
				float(profile["leaf_spread"]) * lerpf(0.62, 1.08, _hash(leaf_index, seed, 409))
			)
			var center := anchor + radial * spread + branch_direction * spread * 0.28
			var leaf_direction := (
				(radial * 0.72 + branch_direction * 0.42 + Vector3.UP * 0.20).normalized()
			)
			var leaf_length := (
				float(profile["leaf_length"]) * lerpf(0.72, 1.16, _hash(leaf_index, seed, 419))
			)
			var width_ratio := 0.16 if species in [&"spruce", &"pine", &"juniper"] else 0.60
			if species in [&"willow", &"ash", &"rowan"]:
				width_ratio = 0.26
			var light := lerpf(0.78, 1.12, _hash(leaf_index, seed, 431))
			var color := _leaf_vertex_color(species, light)
			# Alpha is crown self-occlusion: inner and underside leaves receive
			# less sky light. Instance tints keep alpha 1, so the product survives.
			color.a = _crown_occlusion(center, crown)
			LeafGeometry.append_leaf(
				surface,
				species,
				center,
				leaf_direction,
				leaf_length,
				leaf_length * width_ratio,
				color,
				_hash(leaf_index, seed, 467)
			)
			leaf_count += 1
	var card_count := _append_cluster_cards(surface, species, profile, skeleton, crown)
	var fruit_count := mini(int(profile["fruit_count"]), used_anchors.size())
	return {
		"mesh": surface.commit(),
		"sprays": spray_count,
		"leaf_count": leaf_count,
		"card_count": card_count,
		"fruit_count": fruit_count,
		"anchors": used_anchors,
	}


## R-1194: alpha-scissor leaf-cluster cards give the crown its mass. Every
## branch tip (not only the strided folded-leaf sprays) gets a small fan of
## cards; conifers also get flat needle fans along each branch and around the
## upper trunk so whorls read full instead of skeletal. Each card keeps its own
## seed, so seasonal density, autumn hue and fall order stay per cluster.
static func _append_cluster_cards(
	surface: SurfaceTool,
	species: StringName,
	profile: Dictionary,
	skeleton: Dictionary,
	crown: AABB
) -> int:
	var conifer := species in CONIFERS
	var length := float(profile["leaf_length"]) * (CONIFER_CARD_SCALE if conifer else CARD_SCALE)
	var per_tip := CONIFER_CARDS_PER_TIP if conifer else CARDS_PER_TIP
	var spread := float(profile["leaf_spread"])
	var cards := 0
	for candidate: Dictionary in skeleton["leaf_candidates"]:
		var anchor: Vector3 = candidate["position"]
		var direction: Vector3 = candidate["direction"]
		var seed := int(candidate["seed"])
		for card_index in per_tip:
			var yaw := TAU * (float(card_index) + _hash(card_index, seed, 503) * 0.6) / float(per_tip)
			var radial := TreeMeshSkeleton.radial_around(direction, yaw)
			var axis := (direction * 0.55 + radial * 0.75 + Vector3.UP * 0.15).normalized()
			var size := length * lerpf(0.78, 1.15, _hash(card_index, seed, 509))
			var base := anchor - axis * size * 0.18 + radial * spread * 0.25
			var facing := (Vector3.UP * 0.7 + radial * 0.5).normalized()
			_emit_card(surface, species, base, axis, facing, size, crown, seed, card_index)
			cards += 1
	if not conifer:
		return cards
	var segments: Array = skeleton["segments"]
	for segment_index in segments.size():
		var segment: Dictionary = segments[segment_index]
		var start: Vector3 = segment["start"]
		var end: Vector3 = segment["end"]
		var run := end - start
		if run.length() < 0.02:
			continue
		var steps := maxi(1, ceili(run.length() / (length * 0.42)))
		for step in steps:
			var t := (float(step) + 0.5) / float(steps)
			var station := start.lerp(end, t)
			var seed := segment_index * 131 + step * 7
			if int(segment["depth"]) == 0:
				cards += _append_trunk_ring(
					surface, species, profile, station, crown, length, seed, step
				)
				continue
			# Branch: three fans rolled around the branch axis (about 120 degrees
			# apart, random phase) so the whorl has volume from every side, not
			# just a pair of up-facing plates.
			var forward := run.normalized()
			var side := TreeMeshSkeleton.perpendicular(forward)
			var up_side := forward.cross(side).normalized()
			var base := station - forward * length * 0.35
			var phase := _hash(step, seed, 541) * TAU
			for roll_index in 3:
				var roll := phase + float(roll_index) * TAU / 3.0
				var spoke := side * cos(roll) + up_side * sin(roll)
				var fan_axis := (forward + Vector3.DOWN * 0.10 + spoke * 0.55).normalized()
				_emit_card(
					surface, species, base, fan_axis, spoke, length * (1.0 - 0.1 * roll_index),
					crown, seed, roll_index
				)
			cards += 3
	return cards


## A ring of drooping fans around the bole inside a conifer crown. Spruce and
## juniper fans shrink with height so the needles close into a cone; pine keeps
## short fans because its crown is a high, open umbrella.
static func _append_trunk_ring(
	surface: SurfaceTool,
	species: StringName,
	profile: Dictionary,
	station: Vector3,
	crown: AABB,
	length: float,
	seed: int,
	step: int
) -> int:
	var crown_start := float(profile["crown_start"])
	var crown_top := crown.end.y
	if station.y < crown_start or crown_top <= crown_start:
		return 0
	var cone := species != &"pine"
	var height_t := clampf((station.y - crown_start) / (crown_top - crown_start), 0.0, 1.0)
	var fan := length
	var ring := 3
	if cone:
		fan = maxf(
			length * 0.7,
			float(profile["primary_length"]) * lerpf(0.85, 0.18, height_t) * CONIFER_TRUNK_FAN_SCALE
		)
		ring = 4 if height_t < 0.75 else 3
	for ring_index in ring:
		var yaw := float(ring_index) * TAU / float(ring) + float(step) * 2.39996
		var out := Vector3(cos(yaw), 0.0, sin(yaw))
		var ring_axis := (out + Vector3.DOWN * 0.28).normalized()
		_emit_card(surface, species, station, ring_axis, Vector3.UP, fan, crown, seed, ring_index)
	return ring


static func _emit_card(
	surface: SurfaceTool,
	species: StringName,
	base: Vector3,
	axis: Vector3,
	facing: Vector3,
	size: float,
	crown: AABB,
	seed: int,
	index: int
) -> void:
	var middle := base + axis * size * 0.5
	var conifer := species in CONIFERS
	var outward := middle - crown.get_center()
	# Conifers keep the shell normal nearly horizontal: an upward bias made every
	# whorl face the sun and blow out white.
	outward.y = (outward.y * 0.5) if conifer else (maxf(outward.y, 0.0) + crown.size.y * 0.15)
	var color := _leaf_vertex_color(species, lerpf(0.82, 1.08, _hash(index, seed, 517)))
	color.a = _crown_occlusion(middle, crown)
	LeafGeometry.append_card(
		surface,
		base,
		axis,
		facing,
		outward,
		Vector2(size * 0.92, size),
		color,
		_hash(index, seed, 521),
		_hash(index, seed, 523) > 0.5,
		CONIFER_NORMAL_OUTWARD if conifer else 0.55
	)


## Centre and half-extents of the leaf-bearing crown, used for occlusion.
static func _crown_bounds(candidates: Array) -> AABB:
	if candidates.is_empty():
		return AABB(Vector3.ZERO, Vector3.ONE)
	var bounds := AABB((candidates[0] as Dictionary)["position"], Vector3.ZERO)
	for candidate: Dictionary in candidates:
		bounds = bounds.expand(candidate["position"])
	return bounds


## Cheap ambient occlusion baked per leaf: 1 at the outer shell and top, down to
## ~0.5 deep inside and under the crown. Real crowns are dark inside; without
## this the procedural canopy reads as a uniformly lit green blob.
static func _crown_occlusion(position: Vector3, crown: AABB) -> float:
	var half := crown.size * 0.5
	var centre := crown.get_center()
	var offset := position - centre
	var radial := Vector2(
		offset.x / maxf(half.x, 0.05), offset.z / maxf(half.z, 0.05)
	).length()
	var height := clampf(offset.y / maxf(half.y, 0.05) * 0.5 + 0.5, 0.0, 1.0)
	var shell := clampf(maxf(radial, height * 1.1), 0.0, 1.0)
	return clampf(lerpf(0.48, 1.0, pow(shell, 0.75)), 0.0, 1.0)


static func _build_fruit_mesh(
	species: StringName, profile: Dictionary, anchors: Array
) -> ArrayMesh:
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
		var side := TreeMeshSkeleton.radial_around(direction, _hash(fruit_index, seed, 449) * TAU)
		position += side * 0.10 + Vector3.DOWN * (0.07 + _hash(fruit_index, seed, 457) * 0.08)
		match species:
			&"cherry":
				_append_octahedron(surface, position, 0.038, Color(0.62, 0.035, 0.045))
				_append_octahedron(
					surface,
					position + side * 0.065 + Vector3.DOWN * 0.025,
					0.035,
					Color(0.82, 0.055, 0.07)
				)
			&"plum", &"blackthorn":
				_append_octahedron(surface, position, 0.052, Color(0.30, 0.12, 0.42))
			&"pear":
				_append_octahedron(
					surface, position + Vector3.DOWN * 0.025, 0.058, Color(0.62, 0.72, 0.16)
				)
			&"hawthorn", &"rowan":
				_append_octahedron(surface, position, 0.034, Color(0.78, 0.08, 0.05))
			_:
				var apple_color := Color(0.76, 0.10, 0.055).lerp(
					Color(0.66, 0.72, 0.10), _hash(fruit_index, seed, 461) * 0.46
				)
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
	var side := TreeMeshSkeleton.perpendicular(axis)
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
			surface,
			a0,
			a1,
			b1,
			normal_a,
			normal_a,
			normal_b,
			color,
			Vector2(float(radial_index) / WOOD_RADIAL_SEGMENTS, 0.0),
			Vector2(float(radial_index) / WOOD_RADIAL_SEGMENTS, 1.0),
			Vector2(float(next_index) / WOOD_RADIAL_SEGMENTS, 1.0)
		)
		_append_colored_triangle(
			surface,
			a0,
			b1,
			b0,
			normal_a,
			normal_b,
			normal_b,
			color,
			Vector2(float(radial_index) / WOOD_RADIAL_SEGMENTS, 0.0),
			Vector2(float(next_index) / WOOD_RADIAL_SEGMENTS, 1.0),
			Vector2(float(next_index) / WOOD_RADIAL_SEGMENTS, 0.0)
		)


static func _append_octahedron(
	surface: SurfaceTool, center: Vector3, radius: float, color: Color
) -> void:
	var points := [
		center + Vector3.UP * radius,
		center + Vector3.DOWN * radius,
		center + Vector3.RIGHT * radius,
		center + Vector3.LEFT * radius,
		center + Vector3.FORWARD * radius,
		center + Vector3.BACK * radius,
	]
	for triangle in [
		[0, 2, 4], [0, 5, 2], [0, 3, 5], [0, 4, 3], [1, 4, 2], [1, 2, 5], [1, 5, 3], [1, 3, 4]
	]:
		var a: Vector3 = points[triangle[0]]
		var b: Vector3 = points[triangle[1]]
		var c: Vector3 = points[triangle[2]]
		var normal := (b - a).cross(c - a).normalized()
		_append_colored_triangle(
			surface, a, b, c, normal, normal, normal, color, Vector2.ZERO, Vector2.RIGHT, Vector2.UP
		)


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
		&"willow":
			return Color(light * 0.92, light, light * 0.62)
		&"rowan", &"hawthorn":
			return Color(light * 0.82, light * 0.96, light * 0.62)
		&"juniper":
			return Color(light * 0.58, light * 0.78, light * 0.68)
		&"hazel", &"blackthorn":
			return Color(light * 0.70, light * 0.90, light * 0.60)
		&"plum":
			return Color(light * 0.72, light * 0.92, light * 0.62)
		&"ash", &"elm", &"pear":
			return Color(light * 0.82, light * 0.98, light * 0.66)
		_:
			return Color(light * 0.88, light, light * 0.70)


static func _hash(x: int, y: int, seed: int) -> float:
	return MapViewMeshBuilderMath.hash01(x, y, seed)

class_name MapViewTreeMeshSkeleton
extends RefCounted

## Recursive trunk/branch growth for MapViewTreeMeshes (P0-185 shard).
## Species profiles stay in MapViewTreeMeshProfiles; wood/canopy/fruit emitters
## stay on the facade. Vector helpers are public because leaf and fruit
## placement reuse the same radial frame as growth.

const MAX_WOOD_SEGMENTS := 120
# Mild root flare only - trunks must read slender against height, not stocky.
const TRUNK_BASE_FLARE := 1.03
# Upper leader shrinks hard so every species tapers continuously with height.
const TRUNK_TIP_RATIO := 0.10
const MIN_BRANCH_TIP_RADIUS := 0.0035
## Segment cap of the build in progress. A profile may raise it with
## "max_segments" (city spruce has twice the whorls, MapViewTreeMeshes
## CITY_PROFILE_OVERRIDES); builds are synchronous, so a static is enough.
static var _segment_cap := MAX_WOOD_SEGMENTS


static func build(species: StringName, profile: Dictionary) -> Dictionary:
	var segments: Array[Dictionary] = []
	var leaf_candidates: Array[Dictionary] = []
	var growth_stats := {
		"curved_branch_paths": 0,
		"interior_branch_junctions": 0,
	}
	_segment_cap = int(profile.get("max_segments", MAX_WOOD_SEGMENTS))
	var trunk_height := float(profile["trunk_height"])
	var trunk_radius := float(profile["trunk_radius"])
	var species_seed := absi(String(species).hash()) + 1709
	var trunk_points: Array[Vector3] = [Vector3.ZERO]
	for section in 3:
		var section_t := float(section + 1) / 3.0
		var lean_x := (_hash(section, species_seed, 11) - 0.5) * trunk_radius * section_t
		var lean_z := (_hash(section, species_seed, 23) - 0.5) * trunk_radius * section_t
		trunk_points.append(Vector3(lean_x, trunk_height * section_t, lean_z))
	var trunk_radii: Array[float] = []
	for section in 4:
		trunk_radii.append(_trunk_radius_at_height(trunk_radius, float(section) / 3.0))
	for section in 3:
		# Shared radii at section joints prevent the trunk from widening again
		# above a seam. Every species now narrows continuously into its leader.
		_append_segment(
			segments,
			trunk_points[section],
			trunk_points[section + 1],
			trunk_radii[section],
			trunk_radii[section + 1],
			0
		)

	var primary_count := int(profile["primary_count"])
	var crown_start := float(profile["crown_start"])
	var crown_end := float(profile["crown_end"])
	var primary_attachment_heights: Array[float] = []
	for branch_index in primary_count:
		if segments.size() >= _segment_cap:
			break
		# Seeded height jitter breaks the ladder-like rings while retaining each
		# species' overall crown envelope.
		var nominal_t := (float(branch_index) + 0.5) / float(primary_count)
		var t := clampf(
			nominal_t + (_hash(branch_index, species_seed, 31) - 0.5) * 0.76 / float(primary_count),
			0.02,
			0.98
		)
		var attach_y := lerpf(crown_start, crown_end, t)
		primary_attachment_heights.append(attach_y)
		var yaw := (
			float(branch_index) * 2.399963 + (_hash(branch_index, species_seed, 37) - 0.5) * 1.05
		)
		var envelope := _crown_envelope(species, t)
		var length := (
			float(profile["primary_length"])
			* envelope
			* lerpf(0.84, 1.14, _hash(branch_index, species_seed, 41))
		)
		var rise := (
			float(profile["branch_rise"]) + (_hash(branch_index, species_seed, 53) - 0.5) * 0.28
		)
		var horizontal := sqrt(maxf(1.0 - rise * rise, 0.05))
		var direction := Vector3(cos(yaw) * horizontal, rise, sin(yaw) * horizontal).normalized()
		var start := Vector3(
			(trunk_points[3].x / trunk_height) * attach_y,
			attach_y,
			(trunk_points[3].z / trunk_height) * attach_y
		)
		var attach_height_t := clampf(attach_y / trunk_height, 0.0, 1.0)
		var local_trunk_radius := _trunk_radius_at_height(trunk_radius, attach_height_t)
		# Keep primary limbs thinner than the bole so the trunk silhouette stays
		# readable instead of swelling into a thick mid-canopy mass.
		_grow_branch(
			segments,
			leaf_candidates,
			growth_stats,
			start,
			direction,
			length,
			local_trunk_radius * lerpf(0.34, 0.22, t),
			int(profile["depth"]),
			profile,
			species_seed + branch_index * 101,
			branch_index
		)

	# The leader tip closes columnar and conifer crowns without a spherical cap.
	leaf_candidates.append(
		{"position": trunk_points[3], "direction": Vector3.UP, "seed": species_seed + 997}
	)
	return {
		"segments": segments,
		"leaf_candidates": leaf_candidates,
		"trunk_radii": trunk_radii,
		"growth_stats": growth_stats,
		"primary_attachment_heights": primary_attachment_heights,
	}


## Cubic Hermite resampling of a coarse branch polyline (WHY: a limb built from
## 1-4 straight pieces shows hard kinks where the direction changes). The curve
## passes through every coarse point, so tips and attachment points stay put;
## each piece is split into `subdiv` shorter pieces with interpolated radii.
## The start tangent follows `start_direction` (continuity with the parent
## direction). A one-piece limb has no neighbour to bend toward, so it gets a
## gentle bow of `single_bend` radians about `bend_axis`, which makes it a curve.
static func smooth_polyline(
	points: Array[Vector3],
	radii: Array[float],
	start_direction: Vector3,
	subdiv: int,
	single_bend: float,
	bend_axis: Vector3
) -> Dictionary:
	var count := points.size()
	if count < 2 or subdiv <= 1:
		return {"points": points, "radii": radii}
	var tangents: Array[Vector3] = []
	for i in count:
		var tangent: Vector3
		if i == 0:
			tangent = start_direction.normalized() * points[0].distance_to(points[1])
		elif i == count - 1:
			tangent = points[i] - points[i - 1]
			if count == 2:
				tangent = tangent.rotated(bend_axis, single_bend)
		else:
			tangent = (points[i + 1] - points[i - 1]) * 0.5
		tangents.append(tangent)
	var out_points: Array[Vector3] = [points[0]]
	var out_radii: Array[float] = [radii[0]]
	for i in count - 1:
		for step in range(1, subdiv + 1):
			var u := float(step) / float(subdiv)
			var u2 := u * u
			var u3 := u2 * u
			var point := (
				points[i] * (2.0 * u3 - 3.0 * u2 + 1.0)
				+ tangents[i] * (u3 - 2.0 * u2 + u)
				+ points[i + 1] * (-2.0 * u3 + 3.0 * u2)
				+ tangents[i + 1] * (u3 - u2)
			)
			out_points.append(point)
			out_radii.append(lerpf(radii[i], radii[i + 1], u))
	return {"points": out_points, "radii": out_radii}


static func radial_around(axis: Vector3, angle: float) -> Vector3:
	var side := perpendicular(axis)
	var forward := axis.cross(side).normalized()
	return (side * cos(angle) + forward * sin(angle)).normalized()


static func perpendicular(direction: Vector3) -> Vector3:
	var side := direction.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = direction.cross(Vector3.RIGHT)
	return side.normalized()


static func _grow_branch(
	segments: Array[Dictionary],
	leaf_candidates: Array[Dictionary],
	growth_stats: Dictionary,
	start: Vector3,
	direction: Vector3,
	length: float,
	radius: float,
	depth: int,
	profile: Dictionary,
	seed: int,
	branch_index: int
) -> void:
	if segments.size() >= _segment_cap or length < 0.10:
		leaf_candidates.append({"position": start, "direction": direction, "seed": seed})
		return

	# Two short sections are enough to turn rigid rods into flowing boughs without
	# increasing the shared species meshes beyond their strict segment budget.
	var piece_count := 2 if depth > 0 else 1
	var path_points: Array[Vector3] = [start]
	var path_directions: Array[Vector3] = [direction.normalized()]
	var path_radii: Array[float] = [radius]
	var current_position := start
	var current_direction := direction.normalized()
	var curve_axis := radial_around(direction, TAU * _hash(branch_index, seed, 61))
	var curve_strength := lerpf(-0.18, 0.18, _hash(branch_index, seed, 67))
	var droop := float(profile["droop"]) * lerpf(0.3, 1.0, 1.0 - float(depth) / 3.0)
	var end_radius := maxf(radius * float(profile["radius_decay"]), MIN_BRANCH_TIP_RADIUS)
	for piece_index in piece_count:
		if segments.size() >= _segment_cap:
			break
		var piece_t := float(piece_index + 1) / float(piece_count)
		var meander := radial_around(current_direction, TAU * _hash(piece_index, seed, 71))
		var target_direction := (
			(
				current_direction * 0.84
				+ curve_axis * curve_strength
				+ meander * lerpf(-0.06, 0.06, _hash(piece_index, seed, 73))
				- Vector3.UP * droop * piece_t
			)
			. normalized()
		)
		var next_direction := (current_direction * 0.52 + target_direction * 0.48).normalized()
		var section_length := (
			length / float(piece_count) * lerpf(0.94, 1.06, _hash(piece_index, seed, 77))
		)
		var next_position := (
			current_position + (current_direction + next_direction).normalized() * section_length
		)
		var next_radius := lerpf(radius, end_radius, pow(piece_t, 0.82))
		current_position = next_position
		current_direction = next_direction
		path_points.append(current_position)
		path_directions.append(current_direction)
		path_radii.append(next_radius)

	if path_points.size() > 1:
		# Smooth the coarse path, then emit the segments (see smooth_polyline).
		var smooth := smooth_polyline(
			path_points,
			path_radii,
			direction,
			4,
			lerpf(-0.35, 0.35, _hash(branch_index, seed, 113)),
			curve_axis
		)
		path_points = smooth["points"]
		path_radii = smooth["radii"]
		path_directions = [direction.normalized()]
		for i in range(1, path_points.size()):
			path_directions.append((path_points[i] - path_points[i - 1]).normalized())
		for i in range(path_points.size() - 1):
			_append_segment(
				segments, path_points[i], path_points[i + 1], path_radii[i], path_radii[i + 1], depth + 1
			)
		current_position = path_points[path_points.size() - 1]
		current_direction = path_directions[path_directions.size() - 1]

	if path_points.size() <= 1:
		leaf_candidates.append({"position": start, "direction": direction, "seed": seed})
		return
	growth_stats["curved_branch_paths"] = int(growth_stats["curved_branch_paths"]) + 1
	leaf_candidates.append(
		{"position": current_position, "direction": current_direction, "seed": seed}
	)
	# Seed foliage along the outer half of each bough so crowns fill instead of
	# leaving bare white limbs with only tip sprays (especially birch).
	if depth <= 1:
		for sample_index in 2:
			var sample_t := lerpf(0.42, 0.82, _hash(sample_index, seed, 307))
			var sample_pos := sample_t * float(path_points.size() - 1)
			var sample_i := mini(int(floor(sample_pos)), path_points.size() - 2)
			var sample_frac := sample_pos - float(sample_i)
			var sample_position := path_points[sample_i].lerp(
				path_points[sample_i + 1], sample_frac
			)
			var sample_direction := (
				path_directions[sample_i]
				. lerp(path_directions[sample_i + 1], sample_frac)
				. normalized()
			)
			(
				leaf_candidates
				. append(
					{
						"position": sample_position,
						"direction": sample_direction,
						"seed": seed + 701 + sample_index * 17,
					}
				)
			)
	if depth <= 0:
		return

	for child_index in 2:
		if segments.size() >= _segment_cap:
			break
		# One child softly continues the parent; the other emerges from a variable
		# interior point. This avoids identical Y-forks attached only at branch tips.
		var continuation := child_index == 0
		var attach_t := (
			lerpf(0.84, 0.97, _hash(child_index, seed, 79))
			if continuation
			else lerpf(0.34, 0.76, _hash(child_index, seed, 81))
		)
		var path_position := attach_t * float(path_points.size() - 1)
		var path_index := mini(int(floor(path_position)), path_points.size() - 2)
		var path_t := path_position - float(path_index)
		var child_start := path_points[path_index].lerp(path_points[path_index + 1], path_t)
		var parent_direction := (
			path_directions[path_index].lerp(path_directions[path_index + 1], path_t).normalized()
		)
		var parent_radius := lerpf(path_radii[path_index], path_radii[path_index + 1], path_t)
		if attach_t < 0.82:
			growth_stats["interior_branch_junctions"] = (
				int(growth_stats["interior_branch_junctions"]) + 1
			)
		var split_yaw := (
			TAU * _hash(child_index, seed, 83) + (_hash(branch_index, seed, 89) - 0.5) * 0.45
		)
		var split_angle := (
			lerpf(0.10, 0.30, _hash(child_index, seed, 97))
			if continuation
			else (float(profile["split_angle"]) * lerpf(0.72, 1.24, _hash(child_index, seed, 101)))
		)
		var child_direction := _split_direction(parent_direction, split_yaw, split_angle)
		# Deciduous branchlets seek light; spruce tips stay flatter and birch tips
		# are allowed to droop through the profile's stronger gravity term.
		child_direction = (
			(child_direction + Vector3.UP * float(profile["branch_rise"]) * 0.28).normalized()
		)
		var child_length := (
			length
			* float(profile["length_decay"])
			* lerpf(
				0.94 if continuation else 0.78,
				1.12 if continuation else 1.04,
				_hash(child_index, seed, 107)
			)
		)
		var child_radius := (
			parent_radius
			* (0.78 if continuation else lerpf(0.52, 0.68, _hash(child_index, seed, 109)))
		)
		_grow_branch(
			segments,
			leaf_candidates,
			growth_stats,
			child_start,
			child_direction,
			child_length,
			maxf(child_radius, MIN_BRANCH_TIP_RADIUS),
			depth - 1,
			profile,
			seed + 211 + child_index * 43,
			branch_index * 3 + child_index + 1
		)


static func _trunk_radius_at_height(base_radius: float, height_t: float) -> float:
	# Convex-early taper: most of the diameter loss happens in the lower/mid
	# bole so upper trunks read pencil-thin rather than carrying base bulk up.
	var t := clampf(height_t, 0.0, 1.0)
	return base_radius * lerpf(TRUNK_BASE_FLARE, TRUNK_TIP_RATIO, pow(t, 0.62))


static func _append_segment(
	segments: Array[Dictionary],
	start: Vector3,
	end: Vector3,
	start_radius: float,
	end_radius: float,
	depth: int
) -> void:
	if segments.size() >= _segment_cap:
		return
	(
		segments
		. append(
			{
				"start": start,
				"end": end,
				"start_radius": start_radius,
				"end_radius": end_radius,
				"depth": depth,
			}
		)
	)


static func _split_direction(direction: Vector3, yaw: float, angle: float) -> Vector3:
	var radial := radial_around(direction, yaw)
	return (direction * cos(angle) + radial * sin(angle)).normalized()


static func _crown_envelope(species: StringName, t: float) -> float:
	match species:
		&"spruce":
			return lerpf(1.15, 0.30, t)
		&"pine":
			return lerpf(0.66, 1.05, sin(t * PI * 0.72))
		&"birch", &"aspen", &"ash", &"elm", &"rowan", &"pear":
			return 0.54 + sin(t * PI) * 0.42
		&"willow":
			return 0.72 + sin(t * PI) * 0.38
		&"hazel", &"hawthorn", &"blackthorn":
			return 0.92 + sin(t * PI) * 0.24
		&"juniper":
			return lerpf(0.92, 0.28, t)
		&"linden":
			return lerpf(1.0, 0.42, t) + sin(t * PI) * 0.16
		&"apple", &"cherry", &"plum":
			return 0.80 + sin(t * PI) * 0.25
		_:
			return 0.68 + sin(t * PI) * 0.46


static func _hash(x: int, y: int, seed: int) -> float:
	return MapViewMeshBuilderMath.hash01(x, y, seed)

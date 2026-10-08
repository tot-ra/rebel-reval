class_name TreeSkeletonWeberPenn
extends RefCounted

## VEGR-6 (R-1324): parametric tree skeletons after Weber and Penn, "Creation and
## Rendering of Realistic Trees" (SIGGRAPH 1995), implemented from the paper.
## A trunk with flare and taper carries recursive branch levels. Each level has
## its own count, length (scaled by a crown shape ratio), down angle, phyllotaxis
## rotation, curvature and gravity droop. The result uses the same dictionary
## contract as MapViewTreeMeshSkeleton.build (segments, leaf_candidates,
## trunk_radii, growth_stats, primary_attachment_heights) plus "twigs": the
## shoot ends that MapViewTreeMeshes clusters leaf cards around.
##
## Deterministic: every random choice is a hash of (index, stem seed, salt), so
## the same species and profile always give the same skeleton.

## Crown shape ratios from the paper (ratio is 1 at the crown base, 0 at the top).
enum Shape {
	CONICAL,
	SPHERICAL,
	HEMISPHERICAL,
	CYLINDRICAL,
	TAPERED_CYLINDRICAL,
	FLAME,
	INVERSE_CONICAL,
	TEND_FLAME,
}

const MAX_WOOD_SEGMENTS := 120
const MIN_TIP_RADIUS := 0.0035

## Species presets. Lengths are fractions of the parent stem; angles in degrees.
## Per level: branches, length (+ length_v), down (+ down_v: added toward the
## crown top, negative = upper limbs climb), rotate (+ rotate_v), curve_res
## (sections per stem), curve (total upward curl over the stem, + curve_v jitter),
## attraction (per-section pull toward +Y, negative = gravity droop), taper,
## start (first child offset along the parent, as a fraction of its length).
## Level 0 is the trunk (lean, flare). "cluster_cards" is the card count per twig
## cluster and "cluster_span" how much of a twig's end carries foliage.
const PRESETS := {
	# Scots pine: tall clear bole, domed crown high up, near-horizontal lower limbs
	# whose tips turn up, short ascending shoots ending in dense needle pads.
	&"pine": {
		"shape": Shape.HEMISPHERICAL,
		"splits": 0,
		"cluster_cards": 9,
		"cluster_span": 0.6,
		"levels": [
			{"curve_res": 4, "curve_v": 7.0, "lean": 0.035, "flare": 0.45, "taper": 0.95},
			{
				"branches": 14, "length": 0.40, "length_v": 0.06, "down": 94.0, "down_v": -46.0,
				"rotate": 137.5, "rotate_v": 24.0, "curve_res": 3, "curve": 26.0, "curve_v": 14.0,
				"attraction": -0.18, "taper": 0.88, "start": 0.0,
			},
			{
				"branches": 5, "length": 0.42, "length_v": 0.10, "down": 48.0, "down_v": 12.0,
				"rotate": 140.0, "rotate_v": 30.0, "curve_res": 1, "curve": 0.0, "curve_v": 10.0,
				"attraction": 0.22, "taper": 0.9, "start": 0.38,
			},
		],
	},
	# Norway spruce: conical, limbs to near the ground, hanging second-order shoots.
	&"spruce": {
		"shape": Shape.CONICAL,
		"splits": 0,
		"cluster_cards": 8,
		"cluster_span": 0.85,
		"levels": [
			{"curve_res": 4, "curve_v": 3.0, "lean": 0.015, "flare": 0.35, "taper": 0.98},
			{
				"branches": 22, "length": 0.34, "length_v": 0.04, "down": 98.0, "down_v": -28.0,
				"rotate": 137.5, "rotate_v": 18.0, "curve_res": 2, "curve": 14.0, "curve_v": 8.0,
				"attraction": -0.32, "taper": 0.92, "start": 0.0,
			},
			{
				"branches": 4, "length": 0.36, "length_v": 0.08, "down": 62.0, "down_v": 0.0,
				"rotate": 180.0, "rotate_v": 20.0, "curve_res": 1, "curve": -10.0, "curve_v": 8.0,
				"attraction": -0.45, "taper": 0.9, "start": 0.3,
			},
		],
	},
	# Silver birch: narrow tend-flame crown, ascending limbs, weeping twigs.
	&"birch": {
		"shape": Shape.TEND_FLAME,
		"splits": 0,
		"cluster_cards": 5,
		"cluster_span": 0.7,
		"levels": [
			{"curve_res": 4, "curve_v": 10.0, "lean": 0.05, "flare": 0.3, "taper": 0.95},
			{
				"branches": 12, "length": 0.42, "length_v": 0.08, "down": 42.0, "down_v": 18.0,
				"rotate": 137.5, "rotate_v": 30.0, "curve_res": 3, "curve": -12.0, "curve_v": 16.0,
				"attraction": -0.1, "taper": 0.9, "start": 0.0,
			},
			{
				"branches": 4, "length": 0.48, "length_v": 0.1, "down": 46.0, "down_v": 0.0,
				"rotate": 140.0, "rotate_v": 40.0, "curve_res": 2, "curve": -20.0, "curve_v": 12.0,
				"attraction": -0.65, "taper": 0.9, "start": 0.3,
			},
		],
	},
	# Pedunculate oak: low fork, broad spreading crown of crooked limbs.
	&"oak": {
		"shape": Shape.SPHERICAL,
		"splits": 1,
		"split_height": 0.42,
		"split_angle": 26.0,
		"cluster_cards": 5,
		"cluster_span": 0.6,
		"levels": [
			{"curve_res": 4, "curve_v": 14.0, "lean": 0.05, "flare": 0.6, "taper": 0.85},
			{
				"branches": 9, "length": 0.58, "length_v": 0.1, "down": 66.0, "down_v": -16.0,
				"rotate": 137.5, "rotate_v": 40.0, "curve_res": 3, "curve": 10.0, "curve_v": 38.0,
				"attraction": -0.05, "taper": 0.85, "start": 0.0,
			},
			{
				"branches": 4, "length": 0.46, "length_v": 0.1, "down": 52.0, "down_v": 0.0,
				"rotate": 140.0, "rotate_v": 40.0, "curve_res": 2, "curve": 0.0, "curve_v": 30.0,
				"attraction": 0.0, "taper": 0.9, "start": 0.25,
			},
		],
	},
	# Black alder: straight leader through a narrow ovoid-conic crown.
	&"alder": {
		"shape": Shape.TAPERED_CYLINDRICAL,
		"splits": 0,
		"cluster_cards": 5,
		"cluster_span": 0.6,
		"levels": [
			{"curve_res": 4, "curve_v": 5.0, "lean": 0.03, "flare": 0.35, "taper": 0.95},
			{
				"branches": 13, "length": 0.36, "length_v": 0.06, "down": 62.0, "down_v": -14.0,
				"rotate": 137.5, "rotate_v": 25.0, "curve_res": 3, "curve": 8.0, "curve_v": 14.0,
				"attraction": -0.08, "taper": 0.9, "start": 0.0,
			},
			{
				"branches": 4, "length": 0.42, "length_v": 0.1, "down": 50.0, "down_v": 0.0,
				"rotate": 140.0, "rotate_v": 30.0, "curve_res": 1, "curve": 0.0, "curve_v": 12.0,
				"attraction": 0.05, "taper": 0.9, "start": 0.3,
			},
		],
	},
	# Aspen: tall narrow crown, short ascending limbs.
	&"aspen": {
		"shape": Shape.TEND_FLAME,
		"splits": 0,
		"cluster_cards": 5,
		"cluster_span": 0.6,
		"levels": [
			{"curve_res": 4, "curve_v": 6.0, "lean": 0.03, "flare": 0.3, "taper": 0.95},
			{
				"branches": 12, "length": 0.32, "length_v": 0.06, "down": 50.0, "down_v": -8.0,
				"rotate": 137.5, "rotate_v": 25.0, "curve_res": 3, "curve": 10.0, "curve_v": 14.0,
				"attraction": 0.05, "taper": 0.9, "start": 0.0,
			},
			{
				"branches": 4, "length": 0.42, "length_v": 0.1, "down": 44.0, "down_v": 0.0,
				"rotate": 140.0, "rotate_v": 30.0, "curve_res": 1, "curve": 0.0, "curve_v": 12.0,
				"attraction": 0.1, "taper": 0.9, "start": 0.3,
			},
		],
	},
	# Common juniper: columnar, many short steep limbs from low on the stem.
	&"juniper": {
		"shape": Shape.CYLINDRICAL,
		"splits": 0,
		# Juniper needles are tiny, so a sparse card count leaves the column see-
		# through; it needs many small clusters covering nearly the whole shoot.
		"cluster_cards": 11,
		"cluster_span": 0.95,
		"levels": [
			{"curve_res": 3, "curve_v": 8.0, "lean": 0.04, "flare": 0.2, "taper": 0.97},
			{
				"branches": 20, "length": 0.30, "length_v": 0.05, "down": 32.0, "down_v": -6.0,
				"rotate": 137.5, "rotate_v": 30.0, "curve_res": 2, "curve": 8.0, "curve_v": 12.0,
				"attraction": 0.12, "taper": 0.9, "start": 0.0,
			},
			{
				"branches": 3, "length": 0.5, "length_v": 0.1, "down": 30.0, "down_v": 0.0,
				"rotate": 140.0, "rotate_v": 30.0, "curve_res": 1, "curve": 0.0, "curve_v": 10.0,
				"attraction": 0.15, "taper": 0.9, "start": 0.2,
			},
		],
	},
	# Small-leaved linden: dense dome, lower limbs arch out and down.
	&"linden": {
		"shape": Shape.SPHERICAL,
		"splits": 0,
		"cluster_cards": 5,
		"cluster_span": 0.6,
		"levels": [
			{"curve_res": 4, "curve_v": 6.0, "lean": 0.03, "flare": 0.45, "taper": 0.92},
			{
				"branches": 12, "length": 0.5, "length_v": 0.08, "down": 72.0, "down_v": -24.0,
				"rotate": 137.5, "rotate_v": 25.0, "curve_res": 3, "curve": 6.0, "curve_v": 16.0,
				"attraction": -0.15, "taper": 0.88, "start": 0.0,
			},
			{
				"branches": 4, "length": 0.44, "length_v": 0.1, "down": 48.0, "down_v": 0.0,
				"rotate": 140.0, "rotate_v": 30.0, "curve_res": 1, "curve": 0.0, "curve_v": 14.0,
				"attraction": -0.05, "taper": 0.9, "start": 0.28,
			},
		],
	},
	# Norway maple: forked dense round crown.
	&"maple": {
		"shape": Shape.SPHERICAL,
		"splits": 1,
		"split_height": 0.48,
		"split_angle": 22.0,
		"cluster_cards": 5,
		"cluster_span": 0.6,
		"levels": [
			{"curve_res": 4, "curve_v": 8.0, "lean": 0.03, "flare": 0.45, "taper": 0.9},
			{
				"branches": 10, "length": 0.5, "length_v": 0.08, "down": 56.0, "down_v": -12.0,
				"rotate": 137.5, "rotate_v": 30.0, "curve_res": 3, "curve": 8.0, "curve_v": 20.0,
				"attraction": -0.06, "taper": 0.88, "start": 0.0,
			},
			{
				"branches": 4, "length": 0.44, "length_v": 0.1, "down": 48.0, "down_v": 0.0,
				"rotate": 140.0, "rotate_v": 30.0, "curve_res": 1, "curve": 0.0, "curve_v": 14.0,
				"attraction": 0.0, "taper": 0.9, "start": 0.28,
			},
		],
	},
}
## When the segment cap leaves room, the last (twig) level may grow up to this
## factor denser; the city profile raises the cap so near crowns get more shoots.
const TWIG_FILL_MAX := 1.5


static func has_preset(species: StringName) -> bool:
	return PRESETS.has(species)


static func preset_for(species: StringName) -> Dictionary:
	return PRESETS.get(species, PRESETS[&"pine"])


## Shape ratio of the paper. `ratio` runs 1 at the crown base to 0 at the top.
static func shape_ratio(shape: int, ratio: float) -> float:
	var r := clampf(ratio, 0.0, 1.0)
	match shape:
		Shape.CONICAL:
			return 0.2 + 0.8 * r
		Shape.SPHERICAL:
			return 0.2 + 0.8 * sin(PI * r)
		Shape.HEMISPHERICAL:
			return 0.2 + 0.8 * sin(0.5 * PI * r)
		Shape.CYLINDRICAL:
			return 1.0
		Shape.TAPERED_CYLINDRICAL:
			return 0.5 + 0.5 * r
		Shape.FLAME:
			return r / 0.7 if r <= 0.7 else (1.0 - r) / 0.3
		Shape.INVERSE_CONICAL:
			return 1.0 - 0.8 * r
		_:
			return 0.5 + 0.5 * r / 0.7 if r <= 0.7 else 0.5 + 0.5 * (1.0 - r) / 0.3


## `profile` supplies the species scale shared with the legacy skeleton
## (trunk_height, trunk_radius, crown_start; optional max_segments), so tuning
## of tree size in MapViewTreeMeshProfiles keeps applying.
static func build(species: StringName, profile: Dictionary) -> Dictionary:
	var preset := preset_for(species)
	var levels: Array = preset["levels"]
	var cap := int(profile.get("max_segments", MAX_WOOD_SEGMENTS))
	var height := float(profile["trunk_height"])
	var base_radius := float(profile["trunk_radius"])
	var base_size := clampf(float(profile.get("crown_start", height * 0.3)) / height, 0.04, 0.9)
	var seed := absi(String(species).hash()) % 100000 + 4447
	var state := {
		"segments": [] as Array[Dictionary],
		"cap": cap,
		"curved": 0,
		"interior": 0,
	}

	var trunk_stems := _grow_trunks(state, preset, height, base_radius, seed)
	var stems_by_level: Array = [trunk_stems]
	var primary_heights: Array[float] = []
	for level in range(1, levels.size()):
		var parents: Array = stems_by_level[level - 1]
		var params: Dictionary = levels[level]
		var last_level := level == levels.size() - 1
		var desired: Array[float] = []
		var expected := 0.0
		for parent: Dictionary in parents:
			var count := _desired_children(parent, params, level, base_size)
			desired.append(count)
			expected += count * float(int(params["curve_res"]))
		var remaining := float(cap - (state["segments"] as Array).size())
		if expected <= 0.0 or remaining <= 0.0:
			stems_by_level.append([])
			continue
		# Budget is spread evenly over all parents, so a tight cap thins every
		# limb a little instead of leaving the last-grown limbs bare.
		var factor := minf(remaining / expected, TWIG_FILL_MAX if last_level else 1.0)
		if level == 1:
			# Primary limbs are the species silhouette: their number comes from the
			# profile ("primary_count", which the city overrides raise) and is never
			# trimmed by the segment budget, so every caller gets exactly that many.
			var wanted_total := float(int(profile.get("primary_count", int(params["branches"]))))
			var share_total := 0.0
			for share: float in desired:
				share_total += share
			if share_total <= 0.0 or wanted_total <= 0.0:
				stems_by_level.append([])
				continue
			for share_index in desired.size():
				desired[share_index] = desired[share_index] / share_total * wanted_total
			factor = 1.0
		var children: Array = []
		var carry := 0.0
		for parent_index in parents.size():
			var wanted := desired[parent_index] * factor + carry
			# The epsilon keeps a share like 13.999999 from floor-ing a limb away.
			var count := floori(wanted + 0.000001)
			carry = wanted - float(count)
			var parent: Dictionary = parents[parent_index]
			for child in _grow_children(
				state, parent, params, preset, level, count, height, base_size
			):
				children.append(child)
				if level == 1:
					primary_heights.append(float(child["attach_y"]))
		stems_by_level.append(children)

	var twigs: Array[Dictionary] = []
	var leaf_candidates: Array[Dictionary] = []
	for level in stems_by_level.size():
		for stem: Dictionary in stems_by_level[level]:
			if level == 0 and not bool(stem["leader"]):
				continue
			var points: Array = stem["points"]
			var tip: Vector3 = points[points.size() - 1]
			var tip_dir: Vector3 = (tip - points[points.size() - 2]).normalized()
			var twig := {
				"start": stem["start"],
				"end": tip,
				"direction": tip_dir,
				"length": float(stem["length"]),
				"level": level,
				"seed": int(stem["seed"]),
				"terminal": level == stems_by_level.size() - 1,
			}
			twigs.append(twig)
			leaf_candidates.append({"position": tip, "direction": tip_dir, "seed": int(stem["seed"])})
			# A second, inner candidate keeps the strided folded-shoot sprays spread
			# along the shoot instead of only at its very tip.
			if level > 0:
				var mid_t := lerpf(0.55, 0.75, _hash(level, int(stem["seed"]), 17))
				leaf_candidates.append({
					"position": _point_along(points, mid_t),
					"direction": tip_dir,
					"seed": int(stem["seed"]) + 701,
				})

	var segments: Array[Dictionary] = state["segments"]
	var level_counts: Array[int] = []
	for stems: Array in stems_by_level:
		level_counts.append(stems.size())
	var trunk: Dictionary = trunk_stems[0]
	var trunk_radii: Array[float] = []
	for section in 4:
		trunk_radii.append(_trunk_radius(trunk, base_radius, float(section) / 3.0))
	return {
		"segments": segments,
		"leaf_candidates": leaf_candidates,
		"twigs": twigs,
		"cluster_cards": int(preset["cluster_cards"]),
		"cluster_span": float(preset["cluster_span"]),
		"trunk_radii": trunk_radii,
		"growth_stats": {
			"curved_branch_paths": int(state["curved"]),
			"interior_branch_junctions": int(state["interior"]),
			"level_counts": level_counts,
		},
		"primary_attachment_heights": primary_heights,
		"stems": _stem_summaries(stems_by_level),
	}


static func _grow_trunks(
	state: Dictionary, preset: Dictionary, height: float, base_radius: float, seed: int
) -> Array:
	var params: Dictionary = (preset["levels"] as Array)[0]
	var curve_res := int(params["curve_res"])
	var lean := float(params.get("lean", 0.03))
	var lean_yaw := TAU * _hash(1, seed, 3)
	var lean_dir := Vector3(cos(lean_yaw), 0.0, sin(lean_yaw))
	var direction := (Vector3.UP + lean_dir * lean).normalized()
	var splits := int(preset.get("splits", 0))
	var split_z := float(preset.get("split_height", 1.0)) if splits > 0 else 1.0
	var main := _new_stem(0, Vector3.ZERO, height, base_radius, seed, 0.0)
	main["leader"] = splits == 0
	main["z0"] = 0.0
	main["z1"] = split_z
	var sections := maxi(1, roundi(float(curve_res) * split_z))
	_trace_stem(state, main, direction, height * split_z, sections, params, 0, seed, true)
	if splits == 0:
		return [main]
	# Dichotomous fork: two leaders leave the split point at +-split_angle, each
	# with the trunk's remaining length and a radius that conserves area roughly.
	var fork_point: Vector3 = main["points"][(main["points"] as Array).size() - 1]
	var fork_dir: Vector3 = (fork_point - (main["points"] as Array)[0]).normalized()
	var fork_radius := _trunk_radius(main, base_radius, 1.0)
	var stems: Array = [main]
	var split_yaw := TAU * _hash(2, seed, 5)
	for branch in 2:
		var angle := deg_to_rad(float(preset["split_angle"])) * lerpf(0.8, 1.2, _hash(branch, seed, 7))
		var yaw := split_yaw + PI * float(branch)
		var leader_dir := _rotate_from(fork_dir, yaw, angle)
		var leader := _new_stem(
			0,
			fork_point,
			height * (1.0 - split_z),
			fork_radius * 0.74,
			seed + 31 * (branch + 1),
			0.0
		)
		leader["leader"] = true
		leader["z0"] = split_z
		leader["z1"] = 1.0
		_trace_stem(
			state, leader, leader_dir, height * (1.0 - split_z),
			maxi(1, curve_res - sections), params, 0, int(leader["seed"]), true
		)
		stems.append(leader)
	return stems


## Children count before the budget factor. Level 1 counts follow the share of
## the trunk inside the crown; deeper levels thin with the parent's relative
## length, as in the paper (0.2 + 0.8 * length / max_length).
static func _desired_children(
	parent: Dictionary, params: Dictionary, level: int, base_size: float
) -> float:
	var branches := float(params["branches"])
	if level == 1:
		var crown_share := clampf(
			(float(parent["z1"]) - maxf(float(parent["z0"]), base_size)) / maxf(1.0 - base_size, 0.01),
			0.0,
			1.0
		)
		return branches * crown_share
	var max_length := float(parent["max_length"])
	return branches * (0.2 + 0.8 * clampf(float(parent["length"]) / maxf(max_length, 0.001), 0.0, 1.0))


static func _grow_children(
	state: Dictionary,
	parent: Dictionary,
	params: Dictionary,
	preset: Dictionary,
	level: int,
	count: int,
	height: float,
	base_size: float
) -> Array:
	var children: Array = []
	if count <= 0:
		return children
	var parent_seed := int(parent["seed"])
	var parent_length := float(parent["length"])
	var points: Array = parent["points"]
	var rotation := TAU * _hash(level, parent_seed, 11)
	var start_t := float(params.get("start", 0.0))
	var t0 := start_t
	var t1 := 0.98
	if level == 1:
		# Primary limbs sit on the part of this trunk stem inside the crown.
		var z0 := float(parent["z0"])
		var z1 := float(parent["z1"])
		t0 = clampf((maxf(base_size, z0) - z0) / maxf(z1 - z0, 0.001), 0.0, 1.0)
		t1 = 0.96 if bool(parent["leader"]) else 1.0
	var length_scale := float(params["length"])
	var max_length := (height if level == 1 else parent_length) * length_scale
	for index in count:
		var seed := parent_seed * 7 + index * 131 + level * 17
		var t := lerpf(t0, t1, (float(index) + 0.3 + _hash(index, seed, 13) * 0.4) / float(count))
		var attach := _point_along(points, t)
		var parent_dir := _direction_along(points, t)
		var crown_t := 0.0
		var length := 0.0
		if level == 1:
			var z := lerpf(float(parent["z0"]), float(parent["z1"]), t)
			crown_t = clampf((z - base_size) / maxf(1.0 - base_size, 0.01), 0.0, 1.0)
			length = max_length * shape_ratio(int(preset["shape"]), 1.0 - crown_t)
		else:
			crown_t = t
			# Shoots near the parent tip are shorter (paper: length_n * (L - 0.6 offset)).
			length = max_length * (1.0 - 0.6 * t)
		length *= (
			1.0
			+ (_hash(index, seed, 19) * 2.0 - 1.0)
			* float(params.get("length_v", 0.0))
			/ maxf(length_scale, 0.01)
		)
		if length < 0.04:
			if level > 1:
				continue
			# A primary limb is never dropped: the profile's count is a contract.
			length = 0.04
		var down := float(params["down"]) + float(params.get("down_v", 0.0)) * crown_t
		down += (_hash(index, seed, 23) - 0.5) * 16.0
		var rotate_jitter := (_hash(index, seed, 29) - 0.5) * 2.0 * float(params.get("rotate_v", 0.0))
		rotation += deg_to_rad(float(params["rotate"]) + rotate_jitter)
		var direction := _rotate_from(parent_dir, rotation, deg_to_rad(down))
		var parent_radius := _radius_along(parent, t)
		# Radius follows the length ratio (paper: ratio power) and never exceeds
		# what the parent can carry at the attachment.
		var radius := minf(
			float(parent["base_radius"]) * pow(length / maxf(parent_length, 0.01), 1.2),
			parent_radius * 0.72
		)
		var child := _new_stem(level, attach, length, maxf(radius, MIN_TIP_RADIUS), seed, max_length)
		child["attach_y"] = attach.y
		child["attach_t"] = t
		if t < 0.82:
			state["interior"] = int(state["interior"]) + 1
		_trace_stem(state, child, direction, length, int(params["curve_res"]), params, level, seed, false)
		if (child["points"] as Array).size() > 1:
			children.append(child)
	return children


static func _new_stem(
	level: int, start: Vector3, length: float, radius: float, seed: int, max_length: float
) -> Dictionary:
	return {
		"level": level,
		"start": start,
		"length": length,
		"max_length": max_length if max_length > 0.0 else length,
		"base_radius": radius,
		"seed": seed,
		"points": [start] as Array[Vector3],
		"radii": [radius] as Array[float],
		"leader": false,
		"z0": 0.0,
		"z1": 1.0,
	}


## Walks a stem in `sections` pieces. Each piece curls in the vertical plane by
## curve / sections (+ jitter), then gravity (attraction < 0) or phototropism
## (> 0) pulls it toward -Y / +Y in proportion to how horizontal it is.
static func _trace_stem(
	state: Dictionary,
	stem: Dictionary,
	direction: Vector3,
	length: float,
	sections: int,
	params: Dictionary,
	depth: int,
	seed: int,
	is_trunk: bool
) -> void:
	var segments: Array[Dictionary] = state["segments"]
	var points: Array[Vector3] = stem["points"]
	var radii: Array[float] = stem["radii"]
	var current := direction.normalized()
	var position: Vector3 = stem["start"]
	var piece := length / float(sections)
	var curve := deg_to_rad(float(params.get("curve", 0.0)))
	var curve_v := deg_to_rad(float(params.get("curve_v", 0.0)))
	var attraction := float(params.get("attraction", 0.0))
	var taper := float(params.get("taper", 0.9))
	var traced := 0
	for section in sections:
		if segments.size() >= int(state["cap"]):
			break
		if section > 0 or not is_trunk:
			var bend := curve / float(sections) + (_hash(section, seed, 41) - 0.5) * curve_v
			current = _curl_up(current, bend)
			var wobble := MapViewTreeMeshSkeleton.radial_around(current, TAU * _hash(section, seed, 43))
			current = (current + wobble * (_hash(section, seed, 47) - 0.5) * curve_v * 0.5).normalized()
			if not is_trunk:
				var horizontal := sqrt(maxf(0.0, 1.0 - current.y * current.y))
				current = (current + Vector3.UP * attraction * horizontal / float(sections)).normalized()
		var next := position + current * piece
		var t := float(section + 1) / float(sections)
		var radius: float
		if is_trunk:
			radius = _trunk_radius(
				stem, float(stem["base_radius"]), t, taper, float(params.get("flare", 0.0))
			)
		else:
			radius = maxf(float(stem["base_radius"]) * (1.0 - taper * t), MIN_TIP_RADIUS)
		segments.append({
			"start": position,
			"end": next,
			"start_radius": radii[radii.size() - 1],
			"end_radius": radius,
			"depth": depth,
		})
		position = next
		points.append(next)
		radii.append(radius)
		traced += 1
	if traced >= 2:
		state["curved"] = int(state["curved"]) + 1
	if is_trunk:
		# Flared base radius replaces the stored one so tubes start wide.
		radii[0] = _trunk_radius(
			stem, float(stem["base_radius"]), 0.0, taper, float(params.get("flare", 0.0))
		)
		if not segments.is_empty() and traced > 0:
			segments[segments.size() - traced]["start_radius"] = radii[0]
	stem["taper"] = taper
	stem["flare"] = float(params.get("flare", 0.0))


## Trunk radius at local stem fraction t: linear taper plus the paper's root flare
## (1 + flare * (100^(1 - 8z) - 1) / 100), which only swells the lowest eighth.
static func _trunk_radius(
	stem: Dictionary, base_radius: float, t: float, taper := -1.0, flare := -1.0
) -> float:
	if taper < 0.0:
		taper = float(stem.get("taper", 0.95))
	if flare < 0.0:
		flare = float(stem.get("flare", 0.0))
	var z := lerpf(float(stem.get("z0", 0.0)), float(stem.get("z1", 1.0)), t)
	var radius := float(stem["base_radius"]) * (1.0 - taper * t)
	if float(stem.get("z0", 0.0)) <= 0.0:
		radius = base_radius * (1.0 - taper * z)
		radius *= 1.0 + flare * (pow(100.0, maxf(0.0, 1.0 - 8.0 * z)) - 1.0) / 100.0
	return maxf(radius, MIN_TIP_RADIUS)


static func _radius_along(stem: Dictionary, t: float) -> float:
	var radii: Array = stem["radii"]
	var position := clampf(t, 0.0, 1.0) * float(radii.size() - 1)
	var index := mini(int(floor(position)), radii.size() - 2)
	if index < 0:
		return float(radii[0])
	return lerpf(float(radii[index]), float(radii[index + 1]), position - float(index))


static func _point_along(points: Array, t: float) -> Vector3:
	var position := clampf(t, 0.0, 1.0) * float(points.size() - 1)
	var index := mini(int(floor(position)), points.size() - 2)
	if index < 0:
		return points[0]
	return (points[index] as Vector3).lerp(points[index + 1], position - float(index))


static func _direction_along(points: Array, t: float) -> Vector3:
	var position := clampf(t, 0.0, 1.0) * float(points.size() - 1)
	var index := clampi(int(floor(position)), 0, points.size() - 2)
	return ((points[index + 1] as Vector3) - (points[index] as Vector3)).normalized()


## Direction at `down` radians from `axis`, turned `yaw` radians around it.
static func _rotate_from(axis: Vector3, yaw: float, down: float) -> Vector3:
	var radial := MapViewTreeMeshSkeleton.radial_around(axis, yaw)
	return (axis * cos(down) + radial * sin(down)).normalized()


## Rotate `direction` by `angle` radians toward +Y in its vertical plane
## (negative angle curls it down). Vertical stems curl about a fixed side axis.
static func _curl_up(direction: Vector3, angle: float) -> Vector3:
	var up := Vector3.UP - direction * direction.dot(Vector3.UP)
	if up.length_squared() < 0.0001:
		up = MapViewTreeMeshSkeleton.perpendicular(direction)
	return (direction * cos(angle) + up.normalized() * sin(angle)).normalized()


static func _stem_summaries(stems_by_level: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for level in stems_by_level.size():
		for stem: Dictionary in stems_by_level[level]:
			var points: Array = stem["points"]
			result.append({
				"level": level,
				"start": points[0],
				"end": points[points.size() - 1],
				"length": float(stem["length"]),
				"attach_t": float(stem.get("attach_t", 0.0)),
				"first_direction": ((points[1] as Vector3) - (points[0] as Vector3)).normalized(),
				"last_direction": (
					(points[points.size() - 1] as Vector3) - (points[points.size() - 2] as Vector3)
				).normalized(),
			})
	return result


static func _hash(x: int, y: int, seed: int) -> float:
	return MapViewMeshBuilderMath.hash01(x, y, seed)

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
## VEGR-6 (R-1324) parametric skeletons. Preloaded, not referenced by class name,
## so the dependency stays one-way (Weber-Penn reads the legacy vector helpers).
const TreeSkeletonWeber := preload("res://scripts/map/view3d/tree_skeleton_weber_penn.gd")

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
## Needle fans bow downward by this fraction of their length, like hanging spruce shoots.
const CONIFER_CARD_DROOP := 0.22

## Seamless city (ADR 0031, 1 wu = 1 m) near-crown detail. The shared meshes are
## ~2.5 units tall and get scaled 3-4.5x in the city, which blew leaf-cluster
## cards up to 1-1.9 m (head-sized leaves, needle "planks"). The near variant
## sizes cards to these real lengths and adds cards to keep the crown full.
const NEAR_CARD_METRES := 0.62
const NEAR_CONIFER_CARD_METRES := 0.58
## Shrub-sized species (the city also draws elder, guelder rose, willow and
## alder scrub and spindle with these meshes). At 0.36-0.54 m their far cards
## already beat NEAR_CARD_METRES, but next to Kalev a 2-3 m shrub needs
## hand-sized leaves (~8-12 cm in a 7-12 leaf cluster), so near cards are smaller.
const CITY_SHRUBS: Array[StringName] = [&"hazel", &"hawthorn", &"blackthorn"]
const NEAR_SHRUB_CARD_METRES := 0.28
## Card count multiplier is 1 / size_factor^2 (same leaf area), capped so a
## near crown stays inside NEAR_TRIANGLE_CAP.
const NEAR_MAX_COUNT_FACTOR := 3.5
const NEAR_TRIANGLE_CAP := 56000
## Bark plates (assets/materials/pbr/bark_*) cover about this much trunk.
const BARK_TILE_METRES := 0.55
## Near folded (single) leaves shrink further than cards: a card is a whole
## twig cluster, a folded leaf is one leaf (birch ~5 cm, oak ~12 cm).
const NEAR_FOLDED_LEAF_SHRINK := 0.4
## City skeleton overrides. Spruce with 14 primaries read as a few sparse
## tiers in a cross at real scale; a Norway spruce has a whorl every
## 30-50 cm, branching down to the ground. The far crown uses the same
## skeleton, so the LOD switch never changes the silhouette.
const CITY_PROFILE_OVERRIDES := {
	&"spruce": {"primary_count": 26, "crown_start": 0.34, "max_segments": 300},
	&"pine": {"primary_count": 11, "max_segments": 200},
}

static var _geometry_cache: Dictionary = {}
static var _city_cache: Dictionary = {}


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
	_city_cache.clear()


## City trunk and branches: radii scaled by `radius_factor` (the shared trunks
## are ~3x too thick once scaled to real tree heights), UVs in bark tiles of
## BARK_TILE_METRES running up each limb, and tangents for the bark normal map.
static func city_wood_mesh(
	species: StringName, world_scale: float, radius_factor: float
) -> ArrayMesh:
	var key := "wood:%s:%.2f:%.2f" % [species, world_scale, radius_factor]
	if not _city_cache.has(key):
		_city_cache[key] = _build_wood_mesh(
			species,
			_skeleton_for(species),
			radius_factor,
			BARK_TILE_METRES / maxf(world_scale, 0.01)
		)
	return _city_cache[key]


## City near crown: same skeleton, seasons and wind contract as canopy_mesh,
## but cluster cards at real size (NEAR_*_CARD_METRES) and proportionally more
## of them. Drawn only for trees close to the camera (CityTreeLod).
static func city_canopy_near_mesh(species: StringName, world_scale: float) -> ArrayMesh:
	var key := "near:%s:%.2f" % [species, world_scale]
	if not _city_cache.has(key):
		var profile := city_profile(species)
		var conifer := species in CONIFERS
		var base := float(profile["leaf_length"]) * (CONIFER_CARD_SCALE if conifer else CARD_SCALE)
		var metres := NEAR_CONIFER_CARD_METRES if conifer else NEAR_CARD_METRES
		if species in CITY_SHRUBS:
			metres = NEAR_SHRUB_CARD_METRES
		var target := metres / maxf(world_scale, 0.01)
		var size_factor := clampf(target / maxf(base, 0.001), 0.25, 1.0)
		var count_factor := minf(1.0 / (size_factor * size_factor), NEAR_MAX_COUNT_FACTOR)
		var data := _build_canopy_mesh(
			species, profile, _skeleton_for(species), size_factor, count_factor
		)
		var triangles := (data["mesh"] as ArrayMesh).surface_get_array_len(0) / 3
		if triangles > NEAR_TRIANGLE_CAP:
			# Conifers carry cards along every segment, so they overshoot the
			# budget first; trade some density for the cap, keeping card size.
			count_factor = maxf(1.0, count_factor * float(NEAR_TRIANGLE_CAP) / float(triangles))
			data = _build_canopy_mesh(
				species, profile, _skeleton_for(species), size_factor, count_factor
			)
		_city_cache[key] = data["mesh"]
		_city_cache["stats:" + key] = {
			"card_count": int(data["card_count"]),
			"size_factor": size_factor,
			"count_factor": count_factor,
			"canopy_triangles": (data["mesh"] as ArrayMesh).surface_get_array_len(0) / 3,
		}
	return _city_cache[key]


static func city_canopy_near_stats(species: StringName, world_scale: float) -> Dictionary:
	city_canopy_near_mesh(species, world_scale)
	return (_city_cache["stats:near:%s:%.2f" % [species, world_scale]] as Dictionary).duplicate()


## City far crown: the shared big-card geometry on the city skeleton.
static func city_canopy_far_mesh(species: StringName) -> ArrayMesh:
	var key := "far:%s" % species
	if not _city_cache.has(key):
		_city_cache[key] = _build_canopy_mesh(
			species, city_profile(species), _skeleton_for(species)
		)["mesh"]
	return _city_cache[key]


static func city_profile(species: StringName) -> Dictionary:
	var profile := TreeMeshProfiles.profile_for(species).duplicate()
	profile.merge(CITY_PROFILE_OVERRIDES.get(species, {}), true)
	return profile


static func _skeleton_for(species: StringName) -> Dictionary:
	var key := "skeleton:%s" % species
	if not _city_cache.has(key):
		_city_cache[key] = build_skeleton(species, city_profile(species))
	return _city_cache[key]


## VEGR-6: species that have a Weber-Penn preset grow from the parametric
## generator (forked, tapered, drooping limbs with twig ends); the rest keep the
## legacy recursive skeleton until they get presets. Both return the same
## dictionary contract, so wood, canopy, fruit, LOD and leaf fall are unchanged.
static func build_skeleton(species: StringName, profile: Dictionary) -> Dictionary:
	if TreeSkeletonWeber.has_preset(species):
		return TreeSkeletonWeber.build(species, profile)
	return TreeMeshSkeleton.build(species, profile)


static func _geometry_for(species: StringName) -> Dictionary:
	if _geometry_cache.has(species):
		return _geometry_cache[species]
	var profile := TreeMeshProfiles.profile_for(species)
	var skeleton := build_skeleton(species, profile)
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
		# VEGR-6: branch levels and shoot ends of the parametric skeleton (empty
		# arrays / 0 for species still on the legacy recursive growth).
		"level_counts": (skeleton["growth_stats"].get("level_counts", []) as Array).duplicate(),
		"twig_count": (skeleton.get("twigs", []) as Array).size(),
	}
	var geometry := {"wood": wood, "canopy": canopy_data["mesh"], "fruit": fruit, "stats": stats}
	_geometry_cache[species] = geometry
	return geometry


## `bark_tile` > 0 switches to bark-plate UVs (u wraps a whole number of tiles
## round the limb, v runs up the limb in tiles, continuing from the parent
## segment) and adds tangents; 0 keeps the legacy per-segment 0..1 UVs.
static func _build_wood_mesh(
	_species: StringName, skeleton: Dictionary, radius_factor := 1.0, bark_tile := 0.0
) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments: Array = skeleton["segments"]
	var v_at_end: Dictionary = {}
	# Segment ends keyed with depth: a segment whose start is not the end of a
	# same-depth segment is a branch base needing a collar (limb sections continue
	# at equal depth; a base may touch a parent end of a lower depth).
	var chain_ends: Dictionary = {}
	for chain_segment in segments:
		chain_ends[[_point_key(chain_segment["end"]), int(chain_segment["depth"])]] = true
	for segment_index in segments.size():
		var segment: Dictionary = segments[segment_index]
		var depth := int(segment["depth"])
		var shade := 1.0 if depth == 0 else lerpf(0.84, 1.08, _hash(segment_index, depth, 313))
		var wood_color := Color(shade, shade * 0.98, shade * 0.94)
		# Branches thin less than the trunk so they stay visible and never get
		# thicker than the bole they grow from.
		var factor := radius_factor if depth == 0 else pow(radius_factor, 0.6)
		var start: Vector3 = segment["start"]
		var end: Vector3 = segment["end"]
		var uv_rect := Rect2()
		if bark_tile > 0.0:
			var v0: float = v_at_end.get(_point_key(start), _hash(segment_index, depth, 331) * 4.0)
			var v1 := v0 + start.distance_to(end) / bark_tile
			v_at_end[_point_key(end)] = v1
			var around := TAU * float(segment["start_radius"]) * factor / bark_tile
			uv_rect = Rect2(0.0, v0, maxf(1.0, roundf(around)), v1 - v0)
		_append_tapered_tube(
			surface,
			start,
			end,
			float(segment["start_radius"]) * factor,
			float(segment["end_radius"]) * factor,
			wood_color,
			uv_rect
		)
		if depth > 0 and not chain_ends.has([_point_key(start), depth]):
			_append_branch_collar(
				surface,
				start,
				end,
				float(segment["start_radius"]) * factor,
				_parent_radius_at(segments, start, depth) * factor,
				wood_color,
				uv_rect
			)
	if bark_tile > 0.0:
		surface.generate_tangents()
	return surface.commit()


## Flared, concave collar where a branch leaves its parent, so the limb flows
## out of the bole like a liquid instead of poking in at a hard angle. Only
## large limbs get a strong flare; fine twigs only a gentle one (WHY: at high
## branchiness a strong collar on every twig would read as knobby bulk).
## The first ring sits inside the parent and is hidden by it.
static func _append_branch_collar(
	surface: SurfaceTool,
	start: Vector3,
	end: Vector3,
	radius: float,
	parent_radius: float,
	color: Color,
	uv_rect: Rect2
) -> void:
	# Radii in tree units: twigs ~0.004, primary limbs 0.02-0.05.
	# The first ring must stay inside the parent, or it shows as a flange.
	var flare := minf(lerpf(1.25, 2.0, smoothstep(0.004, 0.03, radius)), parent_radius * 0.92 / radius)
	if flare < 1.08:
		return
	var axis := end - start
	var span := minf(radius * 5.0, axis.length() * 0.9)
	if span <= 0.0001:
		return
	axis = axis.normalized()
	# Concave (exponential-like) falloff of the ring radii along the branch.
	var offsets := [0.0, 0.25, 0.6, 1.0]
	var scales := [flare, lerpf(1.0, flare, 0.5), lerpf(1.0, flare, 0.17), 1.02]
	for i in 3:
		_append_tapered_tube(
			surface,
			start + axis * span * float(offsets[i]),
			start + axis * span * float(offsets[i + 1]),
			radius * float(scales[i]),
			radius * float(scales[i + 1]),
			color,
			uv_rect
		)


## Radius of the nearest lower-depth segment at `point` (the limb a branch grows from).
static func _parent_radius_at(segments: Array, point: Vector3, depth: int) -> float:
	var best_distance := INF
	var best_radius := 0.0
	for candidate: Dictionary in segments:
		if int(candidate["depth"]) >= depth:
			continue
		var a: Vector3 = candidate["start"]
		var ab: Vector3 = (candidate["end"] as Vector3) - a
		var length_sq := ab.length_squared()
		var u := 0.0 if length_sq < 0.0000001 else clampf((point - a).dot(ab) / length_sq, 0.0, 1.0)
		var distance := point.distance_squared_to(a + ab * u)
		if distance < best_distance:
			best_distance = distance
			best_radius = lerpf(float(candidate["start_radius"]), float(candidate["end_radius"]), u)
	return best_radius


static func _point_key(point: Vector3) -> Vector3i:
	return Vector3i((point * 1000.0).round())


static func _build_canopy_mesh(
	species: StringName,
	profile: Dictionary,
	skeleton: Dictionary,
	size_factor := 1.0,
	count_factor := 1.0
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
				float(profile["leaf_length"])
				* size_factor
				* (NEAR_FOLDED_LEAF_SHRINK if size_factor < 1.0 else 1.0)
				* lerpf(0.72, 1.16, _hash(leaf_index, seed, 419))
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
	var card_count := _append_cluster_cards(
		surface, species, profile, skeleton, crown, size_factor, count_factor
	)
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
	crown: AABB,
	size_factor := 1.0,
	count_factor := 1.0
) -> int:
	if skeleton.has("twigs"):
		return _append_twig_clusters(
			surface, species, profile, skeleton, crown, size_factor, count_factor
		)
	var conifer := species in CONIFERS
	var length := (
		float(profile["leaf_length"])
		* (CONIFER_CARD_SCALE if conifer else CARD_SCALE)
		* size_factor
	)
	var per_tip := roundi((CONIFER_CARDS_PER_TIP if conifer else CARDS_PER_TIP) * count_factor)
	if species == &"pine":
		# Scots pine reads as flat, dense needle pads at limb ends (not 5 thin spikes).
		per_tip = roundi(8.0 * count_factor)
	var spread := float(profile["leaf_spread"])
	# With small near cards a whole tip cluster would shrink to a ball; spread
	# the extra cards back along the twig and out round it instead.
	var reach := spread * (0.25 + (1.0 - size_factor) * 0.9)
	var cards := 0
	for candidate: Dictionary in skeleton["leaf_candidates"]:
		var anchor: Vector3 = candidate["position"]
		var direction: Vector3 = candidate["direction"]
		var seed := int(candidate["seed"])
		for card_index in per_tip:
			var yaw := (
				TAU * (float(card_index) + _hash(card_index, seed, 503) * 0.6) / float(per_tip)
			)
			var radial := TreeMeshSkeleton.radial_around(direction, yaw)
			var axis := (direction * 0.55 + radial * 0.75 + Vector3.UP * 0.15).normalized()
			var size := length * lerpf(0.78, 1.15, _hash(card_index, seed, 509))
			var back := _hash(card_index, seed, 511) * (1.0 - size_factor) * spread * 1.2
			var base := (
				anchor
				- axis * size * 0.18
				+ (
					radial
					* reach
					* (lerpf(0.6, 1.2, _hash(card_index, seed, 513)) if size_factor < 1.0 else 1.0)
				)
				- direction * back
			)
			var facing := (Vector3.UP * 0.7 + radial * 0.5).normalized()
			_emit_card(surface, species, base, axis, facing, size, crown, seed, card_index)
			cards += 1
	# Pine limbs stay visibly bare between tufts: no cards along segments or
	# around the bole (that is what made it read as a layered spruce).
	if not conifer or species == &"pine":
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
			var rolls := roundi(3.0 * minf(count_factor, 2.0))
			for roll_index in rolls:
				var roll := phase + float(roll_index) * TAU / float(rolls)
				var spoke := side * cos(roll) + up_side * sin(roll)
				var fan_axis := (forward + Vector3.DOWN * 0.10 + spoke * 0.55).normalized()
				_emit_card(
					surface,
					species,
					base,
					fan_axis,
					spoke,
					length * (1.0 - 0.1 * float(roll_index % 3)),
					crown,
					seed,
					roll_index
				)
			cards += rolls
	return cards


## VEGR-6 (R-1324) clustered leaf placement. Foliage sits in clusters on the
## outer `cluster_span` of every shoot (`skeleton["twigs"]`) instead of being
## scattered over the whole crown, so limbs stay bare between clusters and light
## comes through the gaps. Cards point outward from the crown shell; clusters
## deeper inside get fewer and smaller cards, and `_emit_card` darkens them
## through the baked crown AO. This is what makes a crown read as a lit shell
## over a shadowed hollow with branch structure showing through.
static func _append_twig_clusters(
	surface: SurfaceTool,
	species: StringName,
	profile: Dictionary,
	skeleton: Dictionary,
	crown: AABB,
	size_factor := 1.0,
	count_factor := 1.0
) -> int:
	var conifer := species in CONIFERS
	var length := (
		float(profile["leaf_length"])
		* (CONIFER_CARD_SCALE if conifer else CARD_SCALE)
		* size_factor
	)
	var base_cards := maxi(
		1, roundi(float(skeleton.get("cluster_cards", CARDS_PER_TIP)) * count_factor)
	)
	var span := clampf(float(skeleton.get("cluster_span", 0.6)), 0.05, 1.0)
	var centre := crown.get_center()
	var shell_radius := maxf(Vector2(crown.size.x, crown.size.z).length() * 0.5, 0.05)
	var twigs: Array = skeleton["twigs"]
	var cards := 0
	for twig: Dictionary in twigs:
		var end: Vector3 = twig["end"]
		var direction: Vector3 = twig["direction"]
		var seed := int(twig["seed"])
		var twig_length := float(twig["length"])
		# Clusters only on the shoot end; the inner part of the shoot stays wood.
		var start := end - direction * twig_length * span
		# 0 on the crown axis, 1 out at the shell: how exposed this cluster is.
		var exposure := clampf(
			Vector2(end.x - centre.x, end.z - centre.z).length() / shell_radius, 0.0, 1.0
		)
		if not bool(twig.get("terminal", true)):
			# A limb that still carries shoots of its own gets a token tuft only.
			exposure *= 0.45
		var count := maxi(1, roundi(float(base_cards) * lerpf(0.45, 1.0, exposure)))
		var outward := end - centre
		outward.y = 0.0
		if outward.length_squared() < 0.0001:
			outward = direction
		outward = outward.normalized()
		for card_index in count:
			var t := clampf(
				(float(card_index) + 0.5 + (_hash(card_index, seed, 601) - 0.5) * 0.7)
				/ float(count),
				0.0,
				1.0
			)
			var station := start.lerp(end, t)
			# Golden-angle roll keeps a cluster's cards from stacking into a plate.
			var yaw := TAU * (float(card_index) * 0.618034 + _hash(card_index, seed, 607))
			var radial := TreeMeshSkeleton.radial_around(direction, yaw)
			var axis := (
				direction * 0.42
				+ radial * 0.82
				+ Vector3.UP * (0.0 if conifer else 0.22)
			).normalized()
			var size := (
				length
				* lerpf(0.74, 1.12, _hash(card_index, seed, 613))
				* lerpf(0.66, 1.0, exposure)
			)
			var base := station - axis * size * 0.16 + radial * size * 0.1
			var facing := (radial * 0.55 + outward * 0.45 + Vector3.UP * 0.2).normalized()
			_emit_card(surface, species, base, axis, facing, size, crown, seed, card_index)
			cards += 1
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
	var occlusion := _crown_occlusion(middle, crown)
	color.a = occlusion
	# VEGR-6 crown volume: only shell clusters take the full spherical normal, so
	# the outer surface lights as one dome. Clusters deeper in keep their own
	# cluster normal (bent just a little toward the crown centre), which leaves
	# the hollow dark instead of lighting every interior card like a shell.
	var shell := clampf(inverse_lerp(0.48, 1.0, occlusion), 0.0, 1.0)
	var outward_weight := (CONIFER_NORMAL_OUTWARD if conifer else 0.55) * lerpf(0.3, 1.0, shell)
	LeafGeometry.append_card(
		surface,
		base,
		axis,
		facing,
		outward,
		Vector2(size * 0.92, size),
		color,
		# hash01 can return exactly 0 or 1; the leaf contract needs a seed strictly
		# inside (0, 1), or the shader treats the card as fallen/never-leafing.
		clampf(_hash(index, seed, 521), 0.0001, 0.9999),
		_hash(index, seed, 523) > 0.5,
		outward_weight,
		CONIFER_CARD_DROOP if conifer else 0.0
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
	var radial := Vector2(offset.x / maxf(half.x, 0.05), offset.z / maxf(half.z, 0.05)).length()
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
	color: Color,
	uv_rect := Rect2()
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
		var ua := float(radial_index) / WOOD_RADIAL_SEGMENTS
		var ub := float(next_index) / WOOD_RADIAL_SEGMENTS
		var v0 := 0.0
		var v1 := 1.0
		if uv_rect.size.x > 0.0:
			# Bark plates: the last face closes the ring at u = tiles, not back at 0.
			ub = float(radial_index + 1) / WOOD_RADIAL_SEGMENTS
			ua *= uv_rect.size.x
			ub *= uv_rect.size.x
			v0 = uv_rect.position.y
			v1 = uv_rect.end.y
		_append_colored_triangle(
			surface,
			a0,
			a1,
			b1,
			normal_a,
			normal_a,
			normal_b,
			color,
			Vector2(ua, v0),
			Vector2(ua, v1),
			Vector2(ub, v1)
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
			Vector2(ua, v0),
			Vector2(ub, v1),
			Vector2(ub, v0)
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

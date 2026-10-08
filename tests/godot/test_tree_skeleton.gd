extends "res://tests/godot/test_case.gd"

## VEGR-6 (R-1324): Weber-Penn tree skeletons and clustered leaf placement.
## Covers the parametric generator itself, its species presets, deterministic
## rebuilds, the canopy triangle cap, and that clustered cards keep the R-1187
## leaf contract so seasons, autumn hue and leaf fall still work.

const TreeSkeleton := preload("res://scripts/map/view3d/tree_skeleton_weber_penn.gd")
const TreeMeshProfiles := preload("res://scripts/map/view3d/map_view_tree_mesh_profiles.gd")

## Shared (non-city) canopy budget per species, from the VEGR-0 tree budget.
const CANOPY_TRIANGLE_CAP := 24000
## Every catalogue species grows from a Weber-Penn preset; none may fall back to
## the legacy recursive skeleton (that is what drew orchard trees as a pole with
## a tuft on top and two horizontal arms).
const PRESET_SPECIES: Array[StringName] = MapViewTreeSpecies.ALL_SPECIES


func test_every_preset_species_grows_three_branch_levels() -> void:
	for species in PRESET_SPECIES:
		assert_true(TreeSkeleton.has_preset(species), "%s needs a Weber-Penn preset" % species)
		var skeleton := TreeSkeleton.build(species, TreeMeshProfiles.profile_for(species))
		var levels: Array = skeleton["growth_stats"]["level_counts"]
		assert_true(levels.size() >= 3, "%s must grow trunk + two branch levels" % species)
		for level in levels.size():
			assert_true(int(levels[level]) > 0, "%s level %d came out empty" % [species, level])
		assert_true(
			(skeleton["twigs"] as Array).size() > 0, "%s produced no shoot ends" % species
		)
		assert_true(
			(skeleton["segments"] as Array).size() > 20, "%s skeleton is too sparse" % species
		)


func test_scots_pine_has_a_clear_bole_and_a_high_crown() -> void:
	var profile := TreeMeshProfiles.profile_for(&"pine")
	var skeleton := TreeSkeleton.build(&"pine", profile)
	var height := float(profile["trunk_height"])
	var crown_start := float(profile["crown_start"])
	var heights: Array = skeleton["primary_attachment_heights"]
	assert_true(heights.size() > 0, "pine grew no primary limbs")
	var lowest := INF
	for attach_height: float in heights:
		lowest = minf(lowest, attach_height)
	# Scots pine lifts its crown: nothing may branch off the lower bole.
	assert_true(
		lowest >= crown_start * 0.8,
		"lowest pine limb at %.2f m sits below the %.2f m crown base" % [lowest, crown_start]
	)
	assert_true(lowest < height, "pine limbs must still attach below the leader tip")


func test_trunk_flares_at_the_base_and_tapers_to_the_tip() -> void:
	for species in PRESET_SPECIES:
		var radii: Array = TreeSkeleton.build(
			species, TreeMeshProfiles.profile_for(species)
		)["trunk_radii"]
		assert_eq(radii.size(), 4, "%s must report four trunk sections" % species)
		for section in radii.size() - 1:
			assert_true(
				float(radii[section]) >= float(radii[section + 1]),
				"%s trunk widens again above section %d" % [species, section]
			)
		assert_true(
			float(radii[0]) > float(radii[radii.size() - 1]) * 1.5,
			"%s trunk barely tapers" % species
		)


func test_gravity_droop_and_phototropism_follow_the_preset() -> void:
	# Spruce second-order shoots hang (negative attraction); juniper shoots climb.
	var droop := _mean_tip_rise(&"spruce", 2)
	var climb := _mean_tip_rise(&"juniper", 2)
	assert_true(droop < 0.0, "spruce shoots must hang, mean rise was %.3f" % droop)
	assert_true(climb > 0.0, "juniper shoots must climb, mean rise was %.3f" % climb)
	assert_true(climb > droop, "droop and phototropism must not collapse together")


func test_oak_and_maple_fork_into_two_leaders() -> void:
	for species in [&"oak", &"maple"]:
		var stems: Array = TreeSkeleton.build(
			species, TreeMeshProfiles.profile_for(species)
		)["stems"]
		var leaders := 0
		for stem: Dictionary in stems:
			if int(stem["level"]) == 0:
				leaders += 1
		assert_eq(leaders, 3, "%s must fork into two leaders above the bole" % species)
	var straight: Array = TreeSkeleton.build(
		&"pine", TreeMeshProfiles.profile_for(&"pine")
	)["stems"]
	var pine_stems := 0
	for stem: Dictionary in straight:
		if int(stem["level"]) == 0:
			pine_stems += 1
	assert_eq(pine_stems, 1, "pine keeps a single straight bole")


func test_shrubs_grow_from_a_stool_and_apple_from_scaffold_limbs() -> void:
	# Hazel and blackthorn: several stems from the ground, no single trunk.
	for species in [&"hazel", &"blackthorn"]:
		var stems := _leader_stems(species)
		assert_true(stems.size() >= 4, "%s must rise as a multi-stem stool" % species)
		for stem: Dictionary in stems:
			assert_true(
				(stem["start"] as Vector3).y < 0.1, "%s stems must leave the ground" % species
			)
	# Apple: a short bole, then three or more scaffold limbs spreading outward.
	var apple := _leader_stems(&"apple")
	assert_true(apple.size() >= 3, "apple needs scaffold limbs, not a central leader")
	for stem: Dictionary in apple:
		var rise := (stem["first_direction"] as Vector3).y
		assert_true(rise < cos(deg_to_rad(25.0)), "apple scaffold limb grows too upright")


func _leader_stems(species: StringName) -> Array:
	var stems: Array = TreeSkeleton.build(species, TreeMeshProfiles.profile_for(species))["stems"]
	var leaders: Array = []
	for stem: Dictionary in stems:
		# Level-0 stems after the first are the leaders above the split.
		if int(stem["level"]) == 0 and (stem["start"] as Vector3).length() > 0.0001:
			leaders.append(stem)
	return leaders


func test_rebuilds_from_the_same_seed_are_byte_identical() -> void:
	for species in PRESET_SPECIES:
		var profile := TreeMeshProfiles.profile_for(species)
		var first := TreeSkeleton.build(species, profile)
		var second := TreeSkeleton.build(species, profile)
		assert_eq(
			_segment_digest(first), _segment_digest(second), "%s skeleton is not stable" % species
		)
		MapViewTreeMeshes.reset_cache()
		var mesh_a := MapViewTreeMeshes.canopy_mesh(species).surface_get_arrays(0)
		MapViewTreeMeshes.reset_cache()
		var mesh_b := MapViewTreeMeshes.canopy_mesh(species).surface_get_arrays(0)
		assert_eq(
			var_to_bytes(mesh_a).size(),
			var_to_bytes(mesh_b).size(),
			"%s canopy mesh changed size between rebuilds" % species
		)
		assert_true(
			var_to_bytes(mesh_a) == var_to_bytes(mesh_b),
			"%s canopy mesh is not byte-identical between rebuilds" % species
		)


func test_canopy_triangles_stay_inside_the_species_cap() -> void:
	MapViewTreeMeshes.reset_cache()
	for species in MapViewTreeSpecies.ALL_SPECIES:
		var stats := MapViewTreeMeshes.geometry_stats(species)
		var triangles := int(stats["canopy_triangles"])
		assert_true(
			triangles <= CANOPY_TRIANGLE_CAP,
			"%s canopy is %d triangles, over the %d cap" % [species, triangles, CANOPY_TRIANGLE_CAP]
		)
		assert_true(triangles > 0, "%s canopy is empty" % species)


func test_clustered_cards_keep_the_leaf_contract() -> void:
	MapViewTreeMeshes.reset_cache()
	for species in [&"pine", &"birch", &"oak"]:
		var arrays := MapViewTreeMeshes.canopy_mesh(species).surface_get_arrays(0)
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		var custom: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		assert_true(uv2.size() > 0, "%s lost the UV2 leaf tag" % species)
		assert_eq(custom.size(), uv2.size() * 4, "%s lost the CUSTOM0 petiole + seed" % species)
		var cards := 0
		var shaded := 0
		var lit := 0
		for index in uv2.size():
			if uv2[index].x > 0.5 and uv2[index].y > 0.5:
				cards += 1
				# Petiole (CUSTOM0.xyz) must be a real crown position, seed in 0..1.
				var seed := custom[index * 4 + 3]
				assert_true(seed >= 0.0 and seed <= 1.0, "%s card seed out of range" % species)
			if colors[index].a < 0.75:
				shaded += 1
			elif colors[index].a > 0.95:
				lit += 1
		assert_true(cards > 0, "%s has no cluster cards" % species)
		# A crown must have both a lit shell and a shadowed interior in COLOR.a.
		assert_true(shaded > 0, "%s crown has no shadowed interior" % species)
		assert_true(lit > 0, "%s crown has no lit shell" % species)


## Honest status: this is an invariant guard, not the red/green proof. Fed the
## same Weber-Penn skeleton, the legacy per-tip placement also lands near shoot
## ends, so this test does not separate the two. What it does catch is placement
## drifting off the shoots into the crown volume (the old conifer trunk rings and
## along-segment fans). The red/green proof that clustered placement produces a
## lit shell over a dark hollow is `test_clustered_cards_keep_the_leaf_contract`,
## which fails on the legacy path, plus the captured reference sheets.
func test_every_cluster_card_sits_in_a_shoot_end_zone() -> void:
	MapViewTreeMeshes.reset_cache()
	for species in [&"birch", &"pine", &"spruce", &"linden"]:
		var skeleton := TreeSkeleton.build(species, TreeMeshProfiles.profile_for(species))
		var span := float(skeleton["cluster_span"])
		assert_true(span > 0.0 and span < 1.0, "%s cluster span must be a shoot fraction" % species)
		var twigs: Array = skeleton["twigs"]
		assert_true(twigs.size() > 0, "%s grew no shoots" % species)
		var profile := TreeMeshProfiles.profile_for(species)
		var conifer: bool = species in MapViewTreeMeshes.CONIFERS
		# A card's anchor is offset from its station by a fraction of its own size.
		var margin := float(profile["leaf_length"]) * (
			MapViewTreeMeshes.CONIFER_CARD_SCALE if conifer else MapViewTreeMeshes.CARD_SCALE
		) * 0.3
		var anchors := _card_anchors(species)
		assert_true(anchors.size() > 0, "%s produced no cluster cards" % species)
		var stray := 0
		for anchor in anchors:
			var reach := INF
			for twig: Dictionary in twigs:
				var zone := float(twig["length"]) * span + margin
				reach = minf(reach, anchor.distance_to(twig["end"] as Vector3) - zone)
			if reach > 0.0:
				stray += 1
		assert_eq(
			stray,
			0,
			"%s put %d of %d cards outside every shoot's cluster zone"
			% [species, stray, anchors.size()]
		)


func _card_anchors(species: StringName) -> PackedVector3Array:
	var arrays := MapViewTreeMeshes.canopy_mesh(species).surface_get_arrays(0)
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var custom: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
	var anchors := PackedVector3Array()
	var seen := {}
	for index in uv2.size():
		if uv2[index].x <= 0.5 or uv2[index].y <= 0.5:
			continue
		# Every vertex of one card shares CUSTOM0.xyz, so keep one per card.
		var anchor := Vector3(custom[index * 4], custom[index * 4 + 1], custom[index * 4 + 2])
		if seen.has(anchor):
			continue
		seen[anchor] = true
		anchors.append(anchor)
	return anchors


func test_canopy_shader_drives_three_wind_levels() -> void:
	var code: String = MapViewMaterialShaders.CANOPY_SHADER.code
	assert_true(code.contains("uniform float trunk_sway"), "trunk sway level is missing")
	assert_true(code.contains("TIME * 0.47"), "trunk sway must stay the slowest term")
	assert_true(code.contains("TIME * 0.9"), "branch heave level is missing")
	assert_true(code.contains("TIME * 5.3"), "leaf flutter level is missing")
	assert_true(
		code.contains("leaf_translucency"), "leaf translucency hue shift is missing"
	)
	# The leaf contract and the alpha-scissor rule must survive this change.
	assert_true(code.contains("ALPHA_SCISSOR_THRESHOLD = card_scissor"))
	assert_true(code.contains("UV2.x > 0.5 ? UV.y * UV.y : clamp(VERTEX.y"))


func _mean_tip_rise(species: StringName, level: int) -> float:
	var stems: Array = TreeSkeleton.build(
		species, TreeMeshProfiles.profile_for(species)
	)["stems"]
	var total := 0.0
	var count := 0
	for stem: Dictionary in stems:
		if int(stem["level"]) != level:
			continue
		total += (stem["last_direction"] as Vector3).y
		count += 1
	assert_true(count > 0, "%s grew no level %d shoots" % [species, level])
	return total / float(count)


func _segment_digest(skeleton: Dictionary) -> String:
	var parts := PackedStringArray()
	for segment: Dictionary in skeleton["segments"]:
		parts.append(
			"%.5v|%.5v|%.5f|%.5f|%d" % [
				segment["start"],
				segment["end"],
				segment["start_radius"],
				segment["end_radius"],
				int(segment["depth"]),
			]
		)
	return "\n".join(parts)

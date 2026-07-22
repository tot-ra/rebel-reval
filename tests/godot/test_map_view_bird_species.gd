extends "res://tests/godot/test_case.gd"

const BirdSpecies := preload("res://scripts/map/view3d/map_view_bird_species.gd")
const BirdMeshes := preload("res://scripts/map/view3d/map_view_bird_meshes.gd")


func test_catalog_exposes_thirty_stable_profiled_bird_ids() -> void:
	assert_eq(BirdSpecies.ALL_SPECIES.size(), 30)
	var ids: Dictionary = {}
	var groups: Dictionary = {}
	for species in BirdSpecies.ALL_SPECIES:
		assert_true(BirdSpecies.is_known_species(species), String(species))
		var bird_id := BirdSpecies.id_for(species)
		assert_true(String(bird_id).begins_with("bird."), String(species))
		assert_false(ids.has(bird_id), "duplicate stable bird ID: %s" % bird_id)
		ids[bird_id] = true
		var parsed := BirdSpecies.parse_variant(bird_id)
		assert_eq(parsed.get("species"), species, String(bird_id))

		var profile := BirdSpecies.profile_for(species)
		assert_false(profile.is_empty(), "%s needs a profile" % species)
		var group: StringName = profile.get("group", &"")
		assert_true(BirdSpecies.is_known_group(group), "%s needs a known silhouette group" % species)
		groups[group] = true
		assert_true(float(profile.get("scale_m", 0.0)) > 0.0, "%s needs physical scale" % species)
		assert_true(BirdSpecies.is_known_pose(profile.get("pose", &"")), "%s needs a default pose" % species)

		var song := BirdSpecies.song_profile_for(species)
		assert_true(String(song.get("cue", "")).begins_with("bird."), "%s needs a stable song cue" % species)
		assert_true(not String(song.get("kind", "")).is_empty(), "%s needs an acoustic profile" % species)
		var cadence: Vector2 = song.get("cadence_s", Vector2.ZERO)
		assert_true(cadence.x > 0.0 and cadence.y > cadence.x, "%s needs a bounded cadence" % species)
	assert_eq(groups.size(), BirdSpecies.ALL_GROUPS.size())


func test_every_species_supports_cached_pose_variants_with_bounded_geometry() -> void:
	var default_signatures: Dictionary = {}
	for species in BirdSpecies.ALL_SPECIES:
		for pose in BirdSpecies.ALL_POSES:
			var variant := StringName("bird.%s.%s" % [species, pose])
			var parsed := BirdSpecies.parse_variant(variant)
			assert_eq(parsed.get("pose"), pose, String(variant))
			var mesh := BirdMeshes.mesh_for(species, pose)
			assert_true(mesh is ArrayMesh, "%s needs a procedural mesh" % variant)
			assert_true(mesh.get_surface_count() > 0, "%s mesh needs geometry" % variant)
			assert_true(mesh == BirdMeshes.mesh_for(species, pose), "%s mesh must be cached" % variant)
			var stats := BirdMeshes.geometry_stats(species, pose)
			assert_true(int(stats.get("triangles", 0)) >= 100, "%s silhouette is under-modeled" % variant)
			assert_true(int(stats.get("triangles", 9999)) <= 320, "%s exceeds the low-poly budget" % variant)
		var default_stats := BirdMeshes.geometry_stats(species)
		var bounds: AABB = default_stats.get("aabb", AABB())
		var signature := "%0.2f:%0.2f:%0.2f" % [bounds.size.x, bounds.size.y, bounds.size.z]
		default_signatures[signature] = true
	assert_true(default_signatures.size() >= 10, "reference catalog needs at least ten distinct silhouette envelopes")


func test_district_spawn_weights_cover_every_context_without_spawning() -> void:
	for species in BirdSpecies.ALL_SPECIES:
		var weights := BirdSpecies.spawn_weights_for(species)
		assert_eq(weights.size(), BirdSpecies.ALL_CONTEXTS.size(), "%s needs every district context" % species)
		var positive_contexts := 0
		for context in BirdSpecies.ALL_CONTEXTS:
			var weight := float(weights.get(context, -1.0))
			assert_true(weight >= 0.0 and weight <= 1.0, "%s/%s weight must be normalized" % [species, context])
			if weight > 0.0:
				positive_contexts += 1
		assert_true(positive_contexts > 0, "%s needs at least one plausible context" % species)

	assert_true(
		BirdSpecies.spawn_weight(BirdSpecies.SPECIES_HERRING_GULL, BirdSpecies.CONTEXT_HARBOR)
		> BirdSpecies.spawn_weight(BirdSpecies.SPECIES_HERRING_GULL, BirdSpecies.CONTEXT_WOODLAND)
	)
	assert_true(
		BirdSpecies.spawn_weight(BirdSpecies.SPECIES_SKYLARK, BirdSpecies.CONTEXT_FORELAND)
		> BirdSpecies.spawn_weight(BirdSpecies.SPECIES_SKYLARK, BirdSpecies.CONTEXT_LOWER_TOWN)
	)
	assert_true(
		BirdSpecies.spawn_weight(BirdSpecies.SPECIES_TAWNY_OWL, BirdSpecies.CONTEXT_WOODLAND)
		> BirdSpecies.spawn_weight(BirdSpecies.SPECIES_TAWNY_OWL, BirdSpecies.CONTEXT_MARKET)
	)

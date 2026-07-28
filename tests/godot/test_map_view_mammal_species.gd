extends "res://tests/godot/test_case.gd"

const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")
const MammalMeshes := preload("res://scripts/map/view3d/map_view_mammal_meshes.gd")

## Catalog silhouettes stay cheap, but the two Lower Town urban actors are seen
## from close range on the street and carry facial and paw detail, so they get a
## wider budget. Concurrency is capped at eight urban actors (P2-024).
const REFERENCE_TRIANGLE_BUDGET := 420
const DETAILED_TRIANGLE_BUDGET := 680
const DETAILED_SPECIES: Array[StringName] = [
	MammalSpecies.SPECIES_CAT,
	MammalSpecies.SPECIES_RAT,
]


func test_catalog_exposes_thirty_stable_profiled_mammal_ids() -> void:
	assert_eq(MammalSpecies.ALL_SPECIES.size(), 30)
	var ids: Dictionary = {}
	var groups: Dictionary = {}
	for species in MammalSpecies.ALL_SPECIES:
		assert_true(MammalSpecies.is_known_species(species), String(species))
		var fauna_id := MammalSpecies.id_for(species)
		assert_true(String(fauna_id).begins_with("fauna."), String(species))
		assert_false(ids.has(fauna_id), "duplicate stable fauna ID: %s" % fauna_id)
		ids[fauna_id] = true
		var parsed := MammalSpecies.parse_variant(fauna_id)
		assert_eq(parsed.get("species"), species, String(fauna_id))

		var profile := MammalSpecies.profile_for(species)
		assert_false(profile.is_empty(), "%s needs a profile" % species)
		var group: StringName = profile.get("group", &"")
		assert_true(MammalSpecies.is_known_group(group), "%s needs a known silhouette group" % species)
		groups[group] = true
		assert_true(float(profile.get("scale_m", 0.0)) > 0.0, "%s needs physical scale" % species)
		assert_true(MammalSpecies.is_known_pose(profile.get("pose", &"")), "%s needs a default pose" % species)
	assert_eq(groups.size(), MammalSpecies.ALL_GROUPS.size())


func test_every_species_supports_cached_pose_variants_with_bounded_geometry() -> void:
	var default_signatures: Dictionary = {}
	for species in MammalSpecies.ALL_SPECIES:
		for pose in MammalSpecies.ALL_POSES:
			var variant := StringName("fauna.%s.%s" % [species, pose])
			var parsed := MammalSpecies.parse_variant(variant)
			assert_eq(parsed.get("pose"), pose, String(variant))
			var mesh := MammalMeshes.mesh_for(species, pose)
			assert_true(mesh is ArrayMesh, "%s needs a procedural mesh" % variant)
			assert_true(mesh.get_surface_count() > 0, "%s mesh needs geometry" % variant)
			assert_true(mesh == MammalMeshes.mesh_for(species, pose), "%s mesh must be cached" % variant)
			var stats := MammalMeshes.geometry_stats(species, pose)
			var triangles := int(stats.get("triangles", 0))
			var detail_floor := 500 if species in DETAILED_SPECIES else 80
			assert_true(triangles >= detail_floor, "%s silhouette is under-modeled" % variant)
			var budget := DETAILED_TRIANGLE_BUDGET if species in DETAILED_SPECIES else REFERENCE_TRIANGLE_BUDGET
			assert_true(triangles <= budget, "%s exceeds the low-poly budget" % variant)
		var default_stats := MammalMeshes.geometry_stats(species)
		var bounds: AABB = default_stats.get("aabb", AABB())
		var signature := "%0.2f:%0.2f:%0.2f" % [bounds.size.x, bounds.size.y, bounds.size.z]
		default_signatures[signature] = true
	assert_true(default_signatures.size() >= 8, "reference catalog needs at least eight distinct silhouette envelopes")


func test_district_spawn_weights_cover_every_context_without_spawning() -> void:
	for species in MammalSpecies.ALL_SPECIES:
		var weights := MammalSpecies.spawn_weights_for(species)
		assert_eq(weights.size(), MammalSpecies.ALL_CONTEXTS.size(), "%s needs every district context" % species)
		var positive_contexts := 0
		for context in MammalSpecies.ALL_CONTEXTS:
			var weight := float(weights.get(context, -1.0))
			assert_true(weight >= 0.0 and weight <= 1.0, "%s/%s weight must be normalized" % [species, context])
			if weight > 0.0:
				positive_contexts += 1
		assert_true(positive_contexts > 0, "%s needs at least one plausible context" % species)

	assert_true(
		MammalSpecies.spawn_weight(MammalSpecies.SPECIES_GREY_SEAL, MammalSpecies.CONTEXT_HARBOR)
		> MammalSpecies.spawn_weight(MammalSpecies.SPECIES_GREY_SEAL, MammalSpecies.CONTEXT_LOWER_TOWN)
	)
	assert_true(
		MammalSpecies.spawn_weight(MammalSpecies.SPECIES_HARE, MammalSpecies.CONTEXT_FORELAND)
		> MammalSpecies.spawn_weight(MammalSpecies.SPECIES_HARE, MammalSpecies.CONTEXT_MARKET)
	)
	assert_true(
		MammalSpecies.spawn_weight(MammalSpecies.SPECIES_CAT, MammalSpecies.CONTEXT_LOWER_TOWN)
		> MammalSpecies.spawn_weight(MammalSpecies.SPECIES_CAT, MammalSpecies.CONTEXT_WOODLAND)
	)


func test_procedural_mesh_uses_lit_surface_material() -> void:
	MammalMeshes.reset_cache()
	MammalSpecies.reset_surface_material_cache()
	for species in MammalSpecies.ALL_SPECIES:
		var pose := MammalSpecies.default_pose(species)
		var mesh := MammalMeshes.mesh_for(species, pose)
		assert_true(mesh.get_surface_count() > 0, "%s needs a lit surface" % species)
		_assert_lit_fauna_material(mesh.surface_get_material(0), String(species))


func _assert_lit_fauna_material(material: Material, label: String) -> void:
	assert_true(material is StandardMaterial3D, "%s surface must be StandardMaterial3D" % label)
	var std := material as StandardMaterial3D
	assert_ne(
		std.shading_mode,
		BaseMaterial3D.SHADING_MODE_UNSHADED,
		"%s must react to scene lighting" % label
	)
	assert_true(std.normal_enabled and std.normal_texture != null, "%s needs fur normal response" % label)
	assert_true(std.roughness > 0.05 and std.roughness < 1.0, "%s roughness must be authored" % label)
	assert_true(std.vertex_color_use_as_albedo, "%s keeps vertex colour as albedo tint" % label)

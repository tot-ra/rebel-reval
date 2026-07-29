extends "res://tests/godot/test_case.gd"

const BirdAssets := preload("res://scripts/map/view3d/map_view_bird_assets.gd")
const BirdMeshes := preload("res://scripts/map/view3d/map_view_bird_meshes.gd")
const BirdSpecies := preload("res://scripts/map/view3d/map_view_bird_species.gd")


func test_catalog_uses_only_the_reviewed_authored_glbs() -> void:
	# Static-pose allowlist plus P2-034 harbour gull flap cycles.
	var authored_static := {
		BirdSpecies.SPECIES_MALLARD: BirdSpecies.POSE_STANDING,
		BirdSpecies.SPECIES_HOUSE_SPARROW: BirdSpecies.POSE_PERCHED,
		BirdSpecies.SPECIES_HERRING_GULL: BirdSpecies.POSE_GLIDING,
		BirdSpecies.SPECIES_COMMON_GULL: BirdSpecies.POSE_GLIDING,
		BirdSpecies.SPECIES_COMMON_TERN: BirdSpecies.POSE_GLIDING,
	}
	var authored_flap: Array[StringName] = [
		BirdSpecies.SPECIES_HERRING_GULL,
		BirdSpecies.SPECIES_COMMON_GULL,
		BirdSpecies.SPECIES_COMMON_TERN,
	]
	for species in BirdSpecies.ALL_SPECIES:
		for pose in BirdSpecies.ALL_POSES:
			assert_eq(
				BirdAssets.has_authored_pose(species, pose),
				authored_static.get(species, &"") == pose,
				"Unexpected authored bird pose %s/%s" % [species, pose]
			)
		assert_eq(
			BirdAssets.has_complete_flap_cycle(species),
			species in authored_flap,
			"%s flap-cycle authorship mismatch" % species
		)


func test_mesh_for_prefers_reviewed_authored_defaults_and_falls_back_for_the_rest() -> void:
	BirdMeshes.reset_cache()
	var authored_defaults: Array[StringName] = [
		BirdSpecies.SPECIES_MALLARD,
		BirdSpecies.SPECIES_HOUSE_SPARROW,
		BirdSpecies.SPECIES_HERRING_GULL,
		BirdSpecies.SPECIES_COMMON_GULL,
		BirdSpecies.SPECIES_COMMON_TERN,
	]
	for species in BirdSpecies.ALL_SPECIES:
		var pose := BirdSpecies.default_pose(species)
		var mesh := BirdMeshes.mesh_for(species, pose)
		assert_true(mesh is ArrayMesh, "%s needs a mesh" % species)
		assert_eq(BirdMeshes.uses_authored_mesh(species, pose), species in authored_defaults)
		var stats := BirdMeshes.geometry_stats(species, pose)
		assert_true(int(stats.get("triangles", 0)) >= 100)
		if species not in authored_defaults:
			assert_true(int(stats.get("triangles", 9999)) <= 512)


func test_harbour_gull_flap_cycle_uses_authored_frames() -> void:
	BirdMeshes.reset_cache()
	assert_true(BirdAssets.has_complete_flap_cycle(BirdSpecies.SPECIES_HERRING_GULL))
	var cycle := BirdMeshes.flap_cycle(BirdSpecies.SPECIES_HERRING_GULL)
	assert_eq(cycle.size(), BirdAssets.FLAP_FRAME_COUNT)
	for mesh in cycle:
		assert_true(mesh is ArrayMesh)
		assert_true((mesh as ArrayMesh).get_surface_count() > 0)
	var neutral := BirdMeshes.mesh_for(BirdSpecies.SPECIES_HERRING_GULL, BirdSpecies.POSE_GLIDING)
	assert_true(neutral is ArrayMesh)
	# Neutral gliding.glb matches flap frame 02 (MapViewBirdAssets convention).
	assert_true((cycle[2] as ArrayMesh).get_aabb().is_equal_approx(neutral.get_aabb()))


func test_bird_asset_paths_follow_runtime_convention() -> void:
	assert_eq(
		BirdAssets.pose_glb_path(BirdSpecies.SPECIES_HERRING_GULL, BirdSpecies.POSE_GLIDING),
		"res://assets/birds/herring_gull/gliding.glb"
	)
	assert_eq(
		BirdAssets.flap_frame_path(BirdSpecies.SPECIES_HERRING_GULL, 2),
		"res://assets/birds/herring_gull/gliding_02.glb"
	)


func test_procedural_mesh_uses_lit_surface_material() -> void:
	BirdMeshes.reset_cache()
	BirdSpecies.reset_surface_material_cache()
	var authored_gliding: Array[StringName] = [
		BirdSpecies.SPECIES_HERRING_GULL,
		BirdSpecies.SPECIES_COMMON_GULL,
		BirdSpecies.SPECIES_COMMON_TERN,
	]
	for species in BirdSpecies.ALL_SPECIES:
		var mesh := BirdMeshes.mesh_for(species, BirdSpecies.POSE_GLIDING)
		assert_true(mesh.get_surface_count() > 0, "%s needs a lit surface" % species)
		_assert_lit_fauna_material(
			mesh.surface_get_material(0),
			species,
			species not in authored_gliding
		)


func _assert_lit_fauna_material(material: Material, label: String, expect_vertex_tint: bool) -> void:
	assert_true(material is StandardMaterial3D, "%s surface must be StandardMaterial3D" % label)
	var std := material as StandardMaterial3D
	assert_ne(
		std.shading_mode,
		BaseMaterial3D.SHADING_MODE_UNSHADED,
		"%s must react to scene lighting" % label
	)
	assert_true(std.normal_enabled and std.normal_texture != null, "%s needs feather normal response" % label)
	# Authored harbour-gull GLBs use roughness textures; procedural birds keep a scalar.
	var has_roughness_tex := std.roughness_texture != null
	assert_true(
		has_roughness_tex or (std.roughness > 0.05 and std.roughness < 1.0),
		"%s roughness must be authored" % label
	)
	if expect_vertex_tint:
		assert_true(std.vertex_color_use_as_albedo, "%s keeps vertex colour as albedo tint" % label)

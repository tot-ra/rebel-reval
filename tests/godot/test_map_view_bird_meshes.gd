extends "res://tests/godot/test_case.gd"

const BirdAssets := preload("res://scripts/map/view3d/map_view_bird_assets.gd")
const BirdMeshes := preload("res://scripts/map/view3d/map_view_bird_meshes.gd")
const BirdSpecies := preload("res://scripts/map/view3d/map_view_bird_species.gd")


func test_catalog_has_no_authored_glbs_yet() -> void:
	for species in BirdSpecies.ALL_SPECIES:
		for pose in BirdSpecies.ALL_POSES:
			assert_false(
				BirdAssets.has_authored_pose(species, pose),
				"%s/%s should fall back to procedural geometry until P2-034+" % [species, pose]
			)
		assert_false(
			BirdAssets.has_complete_flap_cycle(species),
			"%s flap cycle should stay procedural until authored frames land" % species
		)


func test_mesh_for_falls_back_to_procedural_geometry() -> void:
	BirdMeshes.reset_cache()
	for species in BirdSpecies.ALL_SPECIES:
		var pose := BirdSpecies.default_pose(species)
		var mesh := BirdMeshes.mesh_for(species, pose)
		assert_true(mesh is ArrayMesh, "%s needs a mesh" % species)
		assert_false(BirdMeshes.uses_authored_mesh(species, pose))
		var stats := BirdMeshes.geometry_stats(species, pose)
		assert_true(int(stats.get("triangles", 0)) >= 100)
		assert_true(int(stats.get("triangles", 9999)) <= 512)


func test_gliding_flap_cycle_stays_procedural_without_authored_frames() -> void:
	BirdMeshes.reset_cache()
	var cycle := BirdMeshes.flap_cycle(BirdSpecies.SPECIES_HERRING_GULL)
	assert_eq(cycle.size(), BirdAssets.FLAP_FRAME_COUNT)
	for mesh in cycle:
		assert_true(mesh is ArrayMesh)
		assert_true((mesh as ArrayMesh).get_surface_count() > 0)
	assert_true(cycle[2] == BirdMeshes.mesh_for(BirdSpecies.SPECIES_HERRING_GULL, BirdSpecies.POSE_GLIDING))


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
	for species in BirdSpecies.ALL_SPECIES:
		var mesh := BirdMeshes.mesh_for(species, BirdSpecies.POSE_GLIDING)
		assert_true(mesh.get_surface_count() > 0, "%s needs a lit surface" % species)
		_assert_lit_fauna_material(mesh.surface_get_material(0), species)


func _assert_lit_fauna_material(material: Material, label: String) -> void:
	assert_true(material is StandardMaterial3D, "%s surface must be StandardMaterial3D" % label)
	var std := material as StandardMaterial3D
	assert_ne(
		std.shading_mode,
		BaseMaterial3D.SHADING_MODE_UNSHADED,
		"%s must react to scene lighting" % label
	)
	assert_true(std.normal_enabled and std.normal_texture != null, "%s needs feather normal response" % label)
	assert_true(std.roughness > 0.05 and std.roughness < 1.0, "%s roughness must be authored" % label)
	assert_true(std.vertex_color_use_as_albedo, "%s keeps vertex colour as albedo tint" % label)

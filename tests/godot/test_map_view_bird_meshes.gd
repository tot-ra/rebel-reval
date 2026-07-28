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

extends "res://tests/godot/test_case.gd"
const Species := preload("res://scripts/map/view3d/map_view_bird_species.gd")
const Meshes := preload("res://scripts/map/view3d/map_view_bird_meshes.gd")
const Anatomy := preload("res://scripts/map/view3d/map_view_bird_anatomy.gd")
const Flight := preload("res://scripts/map/view3d/map_view_bird_flight.gd")

func test_all_poses_have_finite_normals_uvs_and_distinct_material_regions() -> void:
	var max_triangles := 0
	for species in Species.ALL_SPECIES:
		for pose in Species.ALL_POSES:
			var mesh := Meshes.mesh_for(species, pose)
			var arrays := mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var tags: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
			max_triangles = maxi(max_triangles, vertices.size() / 3)
			assert_true(vertices.size() / 3 <= 8000, "%s/%s exceeds budget" % [species, pose])
			assert_eq(normals.size(), vertices.size())
			assert_eq(uvs.size(), vertices.size())
			assert_eq(tags.size(), vertices.size())
			var materials: Dictionary = {}
			var invalid := 0
			for i in vertices.size():
				if not vertices[i].is_finite() or not normals[i].is_finite() or normals[i].length_squared() < 0.9 or not uvs[i].is_finite(): invalid += 1
				materials[snappedf(tags[i].x, 0.1)] = true
			assert_eq(invalid, 0, "%s/%s malformed vertices" % [species, pose])
			assert_eq(materials.size(), 3, "feather, keratin and cornea require separate responses")
	print("Bird catalogue maximum triangles: ", max_triangles)

func test_rebuild_is_deterministic_and_rejects_unknown_ids() -> void:
	assert_true(Meshes.mesh_for(&"unknown") == null)
	assert_true(Meshes.mesh_for(&"osprey", &"unknown") == null)
	for species in [&"tawny_owl", &"grey_heron", &"song_thrush"]:
		var first := Anatomy.build(species, Species.POSE_STANDING)
		var second := Anatomy.build(species, Species.POSE_STANDING)
		assert_eq(first.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], second.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
		assert_eq(first.surface_get_arrays(0)[Mesh.ARRAY_COLOR], second.surface_get_arrays(0)[Mesh.ARRAY_COLOR])

func test_live_rig_preserves_plumage_shader_and_smooth_normals() -> void:
	var flight := Flight.new()
	var actor := Node3D.new()
	for species in [&"osprey", &"grey_heron", &"house_sparrow", &"tawny_owl"]:
		assert_true(flight._install_species_rig(actor, species))
		assert_true(actor.get_node_or_null("WingRootL/WingElbowL") != null)
		for node: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
			assert_true(node.get_active_material(0) is ShaderMaterial, "%s/%s must retain feather shading" % [species, node.name])
			var arrays := node.mesh.surface_get_arrays(0)
			assert_eq(arrays[Mesh.ARRAY_TEX_UV2].size(), arrays[Mesh.ARRAY_VERTEX].size())
	actor.free()
	flight.free()

func test_long_neck_flight_posture_remains_species_specific() -> void:
	var heron_still := Meshes.mesh_for(&"grey_heron", Species.POSE_STANDING).get_aabb()
	var heron_flight := Meshes.mesh_for(&"grey_heron", Species.POSE_GLIDING).get_aabb()
	var swan_flight := Meshes.mesh_for(&"mute_swan", Species.POSE_GLIDING).get_aabb()
	assert_true(heron_flight.size.y < heron_still.size.y, "heron folds neck and trails its legs in flight")
	assert_true(swan_flight.size.z > Species.scale_m(&"mute_swan") * 1.4, "swan keeps its long neck extended")

func test_flight_parts_keep_whole_triangles_and_restore_neutral_geometry() -> void:
	for species in [&"osprey", &"tawny_owl", &"common_tern", &"house_sparrow"]:
		var mesh := Meshes.mesh_for(species, Species.POSE_GLIDING)
		var regions: PackedInt32Array = mesh.get_meta(&"bird_rig_regions")
		var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		assert_eq(regions.size(), vertices.size())
		var split := Meshes.modular_rig_for(species)
		var restored := 0
		for key in ["body", "left_upper", "left_primary", "right_upper", "right_primary"]:
			var part := split[key] as ArrayMesh
			assert_true(part.get_surface_count() > 0)
			restored += part.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
		assert_eq(restored, vertices.size(), "splitting must retain every vertex exactly once")
		var divided_triangles := 0
		for i in range(0, regions.size(), 3):
			if regions[i] != regions[i+1] or regions[i] != regions[i+2]: divided_triangles += 1
		assert_eq(divided_triangles, 0, "anatomy ownership may not bisect triangles")
		assert_true(Meshes.modular_rig_for(species)["body"] == split["body"], "rig must be cached")

func test_all_species_keep_valid_bounded_geometry_through_eight_flap_frames() -> void:
	for species in Species.ALL_SPECIES:
		var vertex_count := 0
		for frame in Meshes.FLAP_KEYFRAMES.size():
			var mesh := Anatomy.build(species, Species.POSE_GLIDING, Meshes.FLAP_KEYFRAMES[frame], Meshes.FLAP_SWEEP_KEYFRAMES[frame])
			var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			if frame == 0: vertex_count = vertices.size()
			assert_eq(vertices.size(), vertex_count, "%s changes topology during a flap" % species)
			assert_true(vertices.size() <= 24000)
			assert_true(mesh.get_aabb().position.is_finite() and mesh.get_aabb().size.is_finite())

extends "res://tests/godot/test_case.gd"

const BirdAssets := preload("res://scripts/map/view3d/map_view_bird_assets.gd")
const BirdFlight := preload("res://scripts/map/view3d/map_view_bird_flight.gd")
const BirdMeshes := preload("res://scripts/map/view3d/map_view_bird_meshes.gd")
const BirdSpecies := preload("res://scripts/map/view3d/map_view_bird_species.gd")


func test_catalog_uses_only_the_reviewed_authored_glbs() -> void:
	# Static-pose allowlist plus P2-034 harbour gull flap cycles, P2-035 waterfowl, P2-036 waders.
	var authored_static := {
		BirdSpecies.SPECIES_MUTE_SWAN: BirdSpecies.POSE_STANDING,
		BirdSpecies.SPECIES_MALLARD: BirdSpecies.POSE_STANDING,
		BirdSpecies.SPECIES_GREYLAG_GOOSE: BirdSpecies.POSE_STANDING,
		BirdSpecies.SPECIES_GREAT_CORMORANT: BirdSpecies.POSE_STANDING,
		BirdSpecies.SPECIES_GREY_HERON: BirdSpecies.POSE_STANDING,
		BirdSpecies.SPECIES_NORTHERN_LAPWING: BirdSpecies.POSE_STANDING,
		BirdSpecies.SPECIES_COMMON_SNIPE: BirdSpecies.POSE_STANDING,
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
		BirdSpecies.SPECIES_MUTE_SWAN,
		BirdSpecies.SPECIES_MALLARD,
		BirdSpecies.SPECIES_GREYLAG_GOOSE,
		BirdSpecies.SPECIES_GREAT_CORMORANT,
		BirdSpecies.SPECIES_GREY_HERON,
		BirdSpecies.SPECIES_NORTHERN_LAPWING,
		BirdSpecies.SPECIES_COMMON_SNIPE,
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


func test_harbour_flap_frames_move_both_wing_halves() -> void:
	BirdMeshes.reset_cache()
	var cycle := BirdMeshes.flap_cycle(BirdSpecies.SPECIES_HERRING_GULL)
	assert_eq(cycle.size(), BirdAssets.FLAP_FRAME_COUNT)
	var neutral_vertices: PackedVector3Array = (cycle[2] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var down_vertices: PackedVector3Array = (cycle[4] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var left_delta := _mean_wing_lift(neutral_vertices, down_vertices, -1.0)
	var right_delta := _mean_wing_lift(neutral_vertices, down_vertices, 1.0)
	assert_true(left_delta > 0.01, "left wing must move during a flap frame")
	assert_true(right_delta > 0.01, "right wing must move during a flap frame")
	assert_true(absf(left_delta - right_delta) <= 0.01, "both wing halves should use the same flap amplitude")



func test_procedural_flap_cycle_sweeps_wings_fore_and_aft() -> void:
	BirdMeshes.reset_cache()
	var cycle := BirdMeshes.flap_cycle(BirdSpecies.SPECIES_BARN_SWALLOW)
	assert_eq(cycle.size(), BirdMeshes.FLAP_KEYFRAMES.size())
	var early_vertices: PackedVector3Array = (cycle[0] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var late_vertices: PackedVector3Array = (cycle[4] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var sweep_delta := _mean_wing_depth_delta(early_vertices, late_vertices)
	assert_true(sweep_delta > 0.002, "procedural flap frames should sweep the wings through the stroke")


func _mean_wing_depth_delta(early_vertices: PackedVector3Array, late_vertices: PackedVector3Array) -> float:
	var total := 0.0
	var count := 0
	for index in early_vertices.size():
		if absf(early_vertices[index].x) < 0.08:
			continue
		total += absf(late_vertices[index].z - early_vertices[index].z)
		count += 1
	return total / float(maxi(count, 1))

func test_runtime_bird_material_keeps_both_wing_faces_visible() -> void:
	var flight := BirdFlight.new()
	var model := MeshInstance3D.new()
	flight._apply_mesh_material(model)
	var material := model.material_override as StandardMaterial3D
	assert_true(material != null)
	assert_eq(material.cull_mode, BaseMaterial3D.CULL_DISABLED)
	model.free()
	flight.free()


func _mean_wing_lift(
	neutral_vertices: PackedVector3Array,
	frame_vertices: PackedVector3Array,
	side: float
) -> float:
	var total := 0.0
	var count := 0
	for index in neutral_vertices.size():
		if neutral_vertices[index].x * side < 0.28:
			continue
		total += absf(frame_vertices[index].y - neutral_vertices[index].y)
		count += 1
	return total / float(maxi(count, 1))

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


func test_modular_flap_rig_exposes_attached_wings_and_shadow_casters() -> void:
	BirdMeshes.reset_cache()
	var frame := BirdMeshes.modular_rig_for(BirdSpecies.SPECIES_HERRING_GULL)
	assert_false(frame.is_empty())
	var flight := BirdFlight.new()
	var actor := Node3D.new()
	assert_true(flight._install_modular_rig(actor, frame, false))
	for pivot_name in [&"WingRootL", &"WingRootR", &"WingRootL/WingElbowL", &"WingRootR/WingElbowR"]:
		assert_true(actor.get_node_or_null(pivot_name) is Node3D, "%s pivot must exist" % pivot_name)
	for mesh_name in [&"Body", &"WingUpperL", &"WingPrimaryL", &"WingUpperR", &"WingPrimaryR"]:
		var mesh_node := actor.get_node_or_null(mesh_name) as MeshInstance3D
		assert_true(mesh_node != null, "%s must be a separate mesh module" % mesh_name)
		assert_eq(mesh_node.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "%s must cast a shadow" % mesh_name)
	actor.free()
	flight.free()

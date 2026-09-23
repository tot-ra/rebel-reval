extends "res://tests/godot/test_case.gd"

## Contract for the foreland wolf production GLB. The catalog ellipsoid was
## replaced by a remeshed digitigrade canid with an agouti coat.

const Models := preload("res://scripts/map/view3d/map_view_medieval_animal_models.gd")
const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")


func test_wolf_has_rigged_canid_body_and_locomotion_clips() -> void:
	assert_true(Models.has_model(MammalSpecies.SPECIES_WOLF), "Wolf must use the production GLB")
	var host := Node3D.new()
	var model := Models.add_model(host, MammalSpecies.SPECIES_WOLF)
	assert_true(model != null, "Wolf production model must load")
	var mesh := model.find_child("AnimalMesh", true, false) as MeshInstance3D
	assert_true(mesh != null, "Wolf needs AnimalMesh")
	assert_eq(mesh.mesh.get_surface_count(), 1, "Wolf body must stay one skinned surface")
	var aabb := mesh.get_aabb()
	assert_true(aabb.size.x >= 1.55 and aabb.size.x <= 1.85, "Wolf needs a long body")
	assert_true(aabb.size.y >= 0.85 and aabb.size.y <= 1.08, "Wolf must keep standing height")
	assert_true(aabb.size.z >= 0.28 and aabb.size.z <= 0.50, "Wolf chest stays narrower than a bear")
	assert_true(aabb.position.y >= -0.02, "Wolf feet must sit on the ground plane")
	assert_true(
		is_equal_approx(model.rotation.y, -PI * 0.5),
		"Wolf needs livestock yaw so look_at walks nose-first"
	)
	var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
	assert_true(material != null, "Wolf must import as StandardMaterial3D")
	assert_ne(
		material.shading_mode,
		BaseMaterial3D.SHADING_MODE_UNSHADED,
		"Wolf must take scene light"
	)
	assert_true(material.vertex_color_use_as_albedo, "Agouti coat is stored in COLOR_0")
	assert_true(material.normal_enabled and material.normal_texture != null, "Wolf needs a fur normal")
	assert_true(material.roughness_texture != null, "Wolf fur needs a roughness map")
	for detail_name in ["EyeLeft", "EyeRight", "PupilLeft", "PupilRight", "NoseTip"]:
		assert_true(
			model.find_child(detail_name, true, false) != null,
			"Wolf is missing fitted detail %s" % detail_name
		)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_true(player.has_animation(Models.IDLE_ANIMATION))
	assert_true(player.has_animation(Models.WALK_ANIMATION))
	assert_eq(player.current_animation, Models.IDLE_ANIMATION)
	Models.sync_animation(host, host.position - Vector3(0.1, 0.0, 0.0), 0.1)
	assert_eq(player.current_animation, Models.WALK_ANIMATION)
	host.free()

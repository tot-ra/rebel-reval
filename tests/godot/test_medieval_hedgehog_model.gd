extends "res://tests/godot/test_case.gd"

## Contract for the garden European hedgehog production GLB. The catalog ellipsoid
## was replaced by a remeshed insectivore with a separate banded keratin mantle.

const Models := preload("res://scripts/map/view3d/map_view_medieval_animal_models.gd")
const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")


func test_hedgehog_has_rigged_body_spine_mantle_and_locomotion_clips() -> void:
	assert_true(
		Models.has_model(MammalSpecies.SPECIES_HEDGEHOG),
		"Hedgehog must use the production GLB"
	)
	var host := Node3D.new()
	var model := Models.add_model(host, MammalSpecies.SPECIES_HEDGEHOG)
	assert_true(model != null, "Hedgehog production model must load")
	if model == null:
		host.free()
		return
	var mesh := model.find_child("AnimalMesh", true, false) as MeshInstance3D
	assert_true(mesh != null, "Hedgehog needs AnimalMesh")
	assert_eq(mesh.mesh.get_surface_count(), 1, "Hedgehog hide must stay one skinned surface")
	var aabb := mesh.get_aabb()
	assert_true(aabb.size.x >= 0.20 and aabb.size.x <= 0.34, "Hedgehog needs a long low body")
	assert_true(aabb.size.y >= 0.08 and aabb.size.y <= 0.16, "Hedgehog hide stays low to the ground")
	assert_true(aabb.size.x > aabb.size.y, "Hedgehog is longer than it is tall")
	assert_true(aabb.position.y >= -0.02, "Hedgehog feet must sit on the ground plane")
	var spines := model.find_child("SpineMantle", true, false) as MeshInstance3D
	assert_true(spines != null, "Hedgehog needs a keratin SpineMantle")
	var spine_aabb := spines.get_aabb()
	var hide_top := aabb.position.y + aabb.size.y
	var spine_top := spine_aabb.position.y + spine_aabb.size.y
	assert_true(spine_top > hide_top + 0.008, "Spines must rise above the hide")
	assert_true(_triangle_count(spines) >= 4000, "Spine mantle is too sparse to read as quills")
	assert_true(
		is_equal_approx(model.rotation.y, -PI * 0.5),
		"Hedgehog needs livestock yaw so look_at walks nose-first"
	)
	var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
	assert_true(material != null, "Hedgehog must import as StandardMaterial3D")
	assert_ne(
		material.shading_mode,
		BaseMaterial3D.SHADING_MODE_UNSHADED,
		"Hedgehog must take scene light"
	)
	assert_true(material.vertex_color_use_as_albedo, "Face coat is stored in COLOR_0")
	assert_true(
		material.normal_enabled and material.normal_texture != null,
		"Hedgehog fur needs a normal"
	)
	assert_true(material.roughness_texture != null, "Hedgehog fur needs a roughness map")
	var spine_material := spines.mesh.surface_get_material(0) as StandardMaterial3D
	assert_true(spine_material != null, "Spines need their own material")
	assert_true(spine_material.vertex_color_use_as_albedo, "Spine bands are stored in COLOR_0")
	assert_ne(spine_material, material, "Keratin must not share the fur material")
	for detail_name in [
		"EyeLeft",
		"EyeRight",
		"PupilLeft",
		"PupilRight",
		"NoseTip",
		"EarLeft",
		"EarRight",
		"WhiskerLeft0",
		"WhiskerRight0",
	]:
		assert_true(
			model.find_child(detail_name, true, false) != null,
			"Hedgehog is missing fitted detail %s" % detail_name
		)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_true(player.has_animation(Models.IDLE_ANIMATION))
	assert_true(player.has_animation(Models.WALK_ANIMATION))
	assert_eq(player.current_animation, Models.IDLE_ANIMATION)
	Models.sync_animation(host, host.position - Vector3(0.1, 0.0, 0.0), 0.1)
	assert_eq(player.current_animation, Models.WALK_ANIMATION)
	host.free()


func _triangle_count(mesh_instance: MeshInstance3D) -> int:
	var arrays: Array = mesh_instance.mesh.surface_get_arrays(0)
	var indexes: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indexes.size() > 0:
		return indexes.size() / 3
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	return vertices.size() / 3

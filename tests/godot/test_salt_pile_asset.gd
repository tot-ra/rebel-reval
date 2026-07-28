extends "res://tests/godot/test_case.gd"

const SaltPileModels := preload("res://scripts/map/view3d/map_view_salt_pile_models.gd")


func test_salt_pile_has_coarse_mound_and_scoop() -> void:
	var host := Node3D.new()
	var model := SaltPileModels.add_model(host)
	assert_true(model.get_meta(&"production_salt_pile_model", false))
	assert_true(model.has_node("SaltPile/SaltMound"), "pile needs a coarse salt mound")
	assert_true(model.has_node("SaltPile/Scoop"), "pile needs a functional wood scoop cue")
	assert_false(model.has_node("SaltA"), "egg-like sphere placeholder must stay retired")

	var bounds := AABB()
	var first := true
	var triangle_count := 0
	var material_names: Dictionary = {}
	var textured_material_names: Dictionary = {}
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var child_bounds := _transform_relative_to(mesh_instance, model) * mesh_instance.get_aabb()
		bounds = child_bounds if first else bounds.merge(child_bounds)
		first = false
		for surface_index in mesh_instance.mesh.get_surface_count():
			triangle_count += mesh_instance.mesh.surface_get_array_index_len(surface_index) / 3
			var material := mesh_instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
			if material == null:
				continue
			material_names[material.resource_name] = true
			if material.albedo_texture != null:
				textured_material_names[material.resource_name] = true

	assert_false(first, "salt pile GLB must expose render geometry")
	assert_true(bounds.size.x >= 1.30 and bounds.size.x <= 1.40, "pile must fit its one-cell visual width")
	assert_true(bounds.size.y >= 0.40 and bounds.size.y <= 0.55, "pile needs a believable height")
	assert_true(bounds.size.z >= 0.90 and bounds.size.z <= 1.05, "pile must keep compact depth")
	assert_true(bounds.position.y >= -0.001, "salt mound and scoop must touch the ground plane")
	assert_eq(triangle_count, 688, "cues must stay deterministic and lightweight")
	assert_eq(material_names.size(), 2, "pile keeps coarse salt and oak identities")
	assert_eq(textured_material_names.size(), 2, "both material families need embedded painted albedos")
	host.free()


func _transform_relative_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent() as Node3D
	while parent != null and parent != ancestor:
		result = parent.transform * result
		parent = parent.get_parent() as Node3D
	return result

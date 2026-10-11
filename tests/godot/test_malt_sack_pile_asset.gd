extends "res://tests/godot/test_case.gd"

const MaltSackPileModels := preload("res://scripts/map/view3d/map_view_malt_sack_pile_models.gd")


func test_malt_sack_pile_has_cloth_ties_visible_malt_and_scoop() -> void:
	var host := Node3D.new()
	var model := MaltSackPileModels.add_model(host)
	assert_true(model.get_meta(&"production_malt_sack_pile_model", false))
	assert_true(model.has_node("MaltSackPile/Sacks"), "pile needs gathered closed sacks")
	assert_true(model.has_node("MaltSackPile/OpenSack"), "pile needs one open sack")
	assert_true(model.has_node("MaltSackPile/SeamsAndTies"), "sacks need visible seams and ties")
	assert_true(model.has_node("MaltSackPile/Malt"), "open sack needs readable malted barley")
	assert_true(model.has_node("MaltSackPile/Scoop"), "pile needs a functional grain scoop cue")
	assert_false(model.has_node("SackA"), "egg-like sphere placeholder must stay retired")

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

	assert_false(first, "malt sack pile GLB must expose render geometry")
	assert_true(bounds.size.x >= 1.25 and bounds.size.x <= 1.28, "pile must fit its one-cell visual width")
	assert_true(bounds.size.y >= 0.67 and bounds.size.y <= 0.68, "pile needs a believable sack height")
	assert_true(bounds.size.z >= 0.95 and bounds.size.z <= 0.97, "pile must keep compact brewery-yard depth")
	assert_true(bounds.position.y >= -0.001, "malt sacks and scoop must touch the ground plane")
	assert_eq(triangle_count, 1624, "cloth cues must stay deterministic and lightweight")
	assert_eq(material_names.size(), 4, "pile keeps burlap, rope, malt, and oak identities")
	assert_eq(textured_material_names.size(), 4, "all malt sack material families need embedded painted albedos")
	host.free()


func _transform_relative_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent() as Node3D
	while parent != null and parent != ancestor:
		result = parent.transform * result
		parent = parent.get_parent() as Node3D
	return result

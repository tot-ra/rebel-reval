extends "res://tests/godot/test_case.gd"

const RopeCoilModels := preload("res://scripts/map/view3d/map_view_rope_coil_models.gd")


func test_rope_coil_has_open_layered_braid_and_curved_frayed_end() -> void:
	var host := Node3D.new()
	var model := RopeCoilModels.add_model(host)
	assert_true(model.get_meta(&"production_rope_coil_model", false))
	assert_true(model.has_node("RopeCoil/LowerTurns"), "coil needs a lower layer of stored rope")
	assert_true(model.has_node("RopeCoil/BraidedCoil"), "coil needs modeled three-strand rope turns")
	assert_true(model.has_node("RopeCoil/FrayedEnd"), "free end needs separated frayed strands")
	assert_false(model.has_node("CoilInner"), "wooden hub placeholder must stay retired")
	assert_false(model.has_node("Tail"), "box-shaped tail placeholder must stay retired")

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

	assert_false(first, "rope coil GLB must expose render geometry")
	assert_true(bounds.size.x >= 1.20 and bounds.size.x <= 1.26, "tail must remain inside a compact one-cell visual width")
	assert_true(bounds.size.y >= 0.11 and bounds.size.y <= 0.13, "two rope layers need believable low height")
	assert_true(bounds.size.z >= 0.84 and bounds.size.z <= 0.88, "coil depth must preserve the established footprint")
	assert_true(bounds.position.y >= -0.001, "coil and loose end must touch the ground plane")
	assert_true(triangle_count >= 6000 and triangle_count <= 8000, "modeled rope lay must stay deterministic and lightweight")
	assert_eq(material_names.size(), 1, "coil keeps one hemp material identity")
	assert_eq(textured_material_names.size(), 1, "hemp needs an embedded painted albedo")
	host.free()


func _transform_relative_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent() as Node3D
	while parent != null and parent != ancestor:
		result = parent.transform * result
		parent = parent.get_parent() as Node3D
	return result

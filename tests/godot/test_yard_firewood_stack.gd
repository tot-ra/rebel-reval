extends "res://tests/godot/test_case.gd"

const FirewoodStackModels := preload("res://scripts/map/view3d/map_view_firewood_stack_models.gd")


func test_yard_firewood_stack_has_split_billets_and_cord() -> void:
	var host := Node3D.new()
	var model := FirewoodStackModels.add_model(host)
	assert_true(model.get_meta(&"production_yard_firewood_stack_model", false))
	assert_true(model.has_node("YardFirewoodStack/Billets"), "stack needs split billets")
	assert_true(model.has_node("YardFirewoodStack/YardCord"), "stack needs hemp yard cord")

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

	assert_false(first, "firewood stack GLB must expose render geometry")
	assert_true(bounds.size.x >= 2.05 and bounds.size.x <= 2.10, "stack width must fit the 2x2 yard footprint")
	assert_true(bounds.size.y >= 0.54 and bounds.size.y <= 0.57, "stack needs a low yard-readable height")
	assert_true(bounds.size.z >= 0.90 and bounds.size.z <= 0.95, "stack depth must stay compact on the apron")
	assert_true(bounds.position.y >= -0.001, "billets must rest on the prop ground plane")
	assert_eq(triangle_count, 1264, "firewood cues must stay deterministic and lightweight")
	assert_eq(material_names.size(), 3, "stack keeps bark, heartwood, and hemp identities")
	assert_eq(textured_material_names.size(), 3, "all firewood material families need embedded painted albedos")
	host.free()


func test_firewood_stack_prop_builds_authored_model() -> void:
	var node := MapViewMeshBuilder.build_prop(
		{"id": &"courtyard_firewood", "kind": MapTypes.PROP_KIND_FIREWOOD_STACK, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(node.has_node("YardFirewoodStackModel"), "firewood_stack must instantiate the authored GLB")
	assert_false(node.has_node("Log0"), "boat-timber cylinders must not stand in for yard firewood")
	node.free()


func _transform_relative_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent() as Node3D
	while parent != null and parent != ancestor:
		result = parent.transform * result
		parent = parent.get_parent() as Node3D
	return result

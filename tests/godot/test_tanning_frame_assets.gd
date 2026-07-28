extends "res://tests/godot/test_case.gd"

const TanningFrameModels := preload("res://scripts/map/view3d/map_view_tanning_frame_models.gd")


func test_tanning_frame_model_loads_with_hide_lacing_and_ground_contact() -> void:
	var host := Node3D.new()
	var model := TanningFrameModels.add_model(host)
	assert_true(model.get_meta(&"production_tanning_frame_model", false))
	assert_true(model.has_node("TanningFrame/Frame"), "tanning frame needs an oak work frame")
	assert_true(model.has_node("TanningFrame/Hide"), "tanning frame needs a stretched hide mesh")
	assert_true(model.has_node("TanningFrame/Lacing"), "tanning frame needs perimeter rope lacing")

	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	assert_true(meshes.size() >= 3, "tanning frame GLB needs frame, hide, and lacing geometry")
	var bounds := AABB()
	var first := true
	var triangle_count := 0
	var textured_surface_count := 0
	var material_names: Dictionary = {}
	for child in meshes:
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var child_bounds := mesh_instance.transform * mesh_instance.get_aabb()
		bounds = child_bounds if first else bounds.merge(child_bounds)
		first = false
		for surface_index in mesh_instance.mesh.get_surface_count():
			triangle_count += mesh_instance.mesh.surface_get_array_index_len(surface_index) / 3
			var material := mesh_instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
			if material == null:
				continue
			material_names[material.resource_name] = true
			if material.albedo_texture != null:
				textured_surface_count += 1

	assert_false(first, "tanning frame GLB must expose a non-empty AABB")
	assert_true(bounds.size.x >= 1.0 and bounds.size.x <= 1.4, "frame must keep its gameplay width")
	assert_true(bounds.size.y >= 1.1 and bounds.size.y <= 1.5, "stretched hide must read above the ground brace")
	assert_true(bounds.size.z >= 0.55 and bounds.size.z <= 0.85, "leaning frame must stay shallow in depth")
	assert_true(bounds.position.y >= -0.001, "frame braces must rest on the prop ground plane")
	assert_true(triangle_count >= 300 and triangle_count <= 1200, "hide lacing must stay lightweight")
	assert_eq(material_names.size(), 3, "frame keeps oak timber, worked hide, and hemp lacing families")
	assert_true(textured_surface_count >= 3, "all tanning frame material families need embedded painted albedos")
	host.free()


func test_tanning_frame_prop_uses_production_model_without_changing_anchor() -> void:
	var prop := MapViewMeshBuilderProps.build_prop(
		{"id": &"saddler_frame", "kind": MapTypes.PROP_KIND_TANNING_FRAME, "position": Vector2(64.0, 64.0)},
		MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(prop.has_node("TanningFrameModel"), "tanning_frame props must instantiate the authored GLB")
	assert_eq(prop.position, Vector3(2.0, 0.0, 2.0), "authored art must preserve the rrmap ground anchor")
	var model := prop.get_node("TanningFrameModel") as Node3D
	assert_true(model.get_meta(&"production_tanning_frame_model", false))
	prop.free()

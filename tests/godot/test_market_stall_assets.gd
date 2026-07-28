extends "res://tests/godot/test_case.gd"

const MarketStallModels := preload("res://scripts/map/view3d/map_view_market_stall_models.gd")


func test_market_stall_model_loads_with_period_frame_canvas_and_ground_contact() -> void:
	var host := Node3D.new()
	var model := MarketStallModels.add_model(host)
	assert_true(model.get_meta(&"production_market_stall_model", false))
	assert_true(model.has_node("MarketStall/StallFrame"), "market stall needs a braced oak frame")
	assert_true(model.has_node("MarketStall/CanvasAwning"), "market stall needs a shaped canvas awning")

	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	assert_true(meshes.size() >= 2, "market stall GLB needs separate frame and awning geometry")
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

	assert_false(first, "market stall GLB must expose a non-empty AABB")
	assert_true(bounds.size.x >= 1.9 and bounds.size.x <= 2.2, "stall must keep its compact market width")
	assert_true(bounds.size.y >= 1.85 and bounds.size.y <= 2.05, "awning must read above a standing merchant")
	assert_true(bounds.size.z >= 1.45 and bounds.size.z <= 1.75, "stall must fit the established market footprint")
	assert_true(bounds.position.y >= -0.001, "stall posts must rest on the prop ground plane")
	assert_true(triangle_count >= 1500 and triangle_count <= 4500, "period joinery must stay readable and lightweight")
	assert_eq(material_names.size(), 5, "stall keeps oak, timber, canvas, rope, and iron material families")
	assert_true(textured_surface_count >= 5, "all market stall material families need embedded painted albedos")
	host.free()


func test_stall_props_use_production_market_model_without_changing_anchor() -> void:
	var prop := MapViewMeshBuilder.build_prop(
		{"id": &"fish_stall", "kind": MapTypes.PROP_KIND_STALL, "position": Vector2(64.0, 64.0)},
		MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(prop.has_node("MarketStallModel"), "stall props must instantiate the authored GLB")
	assert_eq(prop.position, Vector3(2.0, 0.0, 2.0), "authored art must preserve the rrmap ground anchor")
	var model := prop.get_node("MarketStallModel") as Node3D
	assert_true(model.get_meta(&"production_market_stall_model", false))
	prop.free()

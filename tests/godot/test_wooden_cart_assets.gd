extends "res://tests/godot/test_case.gd"

const CartModels := preload("res://scripts/map/view3d/map_view_cart_models.gd")


func test_wooden_cart_model_loads_with_mesh_material_and_ground_contact() -> void:
	var host := Node3D.new()
	var model := CartModels.add_model(host)
	assert_true(model.get_meta(&"production_cart_model", false))
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	assert_true(meshes.size() >= 1, "wooden cart GLB needs render geometry")
	var bounds := AABB()
	var first := true
	var surface_count := 0
	var triangle_count := 0
	var textured_surface_count := 0
	for child in meshes:
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var child_bounds := mesh_instance.transform * mesh_instance.get_aabb()
		bounds = child_bounds if first else bounds.merge(child_bounds)
		first = false
		surface_count += mesh_instance.mesh.get_surface_count()
		for surface_index in mesh_instance.mesh.get_surface_count():
			triangle_count += mesh_instance.mesh.surface_get_array_index_len(surface_index) / 3
			var material := mesh_instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
			if material != null and material.albedo_texture != null:
				textured_surface_count += 1
	assert_false(first, "wooden cart GLB must expose a non-empty AABB")
	assert_true(bounds.size.y >= 0.9 and bounds.size.y <= 1.2, "cart must preserve metric height")
	assert_true(bounds.size.x >= 0.9 and bounds.size.x <= 1.3, "cart must preserve metric width")
	assert_true(bounds.size.z >= 2.2 and bounds.size.z <= 2.7, "cart must preserve metric length")
	assert_true(bounds.position.y >= -0.001, "cart wheels must rest on the prop ground plane")
	assert_true(surface_count >= 3, "cart keeps oak plank, timber, and iron surfaces")
	assert_true(triangle_count >= 3000 and triangle_count <= 6000, "cart detail must stay readable and lightweight")
	assert_true(textured_surface_count >= 2, "embedded oak and iron albedos must survive GLB import")
	host.free()


func test_street_cart_and_farm_cart_use_production_model() -> void:
	for kind: StringName in [MapTypes.PROP_KIND_CART, MapTypes.PROP_KIND_FARM_CART]:
		var prop := MapViewMeshBuilder.build_prop({"id": kind, "kind": kind, "position": Vector2.ZERO}, MapTypes.DEFAULT_CELL_SIZE)
		assert_true(prop.has_node("WoodenCartModel"), "%s must instantiate the authored GLB" % kind)
		var model := prop.get_node("WoodenCartModel") as Node3D
		assert_true(model.get_meta(&"production_cart_model", false))
		prop.free()

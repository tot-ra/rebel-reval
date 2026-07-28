extends "res://tests/godot/test_case.gd"

const RootCellarModels := preload("res://scripts/map/view3d/map_view_root_cellar_models.gd")


func test_root_cellar_model_loads_with_turf_earth_timber_and_ground_contact() -> void:
	var host := Node3D.new()
	var model := RootCellarModels.add_model(host)
	assert_true(model.get_meta(&"production_root_cellar_model", false))
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	assert_true(meshes.size() >= 3, "root cellar needs mound, entrance, and retaining geometry")
	var bounds := AABB()
	var first := true
	var material_names: Array[String] = []
	var triangle_count := 0
	var textured_surface_count := 0
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
			material_names.append(material.resource_name)
			if material.albedo_texture != null:
				textured_surface_count += 1
	assert_false(first, "root cellar GLB must expose a non-empty AABB")
	assert_true(bounds.size.y >= 0.68 and bounds.size.y <= 0.82, "mound must stay low and human-scaled")
	assert_true(bounds.size.x >= 1.8 and bounds.size.x <= 2.1, "mound must preserve the two-cell lateral read")
	assert_true(bounds.size.z >= 1.6 and bounds.size.z <= 1.85, "mound must preserve the authored rural footprint")
	assert_true(bounds.position.y >= -0.001, "root cellar must rest on the prop ground plane")
	assert_true(triangle_count >= 300 and triangle_count <= 1800, "cellar detail must stay readable and lightweight")
	assert_true(textured_surface_count >= 4, "turf, earth, oak, and fieldstone albedos must survive GLB import")
	assert_true(_has_material_fragment(material_names, "turf"), "mound needs a turf material")
	assert_true(_has_material_fragment(material_names, "exposed_earth"), "mound needs visible earth")
	assert_true(_has_material_fragment(material_names, "aged_oak"), "entrance needs an oak material")
	assert_true(_has_material_fragment(material_names, "fieldstone"), "entrance needs restrained fieldstone support")
	host.free()


func test_rural_root_cellar_uses_production_model_without_stone_sphere_placeholder() -> void:
	var prop := MapViewMeshBuilder.build_prop(
		{
			"id": &"test.root_cellar",
			"kind": MapTypes.PROP_KIND_ROOT_CELLAR_MOUND,
			"position": Vector2.ZERO,
		},
		MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(prop.has_node("RootCellarMoundModel"), "root cellar kind must instantiate the authored GLB")
	var model := prop.get_node("RootCellarMoundModel") as Node3D
	assert_true(model.get_meta(&"production_root_cellar_model", false))
	assert_false(prop.has_node("Mound"), "legacy flattened stone sphere must be removed")
	prop.free()


func _has_material_fragment(material_names: Array[String], fragment: String) -> bool:
	for material_name in material_names:
		if fragment in material_name.to_lower():
			return true
	return false

extends "res://tests/godot/map_view_3d_test_base.gd"

const FishingNetModels := preload("res://scripts/map/view3d/map_view_fishing_net_models.gd")


func test_fishing_nets_have_knotted_mesh_floats_sinkers_and_grounded_frame() -> void:
	var host := Node3D.new()
	var model := FishingNetModels.add_model(host)
	assert_true(model != null, "fishing nets need an authored model root")
	if model == null:
		host.free()
		return
	assert_true(model.get_meta(&"production_fishing_nets_model", false))
	assert_true(model.has_node("FishingNets/Frame"), "rack needs a braced oak frame")
	assert_true(model.has_node("FishingNets/Netting"), "rack needs visible diamond netting")
	assert_true(model.has_node("FishingNets/OutlineRope"), "net needs a heavy outline rope and rail lashings")
	assert_true(model.has_node("FishingNets/Floats"), "net needs a readable float line")
	assert_true(model.has_node("FishingNets/Sinkers"), "net needs a weighted foot line")
	assert_false(model.has_node("Mesh0"), "vertical box-strip placeholder must stay retired")

	var bounds := AABB()
	var first := true
	var triangle_count := 0
	var material_names: Dictionary = {}
	var textured_material_names: Dictionary = {}
	for child in model.find_children("*", "MeshInstance3D", true, false):
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
				textured_material_names[material.resource_name] = true

	assert_false(first, "fishing nets GLB must expose render geometry")
	assert_true(bounds.size.x >= 1.4 and bounds.size.x <= 1.55, "rack must preserve the one-cell visual width")
	assert_true(bounds.size.y >= 1.4 and bounds.size.y <= 1.55, "rack needs a readable shoulder-height silhouette")
	assert_true(bounds.size.z >= 0.45 and bounds.size.z <= 0.58, "rear braces must stay inside the compact net-yard depth")
	assert_true(bounds.position.y >= -0.001, "frame and braces must touch the ground plane")
	assert_true(triangle_count >= 3000 and triangle_count <= 4500, "diamond mesh and maritime cues must stay readable and lightweight")
	assert_eq(material_names.size(), 4, "rack keeps oak, hemp, float, and sinker identities")
	assert_eq(textured_material_names.size(), 4, "all fishing-net material families need embedded painted albedos")
	host.free()


func test_fishing_nets_prop_uses_production_model_without_gameplay_bodies() -> void:
	var prop := {
		"id": &"test.fishing_nets",
		"kind": MapTypes.PROP_KIND_FISHING_NETS,
		"position": Vector2(64, 64),
	}
	var node := MapViewMeshBuilderProps.build_prop(prop, MapTypes.DEFAULT_CELL_SIZE)
	assert_true(node.find_child("FishingNetsModel", true, false) != null, "district-life prop must instantiate the production GLB")
	assert_true(node.find_children("*", "CollisionObject3D", true, false).is_empty(), "visual upgrade must not add collision or navigation bodies")
	node.free()

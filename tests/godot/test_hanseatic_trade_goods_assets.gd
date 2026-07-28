extends "res://tests/godot/test_case.gd"

const TradeGoodsModels := preload("res://scripts/map/view3d/map_view_trade_goods_models.gd")


func test_all_hanseatic_trade_goods_glbs_load_with_metric_textured_geometry() -> void:
	for variant: StringName in TradeGoodsModels.MODEL_PATHS:
		var host := Node3D.new()
		var model := TradeGoodsModels.add_model(host, _prop_id_for(variant))
		assert_true(model.get_meta(&"production_trade_goods_model", false))
		assert_eq(model.get_meta(&"cargo_variant", &""), variant)
		var bounds := AABB()
		var first := true
		var triangle_count := 0
		var textured_surfaces := 0
		for child in model.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := child as MeshInstance3D
			if mesh_instance.mesh == null:
				continue
			var child_bounds := mesh_instance.transform * mesh_instance.get_aabb()
			bounds = child_bounds if first else bounds.merge(child_bounds)
			first = false
			for surface_index in mesh_instance.mesh.get_surface_count():
				triangle_count += mesh_instance.mesh.surface_get_array_index_len(surface_index) / 3
				var material := mesh_instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
				if material != null and material.albedo_texture != null:
					textured_surfaces += 1
		assert_false(first, "%s must expose render geometry" % variant)
		assert_true(bounds.size.x > 1.0 and bounds.size.x < 1.7, "%s preserves cargo width" % variant)
		assert_true(bounds.size.y > 0.45 and bounds.size.y < 0.8, "%s preserves cargo height" % variant)
		assert_true(bounds.size.z > 0.65 and bounds.size.z < 1.1, "%s preserves cargo depth" % variant)
		assert_true(bounds.position.y >= -0.02, "%s rests on the prop ground plane" % variant)
		assert_true(triangle_count >= 2500 and triangle_count <= 9000, "%s stays inside its detail budget" % variant)
		assert_true(textured_surfaces >= 3, "%s keeps embedded painted albedos" % variant)
		host.free()


func test_existing_trade_points_receive_four_distinct_historical_cargo_reads() -> void:
	for prop_id: StringName in TradeGoodsModels.VARIANT_BY_PROP_ID:
		var prop := MapViewMeshBuilder.build_prop(
			{"id": prop_id, "kind": MapTypes.PROP_KIND_TRADE_GOODS, "position": Vector2.ZERO},
			MapTypes.DEFAULT_CELL_SIZE
		)
		var model := prop.get_node("TradeGoodsModel") as Node3D
		assert_true(model.get_meta(&"production_trade_goods_model", false))
		assert_eq(model.get_meta(&"cargo_variant", &""), TradeGoodsModels.VARIANT_BY_PROP_ID[prop_id])
		assert_false(prop.has_node("SackA"), "the egg-like sphere placeholder must be retired")
		prop.free()


func _prop_id_for(variant: StringName) -> StringName:
	for prop_id: StringName in TradeGoodsModels.VARIANT_BY_PROP_ID:
		if TradeGoodsModels.VARIANT_BY_PROP_ID[prop_id] == variant:
			return prop_id
	return &"trade_goods"

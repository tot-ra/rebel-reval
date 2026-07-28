extends "res://tests/godot/test_case.gd"

const LightingModels := preload("res://scripts/map/view3d/map_view_medieval_lighting_models.gd")


func test_each_household_lighting_variant_selects_one_textured_model_and_local_light() -> void:
	for variant in MapTypes.LIGHTING_VARIANTS:
		var host := Node3D.new()
		var model := LightingModels.add_model(host, {
			"kind": MapTypes.PROP_KIND_CANDLE,
			"style_variant": variant,
		})
		assert_true(model.get_meta(&"production_lighting_model", false), "%s must use the production GLB" % variant)
		assert_eq(model.get_meta(&"lighting_variant"), variant)

		var selected_roots := 0
		for root_name in LightingModels.VARIANT_ROOT_NAMES.values():
			if model.find_child(String(root_name), true, false) != null:
				selected_roots += 1
		assert_eq(selected_roots, 1, "%s must not retain hidden geometry from other social variants" % variant)

		var flame := _find_flame(model)
		assert_true(flame != null and flame.mesh != null, "%s needs a separate flame mesh" % variant)
		if flame != null:
			assert_true(flame.material_override is StandardMaterial3D, "%s needs an instance-owned flame material" % variant)
			assert_true(flame.has_node("Omni"), "%s needs a local light anchored to its flame" % variant)

		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		var triangle_count := 0
		var textured_surfaces := 0
		for child in meshes:
			var mesh_instance := child as MeshInstance3D
			if mesh_instance == null or mesh_instance.mesh == null:
				continue
			for surface_index in mesh_instance.mesh.get_surface_count():
				triangle_count += mesh_instance.mesh.surface_get_array_index_len(surface_index) / 3
				var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
				if material != null and material.albedo_texture != null:
					textured_surfaces += 1
		assert_true(triangle_count >= 150 and triangle_count <= 1100, "%s must stay readable and lightweight" % variant)
		assert_true(textured_surfaces >= 3, "%s needs embedded painted albedos" % variant)

		var controller := host.get_node("CandleLight") as CandleLight3D
		var light := flame.get_node("Omni") as OmniLight3D if flame != null else null
		assert_true(controller != null and light != null)
		if controller != null and light != null:
			controller.apply_cycle_progress(0.5)
			var day_energy := light.light_energy
			controller.apply_cycle_progress(0.0)
			assert_true(light.light_energy > day_energy, "%s must strengthen after dusk" % variant)
			assert_eq(light.light_color, LightingModels.LIGHT_PROFILES[variant]["color"])
		host.free()


func test_unknown_candle_variant_falls_back_to_artisan_tallow() -> void:
	var prop := {"kind": MapTypes.PROP_KIND_CANDLE, "style_variant": &"modern_paraffin"}
	assert_eq(MapTypes.lighting_variant_for_prop(prop), MapTypes.DEFAULT_LIGHTING_VARIANT)
	assert_eq(MapTypes.invalid_lighting_variant(prop), &"modern_paraffin")
	assert_false(MapPropStyleVariants.is_known(MapTypes.PROP_KIND_CANDLE, &"modern_paraffin"))


func _find_flame(root: Node) -> MeshInstance3D:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		if String(child.name).begins_with("Flame"):
			return child as MeshInstance3D
	return null

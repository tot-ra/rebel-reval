extends "res://tests/godot/test_case.gd"

const StorageModels := preload("res://scripts/map/view3d/map_view_storage_furniture_models.gd")
const PropStyleVariants := preload("res://scripts/map/map_prop_style_variants.gd")


func test_storage_furniture_variants_are_strict_and_socially_explicit() -> void:
	for variant in PropStyleVariants.STORAGE_FURNITURE_VARIANTS:
		assert_true(PropStyleVariants.is_known(MapTypes.PROP_KIND_SHELF, variant))
	assert_false(
		PropStyleVariants.is_known(MapTypes.PROP_KIND_SHELF, &"shelf.modern_wardrobe"),
		"modern or mistyped storage variants must fail map compilation"
	)


func test_default_shelf_is_the_common_open_rack() -> void:
	var prop := MapViewMeshBuilder.build_prop(
		{"id": &"common_house_storage", "kind": MapTypes.PROP_KIND_SHELF, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)
	var model := prop.get_node("MedievalStorageModel") as Node3D
	assert_true(model != null)
	assert_eq(model.get_meta(&"storage_furniture_variant"), StorageModels.COMMON_OPEN)
	assert_true(model.get_meta(&"stores_folded_textiles", false))
	assert_false(model.get_meta(&"has_modern_hanging_rail", true))
	assert_true(model.has_node("CommonOpenRack"), "default shelf must use the open rack GLB")
	assert_false(prop.has_node("Frame"), "production model replaces the solid-box shelf placeholder")
	prop.free()


func test_each_social_variant_loads_distinct_grounded_geometry() -> void:
	var expected_roots := {
		StorageModels.COMMON_OPEN: "CommonOpenRack",
		StorageModels.BURGHER_CUPBOARD: "BurgherCupboard",
		StorageModels.ELITE_ARMARIUM: "EliteArmarium",
	}
	var heights: Dictionary = {}
	for variant in PropStyleVariants.STORAGE_FURNITURE_VARIANTS:
		var prop := MapViewMeshBuilder.build_prop(
			{
				"id": StringName("test_%s" % String(variant).replace(".", "_")),
				"kind": MapTypes.PROP_KIND_SHELF,
				"position": Vector2.ZERO,
				"style_variant": variant,
			},
			MapTypes.DEFAULT_CELL_SIZE
		)
		var model := prop.get_node("MedievalStorageModel") as Node3D
		assert_true(model.has_node(expected_roots[variant]), "%s needs its distinct GLB root" % String(variant))
		var stats := _model_stats(model)
		var bounds: AABB = stats["bounds"]
		assert_true(bounds.position.y >= -0.001, "%s must rest on the ground plane: %s" % [String(variant), bounds])
		assert_true(int(stats["triangles"]) >= 800 and int(stats["triangles"]) < 4000, "%s must remain readable and lightweight" % String(variant))
		assert_true(int(stats["textured_surfaces"]) >= 1, "%s needs an embedded painted wood albedo" % String(variant))
		heights[variant] = bounds.size.y
		prop.free()
	assert_true(float(heights[StorageModels.BURGHER_CUPBOARD]) > float(heights[StorageModels.COMMON_OPEN]))
	assert_true(float(heights[StorageModels.ELITE_ARMARIUM]) > float(heights[StorageModels.BURGHER_CUPBOARD]))


func test_town_hall_assigns_closed_storage_deliberately() -> void:
	var parsed := MapRrmapParser.parse_file("res://content/maps/town_hall.rrmap")
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var expected := {
		&"archive_shelf_north": StorageModels.ELITE_ARMARIUM,
		&"archive_shelf_west": StorageModels.BURGHER_CUPBOARD,
	}
	for prop in parsed.definition.props:
		var prop_id: StringName = prop.get("id", &"")
		if expected.has(prop_id):
			assert_eq(prop.get("style_variant"), expected[prop_id])
			expected.erase(prop_id)
	assert_true(expected.is_empty(), "both civic archive storage pieces need explicit social variants")


func test_invalid_storage_variant_fails_rrmap_compilation() -> void:
	var source := """rrmap 1
map bad_storage loc.bad_storage 8 8 timber_floor
prop bad_shelf shelf 3 3 style_variant=shelf.modern_wardrobe
spawn spawn.main 1 1
"""
	var parsed := MapRrmapParser.parse(source, "res://bad_storage.rrmap")
	assert_false(parsed.is_ok())
	assert_true(str(parsed.formatted_diagnostics()).contains("style_variant is unknown"))


func _model_stats(model: Node3D) -> Dictionary:
	var bounds := AABB()
	var first := true
	var triangles := 0
	var textured_surfaces := 0
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var child_bounds := mesh_instance.transform * mesh_instance.get_aabb()
		bounds = child_bounds if first else bounds.merge(child_bounds)
		first = false
		for surface_index in mesh_instance.mesh.get_surface_count():
			triangles += mesh_instance.mesh.surface_get_array_index_len(surface_index) / 3
			var material := mesh_instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
			if material != null and material.albedo_texture != null:
				textured_surfaces += 1
	return {"bounds": bounds, "triangles": triangles, "textured_surfaces": textured_surfaces}

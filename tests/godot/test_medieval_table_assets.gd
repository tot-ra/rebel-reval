extends "res://tests/godot/test_case.gd"

const TableModels := preload("res://scripts/map/view3d/map_view_table_models.gd")
const PropStyleVariants := preload("res://scripts/map/map_prop_style_variants.gd")


func test_table_variants_select_distinct_grounded_textured_bases() -> void:
	var expectations := {
		PropStyleVariants.TABLE_COMMON_HOUSEHOLD: {
			"root": "CommonHouseholdTable",
			"dimensions": Vector3(1.5, 0.7719, 0.78),
		},
		PropStyleVariants.TABLE_TRESTLE_WORK: {
			"root": "TrestleWorkTable",
			"dimensions": Vector3(1.58, 0.8219, 0.76),
		},
		PropStyleVariants.TABLE_LONG_BOARD: {
			"root": "LongBoardTable",
			"dimensions": Vector3(2.3, 0.7919, 0.82),
		},
	}
	for variant in PropStyleVariants.TABLE_VARIANTS:
		var host := Node3D.new()
		var model := TableModels.add_model(host, {"style_variant": variant})
		assert_true(model.get_meta(&"production_table_model", false))
		assert_eq(model.get_meta(&"table_style_variant"), variant)
		assert_eq(model.get_meta(&"table_items"), [])
		assert_true(model.has_node(expectations[variant]["root"]))

		var audit := _audit_model(model)
		assert_true(audit["bounds"].position.y >= -0.001, "%s must rest on the ground plane" % variant)
		assert_true(
			audit["bounds"].size.distance_to(expectations[variant]["dimensions"]) <= 0.002,
			"%s dimensions changed: %s" % [variant, audit["bounds"].size]
		)
		assert_true(audit["triangles"] >= 1000 and audit["triangles"] <= 1800)
		assert_eq(audit["textured_materials"].size(), 3, "table base needs oak, timber, and iron material families")
		host.free()


func test_tabletop_items_are_independent_modules_and_share_stable_surface_slots() -> void:
	var host := Node3D.new()
	var model := TableModels.add_model(host, {
		"style_variant": PropStyleVariants.TABLE_TRESTLE_WORK,
		"table_items": &"cutting_board+fish+knife+candle",
	})
	assert_eq(model.get_meta(&"table_items"), MapTypes.TABLE_ITEM_KINDS)
	var expected_nodes := {
		MapTypes.TABLE_ITEM_CUTTING_BOARD: "CuttingBoardModule",
		MapTypes.TABLE_ITEM_FISH: "FishModule",
		MapTypes.TABLE_ITEM_KNIFE: "KnifeModule",
		MapTypes.TABLE_ITEM_CANDLE: "CandleModule",
	}
	for item_kind in expected_nodes:
		var module := model.find_child(expected_nodes[item_kind], true, false) as Node3D
		assert_true(module != null, "%s needs a separate module root" % item_kind)
		if module != null:
			assert_eq(module.get_meta(&"table_item_kind"), item_kind)
			assert_true(module.position.y >= TableModels.TABLETOP_HEIGHTS[PropStyleVariants.TABLE_TRESTLE_WORK])
	assert_true(model.get_node("CandleModule/LightingModel") != null, "table candle must reuse the authored lighting kit")
	assert_true(model.find_child("CandleLight", true, false) != null, "composed candle keeps day/night behavior")
	host.free()


func test_legacy_fish_splitting_table_is_a_work_table_composition() -> void:
	var host := Node3D.new()
	var model := TableModels.add_fish_splitting_preset(host)
	assert_true(model.get_meta(&"legacy_fish_splitting_preset", false))
	assert_eq(model.get_meta(&"table_style_variant"), PropStyleVariants.TABLE_TRESTLE_WORK)
	assert_eq(
		model.get_meta(&"table_items"),
		[MapTypes.TABLE_ITEM_CUTTING_BOARD, MapTypes.TABLE_ITEM_FISH, MapTypes.TABLE_ITEM_KNIFE]
	)
	assert_true(model.has_node("TrestleWorkTable"))
	assert_true(model.has_node("CuttingBoardModule"))
	assert_true(model.has_node("FishModule"))
	assert_true(model.has_node("KnifeModule"))
	assert_false(model.has_node("CommonHouseholdTable"))
	assert_false(model.has_node("LongBoardTable"))
	host.free()


func test_table_contract_round_trips_and_rejects_invalid_combinations() -> void:
	var source := """rrmap 1
map table_modules loc.table_modules 12 10 timber_floor
prop work_table table 4 5 rect=3,2 style_variant=table.trestle_work table_items=cutting_board+fish+knife
spawn spawn.main 2 2
"""
	var parsed := MapRrmapParser.parse(source, "res://table_modules.rrmap")
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	assert_eq(parsed.definition.props[0].get("style_variant"), PropStyleVariants.TABLE_TRESTLE_WORK)
	assert_eq(parsed.definition.props[0].get("table_items"), &"cutting_board+fish+knife")
	var canonical := MapRrmapParser.canonical_print(parsed.blueprint)
	assert_true("style_variant=table.trestle_work" in canonical)
	assert_true("table_items=cutting_board+fish+knife" in canonical)
	var reparsed := MapRrmapParser.parse(canonical, "res://table_modules.canonical.rrmap")
	assert_true(reparsed.is_ok(), str(reparsed.formatted_diagnostics()))

	var invalid_specs := [
		{"kind": "table", "items": "bowl", "message": "table_items is unknown: bowl"},
		{"kind": "table", "items": "fish+fish", "message": "cannot contain duplicate items"},
		{"kind": "candle", "items": "fish", "message": "supported only for table props"},
	]
	for spec in invalid_specs:
		var invalid_source := """rrmap 1
map invalid_table loc.invalid_table 12 10 timber_floor
prop invalid_prop %s 4 5 table_items=%s
spawn spawn.main 2 2
""" % [spec["kind"], spec["items"]]
		var rejected := MapRrmapParser.parse(invalid_source, "res://invalid_table.rrmap")
		assert_false(rejected.is_ok())
		assert_true(str(rejected.formatted_diagnostics()).contains(spec["message"]))


func _audit_model(model: Node3D) -> Dictionary:
	var bounds := AABB()
	var first := true
	var triangles := 0
	var textured_materials: Dictionary = {}
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var relative_transform := mesh_instance.transform
		var ancestor := mesh_instance.get_parent() as Node3D
		while ancestor != null and ancestor != model:
			relative_transform = ancestor.transform * relative_transform
			ancestor = ancestor.get_parent() as Node3D
		var child_bounds := relative_transform * mesh_instance.get_aabb()
		bounds = child_bounds if first else bounds.merge(child_bounds)
		first = false
		for surface_index in mesh_instance.mesh.get_surface_count():
			triangles += mesh_instance.mesh.surface_get_array_index_len(surface_index) / 3
			var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
			if material != null and material.albedo_texture != null:
				textured_materials[material.resource_name] = true
	return {
		"bounds": bounds,
		"triangles": triangles,
		"textured_materials": textured_materials,
	}

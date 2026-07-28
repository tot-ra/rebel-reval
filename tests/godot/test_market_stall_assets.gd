extends "res://tests/godot/test_case.gd"

const MarketStallModels := preload("res://scripts/map/view3d/map_view_market_stall_models.gd")


func test_market_stall_model_scales_above_character_height_and_keeps_ground_contact() -> void:
	var host := Node3D.new()
	var model := MarketStallModels.add_model(host)
	assert_true(model.get_meta(&"production_market_stall_model", false))
	assert_true(model.has_node("MarketStall/StallFrame"), "market stall needs a braced oak frame")
	assert_true(model.has_node("MarketStall/CanvasAwning"), "market stall needs a shaped canvas awning")
	assert_eq(model.scale, Vector3.ONE * MarketStallModels.MODEL_SCALE)

	var bounds := _visual_bounds(model)
	assert_true(bounds.size.x >= 3.0 and bounds.size.x <= 3.2, "scaled stall must fill a three-cell market pitch")
	assert_true(bounds.size.y >= 2.85 and bounds.size.y <= 3.0, "awning must clear the 2 m character silhouette")
	assert_true(bounds.size.z >= 2.25 and bounds.size.z <= 2.45, "scaled stall depth must remain compact")
	assert_true(bounds.position.y >= -0.001, "scaled stall posts must remain on the ground plane")
	assert_true(bounds.size.y > 2.0, "market stall roof must stand above a full-height character")

	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var triangle_count := 0
	var textured_surface_count := 0
	var material_names: Dictionary = {}
	for child in meshes:
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			triangle_count += mesh_instance.mesh.surface_get_array_index_len(surface_index) / 3
			var material := mesh_instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
			if material == null:
				continue
			material_names[material.resource_name] = true
			if material.albedo_texture != null:
				textured_surface_count += 1
	assert_true(triangle_count >= 1500 and triangle_count <= 4500, "base frame must stay readable and lightweight")
	assert_eq(material_names.size(), 5, "stall keeps oak, timber, canvas, rope, and iron material families")
	assert_true(textured_surface_count >= 5, "all base material families need embedded painted albedos")
	host.free()


func test_empty_stall_has_slots_but_no_countertop_goods() -> void:
	var host := Node3D.new()
	var model := MarketStallModels.add_model(host)
	var display := model.get_node("CountertopDisplay") as Node3D
	assert_true(display != null)
	assert_eq(display.get_meta(&"display_goods"), [])
	assert_eq(display.get_child_count(), 0)
	assert_true((model.scale * display.scale).is_equal_approx(Vector3.ONE), "display host must cancel the frame scale")
	host.free()


func test_each_countertop_goods_kind_is_an_independent_module() -> void:
	for goods_kind in MapTypes.MARKET_STALL_GOODS_KINDS:
		var host := Node3D.new()
		var model := MarketStallModels.add_model(host, {"display_goods": goods_kind})
		var display := model.get_node("CountertopDisplay") as Node3D
		assert_eq(display.get_child_count(), 1, "%s needs exactly one occupied slot" % String(goods_kind))
		var slot := display.get_child(0) as Node3D
		var module := slot.get_child(0) as Node3D
		assert_eq(module.get_meta(&"market_stall_goods_kind"), goods_kind)
		assert_true(module.find_children("*", "MeshInstance3D", true, false).size() >= 2, "%s needs readable display geometry" % String(goods_kind))
		assert_true(
			is_equal_approx(slot.position.y + module.position.y, MarketStallModels.COUNTERTOP_HEIGHT + 0.025),
			"%s must rest on the countertop" % String(goods_kind)
		)
		host.free()


func test_three_goods_combination_uses_stable_slots_without_scaling_with_frame() -> void:
	var host := Node3D.new()
	var model := MarketStallModels.add_model(
		host,
		{"display_goods": &"fish+cloth+pottery"}
	)
	var display := model.get_node("CountertopDisplay") as Node3D
	assert_eq(
		display.get_meta(&"display_goods"),
		[MapTypes.MARKET_STALL_GOODS_FISH, MapTypes.MARKET_STALL_GOODS_CLOTH, MapTypes.MARKET_STALL_GOODS_POTTERY]
	)
	assert_eq(display.get_child_count(), 3)
	for index in 3:
		var slot := display.get_child(index) as Node3D
		var module := slot.get_child(0) as Node3D
		assert_eq(slot.get_meta(&"market_stall_slot_index"), index)
		assert_eq(slot.position, MarketStallModels.SLOT_POSITIONS[index])
		assert_true(
			module.scale.is_equal_approx(Vector3.ONE * float(MarketStallModels.MODULE_SCALES[3])),
			"goods module scale must not inherit the 1.5 frame scale"
		)
	host.free()


func test_stall_props_use_production_model_without_changing_anchor() -> void:
	var prop := MapViewMeshBuilder.build_prop(
		{
			"id": &"fish_stall",
			"kind": MapTypes.PROP_KIND_STALL,
			"position": Vector2(64.0, 64.0),
			"display_goods": MapTypes.MARKET_STALL_GOODS_FISH,
		},
		MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(prop.has_node("MarketStallModel"), "stall props must instantiate the authored GLB")
	assert_eq(prop.position, Vector3(2.0, 0.0, 2.0), "authored art must preserve the rrmap ground anchor")
	var model := prop.get_node("MarketStallModel") as Node3D
	assert_true(model.get_meta(&"production_market_stall_model", false))
	assert_true(model.has_node("CountertopDisplay/Slot0/GoodsFish"))
	prop.free()


func test_display_goods_round_trips_through_rrmap_and_combines_modules() -> void:
	var source := """rrmap 1
map stall_modules loc.stall_modules 12 10 grass
prop mixed_stall stall 4 5 rect=3,2 display_goods=fish+cloth
spawn spawn.main 2 2
"""
	var parsed := MapRrmapParser.parse(source, "res://stall_modules.rrmap")
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	assert_eq(parsed.definition.props[0].get("display_goods"), &"fish+cloth")
	var canonical := MapRrmapParser.canonical_print(parsed.blueprint)
	assert_true("display_goods=fish+cloth" in canonical)
	var reparsed := MapRrmapParser.parse(canonical, "res://stall_modules.canonical.rrmap")
	assert_true(reparsed.is_ok(), str(reparsed.formatted_diagnostics()))
	assert_eq(reparsed.definition.props[0].get("display_goods"), &"fish+cloth")


func test_display_goods_validation_rejects_unknown_excess_and_non_stall_usage() -> void:
	var invalid_specs := [
		{"kind": "stall", "goods": "bread", "message": "display_goods is unknown: bread"},
		{"kind": "stall", "goods": "fish+cloth+grain+pottery", "message": "supports at most 3 modules"},
		{"kind": "table", "goods": "fish", "message": "supported only for stall props"},
	]
	for spec in invalid_specs:
		var source := """rrmap 1
map invalid_goods loc.invalid_goods 12 10 grass
prop market_prop %s 4 5 display_goods=%s
spawn spawn.main 2 2
""" % [spec["kind"], spec["goods"]]
		var parsed := MapRrmapParser.parse(source, "res://invalid_goods.rrmap")
		assert_false(parsed.is_ok(), "%s must fail validation" % spec["goods"])
		assert_true(
			str(parsed.formatted_diagnostics()).contains(spec["message"]),
			"expected validation message for %s" % spec["goods"]
		)


func test_civic_market_assigns_trade_specific_countertop_modules() -> void:
	var parsed := MapRrmapParser.parse_file("res://content/maps/market_civic_quarter.rrmap")
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var expected := {
		&"fish_stall": MapTypes.MARKET_STALL_GOODS_FISH,
		&"cloth_stall": MapTypes.MARKET_STALL_GOODS_CLOTH,
		&"grain_stall": MapTypes.MARKET_STALL_GOODS_GRAIN,
		&"pottery_stall": MapTypes.MARKET_STALL_GOODS_POTTERY,
	}
	for prop in parsed.definition.props:
		var prop_id: StringName = prop.get("id", &"")
		if expected.has(prop_id):
			assert_eq(prop.get("display_goods"), expected[prop_id])
			expected.erase(prop_id)
	assert_true(expected.is_empty(), "all four civic-market stalls need display modules")


func _visual_bounds(model: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		# Countertop modules are intentionally excluded from base-frame dimensions.
		if model.is_ancestor_of(mesh_instance) and model.get_node("CountertopDisplay").is_ancestor_of(mesh_instance):
			continue
		var child_bounds := (model.transform * mesh_instance.transform) * mesh_instance.get_aabb()
		bounds = child_bounds if first else bounds.merge(child_bounds)
		first = false
	return bounds

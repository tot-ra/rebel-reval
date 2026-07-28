extends "res://tests/godot/test_case.gd"

const ChestModels := preload("res://scripts/map/view3d/map_view_chest_models.gd")
const PropStyleVariants := preload("res://scripts/map/map_prop_style_variants.gd")


func test_chest_variants_have_strict_domain_allowlist() -> void:
	for variant in PropStyleVariants.CHEST_VARIANTS:
		assert_true(PropStyleVariants.is_known(MapTypes.PROP_KIND_CHEST, variant))
	assert_false(
		PropStyleVariants.is_known(MapTypes.PROP_KIND_CHEST, &"chest.merchant_strong_box"),
		"variant typos must fail map compilation"
	)
	assert_false(
		PropStyleVariants.is_known(MapTypes.PROP_KIND_TABLE, PropStyleVariants.CHEST_BURGHER),
		"chest variants must not leak to other prop kinds"
	)


func test_each_wealth_class_uses_distinct_grounded_production_geometry() -> void:
	var expectations := {
		PropStyleVariants.CHEST_PLAIN_COFFER: {
			"name": "PlainCofferModel",
			"dimensions": Vector3(0.815, 0.4475, 0.5125),
			"triangles": Vector2i(650, 1000),
			"materials": 2,
		},
		PropStyleVariants.CHEST_BURGHER: {
			"name": "BurgherChestModel",
			"dimensions": Vector3(1.005, 0.6075, 0.61),
			"triangles": Vector2i(1700, 2400),
			"materials": 3,
		},
		PropStyleVariants.CHEST_MERCHANT_STRONGBOX: {
			"name": "MerchantStrongboxModel",
			"dimensions": Vector3(1.2445, 0.7026, 0.71),
			"triangles": Vector2i(3200, 4500),
			"materials": 3,
		},
	}
	for variant in PropStyleVariants.CHEST_VARIANTS:
		var host := Node3D.new()
		var model := ChestModels.add_model(host, {"style_variant": variant})
		var expected: Dictionary = expectations[variant]
		assert_eq(model.name, expected["name"])
		assert_true(model.get_meta(&"production_chest_model", false))
		assert_eq(model.get_meta(&"chest_style_variant"), variant)

		var audit := _audit_model(model)
		var dimensions: Vector3 = audit["bounds"].size
		var target: Vector3 = expected["dimensions"]
		assert_true(
			dimensions.distance_to(target) <= 0.001,
			"%s dimensions must be %s, got %s" % [variant, target, dimensions]
		)
		assert_true(audit["bounds"].position.y >= -0.001, "%s must rest on the ground plane" % variant)
		assert_true(audit["triangles"] >= expected["triangles"].x)
		assert_true(audit["triangles"] <= expected["triangles"].y)
		assert_eq(audit["materials"].size(), expected["materials"])
		assert_eq(audit["textured_materials"].size(), expected["materials"], "%s needs embedded albedos on every surface" % variant)
		host.free()


func test_chest_style_variant_round_trips_and_rejects_unknown_value() -> void:
	var source := """rrmap 1
map chest_variants loc.chest_variants 12 10 timber_floor
prop strongbox chest 4 5 rect=2,2 style_variant=chest.merchant_strongbox
spawn spawn.main 2 2
"""
	var parsed := MapRrmapParser.parse(source, "res://chest_variants.rrmap")
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	assert_eq(
		parsed.definition.props[0].get("style_variant"),
		PropStyleVariants.CHEST_MERCHANT_STRONGBOX
	)
	var canonical := MapRrmapParser.canonical_print(parsed.blueprint)
	assert_true("style_variant=chest.merchant_strongbox" in canonical)
	var reparsed := MapRrmapParser.parse(canonical, "res://chest_variants.canonical.rrmap")
	assert_true(reparsed.is_ok(), str(reparsed.formatted_diagnostics()))

	var invalid := source.replace("chest.merchant_strongbox", "chest.merchant_strong_box")
	var rejected := MapRrmapParser.parse(invalid, "res://invalid_chest_variant.rrmap")
	assert_false(rejected.is_ok(), "unknown chest variant must fail compilation")
	assert_true(
		str(rejected.formatted_diagnostics()).contains("style_variant is unknown"),
		"invalid variant needs an actionable diagnostic"
	)


func test_authored_maps_select_chests_by_household_and_storage_purpose() -> void:
	var expected := {
		"res://content/maps/kalev_smithy.rrmap": {
			&"chest": PropStyleVariants.CHEST_BURGHER,
		},
		"res://content/maps/holy_spirit_church.rrmap": {
			&"alms_chest": PropStyleVariants.CHEST_BURGHER,
		},
		"res://content/maps/town_hall.rrmap": {
			&"charter_chest": PropStyleVariants.CHEST_BURGHER,
			&"treasury_chest": PropStyleVariants.CHEST_MERCHANT_STRONGBOX,
		},
		"res://content/maps/st_olafs_guild_hall.rrmap": {
			&"guild_chest": PropStyleVariants.CHEST_MERCHANT_STRONGBOX,
		},
	}
	for path in expected:
		var parsed := MapRrmapParser.parse_file(path)
		assert_true(parsed.is_ok(), "%s: %s" % [path, parsed.formatted_diagnostics()])
		if not parsed.is_ok():
			continue
		var remaining: Dictionary = expected[path].duplicate()
		for prop in parsed.definition.props:
			var prop_id: StringName = prop.get("id", &"")
			if remaining.has(prop_id):
				assert_eq(prop.get("style_variant"), remaining[prop_id])
				remaining.erase(prop_id)
		assert_true(remaining.is_empty(), "%s must retain every authored chest" % path)


func test_chest_climb_height_tracks_selected_model() -> void:
	var expected := {
		PropStyleVariants.CHEST_PLAIN_COFFER: 0.45,
		PropStyleVariants.CHEST_BURGHER: 0.61,
		PropStyleVariants.CHEST_MERCHANT_STRONGBOX: 0.70,
	}
	for variant in expected:
		var prop := {
			"kind": MapTypes.PROP_KIND_CHEST,
			"style_variant": variant,
			"footprint": Rect2(Vector2.ZERO, Vector2.ONE),
		}
		assert_true(MapClimbableProps.is_climbable(prop))
		assert_true(is_equal_approx(MapClimbableProps.stand_height(prop), expected[variant]))


func _audit_model(model: Node3D) -> Dictionary:
	var bounds := AABB()
	var first := true
	var triangles := 0
	var materials: Dictionary = {}
	var textured_materials: Dictionary = {}
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var local_transform := _transform_from_ancestor(model, mesh_instance)
		var child_bounds := local_transform * mesh_instance.get_aabb()
		bounds = child_bounds if first else bounds.merge(child_bounds)
		first = false
		for surface_index in mesh_instance.mesh.get_surface_count():
			triangles += mesh_instance.mesh.surface_get_array_index_len(surface_index) / 3
			var material := mesh_instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
			if material == null:
				continue
			materials[material.resource_name] = true
			if material.albedo_texture != null:
				textured_materials[material.resource_name] = true
	assert_false(first, "chest GLB must contain renderable mesh geometry")
	return {
		"bounds": bounds,
		"triangles": triangles,
		"materials": materials,
		"textured_materials": textured_materials,
	}


func _transform_from_ancestor(ancestor: Node3D, node: Node3D) -> Transform3D:
	var transform := Transform3D.IDENTITY
	var current := node
	while current != null and current != ancestor:
		transform = current.transform * transform
		current = current.get_parent() as Node3D
	return transform

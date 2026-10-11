extends "res://tests/godot/test_case.gd"

const HouseholdClutterModels := preload("res://scripts/map/view3d/map_view_household_clutter_models.gd")
const PropStyleVariants := preload("res://scripts/map/map_prop_style_variants.gd")


func test_household_clutter_variants_have_strict_domain_allowlist() -> void:
	for variant in PropStyleVariants.HOUSEHOLD_CLUTTER_VARIANTS:
		assert_true(PropStyleVariants.is_known(MapTypes.PROP_KIND_HOUSEHOLD_CLUTTER, variant))
	assert_false(
		PropStyleVariants.is_known(MapTypes.PROP_KIND_HOUSEHOLD_CLUTTER, &"provision.coffee"),
		"variant typos must fail map compilation"
	)
	assert_false(
		PropStyleVariants.is_known(MapTypes.PROP_KIND_KITCHENWARE, MapTypes.PROVISION_RYE_BREAD_LOAF),
		"household clutter variants must not leak to other prop kinds"
	)


func test_each_household_clutter_variant_uses_production_model_with_ground_pivot() -> void:
	for variant in PropStyleVariants.HOUSEHOLD_CLUTTER_VARIANTS:
		var host := Node3D.new()
		var model := HouseholdClutterModels.add_model(host, {
			"kind": MapTypes.PROP_KIND_HOUSEHOLD_CLUTTER,
			"id": &"household_clutter_test",
			"style_variant": variant,
		})
		assert_true(model.get_meta(&"production_household_clutter_model", false), "%s must use the production GLB" % variant)
		assert_eq(model.get_meta(&"household_clutter_style_variant"), variant)

		var selected_roots := 0
		for root_name in HouseholdClutterModels.VARIANT_ROOT_NAMES.values():
			if model.find_child(String(root_name), true, false) != null:
				selected_roots += 1
		assert_eq(selected_roots, 1, "%s must hide the other household clutter roots" % variant)

		var pivot := _find_authored_pivot(model)
		assert_true(pivot != null, "%s needs an authored pivot marker" % variant)

		var audit := _audit_model(model)
		assert_true(audit["bounds"].position.y >= -0.001, "%s must rest on the ground plane" % variant)
		assert_true(audit["triangles"] >= 8, "%s needs authored mesh geometry" % variant)
		assert_true(audit["materials"].size() >= 1, "%s needs at least one material" % variant)
		host.free()


func test_grouped_household_clutter_modules_have_spread_layout() -> void:
	for variant in [
		MapTypes.HOUSEHOLD_GROUP_CLOSED,
		MapTypes.HOUSEHOLD_GROUP_IN_USE,
		MapTypes.HOUSEHOLD_GROUP_DEPLETED,
		MapTypes.HOUSEHOLD_GROUP_CLEARED,
	]:
		var host := Node3D.new()
		var model := HouseholdClutterModels.add_model(host, {
			"kind": MapTypes.PROP_KIND_HOUSEHOLD_CLUTTER,
			"style_variant": variant,
		})
		var audit := _audit_model(model)
		var span: Vector3 = audit["bounds"].size
		var footprint := maxf(span.x, span.z)
		assert_true(footprint >= 0.28, "%s grouped module should read wider than a single item" % variant)
		assert_true(span.y >= 0.02, "%s grouped module needs authored vertical presence" % variant)
		assert_true(audit["triangles"] >= 48, "%s grouped module needs multiple authored surfaces" % variant)
		host.free()


func _find_authored_pivot(root: Node) -> Node:
	for node in _walk_nodes(root):
		var node_name := String(node.name)
		if node_name.ends_with("GroundPivot") or node_name.ends_with("HandPivot") or node_name.ends_with("TablePivot") or node_name.ends_with("CarryPivot") or node_name.ends_with("HookPivot"):
			return node
	return null


func _walk_nodes(root: Node) -> Array[Node]:
	var stack: Array[Node] = [root]
	var visited: Array[Node] = []
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		visited.append(current)
		for child in current.get_children():
			stack.append(child)
	return visited


func test_unknown_household_clutter_variant_falls_back_to_rye_bread_loaf() -> void:
	var prop := {
		"kind": MapTypes.PROP_KIND_HOUSEHOLD_CLUTTER,
		"style_variant": &"provision.coffee",
	}
	assert_eq(MapTypes.household_clutter_variant_for_prop(prop), MapTypes.PROVISION_RYE_BREAD_LOAF)
	assert_eq(MapTypes.invalid_household_clutter_variant(prop), &"provision.coffee")
	assert_false(PropStyleVariants.is_known(MapTypes.PROP_KIND_HOUSEHOLD_CLUTTER, &"provision.coffee"))


func test_household_clutter_style_variant_round_trips_through_rrmap_parser() -> void:
	var source := """rrmap 1
map household_clutter_test loc.household_clutter_test 12 10 timber_floor
prop peas_bin household_clutter 4 5 rect=1,1 style_variant=provision.dried_peas_bin
spawn spawn.main 2 2
"""
	var parsed := MapRrmapParser.parse(source, "res://household_clutter_test.rrmap")
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	assert_eq(
		parsed.definition.props[0].get("style_variant"),
		MapTypes.PROVISION_DRIED_PEAS_BIN
	)
	var canonical := MapRrmapParser.canonical_print(parsed.blueprint)
	assert_true("style_variant=provision.dried_peas_bin" in canonical)
	var invalid := MapRrmapParser.parse(
		source.replace("provision.dried_peas_bin", "provision.coffee"),
		"res://household_clutter_test.rrmap"
	)
	assert_false(invalid.is_ok(), "unknown household clutter variants must fail validation")


func _audit_model(root: Node3D) -> Dictionary:
	var bounds := AABB()
	var triangles := 0
	var materials: Dictionary = {}
	var first := true
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var local_transform := _transform_from_ancestor(root, mesh_instance)
		var child_bounds := local_transform * mesh_instance.get_aabb()
		bounds = child_bounds if first else bounds.merge(child_bounds)
		first = false
		for surface_index in mesh_instance.mesh.get_surface_count():
			triangles += mesh_instance.mesh.surface_get_array_index_len(surface_index) / 3
			var material := mesh_instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
			if material == null:
				continue
			materials[material.resource_name] = material
	assert_false(first, "household clutter GLB must contain renderable mesh geometry")
	return {
		"bounds": bounds,
		"triangles": triangles,
		"materials": materials,
	}


func _transform_from_ancestor(ancestor: Node3D, node: Node3D) -> Transform3D:
	var transform := Transform3D.IDENTITY
	var current := node
	while current != null and current != ancestor:
		transform = current.transform * transform
		current = current.get_parent() as Node3D
	return transform

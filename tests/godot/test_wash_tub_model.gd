extends "res://tests/godot/test_case.gd"

## R-1190: the yard wash tub is a coopered stave tub, not a legged cylinder
## with a rim-level water disc that read as a bucket or baptismal font.

const WashTubModels := preload("res://scripts/map/view3d/map_view_wash_tub_models.gd")


func _build_tub() -> Node3D:
	return MapViewMeshBuilder.build_prop(
		{"id": &"test_wash_tub", "kind": MapTypes.PROP_KIND_WASH_TUB, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)


func _mesh_aabb(root: Node3D, node_name: String) -> AABB:
	var node := root.find_child(node_name, true, false) as MeshInstance3D
	assert_true(node != null, "wash tub needs a %s mesh" % node_name)
	if node == null:
		return AABB()
	return node.get_aabb()


func test_wash_tub_is_coopered_model_without_legs() -> void:
	var prop := _build_tub()
	var model := prop.find_child("WashTub", true, false)
	assert_true(model != null, "wash_tub must use the authored coopered model")
	assert_true(model != null and model.get_meta(&"production_wash_tub_model", false))
	assert_true(
		prop.find_child("LegFL", true, false) == null,
		"legged cylinder placeholder must stay retired"
	)
	for part in ["Staves", "BottomHead", "Water", "Hoops", "Sleepers", "WashingBat"]:
		assert_true(prop.find_child(part, true, false) != null, "wash tub needs %s" % part)
	prop.free()


func test_water_sits_well_below_the_rim() -> void:
	var prop := _build_tub()
	var water := _mesh_aabb(prop, "Water")
	var staves := _mesh_aabb(prop, "Staves")
	var rim_y := WashTubModels.BODY_TOP
	assert_true(water.end.y <= rim_y - 0.08, "water must be at least 8 cm below the rim")
	assert_true(staves.end.y > rim_y + 0.1, "ear staves must rise above the rim")
	assert_true(water.size.x < staves.size.x, "water must sit inside the stave wall")
	prop.free()


func test_tub_fits_one_cell_and_stands_on_ground() -> void:
	var prop := _build_tub()
	var bounds := AABB()
	var first := true
	for child in prop.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var child_bounds := _local_bounds(prop, mesh_instance)
		bounds = child_bounds if first else bounds.merge(child_bounds)
		first = false
	assert_false(first, "wash tub must expose render geometry")
	assert_true(
		bounds.size.x <= 1.1 and bounds.size.z <= 1.1, "tub must stay inside its one-cell footprint"
	)
	assert_true(bounds.size.y < 0.8, "tub must stay a low yard vessel")
	assert_true(bounds.position.y >= -0.01, "tub must not sink into the ground")
	prop.free()


func test_meshes_are_cached_and_deterministic() -> void:
	var first := _build_tub()
	var second := _build_tub()
	for part in ["Staves", "Hoops", "Water"]:
		var a := first.find_child(part, true, false) as MeshInstance3D
		var b := second.find_child(part, true, false) as MeshInstance3D
		assert_true(
			a != null and b != null and a.mesh == b.mesh,
			"%s mesh must be shared from the cache" % part
		)
	first.free()
	second.free()


func _local_bounds(root: Node3D, node: Node3D) -> AABB:
	var transform := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != root:
		if current is Node3D:
			transform = (current as Node3D).transform * transform
		current = current.get_parent()
	return transform * (node as MeshInstance3D).get_aabb()

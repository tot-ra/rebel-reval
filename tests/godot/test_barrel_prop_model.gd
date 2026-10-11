extends "res://tests/godot/test_case.gd"

## One `barrels` prop builds exactly one coopered barrel, so maps set the barrel
## count by placing props. Geometry is shared and the per-prop turn is stable.

const BarrelMeshes := preload("res://scripts/map/view3d/map_view_barrel_meshes.gd")


func _build(id: StringName) -> Node3D:
	return MapViewMeshBuilder.build_prop(
		{"id": id, "kind": MapTypes.PROP_KIND_BARRELS, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)


func test_prop_builds_a_single_barrel() -> void:
	var prop := _build(&"test.barrel")
	assert_eq(prop.get_child_count(), 1, "a barrels prop must hold exactly one barrel")
	var barrel := prop.get_child(0) as Node3D
	assert_eq(barrel.name, &"Barrel")
	for part in ["Staves", "TopHead", "BottomHead", "Bung"]:
		assert_true(barrel.has_node(part), "barrel is missing %s" % part)
	var hoops := barrel.get_children().filter(
		func(node: Node) -> bool: return String(node.name).begins_with("Hoop")
	)
	assert_eq(hoops.size(), BarrelMeshes.HOOP_BANDS.size())
	prop.free()


func test_barrel_matches_catalog_size_and_stays_inside_its_cell() -> void:
	var prop := _build(&"test.barrel_size")
	var staves := prop.get_node("Barrel/Staves") as MeshInstance3D
	var bounds := staves.mesh.get_aabb()
	assert_almost_eq(bounds.size.y, BarrelMeshes.HEIGHT, 0.001)
	# obj.barrel_oak is 0.62 m across; the bilge must not outgrow it.
	assert_true(bounds.size.x <= 0.625 and bounds.size.z <= 0.625, "barrel wider than catalog")
	assert_almost_eq(
		MapClimbableProps.STAND_HEIGHT_BY_KIND[MapTypes.PROP_KIND_BARRELS], BarrelMeshes.HEIGHT, 0.001
	)
	prop.free()


func test_barrels_share_meshes_and_turn_by_stable_id() -> void:
	var first := _build(&"test.barrel_a")
	var again := _build(&"test.barrel_a")
	var other := _build(&"test.barrel_b")
	var first_barrel := first.get_node("Barrel") as Node3D
	assert_eq(first_barrel.rotation.y, (again.get_node("Barrel") as Node3D).rotation.y)
	assert_ne(first_barrel.rotation.y, (other.get_node("Barrel") as Node3D).rotation.y)
	assert_eq(
		(first.get_node("Barrel/Staves") as MeshInstance3D).mesh,
		(other.get_node("Barrel/Staves") as MeshInstance3D).mesh,
		"barrel meshes must be cached and shared between props"
	)
	first.free()
	again.free()
	other.free()

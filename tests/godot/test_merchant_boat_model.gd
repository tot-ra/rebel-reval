extends "res://tests/godot/test_case.gd"


func test_merchant_boat_uses_a_shaped_cog_hull_and_working_rig() -> void:
	var boat := MapViewMeshBuilder.build_prop(
		{
			"id": &"merchant_cog",
			"kind": MapTypes.PROP_KIND_MERCHANT_BOAT,
			"position": Vector2.ZERO,
		},
		MapTypes.DEFAULT_CELL_SIZE
	)
	var hull := boat.get_node("Hull") as MeshInstance3D
	assert_true(hull.mesh is ArrayMesh, "merchant hull must use station-built geometry, not a prism placeholder")
	var hull_bounds := hull.get_aabb()
	assert_true(hull_bounds.size.x > hull_bounds.size.z * 2.0, "merchant cog needs a long, broad cargo hull")
	assert_true(hull_bounds.position.y < -0.4, "merchant cog needs a keel below the waterline")
	assert_true(boat.has_node("BowStem"), "merchant cog needs a raised bow stem")
	assert_true(boat.has_node("Rudder"), "merchant cog needs a stern-mounted rudder")

	for castle_name in ["Aftcastle", "Forecastle"]:
		var castle := boat.get_node(castle_name) as Node3D
		assert_true(castle.has_node("Platform"), "%s needs a raised working platform" % castle_name)
		assert_true(castle.has_node("RailPort"), "%s must be an open railed castle, not a solid cabin" % castle_name)
	assert_true(boat.has_node("CargoHatch"), "trade ship needs a visible cargo hold")
	assert_true(boat.has_node("CargoCrateLarge"), "trade ship deck needs merchant cargo")

	var sail := boat.get_node("SquareSail") as MeshInstance3D
	assert_true(sail.mesh is ArrayMesh, "square sail must be a shaped cloth mesh, not a flat box")
	var sail_material := sail.material_override as ShaderMaterial
	assert_true(sail_material != null, "square sail must use the shared wind cloth shader")
	assert_true(
		sail_material.get_shader_parameter("free_edge") == Vector2(0.0, 1.0),
		"square sail must hang free from the yard (UV.y)"
	)
	assert_true(boat.has_node("MastheadPennant"), "merchant cogs need a Hanseatic masthead pennant")
	assert_eq(boat.get_node("MastheadPennant").get_meta(&"faction"), FactionHeraldry.HANSEATIC)
	var sail_vertices := sail.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var min_bulge := INF
	var max_bulge := -INF
	for vertex in sail_vertices:
		min_bulge = minf(min_bulge, vertex.x)
		max_bulge = maxf(max_bulge, vertex.x)
	assert_true(max_bulge - min_bulge > 0.2, "square sail needs visible wind-filled curvature")

	var rigging := boat.get_node("Rigging") as Node3D
	for line_name in ["Forestay", "Backstay", "ShroudPortA", "ShroudStarboardA", "SheetPort", "SheetStarboard"]:
		assert_true(rigging.has_node(line_name), "working rig is missing %s" % line_name)
	boat.free()

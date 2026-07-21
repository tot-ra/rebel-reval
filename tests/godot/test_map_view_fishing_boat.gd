extends "res://tests/godot/test_case.gd"

const FishingBoatBuilder := preload("res://scripts/map/view3d/map_view_fishing_boat_builder.gd")


func test_fishing_boat_has_shaped_open_hull_and_working_rig() -> void:
	var boat := Node3D.new()
	FishingBoatBuilder.add_to(boat)
	var hull := boat.get_node("Hull") as MeshInstance3D
	assert_true(hull.mesh is ArrayMesh, "fishing hull must use shaped station-built geometry")
	for path in [
		"Interior",
		"GunwalePort0",
		"GunwaleStarboard0",
		"StrakePort0",
		"Bench0",
		"Yard/FurledSail",
		"Rigging/Forestay",
		"Rigging/ShroudStarboard",
		"OarPort/Shaft",
		"OarPort/Blade",
		"OarStarboard/Shaft",
		"Rudder",
		"Tiller",
		"FishBasket",
	]:
		assert_true(boat.has_node(path), "fishing boat needs %s" % path)

	var arrays := (hull.mesh as ArrayMesh).surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var middle_half_beam := 0.0
	var end_half_beam := 0.0
	var middle_sheer := -INF
	var end_sheer := -INF
	var keel_depth := INF
	for vertex in vertices:
		keel_depth = minf(keel_depth, vertex.y)
		if absf(vertex.x) < 0.1:
			middle_half_beam = maxf(middle_half_beam, absf(vertex.z))
			middle_sheer = maxf(middle_sheer, vertex.y)
		if absf(vertex.x) > 1.8:
			end_half_beam = maxf(end_half_beam, absf(vertex.z))
			end_sheer = maxf(end_sheer, vertex.y)
	assert_true(middle_half_beam > end_half_beam * 4.0, "hull must taper from its working middle into fine ends")
	assert_true(end_sheer > middle_sheer + 0.25, "bow and stern must rise above the amidships gunwale")
	assert_true(keel_depth < -0.3, "hull needs a visible bilge and keel below the waterline")
	boat.free()

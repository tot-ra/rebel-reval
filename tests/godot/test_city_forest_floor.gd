extends "res://tests/godot/test_case.gd"

## R-1661: moss and fungi on the floor of the city woods, and the shade mask
## that lets moss carpet the ground north of buildings and under canopy.


func _floor(plan: CityPlan) -> CityForestFloor:
	var parent := Node3D.new()
	var node := CityForestFloor.build(plan, parent)
	parent.remove_child(node)
	parent.free()
	return node


func test_fungi_follow_the_season() -> void:
	var april := CityForestFloor.kinds_in_season(111)
	assert_array_contains(april, CityForestFloor.KIND_GYROMITRA, "false morel in late April")
	assert_false(april.has(CityForestFloor.KIND_CHANTERELLE), "no chanterelle in April")
	assert_false(april.has(CityForestFloor.KIND_FLY_AGARIC), "no fly agaric in April")
	var august := CityForestFloor.kinds_in_season(230)
	var summer := [
		CityForestFloor.KIND_CHANTERELLE, CityForestFloor.KIND_PORCINI, CityForestFloor.KIND_FLY_AGARIC
	]
	for kind in summer:
		assert_array_contains(august, kind, "%s in August" % kind)
	assert_false(august.has(CityForestFloor.KIND_GYROMITRA), "false morel is over by August")
	for day in [15, 111, 230, 350]:
		var kinds := CityForestFloor.kinds_in_season(day)
		assert_array_contains(kinds, CityForestFloor.KIND_MOSS, "moss on day %d" % day)
		assert_array_contains(kinds, CityForestFloor.KIND_BRACKET, "brackets on day %d" % day)


func test_floor_is_deterministic_and_only_in_woods() -> void:
	var plan := CityPlan.load_default()
	var a := _floor(plan)
	var b := _floor(plan)
	var pa := a.placements()
	var pb := b.placements()
	assert_true(pa.size() > 500, "the woods get a real floor (%d instances)" % pa.size())
	assert_eq(pa.size(), pb.size(), "same plan, same instance count")
	var same := true
	for i in pa.size():
		if pa[i][0] != pb[i][0] or not (pa[i][1] as Transform3D).is_equal_approx(pb[i][1]):
			same = false
			break
	assert_true(same, "same plan, same transforms")
	for kind in CityForestFloor.KINDS:
		assert_true(a.instance_count(kind) > 0, "%s is placed somewhere" % kind)
	# Every instance stands within a few metres of a wooded tree, never on open ground.
	var woods := CityForestFloor.wooded_trees(plan)
	var grid := {}
	for t: Array in woods:
		grid[Vector2i(floori(float(t[0]) / 8.0), floori(float(t[1]) / 8.0))] = true
	var stray := 0
	for entry: Array in pa:
		var o: Vector3 = (entry[1] as Transform3D).origin
		var c := Vector2i(floori(o.x / 8.0), floori(o.z / 8.0))
		var near := false
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				if grid.has(c + Vector2i(dx, dz)):
					near = true
		if not near:
			stray += 1
	assert_eq(stray, 0, "no forest-floor instance outside the woods")
	a.free()
	b.free()


func test_calendar_hides_out_of_season_fungi() -> void:
	var node := _floor(CityPlan.load_default())
	node.set_calendar_date({"year": 1343, "month": 4, "day": 21})
	var april := node.visible_kinds()
	assert_array_contains(april, CityForestFloor.KIND_GYROMITRA, "false morel shows in April")
	assert_false(april.has(CityForestFloor.KIND_PORCINI), "porcini hidden in April")
	node.set_calendar_date({"year": 1343, "month": 8, "day": 20})
	var august := node.visible_kinds()
	assert_array_contains(august, CityForestFloor.KIND_PORCINI, "porcini shows in August")
	assert_false(august.has(CityForestFloor.KIND_GYROMITRA), "false morel hidden in August")
	assert_array_contains(august, CityForestFloor.KIND_MOSS, "moss stays")
	node.free()


func test_lathe_meshes_face_outwards() -> void:
	# The fungi share one back-culled material, so their walls must face out.
	var mesh := CityForestFloor.mesh_for(CityForestFloor.KIND_MOSS)
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var outward := 0
	var inward := 0
	for i in verts.size():
		var radial := Vector2(verts[i].x, verts[i].z)
		if radial.length() < 0.2:
			continue
		if Vector2(normals[i].x, normals[i].z).dot(radial) > 0.0:
			outward += 1
		else:
			inward += 1
	var msg := "moss cushion normals point out (%d out, %d in)" % [outward, inward]
	assert_true(outward > inward * 4, msg)


func test_shade_mask_marks_the_north_side_of_buildings() -> void:
	var plan := CityPlan.load_default()
	var image := CityShadeMask.build_image(plan)
	var north := 0.0
	var south := 0.0
	var samples := 0
	for i in range(0, plan.buildings.size(), 7):
		var ring := plan.footprint(i)
		if ring.size() < 3:
			continue
		var lo := ring[0]
		var hi := ring[0]
		var mid := Vector2.ZERO
		for p in ring:
			lo = lo.min(p)
			hi = hi.max(p)
			mid += p
		mid /= float(ring.size())
		north += CityShadeMask.strip_at(image, plan, Vector2(mid.x, lo.y - 1.5))
		south += CityShadeMask.strip_at(image, plan, Vector2(mid.x, hi.y + 1.5))
		samples += 1
	assert_true(samples > 50, "enough buildings sampled")
	var mean_north := north / samples
	assert_true(mean_north > 0.4, "ground just north of walls is shaded (%.2f)" % mean_north)
	# Dense blocks shade each other, so the south side is not zero.
	assert_true(north > south * 2.0, "north strips, not south (%.2f vs %.2f)" % [north, south])
	# Canopy: the woods are shaded, the open town square is not.
	var woods := CityForestFloor.wooded_trees(plan)
	var canopy := 0.0
	for k in range(0, woods.size(), 25):
		var t: Array = woods[k]
		var uv := (Vector2(t[0], t[1]) - plan.bounds.position) / CityShadeMask.CELL
		var px := Vector2i(uv.floor()).clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE)
		canopy += image.get_pixelv(px).g
	assert_true(canopy / ceilf(woods.size() / 25.0) > 0.4, "woods are under canopy shade")


func test_shade_mask_blue_is_signed_distance_to_walls() -> void:
	var plan := CityPlan.load_default()
	var started := Time.get_ticks_msec()
	var image := CityShadeMask.build_image(plan)
	var build_ms := Time.get_ticks_msec() - started
	var on_wall := 0.0
	var outside := 0
	var inside := 0
	var samples := 0
	for i in range(0, plan.buildings.size(), 7):
		var ring := plan.footprint(i)
		if ring.size() < 3:
			continue
		var a := ring[0]
		var b := ring[1]
		if a.distance_to(b) < 4.0:
			continue
		var mid := (a + b) * 0.5
		var n := (b - a).orthogonal().normalized()
		if Geometry2D.is_point_in_polygon(mid + n * 0.2, ring):
			n = -n
		on_wall += absf(CityShadeMask.wall_distance_at(image, plan, mid))
		if CityShadeMask.wall_distance_at(image, plan, mid + n * 1.5) > 0.6:
			outside += 1
		if CityShadeMask.wall_distance_at(image, plan, mid - n * 1.0) < 0.0:
			inside += 1
		samples += 1
	assert_true(samples > 50, "enough walls sampled (%d)" % samples)
	# Bilinear over 2 m texels: straight walls decode to within a few decimetres.
	assert_true(on_wall / samples < 0.35, "wall line decodes near 0 (%.2f m)" % (on_wall / samples))
	assert_true(outside > samples * 0.8, "1.5 m out reads as outside (%d/%d)" % [outside, samples])
	assert_true(inside > samples * 0.8, "1 m in reads as inside (%d/%d)" % [inside, samples])
	print("shade mask build %d ms" % build_ms)

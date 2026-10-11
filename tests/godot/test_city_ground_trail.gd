extends "res://tests/godot/test_case.gd"

## Open-country relief, cart roads and the footprint trail map of the seamless
## city (docs/SYSTEMS/SEAMLESS_CITY.md, "Ground relief, roads and prints").

const FLAT := 0.5


func _soft_trail() -> CityGroundTrail:
	var plan := CityPlan.load_default()
	# Every spot counts as bare packed earth, so footfalls always bite.
	var trail := CityGroundTrail.create(plan, func(_p: Vector2) -> Color: return Color(0, 1, 0, 0))
	trail.update_for(Vector2(0, -400), 0.016)
	return trail


func test_untouched_ground_is_neutral() -> void:
	var trail := _soft_trail()
	assert_almost_eq(trail.value_at(Vector2(0, -400)), FLAT, 0.01)
	assert_almost_eq(trail.value_at(Vector2(5000, 5000)), FLAT, 0.01, "outside the window")
	trail.free()


func test_foot_press_dents_the_ground_and_heaps_a_rim() -> void:
	var trail := _soft_trail()
	var at := Vector2(0, -400)
	trail.stamp_foot(at, Vector2.RIGHT)
	assert_true(trail.value_at(at) < FLAT - 0.1, "pressed centre")
	var rim_value := trail.value_at(at + Vector2(CityGroundTrail.FOOT_RADIUS.x * 1.2, 0.0))
	assert_true(rim_value > FLAT + 0.02, "rim of pushed-up earth, got %.3f" % rim_value)
	trail.free()


func test_walking_leaves_alternating_prints() -> void:
	var trail := _soft_trail()
	var pos := Vector2(0, -400)
	for i in 80:
		pos += Vector2(0.25, 0.0)
		trail.update_for(pos, 0.016)
	var prints := 0
	var x := 0.0
	while x < 20.0:
		if trail.value_at(Vector2(x, -400.0 + CityGroundTrail.FOOT_SPREAD)) < FLAT - 0.1:
			prints += 1
		if trail.value_at(Vector2(x, -400.0 - CityGroundTrail.FOOT_SPREAD)) < FLAT - 0.1:
			prints += 1
		x += CityGroundTrail.CELL
	assert_true(prints > 20, "prints on both sides of the track, counted %d cells" % prints)
	trail.free()


func test_window_follows_without_losing_nearby_prints() -> void:
	var trail := _soft_trail()
	var at := Vector2(0, -400)
	trail.stamp_foot(at, Vector2.RIGHT)
	var dent := trail.value_at(at)
	# Walk to the window edge: it recentres and keeps what is still inside it.
	var pos := at
	for i in 64:
		pos += Vector2(0.25, 0.0)
		trail.update_for(pos, 0.016)
	assert_almost_eq(trail.value_at(at), dent, 0.01, "print survives the recentre")
	trail.free()


func test_paving_takes_no_print() -> void:
	var plan := CityPlan.load_default()
	var trail := CityGroundTrail.create(plan, func(_p: Vector2) -> Color: return Color(1, 0, 0, 0))
	var pos := Vector2(0, -400)
	trail.update_for(pos, 0.016)
	for i in 40:
		pos += Vector2(0.25, 0.0)
		trail.update_for(pos, 0.016)
	assert_almost_eq(trail.value_at(Vector2(5.0, -400.0)), FLAT, 0.01)
	trail.free()


func test_roads_raster_marks_the_cart_roads() -> void:
	var plan := CityPlan.load_default()
	var image := (load(CityPlan.ROADS_PATH) as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	var road: Dictionary = {}
	for s: Dictionary in plan.streets:
		if s["id"] == "road.tartu":
			road = s
	assert_false(road.is_empty(), "road.tartu is in the plan")
	var pts: Array = road["points"]
	var mid := (Vector2(pts[3][0], pts[3][1]) + Vector2(pts[4][0], pts[4][1])) * 0.5
	var px := Vector2i((mid - plan.bounds.position).floor())
	var texel := image.get_pixelv(px)
	assert_true(texel.r > 0.8, "road body at the road's midpoint, r=%.2f" % texel.r)
	assert_almost_eq(texel.g, 0.5, 0.1, "lateral offset near the centreline")
	var off := image.get_pixelv(px + Vector2i(40, 40))
	assert_true(off.r < 0.05, "no road 40 units away")


func test_open_country_is_no_longer_flat() -> void:
	var plan := CityPlan.load_default()
	# Southern fields: 200 m of ground a few hundred metres from the walls.
	var lo := 1e9
	var hi := -1e9
	for i in 40:
		var h := plan.ground_height(Vector2(-60.0 + float(i) * 5.0, 520.0))
		lo = minf(lo, h)
		hi = maxf(hi, h)
	assert_true(hi - lo > 1.0, "relief across 200 m is %.2f wu" % (hi - lo))


func test_wet_ground_takes_deeper_prints_than_dry() -> void:
	var dry := _soft_trail()
	var wet := _soft_trail()
	dry.wetness = 0.0
	wet.wetness = 1.0
	var pos := Vector2(0, -400)
	for i in 12:
		pos += Vector2(0.25, 0.0)
		dry.update_for(pos, 0.016)
		wet.update_for(pos, 0.016)
	var deepest_dry := 1.0
	var deepest_wet := 1.0
	var x := 0.0
	while x < 4.0:
		for sy in [-1.0, 1.0]:
			var p := Vector2(x, -400.0 + sy * CityGroundTrail.FOOT_SPREAD)
			deepest_dry = minf(deepest_dry, dry.value_at(p))
			deepest_wet = minf(deepest_wet, wet.value_at(p))
		x += CityGroundTrail.CELL
	assert_true(deepest_wet < deepest_dry - 0.1, "wet %.2f vs dry %.2f" % [deepest_wet, deepest_dry])
	dry.free()
	wet.free()


func test_grass_keeps_off_the_road_body_and_shrinks_at_its_edge() -> void:
	var plan := CityPlan.load_default()
	var grass := CityGrass.create(plan)
	var image := (load(CityPlan.ROADS_PATH) as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	var checked := 0
	for y in range(0, image.get_height(), 7):
		for x in range(0, image.get_width(), 7):
			var texel := image.get_pixel(x, y)
			if texel.r > 0.95 and texel.b > 0.5:
				var uv := (Vector2(x, y) + Vector2(0.5, 0.5)) / Vector2(image.get_size())
				var p := plan.bounds.position + uv * plan.bounds.size
				assert_true(grass.road_clearance(p) > 0.7, "busy road body is cleared of plants")
				assert_true(grass._bareness(p) >= 0.7, "bareness covers the road body")
				checked += 1
	assert_true(checked > 20, "found busy road texels, got %d" % checked)
	grass.free()


## Counts cells pressed below neutral in a world rectangle of the trail.
func _pressed_cells(trail: CityGroundTrail, rect: Rect2) -> int:
	var n := 0
	var x := rect.position.x
	while x < rect.end.x:
		var y := rect.position.y
		while y < rect.end.y:
			if trail.value_at(Vector2(x, y)) < FLAT - 0.05:
				n += 1
			y += CityGroundTrail.CELL
		x += CityGroundTrail.CELL
	return n


func _deepest(trail: CityGroundTrail, rect: Rect2) -> float:
	var low := 1.0
	var x := rect.position.x
	while x < rect.end.x:
		var y := rect.position.y
		while y < rect.end.y:
			low = minf(low, trail.value_at(Vector2(x, y)))
			y += CityGroundTrail.CELL
		x += CityGroundTrail.CELL
	return low


func _walk_walker(trail: CityGroundTrail, key: int, from: Vector2, steps: int) -> void:
	var pos := from
	for i in steps:
		pos += Vector2(0.25, 0.0)
		trail.update_for(Vector2(0, -400), 0.016)
		trail.track_walker(key, pos)


func test_citizen_walking_leaves_prints_inside_the_window() -> void:
	var trail := _soft_trail()
	_walk_walker(trail, 1, Vector2(3, -395), 40)
	assert_true(_pressed_cells(trail, Rect2(3, -396, 11, 2)) > 20, "citizen prints near Kalev")
	trail.free()


func test_walkers_beyond_track_radius_leave_nothing() -> void:
	var trail := _soft_trail()
	var far := Vector2(CityGroundTrail.TRACK_RADIUS + 5.0, -400)
	_walk_walker(trail, 2, far, 40)
	assert_eq(_pressed_cells(trail, Rect2(far.x, -401, 12, 2)), 0, "nothing beyond the radius")
	trail.free()


func test_hooves_press_by_species_and_ignore_birds() -> void:
	var trail := _soft_trail()
	var pos := Vector2(2, -398)
	for i in 40:
		pos += Vector2(0.2, 0.0)
		trail.update_for(Vector2(0, -400), 0.016)
		trail.track_hooves(10, pos, &"horse")
		trail.track_hooves(11, pos + Vector2(0, 3), &"goose")
	assert_true(_pressed_cells(trail, Rect2(2, -399, 8, 2)) > 10, "horse hoof prints")
	assert_eq(_pressed_cells(trail, Rect2(2, -396, 8, 2)), 0, "a goose leaves no hoof print")
	trail.free()


func test_cart_wheels_cut_two_grooves_and_wet_cuts_deeper() -> void:
	var dry := _soft_trail()
	var wet := _soft_trail()
	dry.wetness = 0.0
	wet.wetness = 1.0
	var pos := Vector2(2, -400)
	for i in 30:
		pos += Vector2(0.2, 0.0)
		for t: CityGroundTrail in [dry, wet]:
			t.update_for(Vector2(0, -400), 0.016)
			t.track_cart(20, pos, CartTransportModel.VEHICLE_CLASS_CART_2W)
	var cart_class := CartTransportModel.VEHICLE_CLASS_CART_2W
	var gauge: float = CartTransportModel.wheel_track_spec(cart_class)["gauge"]
	for sy in [-1.0, 1.0]:
		var line := Rect2(4, -400.0 + sy * gauge * 0.5 - 0.05, 4, 0.1)
		assert_true(_pressed_cells(wet, line) > 10, "groove on wheel line %.1f" % sy)
		assert_true(_deepest(wet, line) < _deepest(dry, line) - 0.1, "wet groove deeper")
	assert_almost_eq(wet.value_at(Vector2(6, -400)), FLAT, 0.01, "centre between the wheels stays")
	dry.free()
	wet.free()


func test_slow_cart_still_draws_a_groove() -> void:
	var trail := _soft_trail()
	trail.wetness = 1.0
	var pos := Vector2(2, -400)
	# 0.008 wu per frame is under one cell: the segment must accumulate.
	for i in 400:
		pos += Vector2(0.008, 0.0)
		trail.update_for(Vector2(0, -400), 0.016)
		trail.track_cart(21, pos, CartTransportModel.VEHICLE_CLASS_BARROW)
	assert_true(_pressed_cells(trail, Rect2(2.5, -400.1, 2.5, 0.2)) > 10, "barrow groove")
	trail.free()


func test_unknown_vehicle_class_leaves_nothing() -> void:
	var trail := _soft_trail()
	trail.track_cart(22, Vector2(2, -400), &"hovercraft")
	trail.track_cart(22, Vector2(4, -400), &"hovercraft")
	assert_eq(_pressed_cells(trail, Rect2(1, -401, 5, 2)), 0)
	trail.free()


func test_unfed_walkers_are_forgotten() -> void:
	var trail := _soft_trail()
	trail.track_walker(30, Vector2(3, -399))
	trail.update_for(Vector2(0, -400), 0.016)
	trail.update_for(Vector2(0, -400), 0.016)
	assert_eq(trail._marks.size(), 0, "mark dropped after a frame without feed")
	trail.free()


func test_relief_mesh_follows_kalev_on_the_height_grid() -> void:
	var plan := CityPlan.load_default()
	var ground := CityTerrainBuilder.material(plan)
	var trail := _soft_trail()
	var relief: MeshInstance3D = trail.get_node("TrailRelief")
	assert_true(relief.visible, "relief mesh shown once Kalev is placed")
	assert_eq(relief.material_override, ground, "relief mesh draws with the ground material")
	var cell := plan.height_cell()
	var centre := Vector2(relief.position.x, relief.position.z)
	var grid := (centre - plan.height_origin()) / cell
	assert_almost_eq(grid.x, roundf(grid.x), 0.001, "centre on a height grid vertex (x)")
	assert_almost_eq(grid.y, roundf(grid.y), 0.001, "centre on a height grid vertex (z)")
	assert_true(centre.distance_to(Vector2(0, -400)) <= cell * 0.75, "centre near Kalev")
	var rect: Vector4 = ground.get_shader_parameter("trail_mesh_rect")
	assert_almost_eq(rect.x, centre.x, 0.001)
	assert_almost_eq(rect.y, centre.y, 0.001)
	assert_almost_eq(rect.w, 1.0, 0.001, "chunks sink under the mesh")
	# Every cell touching a sunk chunk vertex must lie under the mesh, or the
	# sunk chunk would show as a pit past its edge.
	var farthest_sunk := floorf(rect.z / cell) * cell
	assert_true(farthest_sunk > 0.0, "some chunk vertices sink")
	assert_true(farthest_sunk + cell <= CityGroundTrail.RELIEF_HALF, "sunk cells inside the mesh")
	# Walking a few cells moves the mesh by whole grid cells.
	trail.update_for(Vector2(5.0, -400.0), 0.016)
	var moved := Vector2(relief.position.x, relief.position.z) - centre
	assert_almost_eq(fmod(absf(moved.x), cell), 0.0, 0.001, "re-snapped by whole cells")
	assert_true(moved.x > 0.0, "mesh followed Kalev")
	trail.free()


func test_relief_vertices_sit_on_trail_texel_corners() -> void:
	# Vertex spacing equals a trail cell and divides the height cell, so the mesh
	# vertices are fixed in the world and do not swim against the trail texels.
	var plan := CityPlan.load_default()
	var per_cell := plan.height_cell() / CityGroundTrail.RELIEF_STEP
	assert_almost_eq(per_cell, roundf(per_cell), 0.0001)
	var per_half := CityGroundTrail.RELIEF_HALF / CityGroundTrail.RELIEF_STEP
	assert_almost_eq(per_half, roundf(per_half), 0.0001)
	var origin_steps := plan.height_origin().x / CityGroundTrail.RELIEF_STEP
	assert_almost_eq(origin_steps, roundf(origin_steps), 0.0001)


func test_relief_mesh_has_no_cracks_between_its_densities() -> void:
	# A T-junction where the fine core meets the coarse ring would leave an edge
	# used by one triangle inside the mesh; only the outer border may have those.
	var mesh := CityGroundTrail.relief_mesh()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var uses := {}
	for t in range(0, indices.size(), 3):
		var a := verts[indices[t]]
		var b := verts[indices[t + 1]]
		var c := verts[indices[t + 2]]
		assert_true((b - a).cross(c - a).y < 0.0, "triangle %d keeps the chunk winding" % (t / 3))
		for k in 3:
			var u := indices[t + k]
			var v := indices[t + (k + 1) % 3]
			var key := Vector2i(mini(u, v), maxi(u, v))
			uses[key] = int(uses.get(key, 0)) + 1
	var edge := CityGroundTrail.RELIEF_HALF - 0.001
	var inner_open := 0
	for key: Vector2i in uses:
		if int(uses[key]) == 1:
			var p := (verts[key.x] + verts[key.y]) * 0.5
			if absf(p.x) < edge and absf(p.z) < edge:
				inner_open += 1
	assert_eq(inner_open, 0, "open edges inside the relief mesh")
	assert_true(verts.size() < 50000, "two densities keep vertices down, got %d" % verts.size())

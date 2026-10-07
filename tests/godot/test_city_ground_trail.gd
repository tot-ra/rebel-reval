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

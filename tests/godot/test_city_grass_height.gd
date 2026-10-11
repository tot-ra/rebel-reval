extends "res://tests/godot/test_case.gd"

## Grass height follows use: short where people pass, wild and slow to wade
## through in the open (docs/SYSTEMS/SEAMLESS_CITY.md, tall grass).


func _grass() -> CityGrass:
	return CityGrass.create(CityPlan.load_default())


func test_height_grows_with_distance_from_road_and_houses() -> void:
	var grass := _grass()
	var plan := grass.plan
	# Find a house corner and a point 30 m out along the same ray: wilder further out.
	var ring := plan.footprint(0)
	var wall := ring[0]
	var out := (wall - ring[ring.size() / 2]).normalized()
	var near := wall + out * 2.5
	var far := wall + out * 40.0
	assert_true(
		grass.house_distance(near) < grass.house_distance(far),
		"probe points must sit further from the wall"
	)
	assert_true(
		grass.height_factor(near) <= grass.height_factor(far),
		"grass is no taller beside the wall than far from it"
	)
	grass.free()


func test_factor_range_and_drag_bounds() -> void:
	var grass := _grass()
	for p in [Vector2(0, -400), Vector2(-300, -300), Vector2(100, 100)]:
		var f := grass.height_factor(p)
		assert_true(f >= CityGrass.TALL_SCALE_MIN - 0.001 and f <= CityGrass.TALL_SCALE_MAX + 0.001)
		var d := grass.walk_drag_at(p)
		assert_true(d >= CityGrass.TALL_GRASS_DRAG - 0.001 and d <= 1.0, "drag %.2f" % d)
	grass.free()


func test_bare_road_never_drags() -> void:
	var grass := _grass()
	# Scan the roads raster for a road body pixel; the walker there is not wading.
	var found := false
	var x := grass.plan.bounds.position.x
	while x < grass.plan.bounds.end.x and not found:
		var p := Vector2(x, grass.plan.bounds.position.y + grass.plan.bounds.size.y * 0.5)
		if grass.road_at(p).r > 0.6:
			found = true
			assert_almost_eq(grass.walk_drag_at(p), 1.0, 0.05, "road body is bare")
		x += 3.0
	grass.free()

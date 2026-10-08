extends "res://tests/godot/test_case.gd"

## Hareapea stream (docs/SYSTEMS/CITY_SEA.md "Stream, moat and wake"): water
## reaches the waterline, no tree stands in the bed, reeds fringe the banks.


func _stream_world() -> CityWorld3D:
	var world := CityWorld3D.new()
	world.plan = CityPlan.load_default()
	var hj: Dictionary = world.plan.data["harjapea"]
	var trace := CityPlan.points(hj["points"])
	var halves := world._stream_wet_halves(trace, hj["widths"], hj["surfaces"])
	world._stream_water(trace, halves, hj["surfaces"])
	return world


func test_stream_water_reaches_the_waterline() -> void:
	var world := _stream_world()
	var plan := world.plan
	var hj: Dictionary = plan.data["harjapea"]
	var trace := CityPlan.points(hj["points"])
	var halves := world._stream_wet_halves(trace, hj["widths"], hj["surfaces"])
	for i in trace.size():
		var surface := float(hj["surfaces"][i])
		var wet := halves[i] - CityWorld3D.STREAM_BANK_OVERLAP
		assert_true(
			wet > float(hj["widths"][i]) * 0.5 + 1.0,
			"point %d: water spreads past the flat bed onto the bank (%.1f)" % [i, wet]
		)
		var side := world._ribbon_side(trace, i)
		for sign: float in [-1.0, 1.0]:
			var edge := trace[i] + side * sign * halves[i]
			assert_true(
				plan.ground_height(edge) >= surface - 0.05 or wet >= CityWorld3D.STREAM_PROBE_MAX,
				"point %d: ribbon edge lies on the bank, not over the bed" % i
			)
	world.free()


func test_no_tree_or_bush_stands_in_the_stream() -> void:
	var world := _stream_world()
	var plan := world.plan
	var original := plan.data.duplicate(true)
	world._clear_wet_trees()
	for key: String in ["trees", "bushes"]:
		assert_eq(plan.data[key], original[key], "generator already excludes wet stream %s" % key)
		# The runtime guard must still reject stale/imported wet placements.
		plan.data[key].append([617.64, 294.69, "alder", 1.0])
	world._clear_wet_trees()
	for key: String in ["trees", "bushes"]:
		assert_eq(plan.data[key], original[key], "safety net removes injected wet %s" % key)
	for key: String in ["trees", "bushes"]:
		for t: Array in plan.data[key]:
			var p := Vector2(float(t[0]), float(t[1]))
			assert_true(
				world.water_surface_at(p) <= plan.ground_height(p) - CityWorld3D.TREE_WATERLINE_CLEARANCE,
				"%s %s stands clear of the water" % [key, str(t)]
			)
	world.free()


func test_reeds_fringe_the_stream_banks() -> void:
	var world := _stream_world()
	var plants := CityMoatPlants.build(world.plan, world.moat_water)
	var reeds := plants.get_node_or_null("Reeds") as MultiMeshInstance3D
	var cattails := plants.get_node_or_null("Cattails") as MultiMeshInstance3D
	assert_true(reeds != null and reeds.multimesh.instance_count > 200, "reed clumps on the stream")
	assert_true(cattails != null and cattails.multimesh.instance_count > 40, "cattails on the stream")
	plants.free()
	world.free()


func test_pools_swim_and_margins_wade_without_changing_thresholds() -> void:
	var world := _stream_world()
	var plan := world.plan
	# Lower bend and reaches 18 m downstream of the Viru/Tartu crossings.
	var pools := [Vector2(587.63, 155.78), Vector2(617.64, 294.69), Vector2(657.36, 441.63)]
	for p: Vector2 in pools:
		var depth := world.water_surface_at(p) - plan.walk_height(p)
		assert_true(depth >= 1.6 and depth <= 2.05, "pool column %.3f at %s" % [depth, p])
		var state := PlayerSwimState.new()
		state.update(depth, false, 1.0 / 60.0)
		assert_eq(state.medium, PlayerSwimState.Medium.SWIM, "feet leave bed in pool")
		var margin := p + Vector2(7, 0)
		var shallow := world.water_surface_at(margin) - plan.walk_height(margin)
		assert_true(shallow > 0.12 and shallow < PlayerSwimState.SWIM_EXIT_DEPTH)
		state.update(shallow, false, 1.0 / 60.0)
		assert_eq(state.medium, PlayerSwimState.Medium.WADE, "swimmer can wade out")
	var riffle := Vector2(682.5, 545)
	var riffle_depth := world.water_surface_at(riffle) - plan.walk_height(riffle)
	assert_true(riffle_depth > 0.9 and riffle_depth < PlayerSwimState.SWIM_ENTER_DEPTH)
	world.free()

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
	var before := (plan.data["trees"] as Array).size()
	world._clear_wet_trees()
	assert_true((plan.data["trees"] as Array).size() < before, "trees were removed from the bed")
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

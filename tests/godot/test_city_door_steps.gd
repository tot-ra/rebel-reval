extends "res://tests/godot/test_case.gd"

## R-2197: door stairs are laid out once (CityDoorSteps) and the same layout is
## drawn, walked on and collided with; high doors moved to the uphill side.

const Steps := preload("res://scripts/city/city_door_steps.gd")

## A 10 x 6 wall ring with the door in the middle of its south edge (y = 0,
## outward is -y).
const RING := [Vector2(0, 0), Vector2(10, 0), Vector2(10, 6), Vector2(0, 6)]


func _ring() -> PackedVector2Array:
	return PackedVector2Array(RING)


## Flat street `drop` below the floor in front of the house.
func _layout(rise: float, style: Dictionary, ground: Callable = Callable()) -> Dictionary:
	var ring := _ring()
	var at := ground
	if not at.is_valid():
		at = func(_p: Vector2) -> float: return -rise
	return Steps.layout(ring[0], ring[1], 0.5, ring, 0.0, at, 1.5, style)


func test_kind_follows_rise_and_fabric() -> void:
	assert_eq(int(_layout(0.05, {})["kind"]), Steps.Kind.NONE, "level threshold, no step")
	assert_eq(int(_layout(0.16, {})["kind"]), Steps.Kind.SLAB, "one riser: a threshold stone")
	assert_eq(int(_layout(0.6, {"seed": 3})["kind"]), Steps.Kind.STRAIGHT)
	assert_eq(int(_layout(0.6, {"seed": 4, "grand": true})["kind"]), Steps.Kind.SPLAYED)
	assert_eq(int(_layout(0.6, {"wood": true})["kind"]), Steps.Kind.TIMBER)
	assert_eq(int(_layout(1.6, {})["kind"]), Steps.Kind.SIDE, "tall rise: flight along the wall")


func test_risers_stay_low_and_the_last_meets_the_street() -> void:
	for rise: float in [0.5, 1.0, 1.6, 2.4]:
		var steps := _layout(rise, {"seed": 1})
		var treads: Array = steps["treads"]
		assert_true(treads.size() >= 2, "rise %.1f has a flight" % rise)
		assert_almost_eq(float(treads[0]["top"]), 0.0, 0.001, "top tread level with the floor")
		var tops: Array[float] = []
		for t: Dictionary in treads:
			tops.append(float(t["top"]))
		tops.append(-rise)
		tops.sort()
		for k in range(1, tops.size()):
			if tops[k] - tops[k - 1] > 0.001:
				var riser := tops[k] - tops[k - 1]
				assert_true(riser <= 0.2, "riser %.2f at rise %.1f" % [riser, rise])


func test_side_flight_runs_along_the_wall_and_keeps_out_of_the_house() -> void:
	var steps := _layout(1.6, {"seed": 2})
	for t: Dictionary in steps["treads"]:
		for p in Steps.corners(t):
			assert_true(p.y <= 0.001, "tread outside the house")
			assert_true(p.y >= -Steps.LANDING_DEPTH - 0.01, "flight hugs the wall")
	var span: Vector2 = steps["span"]
	assert_true(span.y - span.x > 0.3, "footing stays open along the flight")
	assert_eq((steps["rails"] as Array).size(), 3, "landing end, landing side, flight side")


func test_side_flight_climbs_to_the_rising_ground() -> void:
	# Ground falls to +x along the wall: the short flight runs to -x, where the
	# ground rises to meet it, and its foot lands on the ground.
	var ground := func(p: Vector2) -> float: return -1.4 - 0.3 * (p.x - 5.0)
	for seed_value in 2:
		var steps := _layout(1.4, {"seed": seed_value}, ground)
		assert_eq(int(steps["kind"]), Steps.Kind.SIDE)
		var foot: Dictionary = (steps["treads"] as Array).back()
		assert_true((foot["c"] as Vector2).x < 5.0, "flight runs to the rising ground")
		assert_true(float(foot["top"]) - float(ground.call(foot["c"])) <= 0.25, "foot meets the ground")


func test_height_at_reads_the_tread_under_the_point() -> void:
	var steps := _layout(0.9, {"seed": 3})
	var t0: Dictionary = steps["treads"][0]
	var t1: Dictionary = steps["treads"][1]
	assert_almost_eq(Steps.height_at(steps, t0["c"]), float(t0["top"]), 0.001)
	assert_almost_eq(Steps.height_at(steps, t1["c"]), float(t1["top"]), 0.001)
	assert_true(is_nan(Steps.height_at(steps, Vector2(5, -8))), "street is no tread")


func test_plan_walks_actors_up_the_stair_it_draws() -> void:
	var plan := CityPlan.load_default()
	var checked := 0
	var kinds := {}
	for i in plan.buildings.size():
		var steps := plan.door_steps(i)
		if steps.is_empty() or (steps["treads"] as Array).is_empty():
			continue
		kinds[int(steps["kind"])] = true
		for t: Dictionary in steps["treads"]:
			var c: Vector2 = t["c"]
			if plan.building_at(c) >= 0:
				continue
			assert_true(
				plan.walk_height(c) >= float(t["top"]) - 0.001,
				"%s: Kalev stands on the tread, not in it" % plan.buildings[i]["id"]
			)
			checked += 1
	assert_true(checked > 200, "most doors have a stair to walk")
	for kind: int in [Steps.Kind.SLAB, Steps.Kind.STRAIGHT, Steps.Kind.TIMBER]:
		assert_true(kinds.has(kind), "the city uses %s stairs" % Steps.KIND_NAMES[kind])


func test_high_doors_moved_to_the_upper_side() -> void:
	# St Catherine's houses by the town wall: their street doors stood 3-4 wu
	# up a straight flight before the generator moved them (R-2197).
	var plan := CityPlan.load_default()
	for id: String in ["bldg.osm.w26902721", "bldg.osm.w28187544"]:
		var index := -1
		for i in plan.buildings.size():
			if String(plan.buildings[i]["id"]) == id:
				index = i
		assert_true(index >= 0, id)
		var door: Array = plan.buildings[index]["door"]
		var out := Vector2.from_angle(float(door[2]))
		var rise := plan.floor_height(index) - plan.ground_height(Vector2(door[0], door[1]) + out)
		assert_true(rise < 2.3, "%s door rise %.2f" % [id, rise])


func test_builder_draws_the_layout_it_is_given() -> void:
	var b := {
		"id": "bldg.test.steps", "kind": "house", "material": "limestone", "roof": "tile",
		"base_h": -1.2, "base_span": 1.2, "wall_h": 4.0, "ridge_angle": 0.0, "roof_pitch_deg": 45,
		"door": [5.0, 0.0, -PI * 0.5], "enterable": false, "openings": false,
	}
	var ground := func(_p: Vector2) -> float: return -1.2
	var with := CityBuildingBuilder.build_building(b, _ring(), 0.0, false, ground)
	var none := CityBuildingBuilder.build_building(
		b, _ring(), 0.0, false, ground, [], {"kind": Steps.Kind.NONE, "treads": [], "rails": []}
	)
	var shell_with: CityBuildingBuilder.Shell = with["shell"]
	var shell_none: CityBuildingBuilder.Shell = none["shell"]
	assert_true(shell_with.triangle_count() > shell_none.triangle_count(), "stair drawn")

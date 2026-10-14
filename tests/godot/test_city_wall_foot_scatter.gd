extends "res://tests/godot/test_case.gd"

## R-1932: 3D wall-foot scatter (CityWallFootScatter): deterministic per
## building, a narrow strip along the wall, clear of doors, paving and busy
## roads, weeds biased to corners, seasons never move the stones.
## docs/SYSTEMS/SEAMLESS_CITY.md, Wall-foot scatter.

const Scatter := preload("res://scripts/city/city_wall_foot_scatter.gd")
const JUNE := {"day": 15, "month": 6, "year": 1343}
const JANUARY := {"day": 15, "month": 1, "year": 1343}
## Houses sampled per test (the first N with a door), enough for statistics.
const SAMPLE := 120
## Instances drawn round the forge must stay inside this budget.
const MAX_INSTANCES_NEAR_FORGE := 30000

var grass: CityGrass
var plan: CityPlan


func before_each() -> void:
	super.before_each()
	plan = CityPlan.load_default()
	grass = CityGrass.create(plan)


func after_each() -> void:
	grass.free()
	super.after_each()


func _houses() -> Array[int]:
	var out: Array[int] = []
	for i in plan.buildings.size():
		if plan.buildings[i].get("door") != null:
			out.append(i)
			if out.size() >= SAMPLE:
				break
	return out


func _origins(buf: PackedFloat32Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for k in buf.size() / Scatter.STRIDE:
		var o := k * Scatter.STRIDE
		out.append(Vector3(buf[o + 3], buf[o + 7], buf[o + 11]))
	return out


func _ring_distance(ring: PackedVector2Array, p: Vector2) -> float:
	var best := INF
	for i in ring.size():
		var q := Geometry2D.get_closest_point_to_segment(p, ring[i], ring[(i + 1) % ring.size()])
		best = minf(best, q.distance_to(p))
	return best


func test_buffers_are_deterministic_and_populated() -> void:
	var day := GameCalendar.day_of_year(JUNE)
	var total := 0
	for index in _houses():
		var one := Scatter.building_buffers(grass, index, day)
		var two := Scatter.building_buffers(grass, index, day)
		assert_eq(one, two, "building %d scatter is deterministic" % index)
		for kind: StringName in one:
			total += (one[kind] as PackedFloat32Array).size() / Scatter.STRIDE
	assert_true(total > SAMPLE * 40, "the strip is dense (%d instances)" % total)


func test_strip_hugs_the_wall_and_skips_doors_paving_and_busy_roads() -> void:
	var day := GameCalendar.day_of_year(JUNE)
	for index in _houses():
		var b: Dictionary = plan.buildings[index]
		var door := Vector2(b["door"][0], b["door"][1])
		var ring := plan.footprint(index)
		var parts := Scatter.building_buffers(grass, index, day)
		for kind: StringName in parts:
			# Chips spread a little and the plank lies along the wall: allow slack.
			var reach := Scatter.PROUD + Scatter.STRIP + 0.45
			for o in _origins(parts[kind]):
				var p := Vector2(o.x, o.z)
				assert_true(
					_ring_distance(ring, p) <= reach,
					"%s of building %d stays in the wall strip" % [kind, index]
				)
				if kind != Scatter.KIND_PLANK:
					assert_true(p.distance_to(door) >= Scatter.DOOR_CLEAR - 0.01,
						"%s of building %d keeps the door step clear" % [kind, index])
				assert_true(grass.surface_at(p).r <= Scatter.PAVED, "nothing on paving")
				var road := grass.road_at(p)
				assert_false(road.r > Scatter.ROAD_BODY and road.b > Scatter.HEAVY_WEAR,
					"nothing on a busy road body")


func test_weeds_gather_at_corners() -> void:
	var day := GameCalendar.day_of_year(JUNE)
	var corner := 0
	var middle := 0
	var corner_len := 0.0
	var middle_len := 0.0
	for index in _houses():
		var ring := plan.footprint(index)
		for i in ring.size():
			var length := ring[i].distance_to(ring[(i + 1) % ring.size()])
			corner_len += minf(length, 4.0)
			middle_len += maxf(length - 4.0, 0.0)
		var parts := Scatter.building_buffers(grass, index, day)
		for kind: StringName in Scatter.PLANT_KINDS:
			for o in _origins(parts.get(kind, PackedFloat32Array())):
				var p := Vector2(o.x, o.z)
				var near := INF
				for v in ring:
					near = minf(near, v.distance_to(p))
				if near < 2.0:
					corner += 1
				else:
					middle += 1
	assert_true(corner > 0 and middle > 0, "weeds at corners (%d) and along walls (%d)" % [
		corner, middle])
	assert_true(
		float(corner) / corner_len > 2.0 * float(middle) / maxf(middle_len, 1.0),
		"weeds per metre at corners exceed twice the wall run"
	)


func test_winter_drops_weeds_and_keeps_stones() -> void:
	var june := GameCalendar.day_of_year(JUNE)
	var january := GameCalendar.day_of_year(JANUARY)
	var stones := 0
	for index in _houses():
		var summer := Scatter.building_buffers(grass, index, june)
		var winter := Scatter.building_buffers(grass, index, january)
		for kind: StringName in Scatter.PLANT_KINDS:
			assert_false(winter.has(kind), "no %s in January" % kind)
		for kind: StringName in [Scatter.KIND_STONE, Scatter.KIND_RIDGE, Scatter.KIND_GRASS]:
			assert_eq(winter.get(kind), summer.get(kind), "%s does not move with the season" % kind)
		stones += (summer.get(Scatter.KIND_STONE, PackedFloat32Array()) as PackedFloat32Array).size()
	assert_true(stones > 0, "some fieldstones lie at the wall foot")


func test_streams_round_the_forge_within_budget() -> void:
	var at := CityTravel.spawn_position(plan, "kalev_smithy")
	var scatter: CityWallFootScatter = grass.wall_foot
	scatter.set_calendar_date(JUNE)
	var start := Time.get_ticks_usec()
	var pending := scatter.update_for(at, Time.get_ticks_usec() + 60_000_000, false)
	var cost_ms := float(Time.get_ticks_usec() - start) / 1000.0
	print("wall-foot scatter round the forge: %.1f ms" % cost_ms)
	assert_false(pending, "every building in range is built")
	var total := 0
	for kind: StringName in Scatter.ALL_KINDS:
		total += scatter.instance_count(kind)
	assert_true(scatter.instance_count(Scatter.KIND_GRASS) > 0, "grass strip drawn")
	assert_true(total < MAX_INSTANCES_NEAR_FORGE, "%d instances within budget" % total)
	# A second call in the same cell does no work.
	assert_false(scatter.update_for(at, Time.get_ticks_usec(), true), "nothing left to build")

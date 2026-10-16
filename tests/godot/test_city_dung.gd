extends "res://tests/godot/test_case.gd"

## R-2077: animal dung where the city's stock lives and walks, aged by the date.

const OPENING := {"year": 1343, "month": 4, "day": 21}
const SUMMER := {"year": 1343, "month": 7, "day": 15}
const WINTER := {"year": 1343, "month": 1, "day": 15}


func _dung(plan: CityPlan) -> CityDung:
	return CityDung.create(plan)


func test_drops_are_deterministic_and_on_dry_open_ground() -> void:
	var plan := CityPlan.load_default()
	var a := CityDung.drops_for(plan)
	var b := CityDung.drops_for(plan)
	assert_true(a.size() > 800, "the stock leaves real dung (%d drops)" % a.size())
	assert_eq(a.size(), b.size(), "same plan, same drops")
	var same := true
	for i in a.size():
		if a[i]["kind"] != b[i]["kind"] or not (a[i]["at"] as Vector2).is_equal_approx(b[i]["at"]):
			same = false
			break
	assert_true(same, "same plan, same spots")
	var kinds := {}
	var wet_ground := 0
	for d: Dictionary in a:
		kinds[d["kind"]] = true
		if plan.building_at(d["at"]) >= 0 or plan.in_moat(d["at"], 1.0):
			wet_ground += 1
	assert_eq(wet_ground, 0, "no dung inside a building or in the moat")
	for kind in CityDung.KINDS:
		assert_true(kinds.has(kind), "%s is laid somewhere" % kind)


func test_drove_follows_the_street_to_grazing() -> void:
	var plan := CityPlan.load_default()
	var street: Dictionary = {}
	for s: Dictionary in plan.streets:
		if String(s["class"]) == "extramural_road" and (s["points"] as Array).size() >= 4:
			street = s
			break
	assert_false(street.is_empty(), "the plan has an extramural road")
	var pts := CityPlan.points(street["points"])
	var from := pts[0] + Vector2(3.0, 0.0)
	var to := pts[pts.size() - 1] + Vector2(0.0, 6.0)
	var route := CityDung.drove_route(plan, from, to)
	assert_true(route.size() > 4, "the drove walks along the road's bends (%d points)" % route.size())
	for i in range(2, route.size() - 2):
		assert_true(pts.has(route[i]), "inner route point %d is a road vertex" % i)


func test_turn_out_and_housing_gate_grazing_dung() -> void:
	var plan := CityPlan.load_default()
	var node := _dung(plan)
	node.set_calendar_date(WINTER)
	assert_eq(node.instance_count(CityDung.KIND_COW_PAT), 0, "no cow pats while cattle are housed")
	# Town yard goats (CityFauna.ANCHORS) are not grazing stock and stay out all year.
	var winter_pellets := node.instance_count(CityDung.KIND_PELLETS)
	assert_true(node.instance_count(CityDung.KIND_HEAP) > 0, "manure heaps stand all winter")
	var heaps := node.instance_count(CityDung.KIND_HEAP)
	node.set_calendar_date(OPENING)
	var opening := node.instance_count(CityDung.KIND_COW_PAT)
	assert_true(opening > 0, "a few days after turn-out the first pats lie out (%d)" % opening)
	assert_true(node.instance_count(CityDung.KIND_HORSE) > 0, "horse dung on the roads")
	assert_eq(node.instance_count(CityDung.KIND_HEAP), heaps, "one heap per yard all year")
	node.set_calendar_date(SUMMER)
	var summer := node.instance_count(CityDung.KIND_COW_PAT)
	assert_true(summer > opening * 2, "by July pats of every age (%d vs %d)" % [summer, opening])
	var summer_pellets := node.instance_count(CityDung.KIND_PELLETS)
	assert_true(
		summer_pellets > winter_pellets * 5,
		"housed sheep leave only the yard goats' pellets (%d vs %d)" % [winter_pellets, summer_pellets]
	)
	print("dung instances winter/opening/summer cow pats: 0/%d/%d, all summer: %d" % [
		opening, summer, node.placements().size()
	])
	node.free()


func test_age_dries_and_flattens_cow_pats() -> void:
	var plan := CityPlan.load_default()
	var node := _dung(plan)
	node.set_calendar_date(SUMMER)
	var low := INF
	var high := 0.0
	var wet := 0
	for entry: Array in node.placements():
		if entry[0] != CityDung.KIND_COW_PAT:
			continue
		var xf: Transform3D = entry[1]
		var s := xf.basis.get_scale()
		var ratio := s.y / s.x
		low = minf(low, ratio)
		high = maxf(high, ratio)
		if bool(entry[2]):
			wet += 1
	assert_true(high > 0.95 and low < 0.6, "fresh pats stand, dry ones are flat (%.2f-%.2f)" % [
		low, high
	])
	assert_true(wet > 0, "some pats are still wet and glossy")
	node.free()


func test_heap_follows_the_june_carting() -> void:
	assert_true(CityDung.heap_fill(120) > 0.9, "a full heap before the June carting")
	assert_true(CityDung.heap_fill(190) < 0.45, "a small heap after the dung went to the fallow")
	assert_true(CityDung.heap_fill(330) > CityDung.heap_fill(220), "it builds up again by winter")


func test_days_out_counts_from_turn_out() -> void:
	assert_eq(CityDung.days_out(WINTER), 0.0, "housed in January")
	var april := CityDung.days_out(OPENING)
	assert_true(april >= 1.0 and april <= 10.0, "freshly out on 21 April (%.0f days)" % april)
	assert_true(CityDung.days_out(SUMMER) > 60.0, "long out by July")

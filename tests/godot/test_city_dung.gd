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
		assert_true(
			_street_distance(plan, route[i]) < CityDung.DROVE_SNAP,
			"inner route point %d is on a drove street" % i
		)


## Byres and sheep sheds drive their stock through the street graph unless their
## grazing lies across open ground beside the yard: some routes change street at
## a junction, each ends on its pasture or fallow, and no straight walk tramples
## a sown field or goes through a house. The town herd crosses the suburb.
func test_drove_routes_through_the_street_graph() -> void:
	var plan := CityPlan.load_default()
	var grazing := CityDung.grazing_areas(plan)
	var routed := 0
	var multi := 0
	var off_road := 0.0
	var reached := true
	var trampling := 0
	var straight := 0
	var graph := CityDung._street_graph(plan)
	for b: Dictionary in plan.data.get("buildings", []):
		if String(b.get("kind", "")) != "outbuilding" or not CityDung.DROVE_STOCK.has(String(b["type"])):
			continue
		var yard := CityFauna._centroid(CityPlan.points(b["footprint"])) + Vector2(3.5, 3.5)
		var path := CityDung.drove_plan(plan, yard, grazing)
		if path.is_empty():
			continue
		var to: Vector2 = path["area"]["centre"]
		var points: PackedVector2Array = path["points"]
		var streets: PackedInt32Array = path["streets"]
		if streets.is_empty():
			straight += 1
			if CityDung._trample_cost(plan, graph, yard, to, path["area"]["polygon"]) > 0.0:
				trampling += 1
			continue
		routed += 1
		if streets.size() >= 2:
			multi += 1
		if not points[points.size() - 1].is_equal_approx(to):
			reached = false
		# Open ground walked from the last street to the grazing's edge.
		var poly: PackedVector2Array = path["area"]["polygon"]
		var leave := points[points.size() - 2]
		if not Geometry2D.is_point_in_polygon(leave, poly):
			off_road = maxf(off_road, CityFarmland._distance_to_polygon(leave, poly))
	assert_true(routed >= 6, "yards drive their stock along streets (%d)" % routed)
	# A yard with no street in reach may still clip a house corner on its way out.
	assert_true(
		trampling * 10 <= straight,
		"straight walks keep off sown fields and houses (%d of %d clip one)" % [trampling, straight]
	)
	assert_true(reached, "every drove ends at its pasture or fallow field")
	assert_true(multi >= 2, "drives cross at least two streets (%d of %d)" % [multi, routed])
	assert_true(off_road < CityDung.DROVE_ENTRY, "and leaves the street near it (%.0f m)" % off_road)
	var gate := CityFauna._anchor_point(plan, CityDung.TOWN_HERD_GATE)
	var herd := CityDung.drove_plan(plan, gate, grazing)
	assert_false(
		(herd.get("streets", PackedInt32Array()) as PackedInt32Array).is_empty(),
		"the town herd walks out of the Karja gate along the road"
	)
	print("drove routes: %d on streets, %d over 2+ streets, longest last off-road leg %.0f m" % [
		routed, multi, off_road
	])


func test_heaps_keep_out_of_gardens_and_bushes() -> void:
	var plan := CityPlan.load_default()
	var gardens := CityDung.garden_polygons(plan)
	assert_true(gardens.size() > 0, "the plan has kitchen gardens")
	var stems := CityDung._stem_buckets(plan)
	var heaps := 0
	var bad := 0
	for d: Dictionary in CityDung.drops_for(plan):
		if d["kind"] != CityDung.KIND_HEAP:
			continue
		heaps += 1
		var at: Vector2 = d["at"]
		for poly in gardens:
			if Geometry2D.is_point_in_polygon(at, poly):
				bad += 1
		if not CityDung.heap_clear(at, gardens, stems):
			bad += 1
	assert_true(heaps > 10, "byres, sheds and sties keep heaps (%d)" % heaps)
	assert_eq(bad, 0, "no heap in a garden bed or under a tree or bush")


func test_rain_darkens_and_softens_dried_dung() -> void:
	var crust := CityDung.material(CityDung.STAGE_CRUST)
	var wet := CityDung.material(CityDung.STAGE_WET)
	CityDung.set_wetness(0.0)
	var dry_rough := crust.roughness
	var dry_albedo := crust.albedo_color.get_luminance()
	CityDung.set_wetness(1.0)
	assert_true(crust.roughness < dry_rough - 0.2, "a soaked crust turns glossy")
	assert_true(crust.albedo_color.get_luminance() < dry_albedo - 0.2, "and darker")
	assert_almost_eq(wet.roughness, 0.45, 0.001, "fresh dung is wet either way")
	CityDung.set_wetness(0.0)
	assert_almost_eq(crust.roughness, dry_rough, 0.001, "it dries back")


static func _street_distance(plan: CityPlan, p: Vector2) -> float:
	var best := INF
	for s: Dictionary in plan.streets:
		if CityDung.DROVE_CLASSES.has(String(s.get("class", ""))):
			best = minf(best, float(CityDung._closest_on(CityPlan.points(s["points"]), p)[2]))
	return best


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


func test_the_same_pat_dries_from_day_to_day() -> void:
	var plan := CityPlan.load_default()
	var node := _dung(plan)
	var later := GameCalendar.add_days(SUMMER, 5)
	assert_eq(CityDung.day_number(later) - CityDung.day_number(SUMMER), 5, "day numbers run on")
	var new_year := {"year": 1344, "month": 1, "day": 1}
	assert_eq(
		CityDung.day_number(new_year) - CityDung.day_number({"year": 1343, "month": 12, "day": 31}),
		1, "and across New Year"
	)
	node.set_calendar_date(SUMMER)
	var before := {}  # origin -> [y/x ratio, colour-free stage, age]
	for entry: Array in node.placements():
		if entry[0] == CityDung.KIND_COW_PAT:
			var xf: Transform3D = entry[1]
			before[xf.origin] = [xf.basis.get_scale().y / xf.basis.get_scale().x, entry[3], entry[4]]
	node.set_calendar_date(later)
	var aged := 0
	var flatter := 0
	var wet_then_dry := 0
	for entry: Array in node.placements():
		var xf: Transform3D = entry[1]
		if entry[0] != CityDung.KIND_COW_PAT or not before.has(xf.origin):
			continue
		var was: Array = before[xf.origin]
		if float(entry[4]) < float(was[2]):
			continue  # crumbled and fell fresh again in between
		aged += 1
		assert_almost_eq(float(entry[4]) - float(was[2]), 5.0, 0.001, "five days older")
		if xf.basis.get_scale().y / xf.basis.get_scale().x < float(was[0]) - 0.001:
			flatter += 1
		if int(was[1]) == CityDung.STAGE_WET and int(entry[3]) != CityDung.STAGE_WET:
			wet_then_dry += 1
	assert_true(aged > 50, "most pats lie on and age (%d)" % aged)
	assert_true(flatter > aged / 3, "young ones slump as they dry (%d of %d)" % [flatter, aged])
	assert_true(wet_then_dry > 0, "yesterday's wet pats have lost their gloss")
	assert_true(CityDung.stage_for(4.0, 18.0) == CityDung.STAGE_DAMP, "a damp sheen for days")
	assert_true(CityDung.stage_for(10.0, 18.0) == CityDung.STAGE_CRUST, "then a crust")
	node.free()


## R-2175: a cow walking near Kalev drops fresh pats at its walking rate, behind
## itself; the newest LIVE_CAP stay, and nothing falls beyond LIVE_RADIUS.
func test_live_drops_fall_behind_walking_animals() -> void:
	var plan := CityPlan.load_default()
	var dung := _dung(plan)
	var live := CityDungLive.create(dung)
	var centre: Vector2 = CityDung.grazing_areas(plan)[0]["centre"]
	# A cow ambles round a 6 m circle in the pasture for 600 m.
	var walked := 0.0
	var angle := 0.0
	var pos := centre + Vector2(6.0, 0.0)
	while walked < 600.0:
		angle += 0.05
		var next := centre + Vector2.from_angle(angle) * 6.0
		walked += pos.distance_to(next)
		pos = next
		live.track_animal(7, pos, &"cow", centre)
		live.end_frame()
	var n := live.live_drops().size()
	var expected := 600.0 / float(CityDungLive.LIVE_SPACING[CityDung.KIND_COW_PAT])
	assert_true(n >= 3 and n <= expected * 2.0, "about one pat per 60 m (%d in 600 m)" % n)
	for entry: Dictionary in live.live_drops():
		assert_eq(entry["kind"], CityDung.KIND_COW_PAT, "a cow drops cow pats")
		var r := (entry["at"] as Vector2).distance_to(centre)
		assert_true(absf(r - 6.0) < 1.2, "on the cow's walk, a body behind it (r %.2f)" % r)
	var far := centre + Vector2(CityDungLive.LIVE_RADIUS + 10.0, 0.0)
	for i in 2000:
		live.track_animal(8, centre + Vector2(6.0, 0.0).rotated(0.05 * i), &"horse", far)
		live.end_frame()
	assert_eq(live.live_drops().size(), n, "animals far from Kalev drop nothing live")
	for i in CityDungLive.LIVE_CAP + 10:
		live.drop(&"sheep", centre + Vector2(0.1 * (i % 7), 0.0), 0.0)
	assert_eq(live.live_drops().size(), CityDungLive.LIVE_CAP, "a ring of the newest drops")
	live.free()
	dung.free()


## R-2175: a foot on a pat squashes it flat and leaves a smear, then a couple of
## fainter muddy prints; the next date rebuild lays the same untouched pat again.
func test_stepping_on_a_pat_squashes_it_and_smears_the_boot() -> void:
	var plan := CityPlan.load_default()
	var dung := _dung(plan)
	dung.set_calendar_date(SUMMER)
	var live := CityDungLive.create(dung)
	var index := -1
	for i in dung.placements().size():
		if dung.placements()[i][0] == CityDung.KIND_COW_PAT:
			index = i
			break
	assert_true(index >= 0, "a cow pat lies out in July")
	var before: Transform3D = dung.placements()[index][1]
	var at := Vector2(before.origin.x, before.origin.z)
	var ratio_before := before.basis.get_scale().y / before.basis.get_scale().x
	assert_true(
		live.step_on(&"kalev", at + Vector2(0.05, 0.0), Vector2.RIGHT), "the foot finds the pat"
	)
	var after: Transform3D = dung.placements()[index][1]
	assert_true(after.basis.get_scale().y < 0.01, "the standing pat is gone from the static layer")
	var flat: Dictionary = live.live_drops()[-1]
	assert_true(bool(flat["squashed"]), "and lies trodden flat in the live ring")
	assert_true((flat["at"] as Vector2).is_equal_approx(at), "where it lay")
	var standing := CityDung.mesh_for(CityDung.KIND_COW_PAT).get_aabb().size.y
	var trodden := CityDungLive.squashed_mesh(CityDung.KIND_COW_PAT).get_aabb().size.y
	assert_true(trodden < standing * 0.4, "flat: %.3f m vs %.3f m" % [trodden, standing])
	assert_eq(live.smears().size(), 1, "a smear dragged off the pat")
	var away := at + Vector2(40.0, 40.0)
	live.step_on(&"kalev", away, Vector2.RIGHT)
	live.step_on(&"kalev", away + Vector2(0.85, 0.0), Vector2.RIGHT)
	live.step_on(&"kalev", away + Vector2(1.7, 0.0), Vector2.RIGHT)
	assert_eq(
		live.smears().size(), 1 + CityDungLive.MUDDY_PRINTS, "a couple of muddy prints, then clean"
	)
	var smear: Color = live.smears()[0][1]
	var last: Color = live.smears()[CityDungLive.MUDDY_PRINTS][1]
	assert_true(last.a < smear.a, "each print fainter")
	# A live drop is squashed the same way (where dung may lie at all).
	if live.drop(&"horse", away + Vector2(5.0, 0.0), 0.0):
		live.step_on(&"citizen", away + Vector2(5.0, 0.0), Vector2.UP)
		assert_true(bool(live.live_drops()[-1]["squashed"]), "a fresh drop squashes too")
	dung.set_calendar_date(SUMMER)
	live.end_frame()
	var copies := 0
	for entry: Dictionary in live.live_drops():
		if bool(entry["static"]):
			copies += 1
	assert_eq(copies, 0, "trodden copies of static pats leave with the rebuild")
	var again: Transform3D = dung.placements()[index][1]
	assert_almost_eq(
		again.basis.get_scale().y / again.basis.get_scale().x, ratio_before, 0.001,
		"the static layer stays deterministic: the date rebuild lays it whole"
	)
	live.free()
	dung.free()


## R-2175: every footfall is announced, Kalev's and a citizen's, with the foot's spot.
func test_trail_announces_each_footfall() -> void:
	var plan := CityPlan.load_default()
	var trail := CityGroundTrail.create(plan, func(_p: Vector2) -> Color: return Color(0, 1, 0, 0))
	var seen := {}
	trail.footfall.connect(func(key: Variant, xz: Vector2, _facing: Vector2) -> void:
		seen[key] = int(seen.get(key, 0)) + 1
		assert_true(xz.y > -402.0 and xz.y < -394.0, "the foot is beside the walker")
	)
	var pos := Vector2(0, -400)
	trail.update_for(pos, 0.016)
	var walker := Vector2(3, -395)
	for i in 40:
		pos += Vector2(0.25, 0.0)
		walker += Vector2(0.25, 0.0)
		trail.update_for(pos, 0.016)
		trail.track_walker(5, walker)
	assert_true(int(seen.get(CityGroundTrail.KALEV_KEY, 0)) >= 8, "Kalev's steps (%s)" % seen)
	assert_true(int(seen.get(5, 0)) >= 8, "the citizen's steps (%s)" % seen)
	trail.free()

class_name CityDung
extends Node3D

## Animal dung on the ground (R-2077): what the city's stock leaves behind.
## Cow pats dry from a dark glossy pancake to a pale flat crust; horse dung lies
## as a heap of straw-brown balls; sheep and goats drop scatters of small dark
## pellets, hares smaller fibrous ones (there were no rabbits in 1343 Estonia);
## pigs leave lumpy piles and fowl small white-capped droppings. A manure heap
## stands beside every byre, sheep shed and sty.
##
## Where it lies follows the animals (CityFauna.groups_for): round every pen,
## tether, pasture, fallow herd and yard, and along the drove from each byre and
## sheep shed to its grazing (through the street graph to the nearest pasture or
## fallow field). The town herd goes out the same way from the Karja (cattle)
## gate. Cart horses foul the extramural roads and, more thinly, the spines.
##
## Each drop has a fixed birth phase in its life cycle, so the plan always lays
## the same dung, and its age runs with the calendar: the same pat dries, pales
## and flattens day by day, then crumbles and a fresh one falls in its place.
## The date decides what shows (set_calendar_date): grazing stock is housed
## through the cold months (CityFauna.stock_housed), so after turn-out only
## dung younger than the days out is on the ground; settled snow buries all but
## the freshest. Visual only: no collision, no GameState, procedural meshes.

const KIND_COW_PAT := &"cow_pat"
const KIND_HORSE := &"horse_balls"
const KIND_PELLETS := &"pellets"
const KIND_PIG := &"pig"
const KIND_HARE := &"hare"
const KIND_FOWL := &"fowl"
const KIND_HEAP := &"heap"
const KINDS: Array[StringName] = [
	KIND_COW_PAT, KIND_HORSE, KIND_PELLETS, KIND_PIG, KIND_HARE, KIND_FOWL, KIND_HEAP
]
const SPECIES_KIND := {
	&"cow": KIND_COW_PAT, &"horse": KIND_HORSE, &"sheep": KIND_PELLETS, &"goat": KIND_PELLETS,
	&"pig": KIND_PIG, &"hare": KIND_HARE, &"chicken": KIND_FOWL, &"goose": KIND_FOWL,
}
## Per kind: `life` days a drop stays readable before it crumbles, washes or is
## trodden in; `dry` days from fresh to pale in summer; `home` drops per animal round its
## home; `range` draw distance in metres; `fresh` the colour of a new drop as a
## multiplier on the mesh's dried palette.
const SPEC := {
	&"cow_pat": {
		"life": 40.0, "dry": 12.0, "home": 5, "range": 75.0, "fresh": Color(0.58, 0.52, 0.36)
	},
	&"horse_balls": {
		"life": 12.0, "dry": 7.0, "home": 4, "range": 60.0, "fresh": Color(0.62, 0.55, 0.38)
	},
	&"pellets": {
		"life": 10.0, "dry": 5.0, "home": 5, "range": 35.0, "fresh": Color(0.6, 0.57, 0.52)
	},
	&"pig": {"life": 10.0, "dry": 6.0, "home": 3, "range": 55.0, "fresh": Color(0.6, 0.55, 0.48)},
	&"hare": {"life": 25.0, "dry": 4.0, "home": 4, "range": 30.0, "fresh": Color(0.6, 0.55, 0.45)},
	&"fowl": {"life": 5.0, "dry": 3.0, "home": 3, "range": 35.0, "fresh": Color(0.8, 0.8, 0.75)},
	&"heap": {"life": 1.0, "dry": 1.0, "home": 0, "range": 140.0, "fresh": Color.WHITE},
}
## Geese drop green; the fowl mesh is a chicken's brown with a white cap.
const SPECIES_TINT := {&"goose": Color(0.72, 0.95, 0.58)}
## Grazing herds spread their dung over the field, so they leave more of it in view.
const GRAZE_FACTOR := 2
## Dung on a road is broken up by hooves and wheels within a couple of weeks;
## long enough that a pat on a drove visibly dries before it goes.
const ROAD_LIFE := 12.0
## Drove routes: from yards with these outbuildings, metres between drops per
## animal of the group (a herd of four leaves a pat every 2.5 m), how far a yard
## may be from the street it joins and from the grazing it walks to.
const DROVE_STOCK := {"byre": [&"cow", 2], "sheep_shed": [&"sheep", 3]}
const DROVE_SPACING := {&"cow_pat": 10.0, &"pellets": 9.0}
const DROVE_CLASSES := ["extramural_road", "lane", "spine", "alley"]
const DROVE_ENTRY := 45.0
const DROVE_MAX := 520.0
const DROVE_HALF_WIDTH := 1.6
## Drove street graph: street vertices this close merge into one junction, and a
## street end this close to another street's segment joins it there (T-junction).
const DROVE_SNAP := 3.0
## A metre walked across open ground costs this many metres of road: herds are
## kept to the streets and only step off them at the yard and at the grazing.
const DROVE_OFFROAD := 3.0
## A metre trampled through a sown (ploughed) field costs this much more again:
## nobody drove a herd through the crop, so such walks go round by the streets.
const DROVE_CROP := 12.0
## A metre through a building's footprint: a herd goes round houses, not through them.
const DROVE_BUILDING := 40.0
## The town herd: burghers' cows driven out daily through the Karja (cattle) gate.
const TOWN_HERD_GATE := "gate.karja"
const TOWN_HERD := 6
## Cart horses: metres between horse droppings by street class.
const HORSE_SPACING := {"extramural_road": 18.0, "spine": 45.0, "square_edge": 30.0}
const HEAP_STOCK := ["byre", "sheep_shed", "pigsty"]
## A heap keeps this far from a tree or bush trunk and from a kitchen-garden bed
## (the mound is ~2.2 m across).
const HEAP_TREE_CLEAR := 1.5
const HEAP_GARDEN_CLEAR := 1.3
## Rain darkens and softens dried dung: albedo multiplier and roughness at full wetness.
const RAIN_DARKEN := Color(0.62, 0.58, 0.55)
const RAIN_ROUGHNESS := 0.55
## Manure heap fill through the year (day of year, 0..1): byre dung piles up all
## winter and is carted to the fallow in June, then builds up again.
const HEAP_FILL: Array[Vector2] = [
	Vector2(1, 0.85), Vector2(158, 1.0), Vector2(182, 0.3), Vector2(367, 0.85)
]
## Snow deeper than this hides a drop unless it fell after the snow did.
const SNOW_BURY := 0.02
const SNOW_FRESH_DAYS := 1.5
## Drying stages by age: a wet glossy skin for the first day, a damp sheen
## until DAMP_SHARE of the drying time, then a dull crust.
const WET_DAYS := 1.0
const DAMP_SHARE := 0.3
const STAGE_WET := 0
const STAGE_DAMP := 1
const STAGE_CRUST := 2
## Drying time multiplier by month: cool, damp spring and autumn days dry dung
## far slower than summer sun and wind; winter dung barely dries at all.
const DRY_SLOWDOWN: Array[float] = [3.0, 3.0, 2.5, 1.8, 1.3, 1.0, 1.0, 1.0, 1.3, 1.8, 2.5, 3.0]
const CHUNK := 96.0
## Opening day of the slice (21 April 1343) until the runtime sets the calendar.
const DEFAULT_DATE := {"year": 1343, "month": 4, "day": 21}
static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}
## Street graph per plan (instance id), built on the first drove route.
static var _graphs: Dictionary = {}
static var _wetness := 0.0

var plan: CityPlan
## Every drop: {kind, at: Vector2, u: birth phase as a fraction of life, life,
## yaw, size, grazing: only out when stock is, tint}.
var _drops: Array[Dictionary] = []
## [kind, Transform3D, wet, stage, age] per shown instance in batch order; kept
## because the headless dummy renderer does not store MultiMesh transforms.
var _placed: Array = []
var _housed := false
var _days_out := 0.0
var _day_number := 0
var _dry_slowdown := 1.0


## Mounted beside CityFauna by the city scene (it needs the fauna's groups, and
## CityFauna needs the game's autoloads, so world-only tools do not build it).
static func create(city_plan: CityPlan) -> CityDung:
	var node := CityDung.new()
	node.name = "CityDung"
	node.plan = city_plan
	node._drops = drops_for(city_plan)
	node.set_calendar_date(DEFAULT_DATE)
	return node


## Every drop the plan's animals leave, before the date filters them. Pure and
## deterministic, so tests and tools can audit the layout.
static func drops_for(city_plan: CityPlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for group: Dictionary in CityFauna.groups_for(city_plan):
		_home_drops(city_plan, group, out)
	_heaps(city_plan, out)
	_droves(city_plan, out)
	_horse_roads(city_plan, out)
	return out


## Shows the dung lying on `date` and rebuilds the batches.
func set_calendar_date(date: Dictionary) -> void:
	_housed = CityFauna.stock_housed(date)
	_days_out = 0.0 if _housed else days_out(date)
	_day_number = day_number(date)
	_dry_slowdown = DRY_SLOWDOWN[int(GameCalendar.normalize_date(date)["month"]) - 1]
	var cover := VegetationPhenology.snow_cover_for(date)
	var fill := heap_fill(GameCalendar.day_of_year(date))
	_rebuild(cover, fill)


## Days since grazing stock was turned out on `date` (0 while housed).
static func days_out(date: Dictionary) -> float:
	for d in range(0, 367):
		if CityFauna.stock_housed(GameCalendar.add_days(date, -d)):
			return float(d)
	return 366.0


## Consecutive day count (Julian calendar), so ages run on across New Year.
static func day_number(date: Dictionary) -> int:
	var year := int(GameCalendar.normalize_date(date)["year"]) - 1
	return year * 365 + floori(year / 4.0) + GameCalendar.day_of_year(date)


## Days since `drop` fell on day `day`: each spot is a cycle of fall, drying and
## crumbling, phase-shifted by the drop's `u` so neighbours are of mixed age.
static func age_on(drop: Dictionary, day: int) -> float:
	var life := float(drop["life"])
	return fposmod(float(day) + float(drop["u"]) * life, life)


## Drying stage of a drop `age` days old that takes `dry_days` to dry out.
static func stage_for(age: float, dry_days: float) -> int:
	if age < WET_DAYS:
		return STAGE_WET
	if age < dry_days * DAMP_SHARE:
		return STAGE_DAMP
	return STAGE_CRUST


static func heap_fill(doy: int) -> float:
	for i in range(1, HEAP_FILL.size()):
		var a := HEAP_FILL[i - 1]
		var b := HEAP_FILL[i]
		if float(doy) <= b.x:
			return lerpf(a.y, b.y, (float(doy) - a.x) / (b.x - a.x))
	return HEAP_FILL[-1].y


func drop_count() -> int:
	return _drops.size()


func drops() -> Array[Dictionary]:
	return _drops


func instance_count(kind: StringName) -> int:
	var n := 0
	for entry: Array in _placed:
		if entry[0] == kind:
			n += 1
	return n


## Every shown instance as [kind, transform, wet, stage, age], in build order (for tests).
func placements() -> Array:
	return _placed


static func _home_drops(city_plan: CityPlan, group: Dictionary, out: Array[Dictionary]) -> void:
	var species := StringName(group["species"])
	if not SPECIES_KIND.has(species):
		return
	var kind: StringName = SPECIES_KIND[species]
	var spec: Dictionary = SPEC[kind]
	var n := (group["members"] as Array).size() * int(spec["home"])
	if group["behavior"] == CityFauna.BEHAVIOR_GRAZE:
		n *= GRAZE_FACTOR
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s/dung" % group["id"])
	var centre: Vector2 = group["centre"]
	var radius := float(group["radius"])
	for i in n:
		# Uniform over the yard, a little denser towards its middle where stock stands.
		var r := radius * pow(rng.randf(), 0.65)
		var at := centre + Vector2.from_angle(rng.randf() * TAU) * r
		_add(city_plan, out, kind, at, rng, float(spec["life"]), bool(group["grazing"]), species)


## One heap beside each byre, sheep shed and sty, on the first clear side.
## Two rings round the shed so a crowded yard still finds a spot; a heap never
## lands in a kitchen-garden bed or under a tree or bush.
static func _heaps(city_plan: CityPlan, out: Array[Dictionary]) -> void:
	var gardens := garden_polygons(city_plan)
	var stems := _stem_buckets(city_plan)
	for b: Dictionary in city_plan.data.get("buildings", []):
		if String(b.get("kind", "")) != "outbuilding" or not HEAP_STOCK.has(String(b["type"])):
			continue
		var pts := CityPlan.points(b["footprint"])
		var centre := CityFauna._centroid(pts)
		var reach := 0.0
		for p in pts:
			reach = maxf(reach, p.distance_to(centre))
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s/heap" % b["id"])
		var start := rng.randi_range(0, 7)
		var yaw := rng.randf() * TAU
		var size := rng.randf_range(0.85, 1.15)
		for k in 16:
			var ring := reach + (1.6 if k < 8 else 3.0)
			var at := centre + Vector2.from_angle(TAU * float(start + k) / 8.0) * ring
			# The heap needs its own clear ground, not just its centre.
			var far_side := at + Vector2(1, 0)
			if (
				CityFauna._is_dry(city_plan, at) and CityFauna._is_dry(city_plan, far_side)
				and heap_clear(at, gardens, stems)
			):
				out.append({
					"kind": KIND_HEAP, "at": at, "u": 0.0, "life": 1.0, "yaw": yaw,
					"size": size, "grazing": false, "tint": Color.WHITE,
				})
				break


## Kitchen-garden bed polygons of the plan's farmhouses (CityFarmland).
static func garden_polygons(city_plan: CityPlan) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for f: Dictionary in CityFarmland.features_for(city_plan):
		if f["kind"] == &"kitchen_garden":
			out.append(f["polygon"])
	return out


## True when a heap at `at` keeps clear of every garden bed and tree or bush stem.
static func heap_clear(
	at: Vector2, gardens: Array[PackedVector2Array], stems: Dictionary
) -> bool:
	for poly in gardens:
		if (
			Geometry2D.is_point_in_polygon(at, poly)
			or CityFarmland._distance_to_polygon(at, poly) < HEAP_GARDEN_CLEAR
		):
			return false
	var key := Vector2i((at / CityFarmland.TREE_BUCKET).floor())
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for t: Vector2 in stems.get(key + Vector2i(dx, dy), []):
				if t.distance_to(at) < HEAP_TREE_CLEAR:
					return false
	return true


## Tree and bush stems bucketed by CityFarmland.TREE_BUCKET.
static func _stem_buckets(city_plan: CityPlan) -> Dictionary:
	var out := {}
	for key: String in ["trees", "bushes"]:
		for t: Array in city_plan.data.get(key, []):
			var p := Vector2(float(t[0]), float(t[1]))
			var cell := Vector2i((p / CityFarmland.TREE_BUCKET).floor())
			if not out.has(cell):
				out[cell] = []
			(out[cell] as Array).append(p)
	return out


## Stock walks from its yard to the grazing and back each day, along the streets
## from its yard: the drops fall on that walk.
static func _droves(city_plan: CityPlan, out: Array[Dictionary]) -> void:
	var grazing := grazing_areas(city_plan)
	for b: Dictionary in city_plan.data.get("buildings", []):
		if String(b.get("kind", "")) != "outbuilding" or not DROVE_STOCK.has(String(b["type"])):
			continue
		var stock: Array = DROVE_STOCK[String(b["type"])]
		# The same yard spot CityFauna keeps the animals at.
		var yard := CityFauna._centroid(CityPlan.points(b["footprint"])) + Vector2(3.5, 3.5)
		_drove(city_plan, out, "%s/drove" % b["id"], yard, grazing, stock[0], int(stock[1]))
	var gate := CityFauna._anchor_point(city_plan, TOWN_HERD_GATE)
	if gate != Vector2.INF:
		var herd_id := "%s/drove" % TOWN_HERD_GATE
		_drove(city_plan, out, herd_id, gate, grazing, &"cow", TOWN_HERD)


static func _drove(
	city_plan: CityPlan, out: Array[Dictionary], id: String, from: Vector2,
	grazing: Array[Dictionary], species: StringName, count: int
) -> void:
	var plan_route := drove_plan(city_plan, from, grazing)
	if plan_route.is_empty():
		return
	var kind: StringName = SPECIES_KIND[species]
	var route: PackedVector2Array = plan_route["points"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var spacing := float(DROVE_SPACING[kind]) / float(count)
	var next := rng.randf() * spacing
	var walked := 0.0
	for i in range(1, route.size()):
		var a := route[i - 1]
		var b := route[i]
		var seg := a.distance_to(b)
		while next <= walked + seg:
			var p := a.lerp(b, (next - walked) / maxf(seg, 0.001))
			var side := Vector2(-(b - a).y, (b - a).x).normalized()
			var at := p + side * rng.randf_range(-DROVE_HALF_WIDTH, DROVE_HALF_WIDTH)
			_add(city_plan, out, kind, at, rng, ROAD_LIFE, true, species)
			next += spacing * rng.randf_range(0.5, 1.5)
		walked += seg


## Yard -> the nearest drove street -> the cheapest way through the street graph
## -> grazing. Falls back to a straight walk when no street is near the yard or
## the streets lead nowhere better than the open field.
## `area` is the grazing polygon round `to`: only the walk to its edge counts as
## open ground, inside it the herd is where it belongs.
static func drove_route(
	city_plan: CityPlan, from: Vector2, to: Vector2, area := PackedVector2Array()
) -> PackedVector2Array:
	return drove_path(city_plan, from, to, area)["points"]


## drove_route with the street indices walked, in order: {points, streets}.
static func drove_path(
	city_plan: CityPlan, from: Vector2, to: Vector2, area := PackedVector2Array()
) -> Dictionary:
	return drove_plan(city_plan, from, [{"centre": to, "polygon": area}], INF)


## The cheapest drove from `from` to any of the `grazing` areas whose centre is
## within `reach`: {points, streets: street indices walked in order, area}, or
## {} when none is in reach. Road metres cost one, open ground DROVE_OFFROAD, so
## a pasture down the lane beats a nearer one across a neighbour's fields, but
## a herd still walks straight into a pasture beside its own yard.
static func drove_plan(
	city_plan: CityPlan, from: Vector2, grazing: Array[Dictionary], reach := DROVE_MAX
) -> Dictionary:
	var graph := _street_graph(city_plan)
	var nodes: PackedVector2Array = graph["nodes"]
	var edges: Array = graph["edges"]  # [a, b, street]
	# Entry: the closest point on any street segment within DROVE_ENTRY of the yard.
	var entry_edge := -1
	var entry := Vector2.INF
	var entry_d := DROVE_ENTRY
	for i in edges.size():
		var q := Geometry2D.get_closest_point_to_segment(from, nodes[edges[i][0]], nodes[edges[i][1]])
		if from.distance_to(q) < entry_d:
			entry_d = from.distance_to(q)
			entry = q
			entry_edge = i
	var walk: Array = []
	if entry_edge >= 0:
		var ea: int = edges[entry_edge][0]
		var eb: int = edges[entry_edge][1]
		walk = _dijkstra(graph, {ea: entry.distance_to(nodes[ea]), eb: entry.distance_to(nodes[eb])})
	var best_cost := INF
	var best_area := {}
	var best: Array = []  # [exit point, end node or -1 along the entry segment, edge]; [] = straight
	var near: Array[Dictionary] = []
	for area: Dictionary in grazing:
		if from.distance_to(area["centre"]) < reach:
			near.append(area)
	# Nearest first, so the best cost tightens early and prunes the rest.
	near.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return from.distance_squared_to(x["centre"]) < from.distance_squared_to(y["centre"]))
	for area: Dictionary in near:
		var to: Vector2 = area["centre"]
		var poly: PackedVector2Array = area["polygon"]
		var straight := _grazing_leg(from, to, poly)
		if straight < best_cost:
			straight += _trample_cost(city_plan, graph, from, to, poly)
		if straight < best_cost:
			best_cost = straight
			best_area = area
			best = []
		if walk.is_empty():
			continue
		var dist: PackedFloat32Array = walk[0]
		# Exit: the point on the graph that minimises road walked plus open ground to the grazing.
		for i in edges.size():
			var a: int = edges[i][0]
			var b: int = edges[i][1]
			# Road walked so far already costs more than the best drove: skip the geometry.
			var reached := minf(dist[a], dist[b]) + DROVE_OFFROAD * entry_d
			if i != entry_edge and reached >= best_cost:
				continue
			# Leave the street where it passes closest to the grazing's centre or at a vertex.
			for q: Vector2 in [
				Geometry2D.get_closest_point_to_segment(to, nodes[a], nodes[b]), nodes[a], nodes[b]
			]:
				var leg := DROVE_OFFROAD * entry_d + _grazing_leg(q, to, poly)
				var nearest := minf(dist[a], dist[b])
				if i == entry_edge:
					nearest = minf(nearest, entry.distance_to(q))
				if nearest + leg >= best_cost:
					continue  # cheap reject before the crop crossing test
				leg += _trample_cost(city_plan, graph, q, to, poly)
				if i == entry_edge and entry.distance_to(q) + leg < best_cost:
					best_cost = entry.distance_to(q) + leg
					best_area = area
					best = [q, -1, i]
				for end: int in [a, b]:
					var cost := dist[end] + nodes[end].distance_to(q) + leg
					if cost < best_cost:
						best_cost = cost
						best_area = area
						best = [q, end, i]
	if best_area.is_empty():
		return {}
	var target: Vector2 = best_area["centre"]
	if best.is_empty():
		return {
			"points": PackedVector2Array([from, target]), "streets": PackedInt32Array(),
			"area": best_area,
		}
	var prev: PackedInt32Array = walk[1]
	var via: PackedInt32Array = walk[2]
	var chain := PackedInt32Array()
	var node: int = best[1]
	while node >= 0:
		chain.append(node)
		node = prev[node]
	chain.reverse()
	var points := PackedVector2Array([from, entry])
	var streets := PackedInt32Array([int(edges[entry_edge][2])])
	for n in chain:
		points.append(nodes[n])
		if via[n] >= 0:
			streets.append(int(edges[via[n]][2]))
	points.append(best[0])
	streets.append(int(edges[best[2]][2]))
	points.append(target)
	var route := PackedVector2Array()
	for p in points:
		if route.is_empty() or route[-1].distance_to(p) > 0.05:
			route.append(p)
	var walked := PackedInt32Array()
	for s in streets:
		if walked.is_empty() or walked[-1] != s:
			walked.append(s)
	return {"points": route, "streets": walked, "area": best_area}


## Cost of walking from `p` straight to the grazing centre `to`: open ground up
## to the edge of `area` costs DROVE_OFFROAD a metre, the grazing itself one.
static func _grazing_leg(p: Vector2, to: Vector2, area: PackedVector2Array) -> float:
	var d := p.distance_to(to)
	if area.size() < 3 or Geometry2D.is_point_in_polygon(p, area):
		return d if area.size() >= 3 else DROVE_OFFROAD * d
	var outside := minf(CityFarmland._distance_to_polygon(p, area), d)
	return DROVE_OFFROAD * outside + (d - outside)


## Extra cost of the straight walk `p` -> `to` through sown fields other than
## the grazing `area` itself, and through buildings other than the one at `p`
## (the yard spot can sit in its own shed's footprint).
static func _trample_cost(
	city_plan: CityPlan, graph: Dictionary, p: Vector2, to: Vector2, area: PackedVector2Array
) -> float:
	var own := city_plan.building_at(p)
	var length := p.distance_to(to)
	var walled := 0.0
	var samples := int(length / 2.0)  # every 2 m: plenty against footprints of 4 m and more
	for k in samples:
		var b := city_plan.building_at(p.lerp(to, (float(k) + 0.5) / float(samples)))
		if b >= 0 and b != own:
			walled += length / float(samples)
	var span := Rect2(p, Vector2.ZERO).expand(to)
	var line := PackedVector2Array([p, to])
	var trampled := 0.0
	for crop: Array in graph["crops"]:
		if not (crop[0] as Rect2).intersects(span) or crop[1] == area:
			continue
		for piece: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(line, crop[1]):
			for k in range(1, piece.size()):
				trampled += piece[k - 1].distance_to(piece[k])
	return DROVE_CROP * trampled + DROVE_BUILDING * walled


## Shortest road distance from the `sources` ({node: start cost}) to every node:
## [dist, previous node (-1 at a source), edge index arrived by (-1 at a source)].
static func _dijkstra(graph: Dictionary, sources: Dictionary) -> Array:
	var nodes: PackedVector2Array = graph["nodes"]
	var edges: Array = graph["edges"]
	var adjacent: Array = graph["adjacent"]
	var dist := PackedFloat32Array()
	dist.resize(nodes.size())
	dist.fill(INF)
	var prev := PackedInt32Array()
	prev.resize(nodes.size())
	prev.fill(-1)
	var via := prev.duplicate()
	var heap := _Heap.new()
	for n: int in sources:
		if float(sources[n]) < dist[n]:
			dist[n] = float(sources[n])
			heap.push(dist[n], n)
	while not heap.is_empty():
		var top := heap.pop()
		var n := int(top.y)
		if top.x > dist[n]:
			continue
		for e: int in adjacent[n]:
			var m: int = edges[e][1] if int(edges[e][0]) == n else edges[e][0]
			var d := dist[n] + nodes[n].distance_to(nodes[m])
			if d < dist[m]:
				dist[m] = d
				prev[m] = n
				via[m] = e
				heap.push(d, m)
	return [dist, prev, via]


## The drove streets as a graph: {nodes, edges: [a, b, street index], adjacent}.
## Vertices within DROVE_SNAP merge into one junction; a street end within
## DROVE_SNAP of another street's segment splits that segment (a T-junction).
static func _street_graph(city_plan: CityPlan) -> Dictionary:
	var key := city_plan.get_instance_id()
	if _graphs.has(key):
		return _graphs[key]
	var lines: Array[PackedVector2Array] = []
	var ids := PackedInt32Array()
	for i in city_plan.streets.size():
		var s: Dictionary = city_plan.streets[i]
		if DROVE_CLASSES.has(String(s.get("class", ""))):
			lines.append(CityPlan.points(s["points"]))
			ids.append(i)
	# Splice street ends into the segments they butt against.
	for i in lines.size():
		for end: Vector2 in [lines[i][0], lines[i][-1]]:
			for j in lines.size():
				if j == i:
					continue
				var hit := _closest_on(lines[j], end)
				var t := float(hit[1])
				if float(hit[2]) < DROVE_SNAP and t - floorf(t) > 0.001 and t < lines[j].size() - 1:
					# Packed arrays are values: write the spliced copy back.
					var line := lines[j]
					line.insert(floori(t) + 1, hit[0])
					lines[j] = line
	var nodes := PackedVector2Array()
	var buckets := {}
	var edges: Array = []
	for i in lines.size():
		var last := -1
		for p in lines[i]:
			var n := _snap_node(nodes, buckets, p)
			if last >= 0 and last != n:
				edges.append([last, n, ids[i]])
			last = n
	var adjacent: Array = []
	adjacent.resize(nodes.size())
	for n in nodes.size():
		adjacent[n] = []  # a plain Array: a packed one would be appended to as a copy
	for e in edges.size():
		(adjacent[edges[e][0]] as Array).append(e)
		(adjacent[edges[e][1]] as Array).append(e)
	# Sown fields the herds must not cross: [bounds, polygon].
	var crops: Array = []
	for field: Dictionary in city_plan.data.get("fields", []):
		if bool(field["ploughed"]):
			var poly := CityPlan.points(field["polygon"])
			var bounds := Rect2(poly[0], Vector2.ZERO)
			for q in poly:
				bounds = bounds.expand(q)
			crops.append([bounds, poly])
	var graph := {"nodes": nodes, "edges": edges, "adjacent": adjacent, "crops": crops}
	_graphs[key] = graph
	return graph


## The node within DROVE_SNAP of `p`, or a new one there.
static func _snap_node(nodes: PackedVector2Array, buckets: Dictionary, p: Vector2) -> int:
	var cell := Vector2i((p / DROVE_SNAP).floor())
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for n: int in buckets.get(cell + Vector2i(dx, dy), []):
				if nodes[n].distance_to(p) < DROVE_SNAP:
					return n
	nodes.append(p)
	if not buckets.has(cell):
		buckets[cell] = []
	(buckets[cell] as Array).append(nodes.size() - 1)
	return nodes.size() - 1


## [closest point, parameter (segment index + t), distance] on a polyline.
static func _closest_on(pts: PackedVector2Array, p: Vector2) -> Array:
	var best := [pts[0], 0.0, p.distance_to(pts[0])]
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var ab := pts[i] - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var q := a + ab * t
		var d := p.distance_to(q)
		if d < float(best[2]):
			best = [q, float(i - 1) + t, d]
	return best


## Pastures and fallow fields, where the herds are driven to: [{centre, polygon}].
static func grazing_areas(city_plan: CityPlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var polys: Array[PackedVector2Array] = []
	for pasture: Dictionary in city_plan.data.get("pastures", []):
		polys.append(CityPlan.points(pasture["polygon"]))
	for field: Dictionary in city_plan.data.get("fields", []):
		if not bool(field["ploughed"]):
			polys.append(CityPlan.points(field["polygon"]))
	for poly in polys:
		out.append({"centre": CityFauna._centroid(poly), "polygon": poly})
	return out


static func _horse_roads(city_plan: CityPlan, out: Array[Dictionary]) -> void:
	for s: Dictionary in city_plan.streets:
		var cls := String(s.get("class", ""))
		if not HORSE_SPACING.has(cls):
			continue
		var pts := CityPlan.points(s["points"])
		var half := float(s.get("width", 4.0)) * 0.3
		var spacing := float(HORSE_SPACING[cls])
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s/horse" % s["id"])
		var next := rng.randf() * spacing
		var walked := 0.0
		for i in range(1, pts.size()):
			var a := pts[i - 1]
			var b := pts[i]
			var seg := a.distance_to(b)
			while next <= walked + seg:
				var p := a.lerp(b, (next - walked) / maxf(seg, 0.001))
				var side := Vector2(-(b - a).y, (b - a).x).normalized()
				var at := p + side * rng.randf_range(-half, half)
				_add(city_plan, out, KIND_HORSE, at, rng, ROAD_LIFE, false, &"horse")
				next += spacing * rng.randf_range(0.5, 1.5)
			walked += seg


static func _add(
	city_plan: CityPlan, out: Array[Dictionary], kind: StringName, at: Vector2,
	rng: RandomNumberGenerator, life: float, grazing: bool, species: StringName
) -> void:
	# Draw the randoms first so a rejected spot does not shift the next drop.
	var u := rng.randf()
	var yaw := rng.randf() * TAU
	var size := rng.randf_range(0.8, 1.2)
	if not CityFauna._is_dry(city_plan, at):
		return
	out.append({
		"kind": kind, "at": at, "u": u, "life": life, "yaw": yaw, "size": size,
		"grazing": grazing, "tint": SPECIES_TINT.get(species, Color.WHITE),
	})


func _rebuild(cover: float, fill: float) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_placed.clear()
	var buckets: Dictionary = {}  # [kind, stage, chunk] -> {transforms, colors, ages}
	for drop: Dictionary in _drops:
		var kind: StringName = drop["kind"]
		var at: Vector2 = drop["at"]
		var spec: Dictionary = SPEC[kind]
		var age := 0.0 if kind == KIND_HEAP else age_on(drop, _day_number)
		if bool(drop["grazing"]) and (_housed or age > _days_out):
			continue
		var lift := 0.0
		if cover > 0.001 and kind != KIND_HEAP:
			lift = CitySnow.depth_at(at, cover)
			if lift > SNOW_BURY and age > SNOW_FRESH_DAYS:
				continue
		var dry_days := float(spec["dry"]) * _dry_slowdown
		var dried := clampf(age / dry_days, 0.0, 1.0)
		var size := float(drop["size"])
		var squash := Vector3(size, size, size)
		if kind == KIND_COW_PAT:
			# A pat slumps and shrinks as it dries into a flat crust.
			squash.y *= lerpf(1.0, 0.55, dried)
		elif kind == KIND_HEAP:
			squash *= lerpf(0.45, 1.0, fill)
		var basis := Basis(Vector3.UP, float(drop["yaw"])).scaled(squash)
		var origin := Vector3(at.x, plan.ground_height(at) + lift - 0.004, at.y)
		var xf := Transform3D(basis, origin)
		var color := (spec["fresh"] as Color).lerp(Color.WHITE, dried) * (drop["tint"] as Color)
		var stage := STAGE_CRUST if kind == KIND_HEAP else stage_for(age, dry_days)
		var key := [kind, stage, Vector2i(floori(at.x / CHUNK), floori(at.y / CHUNK))]
		if not buckets.has(key):
			buckets[key] = {
				"transforms": [] as Array[Transform3D], "colors": [] as Array[Color], "ages": []
			}
		(buckets[key]["transforms"] as Array[Transform3D]).append(xf)
		(buckets[key]["colors"] as Array[Color]).append(color)
		(buckets[key]["ages"] as Array).append(age)
	var keys := buckets.keys()
	keys.sort_custom(func(x: Array, y: Array) -> bool: return str(x) < str(y))
	for key: Array in keys:
		var kind: StringName = key[0]
		var stage := int(key[1])
		var batch: Dictionary = buckets[key]
		var mmi := MapViewMeshBuilderPrimitives.multi_mesh(
			"%s_s%d_%d_%d" % [kind, stage, key[2].x, key[2].y],
			mesh_for(kind),
			batch["transforms"],
			batch["colors"],
			material(stage),
			Vector3.ZERO
		)
		var transforms: Array[Transform3D] = batch["transforms"]
		for i in transforms.size():
			_placed.append([kind, transforms[i], stage == STAGE_WET, stage, batch["ages"][i]])
		# Only the heap is big enough to cast a shadow worth its cost.
		if kind != KIND_HEAP:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = float(SPEC[kind]["range"])
		mmi.visibility_range_end_margin = 6.0
		add_child(mmi)


## Fresh dung is wet and glossy, then keeps a damp sheen for some days, then
## dulls to a crust.
static func material(stage: int) -> StandardMaterial3D:
	if not _materials.has(stage):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		_materials[stage] = m
		_apply_wetness(m, stage)
	return _materials[stage]


## Rain soaks dried dung (R-2077 follow-up): damp and crusted pats darken and
## soften towards the wet gloss. `value` is the ground-trail wetness (0..1) that
## CityWorld3D feeds from rain and puddles; one change updates every batch.
static func set_wetness(value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	if absf(value - _wetness) < 0.01:
		return
	_wetness = value
	for stage: int in _materials:
		_apply_wetness(_materials[stage], stage)


static func wetness() -> float:
	return _wetness


static func _apply_wetness(m: StandardMaterial3D, stage: int) -> void:
	# Fresh dung is already wet; only the drier stages take up the rain.
	var soak := 0.0 if stage == STAGE_WET else _wetness
	m.albedo_color = Color.WHITE.lerp(RAIN_DARKEN, soak)
	m.roughness = lerpf([0.45, 0.72, 0.92][stage], RAIN_ROUGHNESS, soak)
	m.metallic_specular = lerpf([0.45, 0.36, 0.3][stage], 0.42, soak)


static func mesh_for(kind: StringName) -> ArrayMesh:
	if not _meshes.has(kind):
		_meshes[kind] = _build_mesh(kind)
	return _meshes[kind]


## Meshes in metres in their dried palette (the instance colour darkens fresh
## ones). Albedos sit low because the outdoor exposure gain (R-1748) lifts them:
## these read as dung, not as pale stones, beside the packed-earth splat. Small
## droppings are drawn ~1.4x life size so they still read from the follow camera.
static func _build_mesh(kind: StringName) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	match kind:
		KIND_COW_PAT:
			# Coiled tiers of a pat ~0.34 m across, the folds a shade darker.
			var crust := Color(0.31, 0.26, 0.19)
			var fold := Color(0.25, 0.21, 0.15)
			CityForestFloor._lathe(st, [
				[0.17, -0.004, fold], [0.168, 0.012, crust], [0.15, 0.019, fold],
				[0.145, 0.026, crust], [0.11, 0.032, fold], [0.104, 0.039, crust],
				[0.06, 0.043, fold], [0.03, 0.047, crust], [0.0, 0.048, crust]
			], 18, rng, 0.1)
		KIND_HORSE:
			# Six to eight balls of chewed straw, heaped where they fell.
			var straw := Color(0.33, 0.28, 0.18)
			var spots: Array[Vector3] = [
				Vector3(0.0, 0.04, 0.0), Vector3(0.07, 0.035, 0.02), Vector3(-0.05, 0.035, 0.05),
				Vector3(-0.03, 0.035, -0.065), Vector3(0.04, 0.035, -0.06),
				Vector3(0.015, 0.1, -0.01), Vector3(-0.03, 0.095, 0.015), Vector3(0.13, 0.03, 0.09)
			]
			for p in spots:
				var r := rng.randf_range(0.036, 0.046)
				_blob(st, p, Vector3(r, r * 0.9, r * 1.05), straw, Color(0.4, 0.35, 0.21),
					0.25, rng, 0.12)
		KIND_PELLETS:
			# A scatter of small dark pellets, some still stuck in a clump.
			var dark := Color(0.14, 0.12, 0.09)
			for i in 16:
				var p := Vector3(rng.randf_range(-0.09, 0.09), 0.009, rng.randf_range(-0.09, 0.09))
				if i < 5:
					var a := float(i)
					p = Vector3(0.02 * cos(a), 0.01 + 0.012 * float(i % 2), 0.02 * sin(a))
				_blob(st, p, Vector3(0.011, 0.01, 0.012), dark, dark, 0.0, rng, 0.08, 6, 4)
		KIND_HARE:
			var fibre := Color(0.27, 0.23, 0.16)
			for i in 6:
				var p := Vector3(rng.randf_range(-0.12, 0.12), 0.008, rng.randf_range(-0.12, 0.12))
				var r := Vector3(0.013, 0.009, 0.013)
				_blob(st, p, r, fibre, fibre * 0.85, 0.3, rng, 0.06, 6, 4)
		KIND_PIG:
			var muck := Color(0.2, 0.17, 0.14)
			# Three slumped lumps run together.
			var lumps: Array[Array] = [
				[Vector3(0.0, 0.03, 0.0), Vector3(0.07, 0.04, 0.06)],
				[Vector3(0.06, 0.025, 0.04), Vector3(0.045, 0.03, 0.05)],
				[Vector3(-0.03, 0.06, 0.01), Vector3(0.04, 0.03, 0.04)],
			]
			for lump in lumps:
				_blob(st, lump[0], lump[1], muck, muck, 0.0, rng, 0.22)
		KIND_FOWL:
			# Three droppings, each a dark coil under a white cap of urates.
			var brown := Color(0.17, 0.15, 0.11)
			var white := Color(0.62, 0.6, 0.55)
			for i in 3:
				var p := Vector3(rng.randf_range(-0.15, 0.15), 0.008, rng.randf_range(-0.15, 0.15))
				_blob(st, p, Vector3(0.02, 0.011, 0.016), brown, brown, 0.0, rng, 0.2, 7, 4)
				_blob(st, p + Vector3(0.004, 0.009, 0.0), Vector3(0.011, 0.006, 0.01), white, white,
					0.0, rng, 0.1, 6, 3)
		KIND_HEAP:
			# A lumpy mound of byre muck and bedding straw, ~2.2 m across.
			CityForestFloor._lathe(st, [
				[1.15, -0.06, Color(0.08, 0.06, 0.035)], [1.0, 0.16, Color(0.11, 0.08, 0.05)],
				[0.75, 0.36, Color(0.13, 0.1, 0.06)], [0.42, 0.5, Color(0.14, 0.11, 0.065)],
				[0.0, 0.55, Color(0.15, 0.115, 0.07)]
			], 16, rng, 0.22, Color(0.33, 0.27, 0.14), 0.25)
	# Merge shared vertices so the lumps shade smooth, not faceted.
	st.index()
	st.generate_normals()
	return st.commit()


## A latitude-longitude ellipsoid at `centre` with `radii`; `wobble` jitters the
## outline, `fleck` paints that share of vertices in `fleck_color` (straw bits).
static func _blob(
	st: SurfaceTool, centre: Vector3, radii: Vector3, color: Color, fleck_color: Color,
	fleck: float, rng: RandomNumberGenerator, wobble: float, segments := 9, rings := 6
) -> void:
	var grid: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	for k in rings + 1:
		var lat := lerpf(-PI * 0.5, PI * 0.5, float(k) / float(rings))
		var row := PackedVector3Array()
		var cs := PackedColorArray()
		for i in segments:
			var lon := TAU * float(i) / float(segments)
			var j := 1.0 + rng.randf_range(-wobble, wobble)
			if k == 0 or k == rings:
				j = 1.0  # poles stay single points so the cap closes
			var dir := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
			row.append(centre + dir * radii * j)
			cs.append(fleck_color if rng.randf() < fleck else color)
		grid.append(row)
		cols.append(cs)
	for k in rings:
		for i in segments:
			var n := (i + 1) % segments
			var quad := [[k, i], [k + 1, n], [k + 1, i], [k, i], [k, n], [k + 1, n]]
			for v: Array in quad:
				st.set_color(cols[v[0]][v[1]])
				st.add_vertex(grid[v[0]][v[1]])


## A binary min-heap of (cost, node) for the drove graph's Dijkstra.
class _Heap:
	var _items: Array[Vector2] = []

	func is_empty() -> bool:
		return _items.is_empty()

	func push(cost: float, node: int) -> void:
		_items.append(Vector2(cost, node))
		var i := _items.size() - 1
		while i > 0:
			var up := (i - 1) >> 1
			if _items[up].x <= _items[i].x:
				break
			var swap := _items[up]
			_items[up] = _items[i]
			_items[i] = swap
			i = up

	func pop() -> Vector2:
		var top := _items[0]
		var last: Vector2 = _items.pop_back()
		if not _items.is_empty():
			_items[0] = last
			var i := 0
			while true:
				var small := i
				for c in [2 * i + 1, 2 * i + 2]:
					if c < _items.size() and _items[c].x < _items[small].x:
						small = c
				if small == i:
					break
				var swap := _items[small]
				_items[small] = _items[i]
				_items[i] = swap
				i = small
		return top

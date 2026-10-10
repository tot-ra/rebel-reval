class_name CitizenRoster
extends RefCounted

## The census residents of Reval as a pure, deterministic timetable
## (docs/SYSTEMS/CITIZENS.md). Compiled by tools/city/build_citizen_runtime.py
## into content/world/reval_city/citizens.json: residents, the places they use,
## the street graph between them and their daily patterns.
##
## WHY pure: where a person is follows only from the hour, so any resident near
## Kalev can be seated at the right spot (indoors, at the door, mid-street) with
## no per-person simulation state, and saves never need to record it.

const DATA_PATH := "res://content/world/reval_city/citizens.json"
const CELL := 128.0
const BBOX_PAD := 45.0
const LANE_WIDTH := 0.22
const DEFAULT_FACING := Vector2(0.0, 1.0)
## Patrols walk their route back and forth at this speed (m/s), tools/city/gate_garrisons.py.
const PATROL_SPEED := 0.9

static var _default: CitizenRoster

var residents: Array[Dictionary] = []
var by_id: Dictionary = {}
var places: Array = []
## Walked routes of the town watch and the wall patrol: [{id, points: PackedVector2Array}].
var patrols: Array[Dictionary] = []
var patterns: Dictionary = {}
## Census households in plan houses: hh id -> {building, class, trade, size}
## (docs/SYSTEMS/HOUSEHOLDS.md), and their compiled residents in census order.
var households: Dictionary = {}
var members: Dictionary = {}  # hh id -> PackedInt32Array of resident indices
var household_of_building: Dictionary = {}  # plan building id -> hh id

var _astar := AStar2D.new()
var _nodes := PackedVector2Array()
var _routes: Dictionary = {}
var _grid: Dictionary = {}


static func load_default() -> CitizenRoster:
	if _default == null:
		_default = CitizenRoster.new()
		_default.load_file(DATA_PATH)
	return _default


## The roster of a plan: Reval's census, a regional site's own citizens.json when
## its `citizens` flag is on, otherwise an empty roster (ADR 0042: people at a
## regional site come only with a later task).
static func load_for(plan: CityPlan) -> CitizenRoster:
	if plan.site_id == CityPlan.DEFAULT_SITE:
		return load_default()
	var roster := CitizenRoster.new()
	var path := plan.file_path("citizens.json")
	if plan.feature_enabled("citizens") and FileAccess.file_exists(path):
		roster.load_file(path)
	return roster


func load_file(path: String) -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("CitizenRoster: cannot read %s" % path)
		return false
	var data: Dictionary = parsed
	patterns = data["patterns"]
	places = data["places"]
	for route: Dictionary in data.get("patrols", []):
		var points := PackedVector2Array()
		for p: Array in route["points"]:
			points.append(Vector2(p[0], p[1]))
		patrols.append({"id": route["id"], "points": points, "length": _polyline_length(points)})
	households = data.get("households", {})
	for hh: String in households:
		household_of_building[String(households[hh]["building"])] = hh
	for raw: Variant in data["residents"]:
		by_id[raw["id"]] = residents.size()
		var list: PackedInt32Array = members.get(raw["household"], PackedInt32Array())
		list.append(residents.size())
		members[raw["household"]] = list
		residents.append(raw)
	for node: Array in data["graph"]["nodes"]:
		_nodes.append(Vector2(node[0], node[1]))
		_astar.add_point(_nodes.size() - 1, _nodes[-1])
	for edge: Array in data["graph"]["edges"]:
		_astar.connect_points(int(edge[0]), int(edge[1]))
	_build_grid()
	return true


func count() -> int:
	return residents.size()


func index_of(resident_id: String) -> int:
	return int(by_id.get(resident_id, -1))


func place_position(place: int) -> Vector2:
	var p: Array = places[place]
	return Vector2(p[0], p[1])


## Indices of residents whose home, work or errands bring them within `radius`
## of `world_xz` at some hour. A superset: callers still resolve the hour.
func candidates_near(world_xz: Vector2, radius: float) -> PackedInt32Array:
	var found := {}
	var lo := Vector2i(floori((world_xz.x - radius) / CELL), floori((world_xz.y - radius) / CELL))
	var hi := Vector2i(floori((world_xz.x + radius) / CELL), floori((world_xz.y + radius) / CELL))
	for cx in range(lo.x, hi.x + 1):
		for cz in range(lo.y, hi.y + 1):
			for index: int in _grid.get(Vector2i(cx, cz), []):
				found[index] = true
	var out := PackedInt32Array()
	for index: int in found:
		out.append(index)
	out.sort()
	return out


## Where resident `index` is at `hour` (0..24). Keys: visible (false while
## indoors), moving, pos (world xz metres), facing (unit world xz), dest (the
## destination key of the current leg: door, home, work, errand, errand2),
## from (the key the leg started at) and arrived (hours since the leg ended,
## -1 while still under way).
func resolve(index: int, hour: float) -> Dictionary:
	var r: Dictionary = residents[index]
	var entries: Array = patterns[r["pattern"]]
	var jitter := float(r["jitter"])
	var leg := -1
	var depart := 0.0
	for i in entries.size():
		var at_hour := float(entries[i][0])
		if at_hour > 0.0:
			at_hour = clampf(at_hour + jitter, 0.5, 23.0)
		if at_hour > hour:
			break
		leg = i
		depart = at_hour
	if leg < 0:
		var arrived := hour + 24.0 - _leg_end(r, entries, entries.size() - 1)
		var night := _hold(r, String(entries[-1][1]), arrived)
		night["arrived"] = arrived
		return night
	var dest_key := String(entries[leg][1])
	var from_key := String(entries[leg - 1][1]) if leg > 0 else String(entries[-1][1])
	var from_place := _place_of(r, from_key)
	var to_place := _place_of(r, dest_key)
	if from_place == to_place:
		var same := _hold(r, dest_key, hour - depart)
		same["from"] = from_key
		same["arrived"] = hour - depart
		return same
	var route := _route(from_place, to_place)
	var travelled := (hour - depart) * 3600.0 * float(r["walk"])
	if travelled >= float(route["length"]):
		var waited := (travelled - float(route["length"])) / (3600.0 * float(r["walk"]))
		var done := _hold(r, dest_key, waited)
		done["from"] = from_key
		done["arrived"] = waited
		return done
	var spot := _along(route["points"], travelled)
	var lane := Vector2(-spot[1].y, spot[1].x) * (float(_slot(r) % 7) - 3.0) * LANE_WIDTH
	return {
		"visible": true,
		"moving": true,
		"pos": spot[0] + lane,
		"facing": spot[1],
		"dest": dest_key,
		"from": from_key,
		"arrived": -1.0,
	}


## Hour at which leg `leg` of `entries` reaches its destination.
func _leg_end(r: Dictionary, entries: Array, leg: int) -> float:
	var depart := float(entries[leg][0])
	if depart > 0.0:
		depart = clampf(depart + float(r["jitter"]), 0.5, 23.0)
	var from_key := String(entries[leg - 1][1]) if leg > 0 else String(entries[-1][1])
	var a := _place_of(r, from_key)
	var b := _place_of(r, String(entries[leg][1]))
	if a == b:
		return depart
	return depart + float(_route(a, b)["length"]) / (3600.0 * float(r["walk"]))


## Short English description of what the resident is doing at `hour`.
func describe(index: int, hour: float) -> String:
	var r: Dictionary = residents[index]
	var state := resolve(index, hour)
	var dest := String(state["dest"])
	var on_patrol: bool = state.get("patrol", false)
	if state["moving"] and not on_patrol:
		return "On the way %s" % _label(r, dest)
	if dest == "home":
		return "At home"
	return _stay_label(r, dest)


func place_label_key(r: Dictionary, key: String) -> String:
	match key:
		"work":
			return String(r["work_kind"])
		"errand":
			return String(r["errand_kind"])
		"errand2":
			return String(r["errand2_kind"])
		"food":
			return "food_" + String(r["food_kind"])
		"supply":
			return "supply_" + String(r["supply_kind"])
		"door", "water", "fuel", "latrine", "school", "church", "stroll":
			return key
	return "home"


func _stay_label(r: Dictionary, key: String) -> String:
	var kind := place_label_key(r, key)
	match kind:
		"door":
			return "Working at their own door" if r["pattern"] == "craft" else "Outside their house"
		"forum":
			return "At the forum market"
		"landing":
			return "At the fish landing"
		"granary":
			return "Working at the granary quay"
		"hall":
			return "At the town hall"
		"castle":
			return "On duty at the castle"
		"church":
			return "At the church"
		"patrol":
			return "On patrol: %s" % _duty_label(r)
		"post", "gate":
			return "On guard duty%s" % (": " + _duty_label(r) if r.has("duty") else "")
		"well":
			return "At the well"
		"mill":
			return "At the mill"
		"market":
			return "At the market"
		"water":
			return "Drawing water at the well"
		"fuel":
			return "Gathering firewood"
		"latrine":
			return "Emptying the slops into the gutter"
		"school":
			return "At school"
		"stroll":
			return "Out for a walk"
		"food_market":
			return "Buying food at the market"
		"food_bakery":
			return "Buying bread at the bakers' ovens"
		"food_butcher":
			return "Buying meat at the butchers' benches"
		"supply_iron":
			return "Buying iron at the smiths' street"
		"supply_grain":
			return "Fetching grain and malt"
		"supply_fish":
			return "Buying fish at the landing"
		"supply_water":
			return "Carrying water for the trade"
		"supply_wood":
			return "Fetching timber and clay"
		"supply_market":
			return "Shopping for the trade"
	return "Going about the day"


## "<role>, <post>, <shift>" of a resident on gate or patrol duty.
func _duty_label(r: Dictionary) -> String:
	var d: Dictionary = r["duty"]
	return "%s, %s (%s shift)" % [String(d["role"]).replace("_", " "), d["label"], d["shift"]]


func _label(r: Dictionary, key: String) -> String:
	var kind := place_label_key(r, key)
	match kind:
		"home":
			return "home"
		"door":
			return "to their work at the door"
		"forum", "market":
			return "to the market"
		"landing":
			return "to the fish landing"
		"granary":
			return "to the granary quay"
		"hall":
			return "to the town hall"
		"castle":
			return "to the castle"
		"church":
			return "to church"
		"patrol":
			return "to their patrol"
		"post", "gate":
			return "to their post"
		"well", "water":
			return "to the well"
		"mill":
			return "to the mill"
		"fuel":
			return "to gather firewood"
		"latrine":
			return "to empty the slops"
		"school":
			return "to school"
		"stroll":
			return "for a walk"
		"food_market":
			return "to the market for food"
		"food_bakery":
			return "to the bakers"
		"food_butcher":
			return "to the butchers"
		"supply_iron":
			return "to buy iron"
		"supply_grain":
			return "to fetch grain"
		"supply_fish":
			return "to buy fish"
		"supply_water":
			return "to fetch water"
		"supply_wood":
			return "to fetch timber"
		"supply_market":
			return "shopping for the trade"
	return "somewhere"


## 0..47, stable per resident: the personal offset slot.
func _slot(r: Dictionary) -> int:
	return absi(hash(String(r["id"]))) % 48


func _place_of(r: Dictionary, key: String) -> int:
	match key:
		"work", "errand", "errand2", "water", "food", "fuel", "latrine", "supply", "school":
			return int(r[key])
		"church":
			return int(r["church"]) if r["devout"] else int(r["home"])
		"stroll":
			return int(r["stroll"]) if r["strolls"] else int(r["home"])
	return int(r["home"])


## Standing at `key` for `waited` hours; a patrolling guard on duty walks his
## route instead of standing at its start.
func _hold(r: Dictionary, key: String, waited: float) -> Dictionary:
	if key == "work" and r.has("duty") and r["duty"].has("route"):
		return _patrol(r, waited)
	return _still(r, key)


## Position of a patrolling guard `waited` hours after reaching the route's start:
## back and forth along the route, each man a few metres behind the one before.
func _patrol(r: Dictionary, waited: float) -> Dictionary:
	var route: Dictionary = patrols[int(r["duty"]["route"])]
	var points: PackedVector2Array = route["points"]
	var length: float = route["length"]
	var travelled := waited * 3600.0 * PATROL_SPEED + float(r["duty"].get("offset", 0.0))
	var phase := fposmod(travelled, 2.0 * length)
	var forward := phase <= length
	var spot := _along(points, phase if forward else 2.0 * length - phase)
	var facing: Vector2 = spot[1] if forward else -(spot[1] as Vector2)
	return {
		"visible": true, "moving": true, "pos": spot[0], "facing": facing,
		"dest": "work", "from": "work", "arrived": waited, "patrol": true,
	}


static func _polyline_length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


func _still(r: Dictionary, key: String) -> Dictionary:
	var place: Array = places[_place_of(r, key)]
	var facing := DEFAULT_FACING
	var pos := Vector2(place[0], place[1])
	var slot := _slot(r)
	if key == "work" and r.has("duty") and r["duty"].get("exact", false) and place[3] != null:
		# A gate post: this exact spot, looking out of the town.
		facing = Vector2(cos(float(place[3])), sin(float(place[3])))
	elif place[3] != null:
		# At a door: spread along the frontage, a little way out, so a household
		# does not stand in one spot.
		var out := Vector2(cos(float(place[3])), sin(float(place[3])))
		pos += Vector2(-out.y, out.x) * (float(slot % 12) - 5.5) * 0.38 + out * float(slot % 3) * 0.45
		facing = out
	else:
		# Everywhere else: a sunflower spiral round the spot, one cell per resident.
		var a := float(slot) * 2.39996
		pos += Vector2(cos(a), sin(a)) * 0.7 * sqrt(float(slot + 1))
		var look := float(absi(hash(String(r["id"]) + key)) % 628) / 100.0
		facing = Vector2(cos(look), sin(look))
	return {
		"visible": key != "home",
		"moving": false,
		"pos": pos,
		"facing": facing,
		"dest": key,
		"from": key,
		"arrived": 24.0,
	}


func _route(from_place: int, to_place: int) -> Dictionary:
	var key := from_place * 100000 + to_place
	if _routes.has(key):
		return _routes[key]
	var a: Array = places[from_place]
	var b: Array = places[to_place]
	var points := PackedVector2Array([Vector2(a[0], a[1])])
	var from_node := int(a[2])
	var to_node := int(b[2])
	if from_node >= 0 and to_node >= 0:
		for node: int in _astar.get_id_path(from_node, to_node):
			points.append(_nodes[node])
	points.append(Vector2(b[0], b[1]))
	var length := 0.0
	for i in range(1, points.size()):
		length += points[i - 1].distance_to(points[i])
	var route := {"points": points, "length": length}
	_routes[key] = route
	return route


static func _along(points: PackedVector2Array, distance: float) -> Array:
	var left := distance
	for i in range(1, points.size()):
		var seg := points[i].distance_to(points[i - 1])
		if left <= seg and seg > 0.0:
			var dir := (points[i] - points[i - 1]) / seg
			return [points[i - 1] + dir * left, dir]
		left -= seg
	return [points[-1], DEFAULT_FACING]


func _build_grid() -> void:
	for index in residents.size():
		var r: Dictionary = residents[index]
		var box := Rect2(place_position(int(r["home"])), Vector2.ZERO)
		for key: String in ["work", "errand", "errand2"]:
			box = box.expand(place_position(int(r[key])))
		if r.has("duty") and r["duty"].has("route"):
			for point: Vector2 in patrols[int(r["duty"]["route"])]["points"]:
				box = box.expand(point)
		box = box.grow(BBOX_PAD)
		var lo := Vector2i(floori(box.position.x / CELL), floori(box.position.y / CELL))
		var hi := Vector2i(floori(box.end.x / CELL), floori(box.end.y / CELL))
		for cx in range(lo.x, hi.x + 1):
			for cz in range(lo.y, hi.y + 1):
				var cell := Vector2i(cx, cz)
				var members: PackedInt32Array = _grid.get(cell, PackedInt32Array())
				members.append(index)
				_grid[cell] = members

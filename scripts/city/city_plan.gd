class_name CityPlan
extends RefCounted

## Continuous Reval 1343 city plan (ADR 0031). Loads the compiled vector plan and
## heightfield written by tools/city/build_reval_city_plan.py. Coordinates are
## world units (0.87 m): x east, z south; the logic plane uses x and y = z,
## scaled by LOGIC_PX_PER_UNIT. Everything here is read-only data.

const PLAN_PATH := "res://content/world/reval_city/plan.json"
const HEIGHT_PATH := "res://content/world/reval_city/height.json"
const SPLAT_PATH := "res://content/world/reval_city/splat.png"
const ROADS_PATH := "res://content/world/reval_city/roads.png"
const SCHEMA := "rr.city_plan.v1"
const LOGIC_PX_PER_UNIT := 32.0
const INDEX_CELL := 32.0
## Interior floors sit on a slab above the highest ground under the footprint.
const FLOOR_LIFT := 0.12
## A bridge deck rides this far above the bank ground at its ends.
const BRIDGE_DECK_LIFT := 0.12
## Streets further than this (beyond their edge) are not named on the HUD.
const STREET_LABEL_RADIUS := 6.0

static var _cached: CityPlan

var data: Dictionary = {}
var bounds := Rect2()
var metres_per_unit := 0.87
var buildings: Array = []
var streets: Array = []
## Landmark sites (ADR 0032) with their compiled placement.
var sites: Array[CitySite] = []
var _heights := PackedFloat32Array()
var _nx := 0
var _ny := 0
var _cell := 2.0
var _origin := Vector2.ZERO
## Building footprints by INDEX_CELL bucket, for point queries.
var _building_index: Dictionary = {}
var _footprints: Array[PackedVector2Array] = []
var _height_texture: ImageTexture


static func load_default() -> CityPlan:
	if _cached == null:
		_cached = CityPlan.new()
		var error := _cached.load_files(PLAN_PATH, HEIGHT_PATH)
		if error != OK:
			push_error("CityPlan: cannot load %s (%s)" % [PLAN_PATH, error_string(error)])
	return _cached


## Ground heights as a float texture for shaders (rising damp, puddles), with
## the world rectangle it covers: Vector4(origin.x, origin.z, size.x, size.z).
func height_texture() -> ImageTexture:
	if _height_texture == null:
		var image := Image.create_from_data(
			_nx, _ny, false, Image.FORMAT_RF, _heights.to_byte_array()
		)
		_height_texture = ImageTexture.create_from_image(image)
	return _height_texture


func height_texture_rect() -> Vector4:
	return Vector4(
		_origin.x - _cell * 0.5, _origin.y - _cell * 0.5, _cell * float(_nx), _cell * float(_ny)
	)


static func clear_cache() -> void:
	_cached = null


func load_files(plan_path: String, height_path: String) -> Error:
	var plan_text := FileAccess.get_file_as_string(plan_path)
	if plan_text.is_empty():
		return ERR_FILE_NOT_FOUND
	var parsed: Variant = JSON.parse_string(plan_text)
	if not parsed is Dictionary or String((parsed as Dictionary).get("schema", "")) != SCHEMA:
		return ERR_PARSE_ERROR
	data = parsed
	var b: Array = data["bounds"]
	bounds = Rect2(
		Vector2(b[0], b[1]), Vector2(float(b[2]) - float(b[0]), float(b[3]) - float(b[1]))
	)
	metres_per_unit = float(data.get("metres_per_world_unit", 0.87))
	buildings = data.get("buildings", [])
	streets = data.get("streets", [])
	sites = CitySiteRegistry.load_for(data)
	var error := _load_heights(height_path)
	if error != OK:
		return error
	_index_buildings()
	return OK


func _load_heights(path: String) -> Error:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return ERR_FILE_NOT_FOUND
	var doc: Variant = JSON.parse_string(text)
	if not doc is Dictionary:
		return ERR_PARSE_ERROR
	_nx = int(doc["nx"])
	_ny = int(doc["ny"])
	_cell = float(doc["cell"])
	_origin = Vector2(doc["origin"][0], doc["origin"][1])
	var raw := Marshalls.base64_to_raw(String(doc["data"]))
	var offset := float(doc["offset_cm"])
	if raw.size() != _nx * _ny * 2:
		return ERR_FILE_CORRUPT
	_heights.resize(_nx * _ny)
	for i in _nx * _ny:
		_heights[i] = (float(raw.decode_u16(i * 2)) - offset) * 0.01
	return OK


func height_grid_size() -> Vector2i:
	return Vector2i(_nx, _ny)


func height_cell() -> float:
	return _cell


func height_origin() -> Vector2:
	return _origin


## Raw grid sample, clamped to the grid.
func grid_height(ix: int, iy: int) -> float:
	ix = clampi(ix, 0, _nx - 1)
	iy = clampi(iy, 0, _ny - 1)
	return _heights[iy * _nx + ix]


## Bilinear ground height at a world XZ position (world units).
func ground_height(world_xz: Vector2) -> float:
	if _nx == 0:
		return 0.0
	var f := (world_xz - _origin) / _cell
	f.x = clampf(f.x, 0.0, float(_nx) - 1.001)
	f.y = clampf(f.y, 0.0, float(_ny) - 1.001)
	var ix := int(f.x)
	var iy := int(f.y)
	var u := f.x - float(ix)
	var v := f.y - float(iy)
	var i := iy * _nx + ix
	var h00 := _heights[i]
	var h10 := _heights[i + 1]
	var h01 := _heights[i + _nx]
	var h11 := _heights[i + _nx + 1]
	return lerpf(lerpf(h00, h10, u), lerpf(h01, h11, u), v)


## Ground slope in radians from central differences.
func slope_at(world_xz: Vector2) -> float:
	var e := _cell
	var dx := ground_height(world_xz + Vector2(e, 0)) - ground_height(world_xz - Vector2(e, 0))
	var dz := ground_height(world_xz + Vector2(0, e)) - ground_height(world_xz - Vector2(0, e))
	return atan(Vector2(dx, dz).length() / (2.0 * e))


## Height an actor stands at: building floors win over the ground inside a shell.
func walk_height(world_xz: Vector2) -> float:
	var deck := bridge_deck_height(world_xz)
	if not is_nan(deck):
		return deck
	for site in sites:
		var f := site.floor_at(world_xz)
		if not f.is_empty():
			return site.floor_height_at(f, world_xz)
	var index := building_at(world_xz)
	if index >= 0:
		return floor_height(index)
	return ground_height(world_xz)


## Deck height of the timber bridge under the point, or NAN off every bridge.
## The deck ramps from bank height to bank height along the road.
func bridge_deck_height(world_xz: Vector2) -> float:
	for b: Dictionary in data.get("bridges", []):
		var at := Vector2(b["at"][0], b["at"][1])
		var along := Vector2.from_angle(float(b["angle"]))
		var local := world_xz - at
		var u := local.dot(along)
		var v := local.dot(along.orthogonal())
		var half := float(b["length"]) * 0.5
		if absf(u) <= half and absf(v) <= float(b["width"]) * 0.5:
			return bridge_deck_at(b, (u + half) / float(b["length"]))
	return NAN


static func bridge_deck_at(bridge: Dictionary, t: float) -> float:
	return lerpf(float(bridge["ha"]), float(bridge["hb"]), clampf(t, 0.0, 1.0)) + BRIDGE_DECK_LIFT


func floor_height(index: int) -> float:
	var b: Dictionary = buildings[index]
	return float(b["base_h"]) + float(b["base_span"]) + FLOOR_LIFT


func footprint(index: int) -> PackedVector2Array:
	return _footprints[index]


## Index of the building whose footprint contains the point, or -1.
func building_at(world_xz: Vector2) -> int:
	var key := Vector2i(floori(world_xz.x / INDEX_CELL), floori(world_xz.y / INDEX_CELL))
	var bucket: Array = _building_index.get(key, [])
	for index: int in bucket:
		if Geometry2D.is_point_in_polygon(world_xz, _footprints[index]):
			return index
	return -1


func buildings_near(world_xz: Vector2, radius: float) -> Array[int]:
	var found: Array[int] = []
	var seen := {}
	var lo := Vector2i(
		floori((world_xz.x - radius) / INDEX_CELL), floori((world_xz.y - radius) / INDEX_CELL)
	)
	var hi := Vector2i(
		floori((world_xz.x + radius) / INDEX_CELL), floori((world_xz.y + radius) / INDEX_CELL)
	)
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			for index: int in _building_index.get(Vector2i(x, y), []):
				if not seen.has(index):
					seen[index] = true
					found.append(index)
	return found


func _index_buildings() -> void:
	_footprints.clear()
	_building_index.clear()
	for i in buildings.size():
		var ring := PackedVector2Array()
		for p: Array in buildings[i]["footprint"]:
			ring.append(Vector2(p[0], p[1]))
		_footprints.append(ring)
		var box := Rect2(ring[0], Vector2.ZERO)
		for p in ring:
			box = box.expand(p)
		for y in range(floori(box.position.y / INDEX_CELL), floori(box.end.y / INDEX_CELL) + 1):
			for x in range(floori(box.position.x / INDEX_CELL), floori(box.end.x / INDEX_CELL) + 1):
				var key := Vector2i(x, y)
				if not _building_index.has(key):
					_building_index[key] = []
				(_building_index[key] as Array).append(i)


static func to_logic(world_xz: Vector2) -> Vector2:
	return world_xz * LOGIC_PX_PER_UNIT


static func to_world_xz(logic: Vector2) -> Vector2:
	return logic / LOGIC_PX_PER_UNIT


static func points(raw: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Array in raw:
		out.append(Vector2(p[0], p[1]))
	return out


func gate(gate_id: String) -> Dictionary:
	for g: Dictionary in data.get("gates", []):
		if g["id"] == gate_id:
			return g
	return {}


func point_of_interest(poi_id: String) -> Dictionary:
	for p: Dictionary in data.get("points_of_interest", []):
		if p["id"] == poi_id:
			return p
	return {}


## The site whose building footprint contains the point, or null.
func site_at(world_xz: Vector2) -> CitySite:
	for site in sites:
		if site.occupies(world_xz):
			return site
	return null


## The site room containing a world position: {site: CitySite, room}, or {}.
func site_room_at(world_xz: Vector2) -> Dictionary:
	for site in sites:
		var room := site.room_at(world_xz)
		if not room.is_empty():
			return {"site": site, "room": room}
	return {}


## Names for the HUD: {district, street, building} at a world position.
## `inside` is the building index Kalev stands in (or -1).
## Id of the plan district containing `world_xz`, or "" outside every district.
func district_id_at(world_xz: Vector2) -> String:
	for d: Dictionary in data.get("districts", []):
		if Geometry2D.is_point_in_polygon(world_xz, CityPlan.points(d["polygon"])):
			return String(d["id"])
	return ""


func location_at(world_xz: Vector2, inside: int = -1) -> Dictionary:
	var district := "Outside the walls"
	for d: Dictionary in data.get("districts", []):
		if Geometry2D.is_point_in_polygon(world_xz, CityPlan.points(d["polygon"])):
			district = String(d["name"])
			break
	var street := ""
	var best := STREET_LABEL_RADIUS
	for s: Dictionary in streets:
		var label := String(s.get("name", ""))
		if label.is_empty():
			label = String(s.get("name_1343", ""))
		if label.is_empty():
			continue
		var pts := CityPlan.points(s["points"])
		for i in pts.size() - 1:
			var q := Geometry2D.get_closest_point_to_segment(world_xz, pts[i], pts[i + 1])
			var d := q.distance_to(world_xz) - float(s.get("width", 0.0)) * 0.5
			if d < best:
				best = d
				street = label
				var old := String(s.get("name_1343", ""))
				if not old.is_empty() and old != label:
					street = "%s - %s" % [label, old]
	var building := ""
	var room := site_room_at(world_xz)
	if not room.is_empty():
		building = "Inside: %s" % String(room["room"]["name"])
	elif inside >= 0:
		var b: Dictionary = buildings[inside]
		var name := String(b.get("name_1343", ""))
		building = "Inside: %s" % (name if not name.is_empty() else _house_label(b))
	return {"district": district, "street": street, "building": building}


static func _house_label(b: Dictionary) -> String:
	match String(b.get("material", "")):
		"limestone":
			return "stone merchant house"
		"plaster":
			return "plastered house"
		_:
			return "timber house"

class_name HouseholdLayout
extends RefCounted

## Where a household's things stand in its house (docs/SYSTEMS/HOUSEHOLDS.md).
## A pure function of the plan building and the census household: the same
## house always gets the same hearth, beds, table, benches, chest, firewood and
## lights, and the same spots where its people sleep, sit, tend the fire and
## work. Nothing here touches nodes; CityInteriors builds the models from it
## and CitizenRoster seats the residents on its slots.
##
## Every piece is a catalog object (docs/SYSTEMS/OBJECT_CATALOG.md); sizes come
## from the catalog's measured GLB sizes, so a re-modelled object re-flows the room.

const OBJECTS_DIR := "res://content/objects"
## Wall thickness as built by CityBuildingBuilder, plus a hand's breadth.
const WALL_GAP := 0.05
## Kept clear inside the door: the doorway and a step into the room.
const DOOR_CLEAR_DEPTH := 2.0
const DOOR_CLEAR_WIDTH := 1.8
const SCAN_STEP := 0.25
const GRID_STEP := 0.35

## Per piece: catalog object, which local axis is the front (+1 = +Z, -1 = -Z),
## whether Kalev collides with it, and the height people use it at.
const PIECES := {
	&"hearth": {"object": "obj.hearth_domestic", "front": -1, "solid": true},
	&"bed_framed": {"object": "obj.bed_smithy", "front": 1, "solid": true, "lie_h": 0.62},
	&"bed_pallet": {"object": "obj.bed_straw_pallet", "front": 1, "solid": true, "lie_h": 0.42},
	&"table": {"object": "obj.table_common_household", "front": 1, "solid": true},
	&"table_long": {"object": "obj.table_long_board", "front": 1, "solid": true},
	&"workbench": {"object": "obj.table_trestle_work", "front": 1, "solid": true},
	&"bench": {"object": "obj.bench_plank", "front": 1, "solid": true, "seat_h": 0.46},
	&"stool": {"object": "obj.stool_three_leg", "front": 1, "solid": false, "seat_h": 0.44},
	&"chair": {"object": "obj.chair_smithy", "front": -1, "solid": false, "seat_h": 0.47},
	&"chest_poor": {"object": "obj.chest_plain_coffer", "front": 1, "solid": true},
	&"chest": {"object": "obj.chest_burgher", "front": 1, "solid": true},
	&"strongbox": {"object": "obj.chest_merchant_strongbox", "front": 1, "solid": true},
	&"cupboard": {"object": "obj.cupboard_burgher", "front": 1, "solid": true},
	&"shelf": {"object": "obj.shelf_common_open", "front": 1, "solid": true},
	&"firewood": {"object": "obj.firewood_pile_indoor", "front": 1, "solid": false},
	&"bucket": {"object": "obj.water_bucket", "front": 1, "solid": false},
	&"basket": {"object": "obj.basket_wicker", "front": 1, "solid": false},
	&"pot": {"object": "obj.clay_pot", "front": 1, "solid": false},
	&"cargo_grain": {"object": "obj.cargo_grain_flax", "front": 1, "solid": true},
	&"cargo_cloth": {"object": "obj.cargo_cloth_salt", "front": 1, "solid": true},
	&"cargo_furs": {"object": "obj.cargo_furs_wax", "front": 1, "solid": true},
	&"cargo_herring": {"object": "obj.cargo_herring_barrels", "front": 1, "solid": true},
	&"malt": {"object": "obj.malt_sack_pile", "front": 1, "solid": true},
	&"nets": {"object": "obj.fishing_nets", "front": 1, "solid": false},
	&"rope": {"object": "obj.rope_coil_hemp", "front": 1, "solid": false},
	&"firewood_stack": {"object": "obj.firewood_stack", "front": 1, "solid": true},
	&"splint": {"object": "obj.pine_splint_holder", "front": 1, "solid": false},
	&"candle_poor": {"object": "obj.candlestick_tallow_poor", "front": 1, "solid": false},
	&"candle": {"object": "obj.candlestick_tallow_artisan", "front": 1, "solid": false},
	&"candle_rich": {"object": "obj.candlestick_beeswax_rich", "front": 1, "solid": false},
	&"eating_set": {"object": "obj.set_kitchen_eating", "front": 1, "solid": false},
	&"prep_set": {"object": "obj.set_kitchen_prep", "front": 1, "solid": false},
	&"bread": {"object": "obj.rye_bread_loaf", "front": 1, "solid": false},
	&"jug": {"object": "obj.jug", "front": 1, "solid": false},
}
## Census household class -> furnishing tier.
const TIER := {
	"poor": &"poor", "master": &"mid", "merchant": &"rich", "great": &"rich",
}
## Goods kept in the front hall (Diele) by the head's trade; merchants by default.
const HALL_GOODS := {
	"brewer": [&"malt", &"malt", &"cargo_herring"],
	"alewife": [&"malt", &"cargo_herring"],
	"maltster": [&"malt", &"malt"],
	"fisher": [&"nets", &"cargo_herring"],
	"fishmonger": [&"cargo_herring", &"nets"],
	"rope_maker": [&"rope", &"rope", &"cargo_grain"],
	"furrier": [&"cargo_furs", &"cargo_furs"],
	"skinner": [&"cargo_furs"],
	"chandler": [&"cargo_furs"],
	"merchant": [&"cargo_cloth", &"cargo_grain", &"cargo_furs", &"cargo_herring", &"cargo_cloth"],
}
## A room this big (m2) has a living end round the hearth and a front hall:
## it is split by a partition once it is SPLIT_LENGTH long, twice past
## CHAMBER_AREA (hall, living room, chamber).
const HALL_AREA := 80.0
const SPLIT_LENGTH := 9.0
const CHAMBER_AREA := 190.0
const PARTITION_THICK := 0.14
const PARTITION_GAP := 1.1
## Trades that work at a bench in their own house.
const BENCH_TRADES := [
	"smith", "nailsmith", "carpenter", "joiner", "cooper", "shoemaker", "tailor", "weaver",
	"furrier", "goldsmith", "potter", "baker", "brewer", "turner", "saddler", "glover",
	"belt_maker", "cutler", "locksmith", "pewterer", "bowyer", "fletcher", "rope_maker",
]

static var _objects: Dictionary = {}

## Placed things: {piece, object, pos (world xz), yaw, y (above the floor), poly, solid}.
var items: Array[Dictionary] = []
## Spots people use: {kind (sleep, sit, hearth, work, stand), pos, facing, h, item}.
var slots: Array[Dictionary] = []
var building_index := -1
var floor_y := 0.0
var inner := PackedVector2Array()
var hearth := -1
var firewood := -1
var lights: Array[int] = []
## Just inside the door: where people come in and go out.
var entry := Vector2.ZERO
## A big house is split across its length by plank partitions into rooms,
## front (the hall at the street door) to back: rooms[k] = [from, to] along
## `axis` from `axis_origin`; partitions[k] = {a, b, gap, walls: [[p, q], ...]}
## sits between rooms k and k + 1.
var rooms: Array = []
var partitions: Array[Dictionary] = []
var axis := Vector2.RIGHT
var axis_origin := Vector2.ZERO

var _rng := RandomNumberGenerator.new()
var _door := Vector2.ZERO
var _door_in := Vector2.ZERO
var _keep_outs: Array[PackedVector2Array] = []
var _occupied: Array[PackedVector2Array] = []
var _occupied_boxes: Array[Rect2] = []
var _inner_box := Rect2()


## Catalog record of `id` (cached), or {} when it is missing.
static func object(id: String) -> Dictionary:
	if _objects.is_empty():
		_load_objects()
	return _objects.get(id, {})


## Measured size [x, y, z] in metres of a piece's catalog object.
static func piece_size(piece: StringName) -> Vector3:
	var record := object(String(PIECES[piece]["object"]))
	var fallback_size: Array = record.get("physical", {}).get("size_m", [0.5, 0.5, 0.5])
	var size: Array = record.get("model", {}).get("measured_size_m", fallback_size)
	return Vector3(size[0], size[1], size[2])


static func _load_objects() -> void:
	var root := DirAccess.open(OBJECTS_DIR)
	if root == null:
		push_error("HouseholdLayout: cannot open %s" % OBJECTS_DIR)
		return
	for category in root.get_directories():
		var path := "%s/%s" % [OBJECTS_DIR, category]
		for file in DirAccess.get_files_at(path):
			if not file.ends_with(".json"):
				continue
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/%s" % [path, file]))
			if parsed is Dictionary and parsed.has("id"):
				_objects[parsed["id"]] = parsed


## Furnishes plan building `index` for `household` ({class, trade, size} from
## citizens.json). `chimney` is the world xz of the house's chimney, if any.
static func build(
	plan: CityPlan, index: int, household: Dictionary, chimney := Vector2.INF
) -> HouseholdLayout:
	var layout := HouseholdLayout.new()
	layout._build(plan, index, household, chimney)
	return layout


func tier_of(household: Dictionary) -> StringName:
	return TIER.get(String(household.get("class", "poor")), &"poor")


func _build(plan: CityPlan, index: int, household: Dictionary, chimney: Vector2) -> void:
	building_index = index
	var b: Dictionary = plan.buildings[index]
	_rng.seed = hash(String(b["id"]) + ":furnish")
	floor_y = plan.floor_height(index)
	var ring := CityBuildingBuilder.wall_ring(b, plan.footprint(index))
	var thick := (
		CityBuildingBuilder.STONE_WALL if String(b["material"]) == "limestone"
		else CityBuildingBuilder.TIMBER_WALL
	)
	var inset := Geometry2D.offset_polygon(ring, -(thick + WALL_GAP), Geometry2D.JOIN_MITER)
	if inset.is_empty():
		return
	inner = inset[0]
	for poly: PackedVector2Array in inset:
		if absf(CityBuildingBuilder.signed_area(poly)) > absf(CityBuildingBuilder.signed_area(inner)):
			inner = poly
	_inner_box = _aabb(inner).grow(0.001)
	if b.get("door") == null:
		return
	var door_out := Vector2(cos(float(b["door"][2])), sin(float(b["door"][2])))
	_door = Vector2(b["door"][0], b["door"][1])
	_door_in = -door_out
	var side := Vector2(-_door_in.y, _door_in.x) * DOOR_CLEAR_WIDTH * 0.5
	var deep := _door + _door_in * (thick + DOOR_CLEAR_DEPTH)
	_keep_outs.append(PackedVector2Array([_door - side, _door + side, deep + side, deep - side]))
	entry = _door + _door_in * (thick + 0.6)
	_partition()
	_furnish(household, chimney)


func _furnish(household: Dictionary, chimney: Vector2) -> void:
	var tier := tier_of(household)
	var size := maxi(int(household.get("size", 2)), 1)
	var trade := String(household.get("trade", ""))
	var area := absf(CityBuildingBuilder.signed_area(inner))
	# Hearth under the chimney, or on the wall farthest from the door.
	hearth = _place_on_wall(&"hearth", func(p: Vector2, _n: Vector2) -> float:
		return -p.distance_to(chimney) if chimney != Vector2.INF else p.distance_to(_door))
	if hearth >= 0:
		var h: Dictionary = items[hearth]
		var front := _front(hearth)
		_slot(&"hearth", h["pos"] + front * (piece_size(&"hearth").z * 0.5 + 0.5), -front, 0.0, hearth)
		firewood = _place_near(&"firewood", h["pos"], 0.4)
		_place_near(&"bucket", h["pos"], 0.3)
		_place_near(&"pot", h["pos"], 0.3)
	# Beds: a shared bed sleeps two or three; the head couple of a better
	# house has a framed bed. Beds, table and storage gather round the hearth
	# (the warm living end); a big house keeps its front hall for work and goods.
	var beds := clampi(ceili(size / 2.5), 1, 6)
	for k in beds:
		var piece := &"bed_framed" if k == 0 and tier != &"poor" else &"bed_pallet"
		var bed := _place_on_wall(piece, _living(3.6, sleeping_room()))
		if bed < 0 and piece == &"bed_framed":
			bed = _place_on_wall(&"bed_pallet", _living(3.6, sleeping_room()))
		if bed < 0:
			break
		_bed_slots(bed)
	# The table and its seats.
	_place_table(tier, size)
	# Storage.
	var chest_piece := &"chest_poor" if tier == &"poor" else &"chest"
	var first_bed := _first(&"bed_framed", &"bed_pallet")
	_place_on_wall(chest_piece, func(p: Vector2, _n: Vector2) -> float:
		return -p.distance_to(items[first_bed]["pos"]) if first_bed >= 0 else p.distance_to(_door))
	if tier == &"rich":
		_place_on_wall(&"cupboard", _living(2.8))
		_place_on_wall(&"strongbox", _living(4.0))
	if size >= 8:
		_place_on_wall(chest_piece, _living(4.5))
	var shelf := _place_on_wall(&"shelf", _living(1.6))
	if shelf >= 0:
		_on_top(&"prep_set", shelf, 0.92)
		_slot(&"stand", items[shelf]["pos"] + _front(shelf) * 0.7, -_front(shelf), 0.0, shelf)
	_place_near(&"basket", items[shelf]["pos"] if shelf >= 0 else _door, 0.3)
	# A craftsman's bench by the door, where the light is.
	var big := area > HALL_AREA
	if trade in BENCH_TRADES and area > 30.0:
		var bench := _place_on_wall(&"workbench", _by_door)
		if bench >= 0:
			_slot(&"work", items[bench]["pos"] + _front(bench) * 0.75, -_front(bench), 0.0, bench)
			if big:
				_place_on_wall(&"workbench", _by_door)
	# The front hall: goods by trade (merchants keep wares here), and the
	# season's firewood stacked where the carts unload.
	if big:
		var goods: Array = HALL_GOODS.get(trade, HALL_GOODS["merchant"] if tier == &"rich" else [])
		var hall_area := _room_area(0)
		var heaps := int(hall_area / 14.0) if tier == &"rich" else int(hall_area / 30.0)
		for k in (heaps if not goods.is_empty() else 0):
			# Along the walls first, then stacked on the floor either side of the aisle.
			if k % 2 == 0 or _place_in_room(goods[k % goods.size()], 0) < 0:
				_place_on_wall(goods[k % goods.size()], _by_door)
		_place_on_wall(&"firewood_stack", _by_door)
		if tier == &"rich":
			# The counting table where goods are weighed and written down.
			var desk := _place_on_wall(&"table", _by_door)
			if desk >= 0:
				_add(&"candle", items[desk]["pos"], items[desk]["yaw"], piece_size(&"table").y, true)
				_slot(&"work", items[desk]["pos"] + _front(desk) * 0.75, -_front(desk), 0.0, desk)
		# A work table by the hearth for the cooking.
		var prep := _place_on_wall(&"table", _living(1.8))
		if prep >= 0:
			_on_top(&"prep_set", prep, piece_size(&"table").y)
			_slot(&"stand", items[prep]["pos"] + _front(prep) * 0.6, -_front(prep), 0.0, prep)
	# Bigger rooms: wall benches, stools, baskets and pots round the walls
	# where people sat to work and talk.
	var spare := int(area / 28.0) - 1
	var fillers: Array = [&"bench", &"stool", &"basket", &"pot", &"chest_poor", &"stool", &"basket"]
	for k in clampi(spare, 0, 10):
		var piece: StringName = fillers[k % fillers.size()]
		var target := living_room() if k % 3 != 2 else sleeping_room()
		var placed := _place_on_wall(piece, _living(2.5 + float(k % 4), target))
		if placed >= 0 and piece == &"bench":
			_seat_slots(placed, _front(placed), [-0.45, 0.45])
	# Light for the evening: a resinous splint by the hearth in a poor house.
	if tier == &"poor" and hearth >= 0:
		var splint := _place_near(&"splint", items[hearth]["pos"], 0.5)
		if splint >= 0:
			lights.append(splint)
	# Somewhere to stand for anyone without a seat or a task.
	for k in 3:
		var p := _open_point()
		if p != Vector2.INF:
			_slot(&"stand", p, (_door - p).normalized().rotated(_rng.randf_range(-1.2, 1.2)), 0.0, -1)


## Splits a big house into rooms across its length (see `rooms`).
func _partition() -> void:
	var area := absf(CityBuildingBuilder.signed_area(inner))
	# Length direction: the longer extent of the room, oriented away from the door.
	var long := _long_axis()
	var across := Vector2(-long.y, long.x)
	var e1 := _extent(long)
	var e2 := _extent(across)
	axis = long if e1.y - e1.x >= e2.y - e2.x else across
	var ext := _extent(axis)
	if absf(_door.dot(axis) - ext.x) > absf(_door.dot(axis) - ext.y):
		axis = -axis
		ext = _extent(axis)
	axis_origin = axis * ext.x
	var length := ext.y - ext.x
	rooms = [[0.0, length]]
	if area < HALL_AREA or length < SPLIT_LENGTH:
		return
	var cuts: Array = []
	var hall := clampf(length * 0.42, 4.5, 9.0)
	cuts.append(hall)
	if area >= CHAMBER_AREA and length - hall >= SPLIT_LENGTH:
		cuts.append(hall + (length - hall) * 0.55)
	rooms = []
	var from := 0.0
	for c: float in cuts:
		if _cut(c):
			rooms.append([from, c])
			from = c
	rooms.append([from, length])
	# An aisle from the street door through the doorways stays clear.
	var way := PackedVector2Array([entry])
	for part: Dictionary in partitions:
		way.append(part["gap"])
	for i in range(1, way.size()):
		var a := way[i - 1]
		var b := way[i]
		var side := (b - a).normalized().orthogonal() * 0.7
		_keep_outs.append(PackedVector2Array([a - side, b - side, b + side, a + side]))


## One partition across the room at `along` metres from the front.
func _cut(along: float) -> bool:
	var across := Vector2(-axis.y, axis.x)
	var mid := axis_origin + axis * along + across * across.dot(_centroid())
	var hits: Array = []
	for i in inner.size():
		var hit: Variant = Geometry2D.segment_intersects_segment(
			inner[i], inner[(i + 1) % inner.size()], mid - across * 200.0, mid + across * 200.0
		)
		if hit != null:
			hits.append([(hit as Vector2 - mid).dot(across), hit])
	if hits.size() < 2:
		return false
	hits.sort()
	var a: Vector2 = hits[0][1]
	var b: Vector2 = hits[-1][1]
	var span := a.distance_to(b)
	if span < PARTITION_GAP + 1.6:
		return false
	var t := clampf(
		0.3 if _rng.randf() < 0.5 else 0.7,
		(PARTITION_GAP * 0.5 + 0.7) / span,
		1.0 - (PARTITION_GAP * 0.5 + 0.7) / span
	)
	var gap := a.lerp(b, t)
	var dir := (b - a) / span
	var walls := [[a, gap - dir * PARTITION_GAP * 0.5], [gap + dir * PARTITION_GAP * 0.5, b]]
	for w: Array in walls:
		var p: Vector2 = w[0]
		var q: Vector2 = w[1]
		var n := axis * PARTITION_THICK * 0.5
		_occupy(PackedVector2Array([p - n, q - n, q + n, p + n]))
	# Keep the doorway and a step on both sides clear.
	var w2 := dir * (PARTITION_GAP * 0.5 + 0.15)
	var d2 := axis * 1.3
	_keep_outs.append(PackedVector2Array([gap - w2 - d2, gap + w2 - d2, gap + w2 + d2, gap - w2 + d2]))
	partitions.append({"a": a, "b": b, "gap": gap, "walls": walls})
	return true


func _extent(dir: Vector2) -> Vector2:
	var lo := INF
	var hi := -INF
	for p in inner:
		lo = minf(lo, p.dot(dir))
		hi = maxf(hi, p.dot(dir))
	return Vector2(lo, hi)


## Room index of a floor point (0 = the front hall).
func room_of(p: Vector2) -> int:
	var along := (p - axis_origin).dot(axis)
	for k in rooms.size():
		if along < float(rooms[k][1]):
			return k
	return rooms.size() - 1


## The way from the door to `target`: entry, the doorways between, the target.
func path_to(target: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array([entry])
	var from_room := room_of(entry)
	var to_room := room_of(target)
	var step := 1 if to_room >= from_room else -1
	var k := from_room
	while k != to_room:
		var part: Dictionary = partitions[mini(k, k + step)]
		out.append(part["gap"])
		k += step
	out.append(target)
	return out


## Floor area of room `k` (m2), from the room's share of the house length.
func _room_area(k: int) -> float:
	var length := float(rooms[-1][1])
	return (
		absf(CityBuildingBuilder.signed_area(inner))
		* (float(rooms[k][1]) - float(rooms[k][0]))
		/ maxf(length, 0.01)
	)


## A piece on the open floor of room `k` (goods heaps in the hall), squared to
## the house; tries spots in a seeded order. Returns the item or -1.
func _place_in_room(piece: StringName, k: int) -> int:
	var size := piece_size(piece)
	var yaw := atan2(-axis.y, axis.x) + (PI * 0.5 if _rng.randf() < 0.5 else 0.0)
	var spots: Array = []
	var y := _inner_box.position.y
	while y <= _inner_box.end.y:
		var x := _inner_box.position.x
		while x <= _inner_box.end.x:
			var p := Vector2(x, y)
			if room_of(p) == k and Geometry2D.is_point_in_polygon(p, inner):
				spots.append(p)
			x += 0.7
		y += 0.7
	for i in range(spots.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Vector2 = spots[i]
		spots[i] = spots[j]
		spots[j] = tmp
	for p: Vector2 in spots.slice(0, 60):
		if _fits(_rect(p, yaw, size.x + 0.5, size.z + 0.5)):
			return _add(piece, p, yaw, 0.0, true)
	return -1


## Where the household lives (the hearth's room), sleeps and works.
func living_room() -> int:
	return room_of(items[hearth]["pos"]) if hearth >= 0 else rooms.size() - 1


func sleeping_room() -> int:
	var living := living_room()
	for k in range(rooms.size() - 1, 0, -1):
		if k != living:
			return k
	return living


func _room_bonus(p: Vector2, room: int) -> float:
	return 6.0 if rooms.size() > 1 and room_of(p) == room else 0.0


func _place_table(tier: StringName, size: int) -> void:
	var piece := &"table_long" if tier == &"rich" and size >= 6 else &"table"
	var t_size := piece_size(piece)
	var b_size := piece_size(&"bench")
	var group_depth := t_size.z + 2.0 * (b_size.z + 0.12)
	var best := Vector2.INF
	var best_yaw := 0.0
	var best_score := -INF
	var long_dir := _long_axis()
	var yaw := atan2(long_dir.y, long_dir.x) * -1.0
	var centre := _centroid()
	var living := living_room()
	var area := absf(CityBuildingBuilder.signed_area(inner))
	# Coarser search in big rooms: the grid stays a few hundred points.
	var step := clampf(sqrt(area) / 18.0, GRID_STEP, 0.9)
	var lo := _inner_box.position
	var hi := _inner_box.end
	var y := lo.y
	while y <= hi.y:
		var x := lo.x
		while x <= hi.x:
			var p := Vector2(x, y)
			x += step
			if rooms.size() > 1 and room_of(p) != living:
				continue
			if not Geometry2D.is_point_in_polygon(p, inner):
				continue
			var poly := _rect(p, yaw, t_size.x + 0.3, group_depth)
			if _fits(poly):
				var score := -p.distance_to(centre) * 0.3 + 0.25 * p.distance_to(_door)
				score += _room_bonus(p, living_room())
				if hearth >= 0:
					var d := p.distance_to(items[hearth]["pos"])
					score -= absf(d - 2.8)
					if d < 1.8:
						score -= 3.0
				if score > best_score:
					best_score = score
					best = p
					best_yaw = yaw
		y += step
	if best == Vector2.INF:
		# No room for a table between benches: a table on the wall, stools in front.
		var table := _place_on_wall(piece, _near_hearth_score)
		if table < 0 and piece == &"table_long":
			table = _place_on_wall(&"table", _near_hearth_score)
		if table < 0:
			return
		_table_top(table, tier)
		var front := _front(table)
		var across := Vector2(front.y, -front.x)
		for k in mini(size, 2):
			var at: Vector2 = items[table]["pos"] + front * (piece_size(items[table]["piece"]).z * 0.5 + 0.3)
			at += across * (float(k) - 0.5) * 0.6
			var stool := _add(&"stool", at, _yaw_facing(-front, 1), 0.0)
			if stool >= 0:
				_seat_slots(stool, -front, [0.0])
		return
	var table := _add(piece, best, best_yaw, 0.0, true)
	_table_top(table, tier)
	var ez := Vector2(sin(best_yaw), cos(best_yaw))
	for s: float in [-1.0, 1.0]:
		var at := best + ez * s * (t_size.z * 0.5 + b_size.z * 0.5 + 0.1)
		var seat := _add(&"bench", at, best_yaw, 0.0)
		var offsets: Array = [-0.5, 0.0, 0.5] if b_size.x > 1.4 else [0.0]
		if seat >= 0:
			_seat_slots(seat, -ez * s, offsets)
	if tier != &"poor":
		var ex := Vector2(cos(best_yaw), -sin(best_yaw))
		var at := best + ex * (t_size.x * 0.5 + 0.35)
		var chair := _add(&"chair", at, _yaw_facing(-ex, -1), 0.0)
		if chair >= 0:
			_seat_slots(chair, -ex, [0.0])


func _table_top(table: int, tier: StringName) -> void:
	if table < 0:
		return
	var top := piece_size(items[table]["piece"]).y
	_on_top(&"eating_set", table, top)
	var ex := Vector2(cos(items[table]["yaw"]), -sin(items[table]["yaw"]))
	var candle := (
		&"candle_poor" if tier == &"poor" else &"candle_rich" if tier == &"rich" else &"candle"
	)
	var light := _add(candle, items[table]["pos"] + ex * 0.45, items[table]["yaw"], top, true)
	if light >= 0:
		lights.append(light)
	_add(&"bread", items[table]["pos"] - ex * 0.4, items[table]["yaw"] + 0.4, top, true)
	_add(&"jug", items[table]["pos"] - ex * 0.15 + Vector2(0.12, 0.1), 0.0, top, true)


func _on_top(piece: StringName, under: int, top: float) -> int:
	return _add(piece, items[under]["pos"], items[under]["yaw"], top, true)


## Two sleepers side by side; the slot is the foot end, facing away from the head.
func _bed_slots(bed: int) -> void:
	var piece: StringName = items[bed]["piece"]
	var size := piece_size(piece)
	var yaw := float(items[bed]["yaw"])
	var head_to_foot := Vector2(cos(yaw), -sin(yaw))  # the head is at local -X
	var across := Vector2(sin(yaw), cos(yaw))
	var lanes: Array = [-0.24, 0.24] if size.z > 0.9 else [0.0]
	for lane: float in lanes:
		var at: Vector2 = items[bed]["pos"] + head_to_foot * (size.x * 0.5 - 0.12) + across * lane
		_slot(&"sleep", at, head_to_foot, float(PIECES[piece]["lie_h"]), bed)


func _seat_slots(seat: int, facing: Vector2, offsets: Array) -> void:
	var piece: StringName = items[seat]["piece"]
	var along := Vector2(-facing.y, facing.x)
	for o: float in offsets:
		_slot(&"sit", items[seat]["pos"] + along * o, facing, float(PIECES[piece]["seat_h"]), seat)


func _slot(kind: StringName, pos: Vector2, facing: Vector2, h: float, item: int) -> void:
	slots.append({"kind": kind, "pos": pos, "facing": facing.normalized(), "h": h, "item": item})


## Slots of one kind, in placement order.
func slots_of(kind: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in slots:
		if s["kind"] == kind:
			out.append(s)
	return out


func _first(a: StringName, b: StringName) -> int:
	for i in items.size():
		if items[i]["piece"] == a or items[i]["piece"] == b:
			return i
	return -1


func _front(item: int) -> Vector2:
	var yaw := float(items[item]["yaw"])
	return Vector2(sin(yaw), cos(yaw)) * float(PIECES[items[item]["piece"]]["front"])


## Yaw that turns a piece's front toward `direction`.
static func _yaw_facing(direction: Vector2, front: int) -> float:
	var d := direction * float(front)
	return atan2(d.x, d.y)


## Score for the living end: about `ideal` metres from the hearth, away from the door.
func _living(ideal: float, room := -1) -> Callable:
	return func(p: Vector2, _n: Vector2) -> float:
		var score := 0.15 * p.distance_to(_door)
		var target := living_room() if room < 0 else room
		if rooms.size() > 1 and target != living_room():
			# Another room (the chamber): anywhere in it, spread along its walls.
			return (12.0 if room_of(p) == target else 0.0) + _rng.randf() * 2.0
		score += _room_bonus(p, target)
		if hearth >= 0:
			var d := p.distance_to(items[hearth]["pos"])
			score -= absf(d - ideal)
			if d < 1.3:
				score -= 4.0
		return score


func _by_door(p: Vector2, _n: Vector2) -> float:
	var score := -p.distance_to(_door) * 0.5 + _room_bonus(p, 0)
	if hearth >= 0 and p.distance_to(items[hearth]["pos"]) < 2.0:
		score -= 4.0
	return score


func _near_hearth_score(p: Vector2, _n: Vector2) -> float:
	return -p.distance_to(items[hearth]["pos"]) if hearth >= 0 else p.distance_to(_door)


## Best wall position for `piece` by `score(pos, inward)`; back to the wall,
## long side along it. Returns the item index or -1.
func _place_on_wall(piece: StringName, score: Callable) -> int:
	var size := piece_size(piece)
	var front := int(PIECES[piece]["front"])
	# Score every wall position first (cheap), then test the best ones for room.
	var candidates: Array = []
	for i in inner.size():
		var a := inner[i]
		var c := inner[(i + 1) % inner.size()]
		var length := a.distance_to(c)
		if length < size.x + 0.1:
			continue
		var dir := (c - a) / length
		var n := Vector2(-dir.y, dir.x)
		if not Geometry2D.is_point_in_polygon((a + c) * 0.5 + n * 0.05, inner):
			n = -n
		var yaw := _yaw_facing(n, front)
		var t := size.x * 0.5 + 0.05
		while t <= length - size.x * 0.5 - 0.05:
			var p := a + dir * t + n * (size.z * 0.5 + 0.03)
			candidates.append([float(score.call(p, n)) + _rng.randf() * 0.05, p, yaw])
			t += SCAN_STEP
	candidates.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
	for cand: Array in candidates:
		if _fits(_rect(cand[1], cand[2], size.x, size.z)):
			return _add(piece, cand[1], cand[2], 0.0, true)
	return -1


## Free floor spot within a ring round `near` (no wall needed).
func _place_near(piece: StringName, near: Vector2, gap: float) -> int:
	var size := piece_size(piece)
	var reach := maxf(size.x, size.z) * 0.5 + gap
	for ring_k in 4:
		var r := reach + 0.35 * ring_k + 0.5
		for k in 12:
			var a := float(k) / 12.0 * TAU + _rng.randf() * 0.3
			var p := near + Vector2(cos(a), sin(a)) * r
			var yaw := _rng.randf() * TAU
			if _fits(_rect(p, yaw, size.x, size.z)):
				return _add(piece, p, yaw, 0.0, true)
	return -1


func _open_point() -> Vector2:
	for k in 40:
		var lo := Vector2(INF, INF)
		var hi := -lo
		for p in inner:
			lo = lo.min(p)
			hi = hi.max(p)
		var p := Vector2(_rng.randf_range(lo.x, hi.x), _rng.randf_range(lo.y, hi.y))
		if _fits(_rect(p, 0.0, 0.6, 0.6)):
			return p
	return Vector2.INF


## Adds a piece (checked against walls, the door and other pieces unless `skip_check`).
func _add(piece: StringName, pos: Vector2, yaw: float, y: float, skip_check := false) -> int:
	var size := piece_size(piece)
	var poly := _rect(pos, yaw, size.x, size.z)
	if not skip_check and not _fits(poly):
		return -1
	if y <= 0.0:
		_occupy(poly)
	items.append({
		"piece": piece,
		"object": String(PIECES[piece]["object"]),
		"pos": pos,
		"yaw": yaw,
		"y": y,
		"poly": poly,
		"solid": bool(PIECES[piece]["solid"]) and y <= 0.0,
	})
	return items.size() - 1


func _fits(poly: PackedVector2Array) -> bool:
	if inner.size() < 3:
		return false
	var box := _aabb(poly)
	if not _inner_box.encloses(box):
		return false
	for p in poly:
		if not Geometry2D.is_point_in_polygon(p, inner):
			return false
	# A wall corner poking into the piece (concave rooms).
	for p in inner:
		if box.has_point(p) and _inside_convex(p, poly, 0.01):
			return false
	box = box.grow(-0.01)
	for keep in _keep_outs:
		if box.intersects(_aabb(keep)) and _overlap(poly, keep):
			return false
	for k in _occupied.size():
		if box.intersects(_occupied_boxes[k]) and _overlap(poly, _occupied[k]):
			return false
	return true


func _occupy(poly: PackedVector2Array) -> void:
	_occupied.append(poly)
	_occupied_boxes.append(_aabb(poly))


static func _aabb(poly: PackedVector2Array) -> Rect2:
	var box := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	return box


## Separating-axis test for two convex polygons, with a small tolerance so
## pieces may touch.
static func _overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for poly: PackedVector2Array in [a, b]:
		for i in poly.size():
			var e := poly[(i + 1) % poly.size()] - poly[i]
			var n := Vector2(-e.y, e.x).normalized()
			var a_lo := INF
			var a_hi := -INF
			for p in a:
				a_lo = minf(a_lo, p.dot(n))
				a_hi = maxf(a_hi, p.dot(n))
			var b_lo := INF
			var b_hi := -INF
			for p in b:
				b_lo = minf(b_lo, p.dot(n))
				b_hi = maxf(b_hi, p.dot(n))
			if a_hi <= b_lo + 0.01 or b_hi <= a_lo + 0.01:
				return false
	return true


static func _inside_convex(p: Vector2, poly: PackedVector2Array, margin: float) -> bool:
	var sign := 0.0
	for i in poly.size():
		var a := poly[i]
		var e := poly[(i + 1) % poly.size()] - a
		var c := e.cross(p - a) / maxf(e.length(), 0.0001)
		if absf(c) < margin:
			return false
		if sign == 0.0:
			sign = signf(c)
		elif signf(c) != sign:
			return false
	return true


## Footprint of a piece: local X is `w` wide, local Z `d` deep, turned by `yaw`
## the way Node3D.rotation.y turns it.
static func _rect(c: Vector2, yaw: float, w: float, d: float) -> PackedVector2Array:
	var ex := Vector2(cos(yaw), -sin(yaw)) * w * 0.5
	var ez := Vector2(sin(yaw), cos(yaw)) * d * 0.5
	return PackedVector2Array([c - ex - ez, c + ex - ez, c + ex + ez, c - ex + ez])


func _centroid() -> Vector2:
	var c := Vector2.ZERO
	for p in inner:
		c += p
	return c / maxf(inner.size(), 1)


func _long_axis() -> Vector2:
	var best := Vector2.RIGHT
	var best_len := 0.0
	for i in inner.size():
		var e := inner[(i + 1) % inner.size()] - inner[i]
		if e.length() > best_len:
			best_len = e.length()
			best = e.normalized()
	return best

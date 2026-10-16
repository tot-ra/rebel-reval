extends RefCounted

## Places to sit in the seamless city (docs/SYSTEMS/SITTING.md), read from data that already
## exists: the sit slots of furnished households (`HouseholdLayout.slots`, the same places the
## residents use), the benches of the church naves (site manifest `benches`, one seat every
## SEAT_PITCH, facing the altar) and catalogue furniture with the `sit` action in site dressing
## (benches, stools, chairs). A seat is {pos: world xz of the seat's centre, facing: the way the
## sitter looks, h: seat height above the floor, two_sided: a bench without a back}. A seat with a
## resident on it is not offered.

const HouseholdLayoutScript := preload("res://scripts/city/household_layout.gd")
const SEAT_PITCH := 0.55
const BENCH_SEAT_Y := 0.45
## Church bench seat centre, bench-local x (x towards the altar).
const CHURCH_SEAT_X := -0.01
## A seat is taken when a seated body stands within this of the seat's sitting point.
const TAKEN_RADIUS := 0.3
## Seated bodies stand this far in front of the seat's centre (CitizenActor.SIT_BACK).
const SIT_BACK := 0.44

var plan: CityPlan
## CityInteriors (furnished homes and their layouts), or null.
var interiors: Node
## Callable() -> Array of world xz of seated bodies (their logic position, SIT_BACK in front of
## the seat); empty Callable = nobody.
var occupied_fn := Callable()

var _site_seats: Array[Dictionary] = []


static func create(city_plan: CityPlan, city_interiors: Node) -> RefCounted:
	var seats := new()
	seats.plan = city_plan
	seats.interiors = city_interiors
	if city_plan != null:
		seats._collect_sites()
	return seats


## Seats of landmark sites: church benches and catalogue seats in the dressing.
func _collect_sites() -> void:
	for site: CitySite in plan.sites:
		var frame_x := site.to_world(Vector2.RIGHT) - site.to_world(Vector2.ZERO)
		var frame_z := site.to_world(Vector2(0.0, 1.0)) - site.to_world(Vector2.ZERO)
		for bench: Dictionary in site.data.get("benches", []):
			var at := Vector2(bench["at"][0], bench["at"][1])
			var length := float(bench.get("len", 2.0))
			var n := maxi(1, floori(length / SEAT_PITCH))
			for k in n:
				var z := (
					at.y
					- length * 0.5
					+ SEAT_PITCH * (float(k) + 0.5)
					+ (length - SEAT_PITCH * n) * 0.5
				)
				add_seat(site.to_world(Vector2(at.x + CHURCH_SEAT_X, z)), frame_x, BENCH_SEAT_Y)
		for item: Dictionary in site.data.get("dressing", []):
			if String(item.get("kind", "")) != "catalog":
				continue
			var piece := _seat_piece(String(item.get("object", "")))
			if piece.is_empty():
				continue
			var local := Vector2(item["at"][0], item["at"][1])
			var r := deg_to_rad(float(item.get("rotation_deg", 0.0)))
			var along_local := Vector2.RIGHT.rotated(r)
			var along := frame_x * along_local.x + frame_z * along_local.y
			var front := Vector2(-along.y, along.x)
			var size := HouseholdLayoutScript.piece_size(StringName(piece["name"]))
			var n := maxi(1, floori(size.x / SEAT_PITCH)) if piece["name"] == &"bench" else 1
			for k in n:
				var off := (float(k) + 0.5) * size.x / float(n) - size.x * 0.5
				add_seat(
					site.to_world(local) + along * off,
					front * float(piece["front"]),
					float(piece["seat_h"]),
					piece["name"] == &"bench"
				)


func add_seat(pos: Vector2, facing: Vector2, h: float, two_sided := false) -> void:
	_site_seats.append({"pos": pos, "facing": facing.normalized(), "h": h, "two_sided": two_sided})


## {name, seat_h, front} of the household piece behind a catalogue object, or {} if one cannot
## sit on it.
static func _seat_piece(object_id: String) -> Dictionary:
	for name: StringName in HouseholdLayoutScript.PIECES:
		var p: Dictionary = HouseholdLayoutScript.PIECES[name]
		if String(p.get("object", "")) == object_id and p.has("seat_h"):
			return {"name": name, "seat_h": float(p["seat_h"]), "front": int(p.get("front", 1))}
	return {}


## Every seat within `reach` of `xz` (world), furnished homes first loaded.
func seats_near(xz: Vector2, reach: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r2 := reach * reach
	for s in _site_seats:
		if (s["pos"] as Vector2).distance_squared_to(xz) <= r2:
			out.append(s)
	if interiors != null and interiors.has_method("furnished_indices"):
		for index: int in interiors.call("furnished_indices"):
			var lay: Variant = interiors.call("layout", index)
			if lay == null:
				continue
			for slot: Dictionary in lay.slots_of(&"sit"):
				if (slot["pos"] as Vector2).distance_squared_to(xz) <= r2:
					(
						out
						. append(
							{
								"pos": slot["pos"],
								"facing": slot["facing"],
								"h": float(slot["h"]),
								"two_sided": false,
							}
						)
					)
	return out


## The nearest free seat within `reach` of `xz`, facing turned towards `xz` for a backless
## bench; {} if there is none.
func nearest_free(xz: Vector2, reach: float) -> Dictionary:
	var taken: Array = occupied_fn.call() if occupied_fn.is_valid() else []
	var best := {}
	var best_d := INF
	for s in seats_near(xz, reach):
		var p: Vector2 = s["pos"]
		var front: Vector2 = p + (s["facing"] as Vector2) * SIT_BACK
		var back: Vector2 = p - (s["facing"] as Vector2) * SIT_BACK
		var free := true
		for q: Vector2 in taken:
			if (
				q.distance_to(front) < TAKEN_RADIUS
				or (bool(s["two_sided"]) and q.distance_to(back) < TAKEN_RADIUS)
			):
				free = false
				break
		if not free:
			continue
		var d := p.distance_squared_to(xz)
		if d < best_d:
			best_d = d
			best = s.duplicate()
	if not best.is_empty() and bool(best["two_sided"]):
		var f: Vector2 = best["facing"]
		if f.dot(xz - (best["pos"] as Vector2)) < 0.0:
			best["facing"] = -f
	return best


func site_seat_count() -> int:
	return _site_seats.size()

class_name CitySite
extends RefCounted

## One landmark site of the seamless city (ADR 0032): its manifest
## (content/world/reval_city/sites/<name>.json) plus the compiled placement
## the plan carries (`plan.json` -> `sites[]`: anchor, terrace level, world
## footprints). Site-local coordinates are metres: +x along the anchor
## rotation, +z to its right (south when the rotation is 0), y up from the
## terrace level.

var id: StringName
var data: Dictionary
## Plan record: {at, rotation_deg, level, footprints, reserve}.
var placed: Dictionary
var origin := Vector2.ZERO
var level := 0.0
var rotation := 0.0
## Logic-plane data in world XZ, built once.
var floors: Array[Dictionary] = []  # {id, polygon: PackedVector2Array, height}
var rooms: Array[Dictionary] = []  # {id, name, polygon, floor, hide}
var walls: Array[Dictionary] = []  # {a, b, thickness}
var solids: Array[PackedVector2Array] = []
var doors: Array[Dictionary] = []  # {id, a, b, inward, floor, height, style, paint}
var people: Array[Dictionary] = []  # {id, role, rig, at, facing, pose}


static func from_manifest(manifest: Dictionary, plan_record: Dictionary) -> CitySite:
	var site := CitySite.new()
	site.id = StringName(manifest["id"])
	site.data = manifest
	site.placed = plan_record
	site.origin = Vector2(plan_record["at"][0], plan_record["at"][1])
	site.level = float(plan_record["level"])
	site.rotation = deg_to_rad(float(plan_record["rotation_deg"]))
	site._build_walk()
	return site


## Site-local metres (x, z) to world XZ.
func to_world(local: Vector2) -> Vector2:
	return origin + local.rotated(rotation)


func to_local(world_xz: Vector2) -> Vector2:
	return (world_xz - origin).rotated(-rotation)


func world_polygon(raw: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Array in raw:
		out.append(to_world(Vector2(p[0], p[1])))
	return out


## Transform of the site's local frame in the 3D view (y = terrace level).
func transform3d() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, -rotation), Vector3(origin.x, level, origin.y))


## True inside one of the site's building footprints (not its open reserve).
func occupies(world_xz: Vector2) -> bool:
	for poly: Array in placed.get("footprints", []):
		if Geometry2D.is_point_in_polygon(world_xz, CityPlan.points(poly)):
			return true
	return false


## Index of the site building footprint containing the point (-1 if none);
## the same index addresses `data.buildings`.
func building_index_at(world_xz: Vector2) -> int:
	var footprints: Array = placed.get("footprints", [])
	for k in footprints.size():
		if Geometry2D.is_point_in_polygon(world_xz, CityPlan.points(footprints[k])):
			return k
	return -1


func floor_at(world_xz: Vector2) -> Dictionary:
	for f in floors:
		if Geometry2D.is_point_in_polygon(world_xz, f["polygon"]):
			return f
	return {}


func room_at(world_xz: Vector2) -> Dictionary:
	for r in rooms:
		if Geometry2D.is_point_in_polygon(world_xz, r["polygon"]):
			return r
	return {}


## Axis-aligned world bounds of everything the site occupies (buildings,
## reserve); for spatial lookups.
func bounds() -> Rect2:
	var r := Rect2(origin, Vector2.ZERO)
	for poly: Array in placed.get("footprints", []):
		for p: Array in poly:
			r = r.expand(Vector2(p[0], p[1]))
	for p: Array in placed.get("reserve", []):
		r = r.expand(Vector2(p[0], p[1]))
	return r.grow(2.0)


func _build_walk() -> void:
	var walk: Dictionary = data.get("walk", {})
	for f: Dictionary in walk.get("floors", []):
		(
			floors
			. append(
				{
					"id": StringName(f["id"]),
					"polygon": world_polygon(f["polygon"]),
					"height": level + float(f.get("height", 0.0)),
				}
			)
		)
	for w: Dictionary in walk.get("walls", []):
		(
			walls
			. append(
				{
					"a": to_world(Vector2(w["from"][0], w["from"][1])),
					"b": to_world(Vector2(w["to"][0], w["to"][1])),
					"thickness": float(w.get("thickness", 0.6)),
				}
			)
		)
	# Walls described as model fabric give their own walk walls (door and arch
	# openings at floor level left open), so model and collision agree.
	for w: Dictionary in CitySiteKit.walk_walls(data.get("fabric", [])):
		(
			walls
			. append(
				{
					"a": to_world(w["a"]),
					"b": to_world(w["b"]),
					"thickness": float(w["thickness"]),
				}
			)
		)
	for poly: Array in walk.get("solid", []):
		solids.append(world_polygon(poly))
	for d: Dictionary in data.get("dressing", []):
		if d.has("solid"):
			solids.append(_rect(d))
	for r: Dictionary in data.get("rooms", []):
		(
			rooms
			. append(
				{
					"id": StringName(r["id"]),
					"name": String(r.get("name", "")),
					"polygon": world_polygon(r["polygon"]),
					"floor": StringName(r.get("floor", "")),
					"hide": r.get("hide", []),
				}
			)
		)
	for person: Dictionary in data.get("people", []):
		var facing := Vector2.from_angle(deg_to_rad(float(person.get("facing_deg", 0.0))))
		(
			people
			. append(
				{
					"id": StringName(person["id"]),
					"role": String(person.get("role", "")),
					"rig": String(person.get("rig", "crowd_townsman_01")),
					"at": to_world(Vector2(person["at"][0], person["at"][1])),
					"facing": facing.rotated(rotation),
					"pose": StringName(person.get("pose", "stand")),
					"seat_h": float(person.get("seat_h", 0.48)),
				}
			)
		)
	for d: Dictionary in data.get("doors", []):
		var inward_local := Vector2(d["inward"][0], d["inward"][1])
		(
			doors
			. append(
				{
					"id": StringName(d["id"]),
					"a": to_world(Vector2(d["a"][0], d["a"][1])),
					"b": to_world(Vector2(d["b"][0], d["b"][1])),
					"inward": inward_local.rotated(rotation),
					"floor": StringName(d.get("floor", "")),
					"height": float(d.get("height", CityBuildingBuilder.DOOR_HEIGHT)),
					"style": StringName(d.get("style", "plank")),
					"paint":
					(
						Color(d["paint"][0], d["paint"][1], d["paint"][2])
						if d.has("paint")
						else Color(0.5, 0.38, 0.26)
					),
					"inner": bool(d.get("inner", false)),
				}
			)
		)


## Footprint rectangle of a dressing item with a `solid` [w, d] size.
func _rect(item: Dictionary) -> PackedVector2Array:
	var c := Vector2(item["at"][0], item["at"][1])
	var r := deg_to_rad(float(item.get("rotation_deg", 0.0)))
	var h := Vector2(item["solid"][0], item["solid"][1]) * 0.5
	var out := PackedVector2Array()
	for corner: Vector2 in [
		Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)
	]:
		out.append(to_world(c + corner.rotated(r)))
	return out

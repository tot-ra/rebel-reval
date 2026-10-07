extends SceneTree

## Validates the seamless city's landmark sites (ADR 0032):
##   godot --headless --path . --script tools/validate_city_sites.gd
## Errors (exit 1):
## - a registered site has no compiled placement, or a replaced building is
##   still in the plan;
## - a site building overlaps a generic plan building by more than 1 m²;
## - a door's outside point is blocked, or its inside point is not on the
##   door's floor;
## - an authored wall crosses a door gap;
## - a floor no door (or ramp) reaches;
## - a room `hide` path that does not resolve in the site's visual;
## - the visual's walls and the authored walls disagree by more than
##   WALL_TOLERANCE in plan extent (AABB comparison of the "Walls" mesh).

const WALL_TOLERANCE := 0.25
## Door probe distance: past the thickest wall (church towers ~1.3 m).
const PROBE := 1.6
## Narrowest door or arch Kalev can pass reliably (capsule diameter 1.0 m).
const MIN_PASSAGE := 1.4

var _errors: Array[String] = []


func _initialize() -> void:
	var plan := CityPlan.load_default()
	var registry: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://content/world/reval_city/sites/registry.json")
	)
	if plan.sites.size() != (registry["sites"] as Array).size():
		_errors.append(
			"registry lists %d sites, %d loaded" % [registry["sites"].size(), plan.sites.size()]
		)
	var ids := {}
	for b: Dictionary in plan.buildings:
		ids[String(b["id"])] = true
	for site in plan.sites:
		_check_site(site, plan, ids)
	for e in _errors:
		push_error(e)
	print(
		(
			"CITY SITES: %s (%d sites)"
			% ["PASS" if _errors.is_empty() else "FAIL (%d)" % _errors.size(), plan.sites.size()]
		)
	)
	quit(0 if _errors.is_empty() else 1)


func _check_site(site: CitySite, plan: CityPlan, ids: Dictionary) -> void:
	var label := String(site.id)
	for rid: String in site.data.get("replaces", []):
		if ids.has(rid):
			_errors.append("%s: replaced building %s is still in the plan" % [label, rid])
	# Overlap with generic buildings.
	for poly: Array in site.placed.get("footprints", []):
		var ring := CityPlan.points(poly)
		for i in plan.buildings.size():
			var other := plan.footprint(i)
			for piece in Geometry2D.intersect_polygons(ring, other):
				var area := absf(CityBuildingBuilder.signed_area(piece))
				if area > 1.0:
					_errors.append(
						(
							"%s: overlaps %s by %.1f m² (add it to `replaces`)"
							% [label, plan.buildings[i]["id"], area]
						)
					)
	var blockers: Array[PackedVector2Array] = site.solids.duplicate()
	for w: Dictionary in site.walls:
		blockers.append(_wall_box(w))
	var reached := {}
	for d: Dictionary in site.doors:
		var mid: Vector2 = (d["a"] + d["b"]) * 0.5
		var inward: Vector2 = d["inward"]
		var outside := mid - inward * PROBE
		var inside := mid + inward * PROBE
		for poly in blockers:
			if Geometry2D.is_point_in_polygon(outside, poly):
				_errors.append("%s: door %s is blocked outside" % [label, d["id"]])
			if Geometry2D.is_point_in_polygon(inside, poly):
				_errors.append("%s: door %s is blocked inside" % [label, d["id"]])
		# Behind the door is a floor (its own, or a passage through a thick wall
		# that touches it).
		var on_floor := false
		for f: Dictionary in site.floors:
			if Geometry2D.is_point_in_polygon(inside, f["polygon"]):
				on_floor = true
				reached[f["id"]] = true
		if not on_floor:
			_errors.append("%s: door %s does not lead onto %s" % [label, d["id"], d["floor"]])
		for w: Dictionary in site.walls:
			var hit: Variant = Geometry2D.segment_intersects_segment(
				d["a"] + (d["b"] - d["a"]) * 0.05, d["b"] - (d["b"] - d["a"]) * 0.05, w["a"], w["b"]
			)
			if hit != null:
				_errors.append("%s: a wall crosses door %s" % [label, d["id"]])
	# People stand on a floor; standing people must not be inside a solid.
	for person: Dictionary in site.people:
		var at: Vector2 = person["at"]
		# Indoors people stand on a floor; outdoors (a yard) on open ground.
		if site.floor_at(at).is_empty() and site.occupies(at):
			_errors.append("%s: %s is not on a floor" % [label, person["id"]])
		if person["pose"] != &"sit":
			for poly in blockers:
				if Geometry2D.is_point_in_polygon(at, poly):
					_errors.append("%s: %s stands inside a solid" % [label, person["id"]])
		if not ResourceLoader.exists(CitySiteActor.VARIANTS_DIR % person["rig"]):
			_errors.append("%s: %s has no rig %s" % [label, person["id"], person["rig"]])
	for r: Dictionary in site.data.get("walk", {}).get("ramps", []):
		reached[StringName(r.get("to_floor", ""))] = true
	# Floors that touch a reached floor (steps, a raised choir) are reachable.
	var grew := true
	while grew:
		grew = false
		for f: Dictionary in site.floors:
			if reached.has(f["id"]):
				continue
			var grown := Geometry2D.offset_polygon(f["polygon"], 0.3)
			for g: Dictionary in site.floors:
				if not reached.has(g["id"]) or grown.is_empty():
					continue
				if not Geometry2D.intersect_polygons(grown[0], g["polygon"]).is_empty():
					reached[f["id"]] = true
					grew = true
					break
	for f: Dictionary in site.floors:
		if not reached.has(f["id"]):
			_errors.append("%s: floor %s is unreachable" % [label, f["id"]])
	# Walk-through openings must fit Kalev's capsule with room to spare.
	for w: Dictionary in site.data.get("fabric", []):
		for op: Dictionary in w.get("openings", []):
			if String(op.get("kind", "")) in ["door", "arch"] and float(op["w"]) < MIN_PASSAGE:
				_errors.append(
					(
						"%s: %s opening at s=%.1f is %.2f m wide (< %.2f m)"
						% [label, w["id"], float(op["s"]), float(op["w"]), MIN_PASSAGE]
					)
				)
	_check_rooms(site, label)
	_check_visual(site, plan, label)


## Every room is reachable from the street: rooms are linked through doors
## and through fabric openings at floor level (arches, inner doors).
func _check_rooms(site: CitySite, label: String) -> void:
	var links: Dictionary = {}  # room id -> {room id: true}
	var room_at := func(p: Vector2) -> StringName:
		var r := site.room_at(p)
		return r["id"] if not r.is_empty() else &"outside"
	var link := func(a: StringName, b: StringName) -> void:
		if a == b:
			return
		if not links.has(a):
			links[a] = {}
		if not links.has(b):
			links[b] = {}
		links[a][b] = true
		links[b][a] = true
	for d: Dictionary in site.doors:
		var mid: Vector2 = (d["a"] + d["b"]) * 0.5
		link.call(room_at.call(mid - d["inward"] * PROBE), room_at.call(mid + d["inward"] * PROBE))
	for w: Dictionary in site.data.get("fabric", []):
		var a := site.to_world(CitySiteKit._v2(w["a"]))
		var b := site.to_world(CitySiteKit._v2(w["b"]))
		var dir := (b - a).normalized()
		var n := Vector2(-dir.y, dir.x)
		var reach := float(w["thick"]) + 0.8
		for op: Dictionary in w.get("openings", []):
			if not String(op.get("kind", "")) in ["arch", "door"]:
				continue
			var mid := a + dir * float(op["s"])
			link.call(room_at.call(mid + n * reach), room_at.call(mid - n * reach))
	var seen := {&"outside": true}
	var queue: Array = [&"outside"]
	while not queue.is_empty():
		var at: StringName = queue.pop_back()
		for nxt: StringName in links.get(at, {}):
			if not seen.has(nxt):
				seen[nxt] = true
				queue.append(nxt)
	for r: Dictionary in site.rooms:
		if not seen.has(r["id"]):
			_errors.append("%s: room %s cannot be reached from the street" % [label, r["id"]])


func _check_visual(site: CitySite, plan: CityPlan, label: String) -> void:
	var visual: Dictionary = site.data.get("visual", {})
	var node: Node3D
	if String(visual.get("kind", "")) == "builder":
		var script := load(String(visual["script"])) as Script
		if script == null or not script.can_instantiate():
			_errors.append("%s: builder script does not compile" % label)
			return
		node = script.call("build", site, plan)
	elif String(visual.get("kind", "")) == "scene":
		node = (load(String(visual["path"])) as PackedScene).instantiate()
	if node == null:
		_errors.append("%s: visual did not build" % label)
		return
	for r: Dictionary in site.rooms:
		for path: String in r["hide"]:
			if node.get_node_or_null(path) == null:
				_errors.append("%s: room %s hides missing node %s" % [label, r["id"], path])
	# Plan extent of the visual walls (site-local) against the authored walls.
	var walls_mesh: Array = node.find_children("Walls", "MeshInstance3D", true, false)
	if walls_mesh.is_empty() or site.walls.is_empty():
		node.free()
		return
	var mesh_node := walls_mesh[0] as MeshInstance3D
	var xf := _local_transform(mesh_node, node)
	var box := xf * mesh_node.mesh.get_aabb()
	var authored := Rect2(site.to_local(site.walls[0]["a"]), Vector2.ZERO)
	for w: Dictionary in site.walls:
		authored = authored.expand(site.to_local(w["a"])).expand(site.to_local(w["b"]))
	var visual_rect := Rect2(
		Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z)
	)
	var dev := maxf(
		(visual_rect.position - authored.position).abs().length(),
		(visual_rect.end - authored.end).abs().length()
	)
	print("%s: visual walls vs authored walls deviate %.2f m" % [label, dev])
	if dev > WALL_TOLERANCE:
		_errors.append(
			(
				"%s: visual walls %s and authored walls %s differ by %.2f m"
				% [label, visual_rect, authored, dev]
			)
		)
	node.free()


static func _local_transform(n: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


static func _wall_box(w: Dictionary) -> PackedVector2Array:
	var a: Vector2 = w["a"]
	var b: Vector2 = w["b"]
	var dir := (b - a).normalized()
	var n := Vector2(-dir.y, dir.x) * float(w["thickness"])
	return PackedVector2Array([a + n, b + n, b - n, a - n])

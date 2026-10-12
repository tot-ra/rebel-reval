extends "res://tests/godot/test_case.gd"

## St Michael's Cistercian nunnery (R-1719): the walled close as an ADR 0032
## site. Registered, replaces the generic church shell and the houses inside
## the close, entered from the street only through the gate house, the lay
## nave reachable from the south portal, orchard rows and garden beds inside.

const SITE := &"site.st_michael"
## Flood-fill cell for the walking checks (walls are 0.75-1.4 m thick).
const CELL := 0.5


func _plan() -> CityPlan:
	return CityPlan.load_default()


func _site(plan: CityPlan) -> CitySite:
	for site in plan.sites:
		if site.id == SITE:
			return site
	return null


func _close(site: CitySite) -> PackedVector2Array:
	return site.world_polygon(site.data["close"]["polygon"])


func test_site_is_registered_and_replaces_the_generic_church() -> void:
	var plan := _plan()
	var site := _site(plan)
	assert_true(site != null, "site.st_michael loads from the registry")
	assert_true(site.level > 15.0, "terrace level comes from the compiled plan")
	var ids := {}
	for b: Dictionary in plan.buildings:
		ids[String(b["id"])] = true
		assert_ne(
			String(b.get("landmark_id", "")), "landmark.st_michael", "no generic church shell left"
		)
	for rid: String in site.data["replaces"]:
		assert_false(ids.has(rid), "%s is replaced" % rid)


func test_no_plan_house_stands_inside_the_close() -> void:
	var plan := _plan()
	var close := _close(_site(plan))
	for i in plan.buildings.size():
		for piece in Geometry2D.intersect_polygons(close, plan.footprint(i)):
			assert_true(
				absf(CityBuildingBuilder.signed_area(piece)) < 1.0,
				"%s stands inside the nunnery close" % plan.buildings[i]["id"]
			)


func test_the_gate_house_is_the_only_way_into_the_close() -> void:
	var plan := _plan()
	var site := _site(plan)
	var gates: Array = site.data["close"]["gates"]
	assert_eq(gates.size(), 1, "one controlled gate")
	var gate_door := _door(site, StringName(gates[0]["door"]))
	assert_false(gate_door.is_empty(), "the gate names a site door")
	var street := site.to_world(Vector2(14.0, 25.0))
	var garden := site.to_world(Vector2(-20.0, -10.0))
	var orchard := site.to_world(Vector2(30.0, -42.0))
	assert_false(Geometry2D.is_point_in_polygon(street, _close(site)), "the square is outside")
	var reach := _reachable(site, street, [])
	assert_true(reach.call(garden), "the garden is reached through the gate house")
	assert_true(reach.call(orchard), "the orchard is reached through the gate house")
	# Shut the gate: nothing inside the close can be reached from the street.
	var a: Vector2 = gate_door["a"]
	var b: Vector2 = gate_door["b"]
	var n: Vector2 = gate_door["inward"]
	var shut := PackedVector2Array([a - n * 1.0, b - n * 1.0, b + n * 1.0, a + n * 1.0])
	var sealed := _reachable(site, street, [shut])
	assert_false(sealed.call(garden), "no other way into the garden")
	assert_false(sealed.call(orchard), "no other way into the orchard")


func test_lay_people_reach_the_nave_from_the_south_portal() -> void:
	var plan := _plan()
	var site := _site(plan)
	var door := _door(site, &"door.st_michael.south")
	var mid: Vector2 = (door["a"] + door["b"]) * 0.5
	var inside: Vector2 = mid + (door["inward"] as Vector2) * 2.0
	assert_eq(plan.site_room_at(inside)["room"]["id"], &"room.nave")
	assert_eq(plan.location_at(inside)["building"], "Inside: St Michael's (nave)")
	assert_almost_eq(plan.walk_height(inside), site.level + 0.12, 0.001)
	# The census still gathers the nunnery household at its church door
	# (citizens.json place); it stands on the open square in front of it.
	var census_door := Vector2(-105.39, -259.16)
	assert_true(census_door.distance_to(mid) < 4.0, "census door place is at the south portal")
	var reach := _reachable(site, site.to_world(Vector2(14.0, 25.0)), [])
	assert_true(reach.call(census_door), "the census door place is on open ground")
	assert_true(reach.call(inside), "the nave is reached through the portal")
	var porta := site.to_world(Vector2(-3.5, 21.0))
	assert_eq(plan.site_room_at(porta)["room"]["id"], &"room.porta")


func test_orchard_rows_and_garden_beds_fill_the_close() -> void:
	var plan := _plan()
	var site := _site(plan)
	var close := _close(site)
	var fruit := {&"apple": true, &"cherry": true, &"plum": true, &"pear": true}
	var orchards := 0
	for o: Dictionary in plan.data["orchards"]:
		if not String(o["id"]).begins_with("orchard.st_michael."):
			continue
		orchards += 1
		assert_false(bool(o["fence"]), "%s is walled by the close, not fenced" % o["id"])
		assert_true(int(o["trees"]) >= 8, "%s holds a few rows of trees" % o["id"])
	assert_eq(orchards, 2)
	for t: Array in plan.data["trees"]:
		if Geometry2D.is_point_in_polygon(Vector2(t[0], t[1]), close):
			assert_true(fruit.has(StringName(t[2])), "only fruit trees in the close, not %s" % t[2])
	var node: Node3D = (load(String(site.data["visual"]["script"])) as Script).call(
		"build", site, plan
	)
	for path: String in [
		"Church/Lower", "Church/Upper", "Church/Roof", "Porta/Lower", "Porta/Roof",
		"Claustrum", "Service", "CloseWall", "Gardens"
	]:
		assert_true(node.get_node_or_null(path) != null, "%s exists" % path)
	assert_eq(
		node.get_node("Gardens").get_child_count(),
		(site.data["garden_beds"] as Array).size(),
		"one patch per manifest bed group"
	)
	assert_eq((node.get_meta(&"chimneys", []) as Array).size(), 2, "kitchen and brewhouse smoke")
	assert_eq(int(CitySiteKit.GLAZING.get(SITE, -1)), 4, "grisaille glazing programme")
	node.free()


func _door(site: CitySite, id: StringName) -> Dictionary:
	for d: Dictionary in site.doors:
		if d["id"] == id:
			return d
	return {}


## Flood fill over CELL squares round the close from `start`, blocked by the
## site's logic-plane walls (both faces, as the validator draws them), its
## solids and `extra` polygons. Returns a callable: world point -> reached.
func _reachable(site: CitySite, start: Vector2, extra: Array) -> Callable:
	var blockers: Array[PackedVector2Array] = site.solids.duplicate()
	for w: Dictionary in site.walls:
		var a: Vector2 = w["a"]
		var b: Vector2 = w["b"]
		var n := (b - a).normalized().orthogonal() * float(w["thickness"])
		blockers.append(PackedVector2Array([a + n, b + n, b - n, a - n]))
	for poly: PackedVector2Array in extra:
		blockers.append(poly)
	var box := Rect2(_close(site)[0], Vector2.ZERO)
	for p in _close(site):
		box = box.expand(p)
	box = box.grow(12.0)
	var cols := int(box.size.x / CELL) + 1
	var rows := int(box.size.y / CELL) + 1
	var cell_of := func(p: Vector2) -> Vector2i:
		return Vector2i(int((p.x - box.position.x) / CELL), int((p.y - box.position.y) / CELL))
	var blocked := PackedByteArray()
	blocked.resize(cols * rows)
	for poly in blockers:
		var r := Rect2(poly[0], Vector2.ZERO)
		for p in poly:
			r = r.expand(p)
		var c0: Vector2i = cell_of.call(r.position)
		var c1: Vector2i = cell_of.call(r.end)
		for y in range(maxi(c0.y, 0), mini(c1.y + 1, rows)):
			for x in range(maxi(c0.x, 0), mini(c1.x + 1, cols)):
				var centre := box.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * CELL
				if Geometry2D.is_point_in_polygon(centre, poly):
					blocked[y * cols + x] = 1
	var seen := PackedByteArray()
	seen.resize(cols * rows)
	var first: Vector2i = cell_of.call(start)
	var queue: Array[Vector2i] = [first]
	seen[first.y * cols + first.x] = 1
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q := c + d
			if q.x < 0 or q.y < 0 or q.x >= cols or q.y >= rows:
				continue
			var k := q.y * cols + q.x
			if seen[k] == 0 and blocked[k] == 0:
				seen[k] = 1
				queue.append(q)
	return func(p: Vector2) -> bool:
		var c: Vector2i = cell_of.call(p)
		if c.x < 0 or c.y < 0 or c.x >= cols or c.y >= rows:
			return false
		# A point on the edge of a wall box counts if a neighbouring cell is open.
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var q := c + Vector2i(dx, dy)
				if q.x >= 0 and q.y >= 0 and q.x < cols and q.y < rows and seen[q.y * cols + q.x] == 1:
					return true
		return false

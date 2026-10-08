class_name CityCollisionBuilder
extends RefCounted

## Logic-plane collision for the continuous city (ADR 0031). Shapes are built
## from the same plan the view uses, in logic pixels (32 per world unit):
## - enterable houses: one thin quad per wall with a gap at the door, so the
##   inside is walkable and matches the visible interior;
## - other buildings: a solid footprint polygon;
## - curtains, gate jambs, towers, the Toompea wall and the castle ring;
## - the klint and other slopes steeper than MAX_WALK_SLOPE (sea and moat stay open:
##   Kalev swims, ADR 0021).

const Fort := preload("res://scripts/city/city_fortification_builder.gd")
const PX := CityPlan.LOGIC_PX_PER_UNIT
const MAX_WALK_SLOPE_DEG := 38.0
const BODY_CHUNK := 128.0


static func build(plan: CityPlan, parent: Node) -> Node2D:
	var root := Node2D.new()
	root.name = "CityCollision"
	parent.add_child(root)
	var bodies: Dictionary = {}
	var add_poly := func(points: PackedVector2Array) -> void:
		if points.size() < 3:
			return
		var c := Vector2.ZERO
		for p in points:
			c += p
		c /= points.size()
		var key := Vector2i(floori(c.x / BODY_CHUNK), floori(c.y / BODY_CHUNK))
		if not bodies.has(key):
			var body := StaticBody2D.new()
			body.name = "Body_%d_%d" % [key.x, key.y]
			body.collision_layer = CollisionLayers.WORLD
			body.collision_mask = 0
			root.add_child(body)
			bodies[key] = body
		var shape := CollisionPolygon2D.new()
		var scaled := PackedVector2Array()
		for p in points:
			scaled.append(p * PX)
		shape.polygon = scaled
		(bodies[key] as StaticBody2D).add_child(shape)
	_buildings(plan, add_poly)
	_sites(plan, add_poly)
	_fortifications(plan, add_poly)
	_terrain_blocks(plan, add_poly)
	_bounds(plan, add_poly)
	return root


static func _buildings(plan: CityPlan, add_poly: Callable) -> void:
	for i in plan.buildings.size():
		var b: Dictionary = plan.buildings[i]
		var ring := CityBuildingBuilder.normalized_ring(plan.footprint(i))
		if ring.size() < 3:
			continue
		if not bool(b.get("enterable", false)):
			# Concave footprints are fine for CollisionPolygon2D (decomposed).
			add_poly.call(ring)
			continue
		# Same filleted outline the walls and door leaves are built on.
		ring = CityBuildingBuilder.wall_ring(b, plan.footprint(i))
		var thick := (
			CityBuildingBuilder.STONE_WALL
			if String(b["material"]) == "limestone"
			else CityBuildingBuilder.TIMBER_WALL
		)
		var door: Array = b["door"]
		var door_p := Vector2(door[0], door[1])
		var door_edge := CityBuildingBuilder._closest_edge(ring, door_p)
		for e in ring.size():
			var a := ring[e]
			var c := ring[(e + 1) % ring.size()]
			if e == door_edge:
				var length := a.distance_to(c)
				var t := clampf(
					(door_p - a).dot(c - a) / maxf((c - a).length_squared(), 0.001), 0.2, 0.8
				)
				var hg := (
					minf(CityBuildingBuilder.DOOR_WIDTH * 0.5, length * 0.35) / maxf(length, 0.01)
				)
				add_poly.call(_wall_quad(ring, a, a.lerp(c, t - hg), thick))
				add_poly.call(_wall_quad(ring, a.lerp(c, t + hg), c, thick))
			else:
				add_poly.call(_wall_quad(ring, a, c, thick))


## Quad along the edge a-c extending `thick` into the footprint (plus a little
## overlap outward and along so corners seal).
## Landmark sites (ADR 0032): authored wall segments (outer face line, the
## thickness going into the building), solids, and dressing with a footprint.
## Door gaps are simply where no wall segment is authored.
static func _sites(plan: CityPlan, add_poly: Callable) -> void:
	for site in plan.sites:
		var inner: Array[PackedVector2Array] = []
		for f: Dictionary in site.floors:
			inner.append(f["polygon"])
		for w: Dictionary in site.walls:
			var a: Vector2 = w["a"]
			var b: Vector2 = w["b"]
			var t := float(w["thickness"])
			var dir := (b - a).normalized()
			var n := Vector2(-dir.y, dir.x)
			var probe := (a + b) * 0.5 + n * (t + 0.3)
			var inward := false
			for poly in inner:
				inward = inward or Geometry2D.is_point_in_polygon(probe, poly)
			if not inward:
				n = -n
			var a2 := a - dir * 0.05
			var b2 := b + dir * 0.05
			add_poly.call(
				PackedVector2Array([a2 - n * 0.06, b2 - n * 0.06, b2 + n * t, a2 + n * t])
			)
		for poly in site.solids:
			add_poly.call(poly)


static func _wall_quad(
	ring: PackedVector2Array, a: Vector2, c: Vector2, thick: float
) -> PackedVector2Array:
	var dir := (c - a).normalized()
	var n := Vector2(-dir.y, dir.x)
	var mid := (a + c) * 0.5
	if not Geometry2D.is_point_in_polygon(mid + n * 0.05, ring):
		n = -n
	var a2 := a - dir * 0.08
	var c2 := c + dir * 0.08
	return PackedVector2Array([a2 - n * 0.06, c2 - n * 0.06, c2 + n * thick, a2 + n * thick])


static func _segment_box(a: Vector2, b: Vector2, thickness: float) -> PackedVector2Array:
	var dir := (b - a).normalized()
	var side := Vector2(-dir.y, dir.x) * thickness * 0.5
	return PackedVector2Array([a + side, b + side, b - side, a - side])


static func _obox(
	center: Vector2, dir: Vector2, half_len: float, half_wid: float
) -> PackedVector2Array:
	var side := Vector2(-dir.y, dir.x)
	return PackedVector2Array(
		[
			center - dir * half_len - side * half_wid,
			center + dir * half_len - side * half_wid,
			center + dir * half_len + side * half_wid,
			center - dir * half_len + side * half_wid,
		]
	)


static func _fortifications(plan: CityPlan, add_poly: Callable) -> void:
	var gate_by_id := {}
	for g: Dictionary in plan.data["gates"]:
		gate_by_id[g["id"]] = g
	var circuit: Array = plan.data["circuit"]
	var curtains: Array = plan.data["curtains"]
	for i in curtains.size():
		var c: Dictionary = curtains[i]
		var a := Vector2(c["from"][0], c["from"][1])
		var b := Vector2(c["to"][0], c["to"][1])
		var dir := (b - a).normalized()
		var ra := String(circuit[i]["ref"])
		var rb := String(circuit[(i + 1) % circuit.size()]["ref"])
		var p0 := Fort.gate_joint(gate_by_id[ra], dir) if gate_by_id.has(ra) else a
		var p1 := Fort.gate_joint(gate_by_id[rb], -dir) if gate_by_id.has(rb) else b
		if (p1 - p0).dot(dir) <= 0.5:
			continue
		dir = (p1 - p0).normalized()
		# Long segments become several boxes so each sits in its own body chunk.
		var length := p0.distance_to(p1)
		var pieces := maxi(1, int(ceil(length / 40.0)))
		for k in pieces:
			var u := p0.lerp(p1, float(k) / pieces) - dir * 0.3
			var v := p0.lerp(p1, float(k + 1) / pieces) + dir * 0.3
			add_poly.call(_segment_box(u, v, maxf(float(c["thickness"]), 0.8)))
	var all_gates: Array = plan.data["gates"].duplicate()
	for bb: Dictionary in plan.data.get("barbicans", []):
		all_gates.append(bb["outer_gate"])
		for w: Dictionary in bb["walls"]:
			add_poly.call(
				_segment_box(
					Vector2(w["from"][0], w["from"][1]),
					Vector2(w["to"][0], w["to"][1]),
					maxf(float(w["thickness"]), 0.8)
				)
			)
	for g: Dictionary in all_gates:
		var at := Vector2(g["at"][0], g["at"][1])
		var along := Vector2(cos(float(g["angle"])), sin(float(g["angle"])))
		var opening := float(g["opening"])
		var wooden := String(g["state"]) == "wooden"
		var jamb := 0.6 if wooden else 2.4
		var depth := 1.6 if wooden else 1.72 * Fort.GATE_DEPTH_FACTOR
		for s: float in [-1.0, 1.0]:
			add_poly.call(
				_obox(
					at + along * s * (opening * 0.5 + jamb * 0.5),
					along,
					jamb * 0.5 + 0.05,
					depth * 0.5
				)
			)
	for t: Dictionary in plan.data["towers"]:
		if String(t["form"]) == "gate_rect":
			continue
		var at := Vector2(t["at"][0], t["at"][1])
		var along := Vector2(cos(float(t["angle"])), sin(float(t["angle"])))
		var c := Fort._toward_field(plan, at, along, float(t["d"]) * 0.35)
		add_poly.call(_obox(c, along, float(t["w"]) * 0.5, float(t["d"]) * 0.5))
	var openings := {}
	for o: Dictionary in plan.data.get("toompea_openings", []):
		openings[o["wall_id"]] = o
	for w: Dictionary in plan.data.get("toompea_walls", []):
		var a := Vector2(w["from"][0], w["from"][1])
		var b := Vector2(w["to"][0], w["to"][1])
		var thick := float(w["thickness"])
		if openings.has(w["id"]):
			var o: Dictionary = openings[w["id"]]
			var at := Vector2(o["at"][0], o["at"][1])
			var half := float(o["width"]) * 0.5
			var dir := (b - a).normalized()
			if a.distance_to(at) > half + 0.5:
				add_poly.call(_segment_box(a, at - dir * half, thick))
			if b.distance_to(at) > half + 0.5:
				add_poly.call(_segment_box(at + dir * half, b, thick))
		else:
			add_poly.call(_segment_box(a, b, thick))
	var castle: Dictionary = plan.data.get("castle", {})
	if not castle.is_empty():
		var ring := CityPlan.points(castle["ring"])
		for i in ring.size():
			add_poly.call(_segment_box(ring[i], ring[(i + 1) % ring.size()], 2.0))


## Height-grid cells that are too steep or too deep, merged into rectangles
## (row runs, then equal runs stacked vertically).
static func _terrain_blocks(plan: CityPlan, add_poly: Callable) -> void:
	var size := plan.height_grid_size()
	var cell := plan.height_cell()
	var origin := plan.height_origin()
	var max_rise := tan(deg_to_rad(MAX_WALK_SLOPE_DEG)) * cell
	var open_runs: Dictionary = {}  # Vector2i(x0, x1) -> start row
	var emit := func(x0: int, x1: int, y0: int, y1: int) -> void:
		var p0 := origin + Vector2(x0, y0) * cell
		var p1 := origin + Vector2(x1, y1) * cell
		add_poly.call(PackedVector2Array([p0, Vector2(p1.x, p0.y), p1, Vector2(p0.x, p1.y)]))
	for y in size.y - 1:
		var runs: Dictionary = {}
		var x := 0
		while x < size.x - 1:
			if _blocked(plan, x, y, max_rise):
				var start := x
				while x < size.x - 1 and _blocked(plan, x, y, max_rise):
					x += 1
				runs[Vector2i(start, x)] = true
			else:
				x += 1
		for run: Vector2i in open_runs.keys():
			if not runs.has(run):
				emit.call(run.x, run.y, int(open_runs[run]), y)
				open_runs.erase(run)
		for run: Vector2i in runs:
			if not open_runs.has(run):
				open_runs[run] = y
	for run: Vector2i in open_runs:
		emit.call(run.x, run.y, int(open_runs[run]), size.y - 1)


static func _blocked(plan: CityPlan, x: int, y: int, max_rise: float) -> bool:
	var h00 := plan.grid_height(x, y)
	var h10 := plan.grid_height(x + 1, y)
	var h01 := plan.grid_height(x, y + 1)
	var h11 := plan.grid_height(x + 1, y + 1)
	return (
		absf(h10 - h00) > max_rise
		or absf(h01 - h00) > max_rise
		or absf(h11 - h10) > max_rise
		or absf(h11 - h01) > max_rise
	)


static func _bounds(plan: CityPlan, add_poly: Callable) -> void:
	var r := plan.bounds.grow(-2.0)
	var t := 4.0
	add_poly.call(
		PackedVector2Array(
			[
				r.position - Vector2(t, t),
				Vector2(r.end.x + t, r.position.y - t),
				Vector2(r.end.x + t, r.position.y),
				Vector2(r.position.x - t, r.position.y)
			]
		)
	)
	add_poly.call(
		PackedVector2Array(
			[
				Vector2(r.position.x - t, r.end.y),
				Vector2(r.end.x + t, r.end.y),
				r.end + Vector2(t, t),
				Vector2(r.position.x - t, r.end.y + t)
			]
		)
	)
	add_poly.call(
		PackedVector2Array(
			[
				Vector2(r.position.x - t, r.position.y),
				r.position,
				Vector2(r.position.x, r.end.y),
				Vector2(r.position.x - t, r.end.y)
			]
		)
	)
	add_poly.call(
		PackedVector2Array(
			[
				Vector2(r.end.x, r.position.y),
				Vector2(r.end.x + t, r.position.y),
				Vector2(r.end.x + t, r.end.y),
				r.end
			]
		)
	)

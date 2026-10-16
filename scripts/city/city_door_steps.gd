class_name CityDoorSteps
extends RefCounted

## R-2197: the stair from the street up to a plan building's door
## (docs/SYSTEMS/SEAMLESS_CITY.md, "How buildings are built"). One deterministic
## layout feeds three consumers, so what Kalev sees is what he climbs:
## - CityBuildingBuilder draws it (`build`);
## - CityPlan.walk_height stands actors on its treads (`height_at`);
## - CityCollisionBuilder blocks its rails and parapets (`layout["rails"]`).
##
## Before this every door had the same straight block flight, mesh only:
## actors walked through it at terrain height. Kinds now follow the rise and
## the house: a single threshold stone, a straight or splayed limestone flight,
## timber steps on stringers for log and plank houses, and for tall rises a
## flight along the wall from a landing at the door, with a low parapet (stone)
## or a rail (timber) on the open side.

enum Kind { NONE, SLAB, STRAIGHT, SPLAYED, TIMBER, SIDE }

const RuralPlan := preload("res://scripts/city/rural_dwelling_plan.gd")

const KIND_NAMES := {
	Kind.NONE: &"none",
	Kind.SLAB: &"slab",
	Kind.STRAIGHT: &"straight",
	Kind.SPLAYED: &"splayed",
	Kind.TIMBER: &"timber",
	Kind.SIDE: &"side",
}
## Below this rise the door needs no step.
const MIN_RISE := 0.12
const RISER := 0.18
## Up to 14 treads keeps the riser near RISER even on the few doors that still
## face a steep drop.
const MAX_TREADS := 14
const TREAD_MIN := 0.3
const TREAD_MAX := 0.36
## Above this rise a flight along the wall is used when it fits: a straight
## flight would run 2-4.5 m out into the street, and a landing at the door is
## how tall medieval entrances were reached.
const SIDE_MIN_RISE := 1.0
const LANDING_DEPTH := 1.15
## Step margin beyond each door jamb.
const SIDE_MARGIN := 0.22
## Each lower tread of a splayed flight is this much wider on each side.
const SPLAY := 0.1
const PARAPET_H := 0.55
const PARAPET_T := 0.22
const RAIL_H := 0.9
const RAIL_T := 0.08
## Logic collision thickness of a rail or parapet line.
const RAIL_COLLISION_T := 0.22
const PLANK_T := 0.06
const STRINGER_H := 0.22
const FOOT_SINK := 0.3
const WOOD_FAMILIES := [&"log", &"plank"]
const STONE_TOP := Color(0.9, 0.88, 0.84)
const STONE_SIDE := Color(0.82, 0.8, 0.76)
const WOOD := Color(0.6, 0.5, 0.4)


## Layout for a plan building, or {} when it has no door. `free` (Vector2 ->
## bool) says whether a point is open ground (no other building or site); the
## builder passes none and gets the same layout as long as the walls are clear.
static func for_building(
	b: Dictionary,
	ring_in: PackedVector2Array,
	floor_y: float,
	ground_at: Callable,
	free: Callable = Callable()
) -> Dictionary:
	var door: Variant = b.get("door")
	if door == null or ring_in.size() < 3 or not ground_at.is_valid():
		return {}
	var ring := CityBuildingBuilder.wall_ring(b, ring_in)
	var placed := CityBuildingBuilder.door_on_ring(ring, Vector2(door[0], door[1]))
	var edge := int(placed.x)
	var a := ring[edge]
	var c := ring[(edge + 1) % ring.size()]
	var family := StringName(b.get("material", ""))
	var smoke := RuralPlan.form(b) != &""
	var area := absf(CityBuildingBuilder.signed_area(ring))
	return layout(
		a,
		c,
		placed.y,
		ring,
		floor_y,
		ground_at,
		CityBuildingBuilder.door_size(b).x,
		{
			"seed": absi(hash(String(b["id"]) + ":steps")),
			"wood": family in WOOD_FAMILIES or smoke,
			# Fabric and size, not the census tier: the plan lays out stairs
			# before any census is bound, and the builder must agree with it.
			"grand": family == &"limestone" or area >= 65.0,
		},
		free
	)


## Layout in front of the door at `door_t` on wall edge a-c of `ring`.
## Returns {kind, wood, treads, rails, span}:
## - treads: oriented boxes {c, u, v, hu, hv, top}; `u` points down the run;
## - rails: lines {a, b, top_a, top_b} on the open side (parapet or rail);
## - span: Vector2 edge parameters the stair covers along the wall (the footing
##   stays open there).
static func layout(
	a: Vector2,
	c: Vector2,
	door_t: float,
	ring: PackedVector2Array,
	floor_y: float,
	ground_at: Callable,
	door_width: float,
	style: Dictionary,
	free: Callable = Callable()
) -> Dictionary:
	var out_layout := {
		"kind": Kind.NONE, "wood": bool(style.get("wood", false)), "treads": [], "rails": [],
		"span": Vector2(door_t, door_t),
	}
	var length := a.distance_to(c)
	if length < 0.01:
		return out_layout
	var dir := (c - a) / length
	var out := Vector2(-dir.y, dir.x)
	var mid := a.lerp(c, door_t)
	if Geometry2D.is_point_in_polygon(mid + out * 0.3, ring):
		out = -out
	var rise := floor_y - float(ground_at.call(mid + out * 1.0))
	if rise < MIN_RISE:
		return out_layout
	var seed_value := int(style.get("seed", 0))
	var wood := bool(out_layout["wood"])
	var tread := lerpf(TREAD_MIN, TREAD_MAX, float(seed_value % 7) / 6.0)
	var half_w := door_width * 0.5 + SIDE_MARGIN
	var n := clampi(int(ceil(rise / RISER)), 1, MAX_TREADS)
	var s_mid := length * door_t
	if n == 1:
		out_layout["kind"] = Kind.SLAB
		_straight(out_layout, mid, out, dir, floor_y, rise, 1, tread + 0.12, half_w + 0.1, 0.0, ground_at)
	elif rise > SIDE_MIN_RISE and _side(
		out_layout, mid, out, dir, s_mid, length, floor_y, half_w, tread, seed_value, ground_at, free
	):
		out_layout["kind"] = Kind.SIDE
	else:
		var splay := 0.0
		if wood:
			out_layout["kind"] = Kind.TIMBER
		elif bool(style.get("grand", false)) and seed_value % 3 != 0:
			out_layout["kind"] = Kind.SPLAYED
			# Never splay past the wall's own corners.
			var room := minf(s_mid, length - s_mid) - half_w
			splay = clampf(room / float(n), 0.0, SPLAY)
		else:
			out_layout["kind"] = Kind.STRAIGHT
		_straight(out_layout, mid, out, dir, floor_y, rise, n, tread, half_w, splay, ground_at)
		if wood and rise > 0.8:
			var run := tread * float((out_layout["treads"] as Array).size())
			var last_top := float((out_layout["treads"] as Array).back()["top"])
			for s: float in [-1.0, 1.0]:
				var side := dir * s * (half_w - RAIL_T)
				(out_layout["rails"] as Array).append(
					{"a": mid + side, "b": mid + side + out * run, "top_a": floor_y + RAIL_H,
					"top_b": last_top + RAIL_H}
				)
	if out_layout["kind"] != Kind.SIDE:
		var spread := half_w + (out_layout["treads"] as Array).size() * float(
			SPLAY if out_layout["kind"] == Kind.SPLAYED else 0.0
		)
		out_layout["span"] = Vector2((s_mid - spread) / length, (s_mid + spread) / length)
	return out_layout


## Treads straight out from the door: tread k is a column from the ground up to
## floor - rise * k / n, one tread deeper than the last. Treads the ground has
## already reached (a street climbing away from the door) are left out.
static func _straight(
	out_layout: Dictionary, mid: Vector2, out: Vector2, dir: Vector2, floor_y: float,
	rise: float, n: int, tread: float, half_w: float, splay: float, ground_at: Callable
) -> void:
	var treads: Array = out_layout["treads"]
	for k in n:
		var top := floor_y - rise * float(k) / n
		var centre := mid + out * tread * (float(k) + 0.5)
		if k > 0 and float(ground_at.call(centre)) > top - 0.06:
			break
		treads.append(
			{"c": centre, "u": out, "v": dir, "hu": tread * 0.5, "hv": half_w + splay * k, "top": top}
		)


## Landing at the door and a flight down along the wall. Treads step down one
## riser at a time until the ground meets them, so on a slope the shorter run,
## towards the rising ground, wins (a stair along a facade on a hill climbs the
## hill); on level ground the seed picks the side. False when neither side has
## room on the wall and open ground; the caller then lays a straight flight.
static func _side(
	out_layout: Dictionary, mid: Vector2, out: Vector2, dir: Vector2, s_mid: float,
	length: float, floor_y: float, half_w: float, tread: float, seed_value: int,
	ground_at: Callable, free: Callable
) -> bool:
	var depth := LANDING_DEPTH
	var rise_door := floor_y - float(ground_at.call(mid + out))
	# Even risers on level ground; a slope only shortens the run.
	var riser := rise_door / ceilf(rise_door / RISER)
	var best: Array = []
	var best_sign := 0.0
	for s: float in [1.0, -1.0]:
		var run_dir := dir * s
		var flight: Array = []
		var landed := false
		for k in range(1, MAX_TREADS):
			var top := floor_y - riser * float(k)
			var centre := mid + run_dir * (half_w + tread * (float(k) - 0.5)) + out * depth * 0.5
			var g := float(ground_at.call(centre))
			if top <= g + 0.06:
				# The ground already stands at this tread: the last one was the foot.
				landed = true
				break
			flight.append(
				{"c": centre, "u": run_dir, "v": out, "hu": tread * 0.5, "hv": depth * 0.5, "top": top}
			)
			if top - g <= riser + 0.02:
				landed = true
				break
		if not landed or flight.is_empty():
			continue
		var run := half_w + tread * float(flight.size())
		var room := (length - s_mid) if s > 0.0 else s_mid
		if run > room - 0.05:
			continue
		if free.is_valid():
			var far := mid + run_dir * run + out * depth
			var probes: Array[Vector2] = [
				mid + out * depth, mid - run_dir * half_w + out * depth, far, (mid + far) * 0.5
			]
			var clear := true
			for p in probes:
				clear = clear and bool(free.call(p))
			if not clear:
				continue
		var better := (
			best_sign == 0.0
			or flight.size() < best.size()
			or (flight.size() == best.size() and (seed_value % 2 == 0) == (s > 0.0))
		)
		if better:
			best = flight
			best_sign = s
	if best_sign == 0.0:
		return false
	var s := best_sign
	var run_dir := dir * s
	var last := best.size()
	var treads: Array = out_layout["treads"]
	treads.append(
		{
			"c": mid + out * depth * 0.5, "u": out, "v": dir, "hu": depth * 0.5, "hv": half_w,
			"top": floor_y,
		}
	)
	treads.append_array(best)
	var wood := bool(out_layout["wood"])
	var h := RAIL_H if wood else PARAPET_H
	var inset := (RAIL_T if wood else PARAPET_T) * 0.5
	var rails: Array = out_layout["rails"]
	var back := mid - run_dir * half_w
	var turn := mid + run_dir * half_w
	var o := out * (depth - inset)
	# Closed end of the landing, its outer side, then down the flight.
	rails.append({"a": back + run_dir * inset, "b": back + run_dir * inset + o, "top_a": floor_y + h,
		"top_b": floor_y + h})
	rails.append({"a": back + o, "b": turn + o, "top_a": floor_y + h, "top_b": floor_y + h})
	var foot_top := float(treads.back()["top"])
	rails.append({"a": turn + o, "b": turn + o + run_dir * tread * float(last),
		"top_a": floor_y + h, "top_b": foot_top + h})
	var s0 := s_mid - half_w
	var s1 := s_mid + half_w
	if s > 0.0:
		s1 += tread * float(last)
	else:
		s0 -= tread * float(last)
	out_layout["span"] = Vector2(s0 / length, s1 / length)
	return true


## Top of the tread under `xz`, or NAN when the point is on no tread.
static func height_at(steps: Dictionary, xz: Vector2) -> float:
	var best := NAN
	for t: Dictionary in steps.get("treads", []):
		var d: Vector2 = xz - (t["c"] as Vector2)
		if (
			absf(d.dot(t["u"])) <= float(t["hu"]) + 0.001
			and absf(d.dot(t["v"])) <= float(t["hv"]) + 0.001
		):
			best = float(t["top"]) if is_nan(best) else maxf(best, float(t["top"]))
	return best


## World bounds of the treads and rails (for spatial indexing).
static func bounds(steps: Dictionary) -> Rect2:
	var box := Rect2()
	var first := true
	for t: Dictionary in steps.get("treads", []):
		for p in corners(t):
			if first:
				box = Rect2(p, Vector2.ZERO)
				first = false
			else:
				box = box.expand(p)
	return box


static func corners(t: Dictionary) -> PackedVector2Array:
	var u: Vector2 = t["u"] * float(t["hu"])
	var v: Vector2 = t["v"] * float(t["hv"])
	var c: Vector2 = t["c"]
	return PackedVector2Array([c - u - v, c - u + v, c + u + v, c + u - v])


## Logic-plane boxes that block walking through the rails and parapets.
static func collision_polygons(steps: Dictionary) -> Array[PackedVector2Array]:
	var polys: Array[PackedVector2Array] = []
	for r: Dictionary in steps.get("rails", []):
		var a: Vector2 = r["a"]
		var b: Vector2 = r["b"]
		if a.distance_to(b) < 0.05:
			continue
		var d := (b - a).normalized()
		var side := Vector2(-d.y, d.x) * RAIL_COLLISION_T * 0.5
		polys.append(PackedVector2Array([a + side, b + side, b - side, a - side]))
	return polys


## Draws the stair into `shell`: limestone columns (straight, splayed, slab and
## stone side flights) or plank treads on stringers (timber), then parapets or
## rails.
static func build(shell: CityBuildingBuilder.Shell, steps: Dictionary, ground_at: Callable) -> void:
	var treads: Array = steps.get("treads", [])
	if treads.is_empty():
		return
	var wood := bool(steps["wood"])
	for t: Dictionary in treads:
		if wood and int(steps["kind"]) != Kind.SLAB:
			_plank_tread(shell, t, ground_at)
		else:
			_column(shell, "timber" if wood else "stone", t, float(t["top"]), ground_at,
				WOOD if wood else STONE_TOP, WOOD * 0.85 if wood else STONE_SIDE)
	if wood and int(steps["kind"]) != Kind.SLAB:
		_stringers(shell, steps, ground_at)
	for r: Dictionary in steps.get("rails", []):
		if wood:
			_rail(shell, r, ground_at)
		else:
			_parapet(shell, r, ground_at)


## Solid box from under the ground up to `top`.
static func _column(
	shell: CityBuildingBuilder.Shell, key: String, t: Dictionary, top: float, ground_at: Callable,
	top_color: Color, side_color: Color
) -> void:
	var pts := corners(t)
	var bottom := INF
	for p in pts:
		bottom = minf(bottom, float(ground_at.call(p)))
	bottom -= FOOT_SINK
	_box(shell, key, pts, bottom, top - 0.01, top_color, side_color)


static func _box(
	shell: CityBuildingBuilder.Shell, key: String, pts: PackedVector2Array, bottom: float,
	top: float, top_color: Color, side_color: Color
) -> void:
	var centre := (pts[0] + pts[2]) * 0.5
	var lo: Array[Vector3] = []
	var hi: Array[Vector3] = []
	for p in pts:
		lo.append(Vector3(p.x, bottom, p.y))
		hi.append(Vector3(p.x, top, p.y))
	shell.quad_out(key, hi[0], hi[1], hi[2], hi[3], top_color, Vector3.UP)
	for i in 4:
		var j := (i + 1) % 4
		var face := (pts[i] + pts[j]) * 0.5 - centre
		shell.quad_out(key, lo[i], lo[j], hi[j], hi[i], side_color, Vector3(face.x, 0.0, face.y))


## A plank tread overhanging its riser line a little, open underneath.
static func _plank_tread(
	shell: CityBuildingBuilder.Shell, t: Dictionary, ground_at: Callable
) -> void:
	var top := float(t["top"])
	var plank := t.duplicate()
	plank["hu"] = float(t["hu"]) + 0.02
	# The landing of a timber side flight stands on two posts at its outer corners.
	if float(t["hu"]) > TREAD_MAX:
		var u: Vector2 = t["u"]
		var v: Vector2 = t["v"]
		for s: float in [-1.0, 1.0]:
			var post_c: Vector2 = t["c"] + u * (float(t["hu"]) - 0.08) + v * s * (float(t["hv"]) - 0.08)
			var post := {"c": post_c, "u": u, "v": v, "hu": 0.07, "hv": 0.07}
			_box(shell, "timber", corners(post), float(ground_at.call(post_c)) - FOOT_SINK,
				top - PLANK_T, WOOD * 0.8, WOOD * 0.7)
	_box(shell, "timber", corners(plank), top - PLANK_T, top - 0.005, WOOD, WOOD * 0.8)


## Two sloped beams carrying the treads of a timber flight, one at each side of
## the run (a side flight's inner beam lies against the wall).
static func _stringers(
	shell: CityBuildingBuilder.Shell, steps: Dictionary, ground_at: Callable
) -> void:
	var treads: Array = steps["treads"]
	var first := 1 if int(steps["kind"]) == Kind.SIDE else 0
	if treads.size() - first < 1:
		return
	var t0: Dictionary = treads[first]
	var t1: Dictionary = treads.back()
	var u: Vector2 = t0["u"]
	var v: Vector2 = t0["v"]
	var hv := float(t0["hv"])
	var start: Vector2 = t0["c"] - u * float(t0["hu"])
	var run_end: Vector2 = t1["c"] + u * float(t1["hu"])
	var top0 := float(t0["top"]) - PLANK_T
	var top1 := minf(float(t1["top"]) - PLANK_T, float(ground_at.call(run_end)) + 0.12)
	for s: float in [-1.0, 1.0]:
		var off := v * s * (hv - 0.04)
		var side := v * s * 0.04
		var a := start + off
		var b := run_end + off
		var bottom_b := float(ground_at.call(b)) - 0.1
		var quad_lo: Array[Vector3] = [
			Vector3(a.x - side.x, top0 - STRINGER_H, a.y - side.y),
			Vector3(b.x - side.x, bottom_b, b.y - side.y),
			Vector3(b.x + side.x, bottom_b, b.y + side.y),
			Vector3(a.x + side.x, top0 - STRINGER_H, a.y + side.y),
		]
		var quad_hi: Array[Vector3] = [
			Vector3(a.x - side.x, top0, a.y - side.y),
			Vector3(b.x - side.x, top1, b.y - side.y),
			Vector3(b.x + side.x, top1, b.y + side.y),
			Vector3(a.x + side.x, top0, a.y + side.y),
		]
		_prism(shell, "timber", quad_lo, quad_hi, WOOD * 0.75)


## Low limestone parapet along a rail line, its top following the treads.
static func _parapet(shell: CityBuildingBuilder.Shell, r: Dictionary, ground_at: Callable) -> void:
	var a: Vector2 = r["a"]
	var b: Vector2 = r["b"]
	if a.distance_to(b) < 0.05:
		return
	var d := (b - a).normalized()
	var side := Vector2(-d.y, d.x) * PARAPET_T * 0.5
	var ga := float(ground_at.call(a)) - FOOT_SINK
	var gb := float(ground_at.call(b)) - FOOT_SINK
	var ta := float(r["top_a"])
	var tb := float(r["top_b"])
	var lo: Array[Vector3] = [
		Vector3(a.x + side.x, ga, a.y + side.y), Vector3(b.x + side.x, gb, b.y + side.y),
		Vector3(b.x - side.x, gb, b.y - side.y), Vector3(a.x - side.x, ga, a.y - side.y),
	]
	var hi: Array[Vector3] = [
		Vector3(a.x + side.x, ta, a.y + side.y), Vector3(b.x + side.x, tb, b.y + side.y),
		Vector3(b.x - side.x, tb, b.y - side.y), Vector3(a.x - side.x, ta, a.y - side.y),
	]
	_prism(shell, "stone", lo, hi, STONE_SIDE)


## Timber rail: posts at both ends and about every metre, and a top rail.
static func _rail(shell: CityBuildingBuilder.Shell, r: Dictionary, ground_at: Callable) -> void:
	var a: Vector2 = r["a"]
	var b: Vector2 = r["b"]
	var length := a.distance_to(b)
	if length < 0.05:
		return
	var d := (b - a) / length
	var n := Vector2(-d.y, d.x)
	var posts := maxi(1, int(ceil(length / 1.0)))
	for k in posts + 1:
		var f := float(k) / posts
		var p := a.lerp(b, f)
		var post := {"c": p, "u": d, "v": n, "hu": RAIL_T * 0.5, "hv": RAIL_T * 0.5}
		var top := lerpf(float(r["top_a"]), float(r["top_b"]), f)
		_box(shell, "timber", corners(post), float(ground_at.call(p)) - FOOT_SINK, top,
			WOOD * 0.8, WOOD * 0.7)
	var side := n * RAIL_T * 0.6
	var ta := float(r["top_a"])
	var tb := float(r["top_b"])
	var lo: Array[Vector3] = [
		Vector3(a.x + side.x, ta - 0.07, a.y + side.y), Vector3(b.x + side.x, tb - 0.07, b.y + side.y),
		Vector3(b.x - side.x, tb - 0.07, b.y - side.y), Vector3(a.x - side.x, ta - 0.07, a.y - side.y),
	]
	var hi: Array[Vector3] = [
		Vector3(a.x + side.x, ta + 0.02, a.y + side.y), Vector3(b.x + side.x, tb + 0.02, b.y + side.y),
		Vector3(b.x - side.x, tb + 0.02, b.y - side.y), Vector3(a.x - side.x, ta + 0.02, a.y - side.y),
	]
	_prism(shell, "timber", lo, hi, WOOD * 0.8)


## Closed six-sided solid between a bottom and a top quad (same corner order).
static func _prism(
	shell: CityBuildingBuilder.Shell, key: String, lo: Array[Vector3], hi: Array[Vector3],
	color: Color
) -> void:
	var centre := Vector3.ZERO
	for p in lo + hi:
		centre += p
	centre /= 8.0
	shell.quad_out(key, hi[0], hi[1], hi[2], hi[3], color, Vector3.UP)
	shell.quad_out(key, lo[0], lo[1], lo[2], lo[3], color, Vector3.DOWN)
	for i in 4:
		var j := (i + 1) % 4
		var face := (lo[i] + lo[j] + hi[i] + hi[j]) * 0.25 - centre
		shell.quad_out(key, lo[i], lo[j], hi[j], hi[i], color, face)

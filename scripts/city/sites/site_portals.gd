class_name CitySitePortals
extends RefCounted

## Landmark entrance portals (R-1693, docs/SYSTEMS/CITY_DOORS.md). A profiled
## door opening is three zones through the wall, outside to inside:
##   orders   - stepped jambs and archivolts, each arris chamfered or rolled,
##              concentric with the aperture's two-centred arch;
##   stop     - the narrow aperture itself (the manifest opening, unchanged);
##   embrasure- a wider, taller rear arch the leaf hangs in, so a leaf cut to
##              the pointed head swings inward without passing through masonry.
## The aperture (`s`, `w`, sill, spring, apex) stays the authority for the walk
## walls; only the visual faces around it change. Leaves are shaped to the
## same arch (CityDoors), so the head no longer opens onto the nave above a
## rectangular leaf.

## Embrasure widening per side; leaf overlap onto the stop per side.
const REBATE := 0.18
const OVERLAP := 0.05
## Minimum length of the stop tunnel, and how far in front of the leaf's
## centre plane it ends (front strap ironwork stands 0.1 m proud).
const STOP := 0.06
const CLEAR := 0.11
## Embrasure springs this far above the leaf's apex.
const HEAD_CLEAR := 0.1
const ROLL_SEGMENTS := 3
## Inward swing of a leaf in an embrasure: flat against its side, never into it.
const OPEN_ANGLE := deg_to_rad(90.0)

## Orders outside -> in: [offset beyond the aperture (m), jamb depth (m), arris].
## The last entry is the stop's own arris and depth is ignored. Profile choices,
## sources and confidence: docs/SYSTEMS/CITY_DOORS.md#portal-decisions-r-1693.
const PROFILES := {
	# Stepped portal survives but belongs to the later 14th-c. rebuild; 1343
	# shows a restrained two-order chamfered predecessor.
	&"door.holy_spirit.north":
	[[0.3, 0.16, &"chamfer"], [0.14, 0.16, &"chamfer"], [0.0, 0.0, &"chamfer"]],
	# Tower ground-floor portal: pointed and moulded (rolls) on the main axis.
	&"door.st_olaf.west":
	[
		[0.48, 0.18, &"chamfer"],
		[0.32, 0.16, &"roll"],
		[0.16, 0.16, &"chamfer"],
		[0.0, 0.0, &"roll"],
	],
	&"door.st_olaf.south":
	[[0.36, 0.18, &"chamfer"], [0.18, 0.16, &"roll"], [0.0, 0.0, &"chamfer"]],
	# Porch entrance in a 0.8 m wall: two shallow orders only.
	&"door.st_nicholas.north":
	[[0.24, 0.12, &"chamfer"], [0.12, 0.12, &"roll"], [0.0, 0.0, &"chamfer"]],
	&"door.st_nicholas.west":
	[
		[0.45, 0.18, &"chamfer"],
		[0.3, 0.16, &"roll"],
		[0.15, 0.16, &"chamfer"],
		[0.0, 0.0, &"roll"],
	],
	&"door.st_nicholas.south":
	[[0.26, 0.16, &"chamfer"], [0.13, 0.14, &"chamfer"], [0.0, 0.0, &"chamfer"]],
	# Cathedral south portal in the new nave: the richest stepped entrance.
	&"door.st_mary.south":
	[
		[0.5, 0.18, &"chamfer"],
		[0.34, 0.16, &"roll"],
		[0.17, 0.16, &"roll"],
		[0.0, 0.0, &"chamfer"],
	],
	# Priests' door: one chamfered order, a working entrance.
	&"door.st_mary.priests": [[0.14, 0.16, &"chamfer"], [0.0, 0.0, &"chamfer"]],
	# Dominican west portal (R-1718): the surviving stepped pointed portal with a
	# moulded archivolt; its date is unrecorded, so three plain orders without
	# the carved vine and oak-leaf capital friezes.
	&"door.st_catherine.west":
	[
		[0.42, 0.18, &"chamfer"],
		[0.28, 0.16, &"roll"],
		[0.14, 0.16, &"chamfer"],
		[0.0, 0.0, &"chamfer"],
	],
}


## Marks each profiled door's opening in `manifest.fabric` with
## `portal: {door, depth}` (depth of the door's hinge line behind the outer
## face). Idempotent; unmatched profiles are left for the tests to report.
static func annotate(manifest: Dictionary) -> void:
	for door: Dictionary in manifest.get("doors", []):
		var id := StringName(door["id"])
		if not PROFILES.has(id):
			continue
		var hit := find(manifest, door)
		if hit.is_empty():
			continue
		hit["op"]["portal"] = {"door": String(id), "depth": hit["depth"]}


## The fabric opening a door record hangs in: {wall, op, depth}, or {} when
## none (or more than one) matches. Site-local metres.
static func find(manifest: Dictionary, door: Dictionary) -> Dictionary:
	var a := Vector2(door["a"][0], door["a"][1])
	var b := Vector2(door["b"][0], door["b"][1])
	var c := (a + b) * 0.5
	var hits: Array[Dictionary] = []
	for w: Dictionary in manifest.get("fabric", []):
		var wa := Vector2(w["a"][0], w["a"][1])
		var wb := Vector2(w["b"][0], w["b"][1])
		var dir := (wb - wa).normalized()
		var out := _outward(w)
		var s := (c - wa).dot(dir)
		var depth := -(c - wa).dot(out)
		if depth < -0.05 or depth > float(w["thick"]) + 0.05:
			continue
		for op: Dictionary in w.get("openings", []):
			if String(op.get("kind", "")) != "door":
				continue
			var half := float(op["w"]) * 0.5
			if absf(s - float(op["s"])) < half and absf(a.distance_to(b) - half * 2.0) < 0.1:
				hits.append({"wall": w, "op": op, "depth": depth})
	return hits[0] if hits.size() == 1 else {}


static func _outward(w: Dictionary) -> Vector2:
	var wa := Vector2(w["a"][0], w["a"][1])
	var wb := Vector2(w["b"][0], w["b"][1])
	var dir := (wb - wa).normalized()
	var out := Vector2(-dir.y, dir.x)
	var inside := Vector2(w["inside"][0], w["inside"][1])
	return -out if out.dot(inside - (wa + wb) * 0.5) > 0.0 else out


## Opening record (CitySiteKit._opening format) grown by `g` all round except
## the sill. A pointed head keeps its two arc centres (concentric archivolt).
static func grow(o: Dictionary, g: float) -> Dictionary:
	var r := o.duplicate()
	var w := float(o["w"])
	r["s"] = float(o["s"]) - g
	r["w"] = w + g * 2.0
	if float(o["apex"]) > 0.0:
		var h := float(o["apex"]) - float(o["spring"])
		var radius := (w * w * 0.25 + h * h) / w + g
		var w2 := w + g * 2.0
		r["apex"] = float(o["spring"]) + sqrt(maxf(radius * w2 - w2 * w2 * 0.25, 0.0))
	else:
		r["spring"] = float(o["spring"]) + g
	return r


## Depth of the leaf's centre plane: the authored hinge line, pushed back far
## enough to clear the orders and a short stop.
static func leaf_depth(op: Dictionary) -> float:
	var orders: Array = PROFILES[StringName(op["portal"]["door"])]
	var d := 0.0
	for order: Array in orders:
		d += float(order[1])
	d += _arris_size(orders[orders.size() - 1])
	return maxf(float(op["portal"]["depth"]), d + STOP + CLEAR)


## Rear arch: wider than the aperture by REBATE a side, springing above the
## overlapping leaf's apex.
static func embrasure(o: Dictionary) -> Dictionary:
	var e := grow(o, REBATE)
	var leaf := grow(o, OVERLAP)
	var top := float(leaf["apex"]) if float(o["apex"]) > 0.0 else float(leaf["spring"])
	e["spring"] = top + HEAD_CLEAR
	e["apex"] = (
		float(e["spring"]) + (float(o["apex"]) - float(o["spring"])) * 0.75
		if float(o["apex"]) > 0.0
		else 0.0
	)
	return e


## Section rings outside -> in: [opening record, depth]. Consecutive rings are
## joined by quads; the first ring is the outer face hole, the last the inner.
static func rings(o: Dictionary, op: Dictionary, thick: float) -> Array:
	var orders: Array = PROFILES[StringName(op["portal"]["door"])]
	var path: Array[Vector3] = []  # (offset, depth, 0 = order ring / 1 = embrasure)
	var d := 0.0
	for k in orders.size():
		var g := float(orders[k][0])
		var c := _arris_size(orders[k])
		match orders[k][2]:
			&"chamfer":
				path.append(Vector3(g + c, d, 0))
				path.append(Vector3(g, d + c, 0))
			&"roll":
				for j in ROLL_SEGMENTS + 1:
					var t := PI * 0.5 * j / ROLL_SEGMENTS
					path.append(Vector3(g + c - c * sin(t), d + c - c * cos(t), 0))
			_:
				path.append(Vector3(g, d, 0))
		if k < orders.size() - 1:
			d += float(orders[k][1])
			path.append(Vector3(g, d, 0))
	var stop := leaf_depth(op) - CLEAR
	path.append(Vector3(0, stop, 0))
	path.append(Vector3(0, stop, 1))
	path.append(Vector3(0, thick, 1))
	var e := embrasure(o)
	var out: Array = []
	for p in path:
		var ring: Dictionary = e if p.z > 0.5 else grow(o, p.x)
		if not out.is_empty() and is_equal_approx(out[-1][1], p.y) and out[-1][0] == ring:
			continue
		out.append([ring, p.y])
	return out


static func _arris_size(order: Array) -> float:
	return 0.07 if order[2] == &"roll" else (0.05 if order[2] == &"chamfer" else 0.0)


## Builds the portal faces between consecutive rings. `at(s, y, depth)` maps
## wall coordinates to site space; `deep` points into the wall.
static func build(
	shell: CityBuildingBuilder.Shell,
	at: Callable,
	section: Array,
	dir: Vector2,
	deep: Vector3,
	inner_key: String
) -> void:
	var o: Dictionary = section[0][0]
	var centre := Vector2(
		float(o["s"]) + float(o["w"]) * 0.5, (float(o["sill"]) + CitySiteKit._top(o)) * 0.5
	)
	for i in section.size() - 1:
		var ra: Dictionary = section[i][0]
		var rb: Dictionary = section[i + 1][0]
		var da: float = section[i][1]
		var db: float = section[i + 1][1]
		var pa := CitySiteKit.outline(ra)
		var pb := CitySiteKit.outline(rb)
		# Embrasure faces are plastered like the interior; orders and stop are ashlar.
		var plaster: bool = rb == section[-1][0] and ra == rb
		var key := inner_key if plaster else "ashlar"
		var tone := Color.WHITE if plaster else CitySiteKit.ASHLAR
		for k in pa.size():
			var k2 := (k + 1) % pa.size()
			# The closing edge runs along the sill: a threshold strip only where
			# the ring advances in depth (a step face would be degenerate).
			if k2 == 0 and is_equal_approx(da, db):
				continue
			# Facing hint only (tri_out fixes the winding): a step face at one
			# depth looks outward when the ring narrows, inward when it widens;
			# every face that advances in depth looks towards the opening's axis.
			var u := ((pa[k] + pa[k2]) * 0.5 - centre).normalized()
			var normal := -Vector3(dir.x * u.x, u.y, dir.y * u.x)
			if is_equal_approx(da, db):
				normal = deep * signf(float(rb["w"]) - float(ra["w"]))
			shell.quad_out(
				key,
				at.call(pa[k].x, pa[k].y, da),
				at.call(pa[k2].x, pa[k2].y, da),
				at.call(pb[k2].x, pb[k2].y, db),
				at.call(pb[k].x, pb[k].y, db),
				tone,
				normal
			)


## Leaf geometry for a portal door: {depth_shift, overlap, span, spring, apex}
## with heights relative to the door's floor; {} for an unprofiled door.
static func leaf(site: CitySite, door_id: StringName, floor_y: float) -> Dictionary:
	if not PROFILES.has(door_id):
		return {}
	for raw: Dictionary in site.data.get("doors", []):
		if StringName(raw["id"]) != door_id:
			continue
		var hit := find(site.data, raw)
		if hit.is_empty() or not hit["op"].has("portal"):
			return {}
		var o := CitySiteKit._opening(hit["op"], false)
		var head := grow(o, OVERLAP)
		var top := float(head["apex"]) if float(head["apex"]) > 0.0 else float(head["spring"])
		return {
			"depth_shift": leaf_depth(hit["op"]) - float(hit["depth"]),
			"overlap": OVERLAP,
			"span": float(head["w"]),
			"spring": site.level + float(o["spring"]) - floor_y,
			"apex": site.level + top - floor_y,
		}
	return {}

extends RefCounted

## A house's stone chimney and the hearth under it (docs/SYSTEMS/SEAMLESS_CITY.md,
## step 5; docs/SYSTEMS/HOUSEHOLDS.md). Split out of CityBuildingBuilder, which
## calls `build` for every house and `flue_cap` after the interior cutaway.

const SECTION := Color(0.62, 0.58, 0.52)
## How far the sooty flue is modelled down the stack before the dark floor.
const FLUE_DEPTH := 0.55
## Hole size against the narrowest rim at the flue mouth.
const FLUE_HOLE_SHARE := 0.66


## Stone chimney on the inner face of a gable wall (`spot`), where the hearth
## stands: HouseholdLayout puts the hearth's own brick flue right under it.
## Inside an enterable house (`breast` is its shell) a chimney breast rises from
## behind the hearth and from the top of its flue through the ceiling, so the
## hearth smoke has somewhere to go; the stack carries on through the roof.
## Returns {top (flue mouth), wall (outer wall point), inner, dir, inward, depth}
## or {} when no wall has room for a hearth.
static func build(
	roof: CityBuildingBuilder.Shell,
	breast: CityBuildingBuilder.Shell,
	ring: PackedVector2Array,
	thick: float,
	floor_y: float,
	frame: Dictionary,
	rng: RandomNumberGenerator,
	door_edge: int,
	door: Vector2
) -> Dictionary:
	# The two draws of the old random spot on the slope keep the RNG schedule.
	rng.randf()
	rng.randf()
	var top := float(frame["ridge"]) + rng.randf_range(0.6, 1.1)
	var tint := Color(1, 1, 1) * rng.randf_range(0.75, 0.95)
	tint.a = 1.0
	var found := spot(ring, thick, frame, door_edge, door)
	if found.is_empty():
		return {}
	var w: Vector2 = found["inner"]
	var dir: Vector2 = found["dir"]
	var inward: Vector2 = found["inward"]
	var hearth_d := HouseholdLayout.hearth_inset()
	var flue_d := hearth_d - HouseholdLayout.HEARTH_FLUE_BACK
	var half := CityBuildingBuilder.CHIMNEY_SIZE * 0.5
	# Flush with the wall, reaching just past the front of the hearth's flue.
	var depth := flue_d + half
	var low := INF
	for sx: float in [-1.0, 1.0]:
		for d: float in [0.0, depth]:
			low = minf(low, CityBuildingBuilder.roof_height(frame, w + dir * sx * half + inward * d))
	if breast != null:
		var flue_top := floor_y + HouseholdLayout.HEARTH_FLUE_TOP
		# Behind the hearth, filling its standoff from the wall up to the flue top...
		var back := hearth_d - HouseholdLayout.HEARTH_BACK + 0.02
		_prism(breast, w, dir, inward, half, back, floor_y, flue_top, tint)
		# ...then over the flue to the stack (the cutaway splits it at CUT_HEIGHT).
		_prism(breast, w, dir, inward, half, depth, flue_top - 0.04, low - 0.2, tint, true)
	_prism(roof, w, dir, inward, half, depth, low - 0.2, top, tint)
	var c := w + inward * flue_d
	var outline := Vector2(half, depth * 0.5)
	flue_mouth(roof, w + inward * depth * 0.5, dir, inward, outline, c, top, tint, 0.035)
	found["top"] = Vector3(c.x, top, c.y)
	found["depth"] = depth
	return found


## Where a house's chimney goes: the inner face of the wall (not the door's)
## that is highest under the roof - the gable, where the ridge crosses it -
## and away from the door, with room either side for the hearth. Returns
## {wall (outer point), inner (inner wall-face point), dir (along the wall),
## inward} or {}.
static func spot(
	ring: PackedVector2Array, thick: float, frame: Dictionary, door_edge: int, door: Vector2
) -> Dictionary:
	var hearth := HouseholdLayout.piece_size(&"hearth")
	var margin := thick + hearth.x * 0.5 + 0.2
	var fn: Vector2 = frame["n"]
	# The room as HouseholdLayout furnishes it: the hearth must fit inside.
	var room := PackedVector2Array()
	for poly: PackedVector2Array in Geometry2D.offset_polygon(
		ring, -(thick + HouseholdLayout.WALL_GAP), Geometry2D.JOIN_MITER
	):
		if absf(CityBuildingBuilder.signed_area(poly)) > absf(CityBuildingBuilder.signed_area(room)):
			room = poly
	var best := {}
	var best_score := -INF
	for i in ring.size():
		if i == door_edge:
			continue
		var a := ring[i]
		var c := ring[(i + 1) % ring.size()]
		var length := a.distance_to(c)
		if length < margin * 2.0:
			continue
		var dir := (c - a) / length
		var inward := Vector2(-dir.y, dir.x)
		if not Geometry2D.is_point_in_polygon((a + c) * 0.5 + inward * 0.05, ring):
			inward = -inward
		# The gable's peak: where the ridge line meets this wall.
		var t := length * 0.5
		if absf(fn.dot(dir)) > 0.05:
			t = (float(frame["mid"]) - fn.dot(a)) / fn.dot(dir)
		var wall := a + dir * clampf(t, margin, length - margin)
		var inner := wall + inward * thick
		var centre := inner + inward * HouseholdLayout.hearth_inset()
		var flue := centre - inward * HouseholdLayout.HEARTH_FLUE_BACK
		var fits := room.size() >= 3
		for sx: float in [-0.5, 0.5]:
			for sz: float in [-0.5, 0.5]:
				var corner := centre + dir * hearth.x * sx + inward * hearth.z * sz
				fits = fits and Geometry2D.is_point_in_polygon(corner, room)
		if not fits:
			continue
		var score := CityBuildingBuilder.roof_height(frame, flue)
		if door != Vector2.INF:
			# Clear of the doorway and its step into the room.
			if flue.distance_to(door) < 3.0:
				continue
			score += flue.distance_to(door) * 0.25
		if score > best_score:
			best_score = score
			best = {"wall": wall, "inner": inner, "dir": dir, "inward": inward}
	return best


## Section cap on the chimney breast where the cutaway cuts it: stone round a
## dark flue, so the cut stack reads from above like the cut walls.
static func flue_cap(shell: CityBuildingBuilder.Shell, flue: Dictionary, y: float) -> void:
	var w: Vector2 = flue["inner"]
	var dir: Vector2 = flue["dir"]
	var inward: Vector2 = flue["inward"]
	var depth := float(flue["depth"])
	var half := CityBuildingBuilder.CHIMNEY_SIZE * 0.5
	var c: Vector3 = flue["top"]
	# A section is a flat cut: no mortar crown.
	var outline := Vector2(half, depth * 0.5)
	var mid := w + inward * depth * 0.5
	flue_mouth(shell, mid, dir, inward, outline, Vector2(c.x, c.z), y, SECTION, 0.0)


## Top of a stack whose outline is the rectangle at `centre` (half-extents
## `half` along `u` and `v`): a stone rim round an irregular, rounded flue
## hole at `hole`, and the sooty flue running FLUE_DEPTH down into the dark.
## WHY: a flat black square read as a painted-on rectangle from the iso
## camera. Real flue mouths are rough rubble with a mortar crown, blackened
## by soot toward the hole, and you see a little way down the flue.
## `crown` lifts the mortar toward the hole (0 for a flat section cut).
## The outer ring stays exactly at `y` so it meets the stack walls' top edge.
static func flue_mouth(
	shell: CityBuildingBuilder.Shell,
	centre: Vector2,
	u: Vector2,
	v: Vector2,
	half: Vector2,
	hole: Vector2,
	y: float,
	tint: Color,
	crown: float
) -> void:
	# Own RNG seeded by the hole position: the building RNG schedule (and so
	# every other detail of the house) stays as it was.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(hole.x * 100.0), roundi(hole.y * 100.0)))
	var h := Vector2((hole - centre).dot(u), (hole - centre).dot(v))
	var inscribed := minf(half.x - absf(h.x), half.y - absf(h.y))
	if inscribed <= 0.05:
		return
	# Angles round the hole: an even spread plus the rectangle's corners, so
	# the rim fan covers the corners exactly.
	var angles: Array[float] = []
	var count := 22
	var spin := rng.randf() * TAU / float(count)
	for k in count:
		angles.append(spin + TAU * float(k) / float(count))
	for corner: Vector2 in [half, Vector2(-half.x, half.y), -half, Vector2(half.x, -half.y)]:
		angles.append(fposmod((corner - h).angle(), TAU))
	for k in angles.size():
		angles[k] = fposmod(angles[k], TAU)
	angles.sort()
	# Smooth irregularity: a rounded square (superellipse) wobbled by three
	# low harmonics, so the outline is lumpy but never spiky.
	var wobble := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var amps := [rng.randf_range(0.05, 0.09), rng.randf_range(0.03, 0.06), rng.randf_range(0.02, 0.04)]
	var outer := PackedVector2Array()
	var mid := PackedVector2Array()
	var inner := PackedVector2Array()
	var lift := PackedFloat32Array()
	var last := -INF
	for a: float in angles:
		if a - last < 0.02:
			continue
		last = a
		var d := Vector2(cos(a), sin(a))
		var exit := INF
		if absf(d.x) > 1e-5:
			exit = minf(exit, ((half.x if d.x > 0.0 else -half.x) - h.x) / d.x)
		if absf(d.y) > 1e-5:
			exit = minf(exit, ((half.y if d.y > 0.0 else -half.y) - h.y) / d.y)
		var square := 1.0 / pow(pow(absf(d.x), 3.0) + pow(absf(d.y), 3.0), 1.0 / 3.0)
		var lump := (
			1.0
			+ float(amps[0]) * sin(2.0 * a + float(wobble[0]))
			+ float(amps[1]) * sin(3.0 * a + float(wobble[1]))
			+ float(amps[2]) * sin(5.0 * a + float(wobble[2]))
		)
		var r := minf(inscribed * FLUE_HOLE_SHARE * square * lump, exit - 0.05)
		var o := h + d * exit
		var i := h + d * r
		# The crown's break line wanders too, so no second ring reads as a shape.
		var m := i.lerp(o, rng.randf_range(0.35, 0.6))
		outer.append(centre + u * o.x + v * o.y)
		inner.append(centre + u * i.x + v * i.y)
		mid.append(centre + u * m.x + v * m.y)
		lift.append(crown * rng.randf_range(0.6, 1.4))
	var soot := Color(tint.r * 0.36, tint.g * 0.33, tint.b * 0.30, 1.0)
	var deep := Color(tint.r * 0.12, tint.g * 0.11, tint.b * 0.10, 1.0)
	# Colours per ring vertex: clean stone at the edge (a little soot creeping
	# over it here and there), blending to black at the lip and down the flue.
	var c_outer := PackedColorArray()
	var c_mid := PackedColorArray()
	var c_inner := PackedColorArray()
	for k in inner.size():
		var shade := rng.randf_range(0.88, 1.05)
		c_outer.append(tint.lerp(soot, rng.randf_range(0.0, 0.3)) * shade)
		c_mid.append(tint.lerp(soot, rng.randf_range(0.4, 0.75)) * shade)
		c_inner.append(soot * rng.randf_range(0.75, 1.0))
	var bottom := y - FLUE_DEPTH
	var band := y - 0.16
	var n := inner.size()
	for k in n:
		var j := (k + 1) % n
		var o0 := Vector3(outer[k].x, y, outer[k].y)
		var o1 := Vector3(outer[j].x, y, outer[j].y)
		var m0 := Vector3(mid[k].x, y + crown * 0.8, mid[k].y)
		var m1 := Vector3(mid[j].x, y + crown * 0.8, mid[j].y)
		var i0 := Vector3(inner[k].x, y + lift[k], inner[k].y)
		var i1 := Vector3(inner[j].x, y + lift[j], inner[j].y)
		_shaded_quad(shell, o0, o1, m1, m0, [c_outer[k], c_outer[j], c_mid[j], c_mid[k]], Vector3.UP)
		_shaded_quad(shell, m0, m1, i1, i0, [c_mid[k], c_mid[j], c_inner[j], c_inner[k]], Vector3.UP)
		# The flue walls, darkening with depth, facing into the hole.
		var into := hole - (inner[k] + inner[j]) * 0.5
		var face := Vector3(into.x, 0.0, into.y)
		var b0 := Vector3(inner[k].x, band, inner[k].y)
		var b1 := Vector3(inner[j].x, band, inner[j].y)
		var dim := [c_inner[k] * 0.55, c_inner[j] * 0.55]
		_shaded_quad(shell, i0, i1, b1, b0, [c_inner[k], c_inner[j], dim[1], dim[0]], face)
		var d0 := Vector3(inner[k].x, bottom, inner[k].y)
		var d1 := Vector3(inner[j].x, bottom, inner[j].y)
		_shaded_quad(shell, b0, b1, d1, d0, [dim[0], dim[1], deep, deep], face)
		shell.tri_out("dark", Vector3(hole.x, bottom, hole.y), d0, d1, Color(1, 1, 1), Vector3.UP)


## Quad p0-p1-p2-p3 on the "stone" surface with a colour per corner, wound to
## face `out`.
static func _shaded_quad(
	shell: CityBuildingBuilder.Shell,
	p0: Vector3,
	p1: Vector3,
	p2: Vector3,
	p3: Vector3,
	colors: Array,
	out: Vector3
) -> void:
	var surf := shell.surface("stone")
	for t: Array in [[0, 1, 2], [0, 2, 3]]:
		var pts: Array[Vector3] = [p0, p1, p2, p3]
		var a := pts[t[0]]
		var b := pts[t[1]]
		var c := pts[t[2]]
		var ca: Color = colors[t[0]]
		var cb: Color = colors[t[1]]
		var cc: Color = colors[t[2]]
		var normal := (c - a).cross(b - a)
		if normal.length_squared() < 1e-10:
			continue
		# Same convention as Shell.tri / tri_out: normal = (c - a) x (b - a).
		if normal.dot(out) < 0.0:
			var swap := b
			b = c
			c = swap
			var swap_c := cb
			cb = cc
			cc = swap_c
			normal = -normal
		surf.add(a, b, c, normal.normalized(), ca, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
		# Surf.add takes one colour per triangle; overwrite the last two corners.
		var last := surf.colors.size() - 1
		surf.colors[last - 1] = cb
		surf.colors[last] = cc



## Stone block on the wall face at `w`: `half` either side along `dir`, from
## the wall `depth` into the room along `inward`, from `y0` to `y1`.
static func _prism(
	shell: CityBuildingBuilder.Shell,
	w: Vector2,
	dir: Vector2,
	inward: Vector2,
	half: float,
	depth: float,
	y0: float,
	y1: float,
	tint: Color,
	bottom := false
) -> void:
	if y1 <= y0:
		return
	var corners: Array[Vector2] = [
		w - dir * half,
		w + dir * half,
		w + dir * half + inward * depth,
		w - dir * half + inward * depth,
	]
	var mid := w + inward * depth * 0.5
	for i in 4:
		var a := corners[i]
		var b := corners[(i + 1) % 4]
		var out := Vector3((a + b).x * 0.5 - mid.x, 0.0, (a + b).y * 0.5 - mid.y)
		shell.quad_out(
			"stone",
			Vector3(a.x, y0, a.y),
			Vector3(b.x, y0, b.y),
			Vector3(b.x, y1, b.y),
			Vector3(a.x, y1, a.y),
			tint,
			out
		)
	if bottom:
		shell.quad_out(
			"stone",
			Vector3(corners[0].x, y0, corners[0].y),
			Vector3(corners[1].x, y0, corners[1].y),
			Vector3(corners[2].x, y0, corners[2].y),
			Vector3(corners[3].x, y0, corners[3].y),
			tint,
			Vector3.DOWN
		)

class_name CitySiteKit
extends RefCounted

## Geometry kit for landmark site models (ADR 0032), in site-local metres
## (+x along the site axis, +z to its right, y up from the terrace level).
## Walls are built from manifest "fabric" entries: an outer face line a-b, a
## thickness towards `inside`, a height range and openings. Openings may be
## flat-headed (doors, almshouse lights) or pointed (two-centred arches for
## lancets, portals and arcades), with an inward splay, a stained-glass pane,
## or blind (niches). The same fabric gives the logic-plane walls (CitySite),
## so the model and the walk data cannot drift apart.

const STONE := Color(0.93, 0.91, 0.86)
const ASHLAR := Color(0.86, 0.84, 0.79)
const OAK := Color(0.58, 0.47, 0.36)
const OAK_DARK := Color(0.4, 0.31, 0.23)
const IRON := Color(0.17, 0.16, 0.15)
const ARCH_SEGMENTS := 8
const LIMEWASH := preload("res://scripts/city/city_limewash.gdshader")
const FLAGSTONE := preload("res://scripts/city/city_flagstone.gdshader")
const GLASS := preload("res://scripts/city/city_stained_glass.gdshader")

static var _materials: Dictionary = {}


## Builds every wall of a fabric list into `shell` (stained glass into
## `glass`, a separate shell so it can use its own material).
static func walls(
	shell: CityBuildingBuilder.Shell, glass: CityBuildingBuilder.Shell, fabric: Array
) -> void:
	for w: Dictionary in fabric:
		wall(shell, glass, w)


static func wall(
	shell: CityBuildingBuilder.Shell, glass: CityBuildingBuilder.Shell, w: Dictionary
) -> void:
	var a := _v2(w["a"])
	var b := _v2(w["b"])
	var inside := _v2(w["inside"])
	var thick := float(w["thick"])
	var y0 := float(w.get("y0", -0.6))
	var y1 := float(w["y1"])
	var floor_y := float(w.get("floor", 0.12))
	var length := a.distance_to(b)
	var dir := (b - a) / length
	var out := Vector2(-dir.y, dir.x)
	if out.dot(inside - (a + b) * 0.5) > 0.0:
		out = -out
	var outer := func(s: float, y: float) -> Vector3:
		var p := a + dir * s
		return Vector3(p.x, y, p.y)
	var inner := func(s: float, y: float) -> Vector3:
		var p := a + dir * s - out * thick
		return Vector3(p.x, y, p.y)
	var o3 := Vector3(out.x, 0, out.y)
	var outer_key := String(w.get("outer", "wall:limestone"))
	var inner_key := String(w.get("inner", "painted"))
	var outs: Array = []
	var ins: Array = []
	for op: Dictionary in w.get("openings", []):
		var o := _opening(op, false)
		outs.append(o)
		ins.append(_opening(op, true) if String(op.get("kind", "window")) != "niche" else {})
	_face(shell, outer_key, outer, 0.0, length, y0, y1, outs, o3, STONE)
	var inner_openings: Array = []
	for o: Dictionary in ins:
		if not o.is_empty():
			inner_openings.append(o)
	var s0 := float(w.get("inner_from", thick))
	var s1 := length - float(w.get("inner_to", thick))
	if bool(w.get("inner_face", true)):
		_face(shell, inner_key, inner, s0, s1, floor_y, y1, inner_openings, -o3, Color.WHITE)
	for k in outs.size():
		var o: Dictionary = outs[k]
		if String(o["kind"]) == "niche":
			_niche(shell, outer, o, out, 0.22, dir)
			continue
		_reveal(shell, outer, inner, o, ins[k], dir)
		if bool(o.get("glass", false)):
			_glass(glass, a, dir, out, thick * 0.3, o)
		if String(o["kind"]) == "louvre":
			_louvres(shell, a, dir, out, thick * 0.5, o)
	shell.quad_out(
		String(w.get("top", outer_key)),
		outer.call(0.0, y1),
		outer.call(length, y1),
		inner.call(length, y1),
		inner.call(0.0, y1),
		STONE,
		Vector3.UP
	)


## Opening record from a manifest entry; `inner` applies the splay.
static func _opening(op: Dictionary, inner: bool) -> Dictionary:
	var kind := String(op.get("kind", "window"))
	var w := float(op["w"])
	var s := float(op["s"]) - w * 0.5
	var sill := float(op.get("sill", 0.12))
	var spring := float(op.get("spring", sill + 2.0))
	var apex := float(op.get("apex", 0.0))
	var splay := float(op.get("splay", 0.3 if kind == "window" else 0.0)) if inner else 0.0
	if splay > 0.0:
		var rise := apex - spring if apex > 0.0 else 0.0
		s -= splay
		w += splay * 2.0
		sill -= splay * 0.6
		spring += 0.1
		apex = spring + rise * (w / maxf(w - splay * 2.0, 0.01)) if apex > 0.0 else 0.0
	return {
		"s": s,
		"w": w,
		"sill": sill,
		"spring": spring,
		"apex": apex,
		"kind": kind,
		"glass": bool(op.get("glass", false)),
		"seed": float(op.get("seed", s))
	}


static func _top(o: Dictionary) -> float:
	return float(o["apex"]) if float(o["apex"]) > 0.0 else float(o["spring"])


## Face between s0..s1, y0..y1 with rectangular holes up to each opening's
## top, then the arch spandrels filled back in.
static func _face(
	shell: CityBuildingBuilder.Shell,
	key: String,
	at: Callable,
	s0: float,
	s1: float,
	y0: float,
	y1: float,
	openings: Array,
	face: Vector3,
	color: Color
) -> void:
	var holes: Array[Rect2] = []
	for o: Dictionary in openings:
		holes.append(
			Rect2(float(o["s"]), float(o["sill"]), float(o["w"]), _top(o) - float(o["sill"]))
		)
	holed_face(shell, key, at, s0, s1, y0, y1, holes, face, color)
	for o: Dictionary in openings:
		if float(o["apex"]) <= 0.0:
			continue
		var pts := arch(float(o["s"]), float(o["w"]), float(o["spring"]), float(o["apex"]))
		var half := pts.size() / 2
		var left_corner := Vector2(float(o["s"]), float(o["apex"]))
		var right_corner := Vector2(float(o["s"]) + float(o["w"]), float(o["apex"]))
		for k in half:
			shell.tri_out(
				key,
				at.call(left_corner.x, left_corner.y),
				at.call(pts[k].x, pts[k].y),
				at.call(pts[k + 1].x, pts[k + 1].y),
				color,
				face
			)
		for k in range(half, pts.size() - 1):
			shell.tri_out(
				key,
				at.call(right_corner.x, right_corner.y),
				at.call(pts[k].x, pts[k].y),
				at.call(pts[k + 1].x, pts[k + 1].y),
				color,
				face
			)


## Points of a two-centred arch from the left springer over the apex to the
## right springer, in (s, y).
static func arch(s: float, w: float, spring: float, apex: float) -> PackedVector2Array:
	var h := apex - spring
	var r := (w * w * 0.25 + h * h) / maxf(w, 0.01)
	var cx := s + r
	var theta_a := acos(clampf((s + w * 0.5 - cx) / r, -1.0, 1.0))
	var pts := PackedVector2Array()
	for k in ARCH_SEGMENTS + 1:
		var th := PI - (PI - theta_a) * float(k) / ARCH_SEGMENTS
		pts.append(Vector2(cx + r * cos(th), spring + r * sin(th)))
	for k in range(ARCH_SEGMENTS - 1, -1, -1):
		var p := pts[k]
		pts.append(Vector2(2.0 * (s + w * 0.5) - p.x, p.y))
	return pts


## Outline of an opening (sill corners, springers, arch) in (s, y), counter-clockwise.
static func outline(o: Dictionary) -> PackedVector2Array:
	var s := float(o["s"])
	var w := float(o["w"])
	var sill := float(o["sill"])
	var out := PackedVector2Array([Vector2(s + w, sill)])
	if float(o["apex"]) > 0.0:
		var pts := arch(s, w, float(o["spring"]), float(o["apex"]))
		for k in range(pts.size() - 1, -1, -1):
			out.append(pts[k])
	else:
		out.append(Vector2(s + w, float(o["spring"])))
		out.append(Vector2(s, float(o["spring"])))
	out.append(Vector2(s, sill))
	return out


static func _reveal(
	shell: CityBuildingBuilder.Shell,
	outer: Callable,
	inner: Callable,
	o: Dictionary,
	io: Dictionary,
	dir: Vector2
) -> void:
	var a := outline(o)
	var b := outline(io)
	# Resample the inner outline to the outer's vertex count (same topology).
	if a.size() != b.size():
		return
	var key := "limewash" if String(o["kind"]) == "window" else "ashlar"
	var tone := Color.WHITE if key == "limewash" else ASHLAR
	for k in a.size():
		var p := a[k]
		var q := a[(k + 1) % a.size()]
		var pi := b[k]
		var qi := b[(k + 1) % b.size()]
		var mid := (p + q) * 0.5
		var c := Vector2(float(o["s"]) + float(o["w"]) * 0.5, (float(o["sill"]) + _top(o)) * 0.5)
		var n2 := (c - mid).normalized()
		var face := Vector3(dir.x * n2.x, n2.y, dir.y * n2.x)
		shell.quad_out(
			key,
			outer.call(p.x, p.y),
			outer.call(q.x, q.y),
			inner.call(qi.x, qi.y),
			inner.call(pi.x, pi.y),
			tone,
			face
		)


## A blind niche: recessed back (lime-washed) and ashlar reveals.
static func _niche(
	shell: CityBuildingBuilder.Shell,
	outer: Callable,
	o: Dictionary,
	out: Vector2,
	depth: float,
	dir := Vector2.RIGHT
) -> void:
	var back := func(s: float, y: float) -> Vector3:
		var v: Vector3 = outer.call(s, y)
		return v - Vector3(out.x, 0, out.y) * depth
	var pts := outline(o)
	var c := Vector2(float(o["s"]) + float(o["w"]) * 0.5, float(o["sill"]) + 0.3)
	var o3 := Vector3(out.x, 0, out.y)
	for k in range(1, pts.size() - 1):
		shell.tri_out(
			"limewash",
			back.call(pts[0].x, pts[0].y),
			back.call(pts[k].x, pts[k].y),
			back.call(pts[k + 1].x, pts[k + 1].y),
			Color.WHITE,
			o3
		)
	for k in pts.size():
		var p := pts[k]
		var q := pts[(k + 1) % pts.size()]
		var n2 := (c - (p + q) * 0.5).normalized()
		shell.quad_out(
			"ashlar",
			outer.call(p.x, p.y),
			outer.call(q.x, q.y),
			back.call(q.x, q.y),
			back.call(p.x, p.y),
			ASHLAR,
			Vector3(dir.x * n2.x, n2.y, dir.y * n2.x)
		)


## Stained-glass pane in the opening, `inset` behind the outer face; normal
## points outdoors. UV in metres; COLOR.r carries the light's width / 4.
static func _glass(
	glass: CityBuildingBuilder.Shell,
	a: Vector2,
	dir: Vector2,
	out: Vector2,
	inset: float,
	o: Dictionary
) -> void:
	var pts := outline(o)
	var s0 := float(o["s"])
	var sill := float(o["sill"])
	var w := float(o["w"])
	var c := Color(w / 4.0, fposmod(float(o["seed"]) * 0.37, 1.0), 1.0)
	var at := func(p: Vector2) -> Vector3:
		var q := a + dir * p.x - out * inset
		return Vector3(q.x, p.y, q.y)
	var o3 := Vector3(out.x, 0, out.y)
	var centre := Vector2(s0 + w * 0.5, (sill + _top(o)) * 0.5)
	for k in pts.size():
		var p := pts[k]
		var q := pts[(k + 1) % pts.size()]
		glass.tri_out(
			"glass",
			at.call(centre),
			at.call(p),
			at.call(q),
			c,
			o3,
			Vector2(centre.x - s0, centre.y - sill),
			Vector2(p.x - s0, p.y - sill),
			Vector2(q.x - s0, q.y - sill)
		)


## Belfry louvres: slanted boards across the opening.
static func _louvres(
	shell: CityBuildingBuilder.Shell,
	a: Vector2,
	dir: Vector2,
	out: Vector2,
	inset: float,
	o: Dictionary
) -> void:
	var y := float(o["sill"]) + 0.1
	while y < float(o["spring"]) - 0.1:
		var p0 := a + dir * float(o["s"]) - out * inset
		var p1 := a + dir * (float(o["s"]) + float(o["w"])) - out * inset
		shell.quad_out(
			"timber",
			Vector3(p0.x, y, p0.y),
			Vector3(p1.x, y, p1.y),
			Vector3(p1.x + out.x * 0.15, y + 0.16, p1.y + out.y * 0.15),
			Vector3(p0.x + out.x * 0.15, y + 0.16, p0.y + out.y * 0.15),
			OAK_DARK,
			Vector3(out.x, 1.0, out.y)
		)
		y += 0.22


static func holed_face(
	shell: CityBuildingBuilder.Shell,
	key: String,
	at: Callable,
	s_min: float,
	s_max: float,
	y_min: float,
	y_max: float,
	holes: Array[Rect2],
	face: Vector3,
	color: Color
) -> void:
	var ss: Array[float] = [s_min, s_max]
	var ys: Array[float] = [y_min, y_max]
	for o: Rect2 in holes:
		ss.append_array([o.position.x, o.end.x])
		ys.append_array([o.position.y, o.end.y])
	ss.sort()
	ys.sort()
	for i in ss.size() - 1:
		for j in ys.size() - 1:
			var s0: float = clampf(ss[i], s_min, s_max)
			var s1: float = clampf(ss[i + 1], s_min, s_max)
			var y0: float = clampf(ys[j], y_min, y_max)
			var y1: float = clampf(ys[j + 1], y_min, y_max)
			if s1 - s0 < 0.001 or y1 - y0 < 0.001:
				continue
			var mid := Vector2((s0 + s1) * 0.5, (y0 + y1) * 0.5)
			var hole := false
			for o: Rect2 in holes:
				hole = hole or o.has_point(mid)
			if not hole:
				shell.quad_out(
					key,
					at.call(s0, y0),
					at.call(s1, y0),
					at.call(s1, y1),
					at.call(s0, y1),
					color,
					face
				)


## Crow-stepped gable in the plane x = `x` (outer face), facing `side` (+1/-1
## along x), spanning z0..z1 from `base` to `apex`, `steps` steps a side,
## `thick` deep, with a coping slab on every step and blind niches.
static func stepped_gable(
	shell: CityBuildingBuilder.Shell,
	x: float,
	side: float,
	z0: float,
	z1: float,
	base: float,
	apex: float,
	steps: int,
	thick: float,
	niches: int = 3
) -> void:
	var half := (z1 - z0) * 0.5
	var zc := (z0 + z1) * 0.5
	var step_w := half / (steps + 0.5)
	var step_h := (apex - base) / (steps + 1)
	# Profile in (z, y), counter-clockwise from the left foot.
	var prof := PackedVector2Array([Vector2(z0, base)])
	prof.append(Vector2(z1, base))
	for k in steps:
		var zr := z1 - step_w * k
		prof.append(Vector2(zr, base + step_h * (k + 1)))
		prof.append(Vector2(zr - step_w, base + step_h * (k + 1)))
	prof.append(Vector2(zc + step_w * 0.5, apex))
	prof.append(Vector2(zc - step_w * 0.5, apex))
	for k in range(steps - 1, -1, -1):
		var zl := z0 + step_w * k
		prof.append(Vector2(zl + step_w, base + step_h * (k + 1)))
		prof.append(Vector2(zl, base + step_h * (k + 1)))
	var x_in := x - side * thick
	var tris := Geometry2D.triangulate_polygon(prof)
	for k in range(0, tris.size(), 3):
		var p := [prof[tris[k]], prof[tris[k + 1]], prof[tris[k + 2]]]
		shell.tri_out(
			"wall:limestone",
			Vector3(x, p[0].y, p[0].x),
			Vector3(x, p[1].y, p[1].x),
			Vector3(x, p[2].y, p[2].x),
			STONE,
			Vector3(side, 0, 0)
		)
		shell.tri_out(
			"wall:limestone",
			Vector3(x_in, p[0].y, p[0].x),
			Vector3(x_in, p[1].y, p[1].x),
			Vector3(x_in, p[2].y, p[2].x),
			STONE,
			Vector3(-side, 0, 0)
		)
	for k in range(1, prof.size()):
		var p := prof[k]
		var q := prof[(k + 1) % prof.size()]
		if absf(p.y - base) < 0.01 and absf(q.y - base) < 0.01:
			continue
		var n2 := Vector2(q.y - p.y, -(q.x - p.x)).normalized()
		shell.quad_out(
			"wall:limestone",
			Vector3(x, p.y, p.x),
			Vector3(x, q.y, q.x),
			Vector3(x_in, q.y, q.x),
			Vector3(x_in, p.y, p.x),
			STONE,
			Vector3(0, n2.y, n2.x)
		)
		# Coping on the flat tops of the steps.
		if absf(p.y - q.y) < 0.01:
			CitySiteProps._box(
				shell,
				"ashlar",
				Vector3(minf(x, x_in) - 0.08, p.y, minf(p.x, q.x) - 0.06),
				Vector3(maxf(x, x_in) + 0.08, p.y + 0.14, maxf(p.x, q.x) + 0.06),
				ASHLAR
			)
	# Blind lancet niches, the middle one tallest.
	for k in niches:
		var off := (float(k) - (niches - 1) * 0.5) * step_w * 1.1
		var h := (apex - base) * (0.55 - absf(off) / half * 0.45)
		var w := minf(step_w * 0.6, 0.9)
		var y0 := base + (apex - base) * 0.12
		var o := {
			"s": zc + off - w * 0.5,
			"w": w,
			"sill": y0,
			"spring": y0 + h * 0.75,
			"apex": y0 + h,
			"kind": "niche"
		}
		var at := func(s: float, y: float) -> Vector3: return Vector3(x, y, s)
		_niche(shell, at, o, Vector2(side, 0.0), 0.2, Vector2(0.0, 1.0))


## Gable roof along x between x0 and x1 over z0..z1 (ridge at the middle),
## eave at `eave`, pitch in degrees, eave overhang, half-round ridge tiles.
static func gable_roof(
	roof: CityBuildingBuilder.Shell,
	x0: float,
	x1: float,
	z0: float,
	z1: float,
	eave: float,
	pitch_deg: float,
	overhang: float,
	key := "roof:tile"
) -> float:
	var half := (z1 - z0) * 0.5
	var zc := (z0 + z1) * 0.5
	var slope := tan(deg_to_rad(pitch_deg))
	var ridge := eave + half * slope
	var thick := 0.14
	for side: float in [-1.0, 1.0]:
		var ze := zc + side * (half + overhang)
		var ye := eave - overhang * slope
		var run := sqrt((half + overhang) * (half + overhang) + (ridge - ye) * (ridge - ye))
		var face := Vector3(0.0, 1.0, side * slope).normalized()
		var a := Vector3(x0, ridge + thick, zc)
		var b := Vector3(x1, ridge + thick, zc)
		var c := Vector3(x1, ye + thick, ze)
		var d := Vector3(x0, ye + thick, ze)
		roof.tri_out(
			key, a, b, c, Color.WHITE, face, Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, run)
		)
		roof.tri_out(
			key, a, c, d, Color.WHITE, face, Vector2(x0, 0), Vector2(x1, run), Vector2(x0, run)
		)
		roof.quad_out(
			"timber",
			Vector3(x0, ridge, zc),
			Vector3(x1, ridge, zc),
			Vector3(x1, ye, ze),
			Vector3(x0, ye, ze),
			OAK_DARK * 0.8,
			-face
		)
		roof.quad_out(
			key,
			Vector3(x0, ye + thick, ze),
			Vector3(x1, ye + thick, ze),
			Vector3(x1, ye - 0.03, ze),
			Vector3(x0, ye - 0.03, ze),
			Color(0.9, 0.9, 0.9),
			Vector3(0, -0.3, side)
		)
	var rr := 0.17
	var x := x0
	while x < x1 - 0.01:
		var x2 := minf(x + 0.4, x1)
		for k in 6:
			var t0 := PI * float(k) / 6.0
			var t1 := PI * float(k + 1) / 6.0
			var p0 := Vector3(x, ridge + thick + sin(t0) * rr * 0.8, zc + cos(t0) * rr)
			var p1 := Vector3(x, ridge + thick + sin(t1) * rr * 0.8, zc + cos(t1) * rr)
			var n := Vector3(0, sin((t0 + t1) * 0.5), cos((t0 + t1) * 0.5))
			roof.quad_out(
				key, p0, Vector3(x2, p0.y, p0.z), Vector3(x2, p1.y, p1.z), p1, Color.WHITE, n
			)
		x = x2
	return ridge


## Four-sided pyramid roof (tower helm) over a square centred at c.
static func pyramid_roof(
	roof: CityBuildingBuilder.Shell,
	c: Vector2,
	half: float,
	eave: float,
	apex: float,
	key := "roof:shingle"
) -> void:
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var tip := Vector3(c.x, apex, c.y)
	for k in 4:
		var p: Vector2 = c + (corners[k] as Vector2) * (half + 0.3)
		var q: Vector2 = c + (corners[(k + 1) % 4] as Vector2) * (half + 0.3)
		var mid := (p + q) * 0.5 - c
		var face := Vector3(mid.x, half * 0.6, mid.y).normalized()
		var run := (Vector3(p.x, eave, p.y)).distance_to(tip)
		roof.tri_out(
			key,
			Vector3(p.x, eave, p.y),
			Vector3(q.x, eave, q.y),
			tip,
			Color.WHITE,
			face,
			Vector2(0, run),
			Vector2(half * 2.0, run),
			Vector2(half, 0)
		)
	CitySiteProps._box(
		roof,
		"dark",
		Vector3(c.x - 0.04, apex - 0.1, c.y - 0.04),
		Vector3(c.x + 0.04, apex + 1.4, c.y + 0.04),
		IRON
	)
	CitySiteProps._box(
		roof,
		"dark",
		Vector3(c.x - 0.35, apex + 0.9, c.y - 0.03),
		Vector3(c.x + 0.35, apex + 0.96, c.y + 0.03),
		IRON
	)


## Octagonal limestone pillar with a moulded base and capital.
static func pillar(shell: CityBuildingBuilder.Shell, at: Vector3, r: float, height: float) -> void:
	var rings := [
		[0.0, r * 1.35],
		[0.3, r * 1.35],
		[0.38, r],
		[height - 0.45, r],
		[height - 0.3, r * 1.4],
		[height, r * 1.4]
	]
	for k in rings.size() - 1:
		var y0: float = rings[k][0]
		var r0: float = rings[k][1]
		var y1: float = rings[k + 1][0]
		var r1: float = rings[k + 1][1]
		for j in 8:
			var a0 := TAU * (j + 0.5) / 8.0
			var a1 := TAU * (j + 1.5) / 8.0
			var n := Vector3(cos((a0 + a1) * 0.5), 0.0, sin((a0 + a1) * 0.5))
			shell.quad_out(
				"ashlar",
				at + Vector3(cos(a0) * r0, y0, sin(a0) * r0),
				at + Vector3(cos(a1) * r0, y0, sin(a1) * r0),
				at + Vector3(cos(a1) * r1, y1, sin(a1) * r1),
				at + Vector3(cos(a0) * r1, y1, sin(a0) * r1),
				ASHLAR,
				n
			)


## Limestone flag floor over a rectangle (x0, z0, x1, z1) at height y, with
## occasional darker ledger (tomb) slabs carrying an incised cross.
static func flag_floor(
	shell: CityBuildingBuilder.Shell, r: Rect2, y: float, rng: RandomNumberGenerator, ledgers := 0.0
) -> void:
	var z := r.position.y
	var row := 0
	while z < r.end.y - 0.01:
		var dz := minf(rng.randf_range(0.55, 0.85), r.end.y - z)
		var x := r.position.x - (0.0 if row % 2 == 0 else 0.3)
		while x < r.end.x - 0.01:
			var tomb := rng.randf() < ledgers
			var dx := 2.0 if tomb else rng.randf_range(0.6, 1.0)
			var x0 := maxf(x, r.position.x)
			var x1 := minf(x + dx, r.end.x)
			var tone := (
				Color.WHITE * (rng.randf_range(0.6, 0.7) if tomb else rng.randf_range(0.78, 1.0))
			)
			tone.a = 1.0
			var lift := rng.randf_range(-0.006, 0.006)
			shell.quad_out(
				"flags",
				Vector3(x0 + 0.008, y + lift, z + 0.008),
				Vector3(x1 - 0.008, y + lift, z + 0.008),
				Vector3(x1 - 0.008, y + lift, z + dz - 0.008),
				Vector3(x0 + 0.008, y + lift, z + dz - 0.008),
				tone,
				Vector3.UP
			)
			if tomb and x1 - x0 > 1.2:
				var cx := (x0 + x1) * 0.5
				var cz := z + dz * 0.5
				CitySiteProps._box(
					shell,
					"dark",
					Vector3(cx - 0.5, y + lift + 0.001, cz - 0.02),
					Vector3(cx + 0.5, y + lift + 0.003, cz + 0.02),
					Color(0.3, 0.28, 0.25)
				)
				CitySiteProps._box(
					shell,
					"dark",
					Vector3(cx + 0.15, y + lift + 0.001, cz - 0.18),
					Vector3(cx + 0.19, y + lift + 0.003, cz + 0.18),
					Color(0.3, 0.28, 0.25)
				)
			x += dx
		z += dz
		row += 1
	shell.quad_out(
		"dark",
		Vector3(r.position.x, y - 0.012, r.position.y),
		Vector3(r.end.x, y - 0.012, r.position.y),
		Vector3(r.end.x, y - 0.012, r.end.y),
		Vector3(r.position.x, y - 0.012, r.end.y),
		Color(0.55, 0.5, 0.44),
		Vector3.UP
	)


## Section caps on the fabric walls at the cut height, skipping the spans of
## openings that the cut passes through.
static func cut_caps(shell: CityBuildingBuilder.Shell, fabric: Array, y: float) -> void:
	for w: Dictionary in fabric:
		if float(w["y1"]) <= y:
			continue
		var a := _v2(w["a"])
		var b := _v2(w["b"])
		var inside := _v2(w["inside"])
		var length := a.distance_to(b)
		var dir := (b - a) / length
		var n := Vector2(-dir.y, dir.x)
		if n.dot(inside - (a + b) * 0.5) < 0.0:
			n = -n
		var spans: Array[Vector2] = [Vector2(0.0, length)]
		for op: Dictionary in w.get("openings", []):
			var o := _opening(op, false)
			if String(o["kind"]) == "niche" or float(o["sill"]) > y or _top(o) < y:
				continue
			var cut: Array[Vector2] = []
			for sp in spans:
				if float(o["s"]) >= sp.y or float(o["s"]) + float(o["w"]) <= sp.x:
					cut.append(sp)
					continue
				if float(o["s"]) > sp.x:
					cut.append(Vector2(sp.x, float(o["s"])))
				if float(o["s"]) + float(o["w"]) < sp.y:
					cut.append(Vector2(float(o["s"]) + float(o["w"]), sp.y))
			spans = cut
		var thick := float(w["thick"])
		for sp in spans:
			var p0 := a + dir * sp.x
			var p1 := a + dir * sp.y
			shell.quad_out(
				"ashlar",
				Vector3(p0.x, y, p0.y),
				Vector3(p1.x, y, p1.y),
				Vector3(p1.x + n.x * thick, y, p1.y + n.y * thick),
				Vector3(p0.x + n.x * thick, y, p0.y + n.y * thick),
				Color(0.62, 0.58, 0.52),
				Vector3.UP
			)


static func bar(
	shell: CityBuildingBuilder.Shell, key: String, a: Vector3, b: Vector3, size: float, color: Color
) -> void:
	var d := (b - a).normalized()
	var ref := Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT
	var u := d.cross(ref).normalized() * size * 0.5
	var v := d.cross(u).normalized() * size * 0.5
	var ring := [u + v, u - v, -u - v, -u + v]
	for k in 4:
		var p: Vector3 = ring[k]
		var q: Vector3 = ring[(k + 1) % 4]
		shell.quad_out(key, a + p, a + q, b + q, b + p, color, p + q)


static func mesh(node_name: String, shell: CityBuildingBuilder.Shell) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = shell.to_mesh(material_for)
	return inst


## Materials by key: the city's own (walls, roofs, dark, timber) plus the
## site kit's lime wash, painted wash, flags, ashlar and stained glass.
static func material_for(key: String) -> Material:
	if _materials.has(key):
		return _materials[key]
	var mat: Material
	match key:
		"limewash":
			var sm := ShaderMaterial.new()
			sm.shader = LIMEWASH
			mat = sm
		"painted":
			var pm := ShaderMaterial.new()
			pm.shader = LIMEWASH
			pm.set_shader_parameter("paint", 1.0)
			mat = pm
		"flags":
			var fs := ShaderMaterial.new()
			fs.shader = FLAGSTONE
			mat = fs
		"glass":
			var gs := ShaderMaterial.new()
			gs.shader = GLASS
			mat = gs
		"ashlar":
			var std := StandardMaterial3D.new()
			std.albedo_texture = load("res://assets/materials/pbr/stone/stone_albedo.png")
			std.normal_enabled = true
			std.normal_texture = load("res://assets/materials/pbr/stone/stone_normal.png")
			std.uv1_triplanar = true
			std.uv1_world_triplanar = true
			std.uv1_scale = Vector3(0.9, 0.9, 0.9)
			std.albedo_color = Color(0.8, 0.78, 0.72)
			std.vertex_color_use_as_albedo = true
			std.roughness = 0.88
			mat = std
		"timber":
			var std := StandardMaterial3D.new()
			std.albedo_texture = load("res://assets/materials/pbr/timber/timber_albedo.png")
			std.normal_enabled = true
			std.normal_texture = load("res://assets/materials/pbr/timber/timber_normal.png")
			std.uv1_triplanar = true
			std.uv1_world_triplanar = true
			std.uv1_scale = Vector3(1.4, 1.4, 1.4)
			std.vertex_color_use_as_albedo = true
			std.roughness = 0.82
			std.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat = std
		_:
			mat = CityBuildingBuilder.material_for_key(key)
	_materials[key] = mat
	return mat


## A site's own copy of the painted wash, bound to its frame and floor (the
## rich frieze runs beyond `rich_from` along the site axis).
static func painted_for(site: CitySite, floor_y: float, rich_from: float) -> ShaderMaterial:
	var pm := (material_for("painted") as ShaderMaterial).duplicate() as ShaderMaterial
	pm.set_shader_parameter("floor_y", site.level + floor_y)
	pm.set_shader_parameter("site_origin", site.origin)
	pm.set_shader_parameter("site_axis", Vector2(cos(site.rotation), sin(site.rotation)))
	pm.set_shader_parameter("rich_from", rich_from)
	return pm


static func _v2(raw: Variant) -> Vector2:
	return Vector2(raw[0], raw[1]) if raw is Array else raw


## Logic-plane wall segments of a fabric list: each wall split around the
## openings people walk through (doors and arches whose sill is at the floor),
## as {a, b, thickness} with the thickness on the `inside` side of the line.
static func walk_walls(fabric: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w: Dictionary in fabric:
		if not bool(w.get("collide", true)):
			continue
		var a := _v2(w["a"])
		var b := _v2(w["b"])
		var length := a.distance_to(b)
		var dir := (b - a) / length
		var spans: Array[Vector2] = [Vector2(0.0, length)]
		for op: Dictionary in w.get("openings", []):
			var kind := String(op.get("kind", "window"))
			if (
				not kind in ["door", "arch"]
				or float(op.get("sill", 0.12)) > float(w.get("floor", 0.12)) + 0.3
			):
				continue
			var s0 := float(op["s"]) - float(op["w"]) * 0.5
			var s1 := s0 + float(op["w"])
			var next: Array[Vector2] = []
			for sp in spans:
				if s0 >= sp.y or s1 <= sp.x:
					next.append(sp)
					continue
				if s0 > sp.x:
					next.append(Vector2(sp.x, s0))
				if s1 < sp.y:
					next.append(Vector2(s1, sp.y))
			spans = next
		for sp in spans:
			out.append(
				{
					"a": a + dir * sp.x,
					"b": a + dir * sp.y,
					"thickness": float(w["thick"]),
					"inside": _v2(w["inside"])
				}
			)
	return out

class_name CogHull
extends RefCounted

## Lofted hull of a Hanseatic cog in true metres (+X bow, +Y up, +Z starboard,
## origin on the waterline amidships). Sources: docs/reports/baltic_vessels_1343.md
## (Peeter 18 x 6.6 m, Lootsi 24.5 x 9 m, Bremen 23 x 7.6 m): a flat carvel
## bottom, straight raked stem and stern posts, clinker (lapped) sides, a
## keel plank about 17 m long. This hull is a plausible composite ~21 m by 7 m.
##
## A hull point is `point(s, a)`: `s` runs 0 (stern post) .. 1 (stem post) and
## `a` 0..1 runs from the keel line over the flat bottom and up the side to
## the sheer. The post rakes are built into the loft (x depends on height), so
## the planks really end on the posts instead of in a box.

const KEEL_Y := -1.8
const STERN_X := -8.8
const STEM_X := 8.6
const STERN_RAKE := 0.2
const STEM_RAKE := 0.38
const MAX_HALF_BEAM := 3.5
const SHEER_Y := 3.5
const STERNCASTLE_Y := 4.55
const FORECASTLE_Y := 4.35
const DECK_Y := 2.3
const BOTTOM_FRACTION := 0.46
const FLAT_SHARE := 0.2
const SIDE_STRAKES := 10
const BOTTOM_PLANKS := 4
## Hull plank thickness (inner skin sits this far inside the outer one) and the
## clinker overlap each strake stands proud of the one below it.
const THICKNESS := 0.2
const LAP := 0.045
const STATIONS := 34
const PLANK_STATIONS := 5

const WATERLINE_STAIN := Color(0.62, 0.7, 0.56)


static func x_aft(y: float) -> float:
	return STERN_X - STERN_RAKE * (y - KEEL_Y)


static func x_fore(y: float) -> float:
	return STEM_X + STEM_RAKE * (y - KEEL_Y)


static func half_beam(s: float) -> float:
	var u := absf(s * 2.0 - 1.0)
	return MAX_HALF_BEAM * sqrt(maxf(1.0 - pow(u, 2.6), 0.0))


static func sheer_y(s: float) -> float:
	var stern := 1.0 - smoothstep(0.25, 0.36, s)
	var bow := smoothstep(0.70, 0.79, s)
	return SHEER_Y + (STERNCASTLE_Y - SHEER_Y) * stern + (FORECASTLE_Y - SHEER_Y) * bow


## Outer surface, starboard side, before clinker lap.
static func point(s: float, a: float) -> Vector3:
	var w := half_beam(s)
	var wb := w * BOTTOM_FRACTION
	var top := sheer_y(s)
	var y := KEEL_Y
	var z := 0.0
	if a <= FLAT_SHARE:
		z = wb * a / FLAT_SHARE
	else:
		var q := (a - FLAT_SHARE) / (1.0 - FLAT_SHARE)
		z = wb + (w - wb) * pow(q, 0.7)
		y = KEEL_Y + (top - KEEL_Y) * pow(q, 1.3)
	return Vector3(lerpf(x_aft(y), x_fore(y), s), y, z)


static func normal(s: float, a: float) -> Vector3:
	var e := 0.004
	var da := point(s, minf(a + e, 1.0)) - point(s, maxf(a - e, 0.0))
	var ds := point(minf(s + e, 1.0), a) - point(maxf(s - e, 0.0), a)
	var n := ds.cross(da)
	if n.length() < 0.00001:
		return Vector3(0, 0, 1) if a > FLAT_SHARE else Vector3(0, -1, 0)
	return n.normalized()


static func s_for_x(x: float, y: float) -> float:
	return clampf((x - x_aft(y)) / (x_fore(y) - x_aft(y)), 0.0, 1.0)


## Half width of the hull at height `y` and station `x`: the outer skin, or the
## inside face of the planking when `inner`.
static func half_width_at(x: float, y: float, inner := true) -> float:
	var s := s_for_x(x, y)
	var w := half_beam(s)
	var wb := w * BOTTOM_FRACTION
	var top := sheer_y(s)
	var t := clampf((y - KEEL_Y) / (top - KEEL_Y), 0.0, 1.0)
	var z := wb + (w - wb) * pow(pow(t, 1.0 / 1.3), 0.7)
	return maxf(z - (THICKNESS if inner else 0.0), 0.0)


static func band_edges() -> Array[float]:
	var edges: Array[float] = []
	for k in BOTTOM_PLANKS + 1:
		edges.append(FLAT_SHARE * float(k) / BOTTOM_PLANKS)
	for i in range(1, SIDE_STRAKES + 1):
		edges.append(FLAT_SHARE + (1.0 - FLAT_SHARE) * float(i) / SIDE_STRAKES)
	return edges


static func station(i: int) -> float:
	return 0.5 - 0.5 * cos(PI * float(i) / STATIONS)


static func _hash(a: int, b: int) -> float:
	return fposmod(sin(float(a) * 127.1 + float(b) * 311.7) * 43758.5453, 1.0)


static func _tone(band: int, plank: int, y: float, upper: float) -> Color:
	var base := 0.8 + 0.22 * _hash(band, plank)
	var c := Color(base, base * 0.97, base * 0.93)
	# Weed and wet stain around the waterline; sun-silvered strakes high up.
	var wet := 1.0 - smoothstep(-0.9, 0.5, y)
	c = c.lerp(c * WATERLINE_STAIN, wet * 0.85)
	c = c.lerp(Color(1.06, 1.05, 1.02) * c, smoothstep(2.0, 4.0, y) * upper)
	return c


## The outer skin: bottom planks flush, side strakes lapped. The returned mesh
## uses vertex colour for per-plank tone and waterline stain.
static func add_outer(parts: CogParts) -> void:
	var edges := band_edges()
	for side: float in [1.0, -1.0]:
		for i in STATIONS:
			var s0 := station(i)
			var s1 := station(i + 1)
			for b in edges.size() - 1:
				var lapped := b >= BOTTOM_PLANKS
				var plank := (i + b * 2) / PLANK_STATIONS
				var corners: Array[Vector3] = []
				var norms: Array[Vector3] = []
				var uvs: Array[Vector2] = []
				for k: Array in [
					[s0, edges[b], 0.0],
					[s1, edges[b], 0.0],
					[s1, edges[b + 1], 1.0],
					[s0, edges[b + 1], 1.0]
				]:
					var n := normal(k[0], k[1])
					var p := point(k[0], k[1])
					if lapped:
						# Lower edge proud by LAP, easing to flush at the upper edge.
						p += n * LAP * (1.0 - float(k[2]))
					corners.append(Vector3(p.x, p.y, p.z * side))
					norms.append(Vector3(n.x, n.y, n.z * side))
					uvs.append(Vector2(p.x / 2.2 + 0.37 * b, float(k[2])))
				if side < 0.0:
					corners.reverse()
					norms.reverse()
					uvs.reverse()
				var mid_y := (corners[0].y + corners[2].y) * 0.5
				parts.smooth_quad(
					corners, norms, uvs, _tone(b, plank, mid_y, 1.0 if lapped else 0.0)
				)
				# The lap edge: the little downward shadow face under each strake.
				if lapped:
					_ledge(parts, s0, s1, edges[b], side, plank)


## Underside of the lap where strake `b` rides over strake `b - 1`.
static func _ledge(
	parts: CogParts, s0: float, s1: float, a: float, side: float, plank: int
) -> void:
	var p0 := point(s0, a)
	var p1 := point(s1, a)
	var n0 := normal(s0, a)
	var n1 := normal(s1, a)
	var o0 := p0 + n0 * LAP
	var o1 := p1 + n1 * LAP
	# Face looks down and outward; flat-shaded.
	var down := (Vector3.DOWN + Vector3(n0.x, n0.y, n0.z * side) * 0.5).normalized()
	var c: Array[Vector3] = [
		Vector3(p0.x, p0.y, p0.z * side),
		Vector3(p1.x, p1.y, p1.z * side),
		Vector3(o1.x, o1.y, o1.z * side),
		Vector3(o0.x, o0.y, o0.z * side),
	]
	if side < 0.0:
		c.reverse()
	var dn: Array[Vector3] = [down, down, down, down]
	var uv: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	parts.smooth_quad(c, dn, uv, _tone(0, plank, p0.y, 0.0) * 0.55)


## The inner skin (seen from the deck, the hold and the cabins) and the gunwale
## cap that closes the gap between the two skins at the sheer.
static func add_inner(parts: CogParts) -> void:
	var edges := band_edges()
	for side: float in [1.0, -1.0]:
		for i in STATIONS:
			var s0 := station(i)
			var s1 := station(i + 1)
			for b in edges.size() - 1:
				var corners: Array[Vector3] = []
				var norms: Array[Vector3] = []
				var uvs: Array[Vector2] = []
				for k: Array in [
					[s0, edges[b], 0.0],
					[s1, edges[b], 0.0],
					[s1, edges[b + 1], 1.0],
					[s0, edges[b + 1], 1.0]
				]:
					var n := normal(k[0], k[1])
					var p := point(k[0], k[1]) - n * THICKNESS
					p.z = maxf(p.z, 0.0)
					corners.append(Vector3(p.x, p.y, p.z * side))
					norms.append(Vector3(-n.x, -n.y, -n.z * side))
					uvs.append(Vector2(p.x / 2.2 + 0.37 * b, float(k[2])))
				# Seen from inside: the mirror of the outer winding.
				if side > 0.0:
					corners.reverse()
					norms.reverse()
					uvs.reverse()
				var tone := 0.72 + 0.2 * _hash(b + 40, (i + b * 2) / PLANK_STATIONS)
				parts.smooth_quad(corners, norms, uvs, Color(tone, tone * 0.95, tone * 0.88))
		# Gunwale cap, sheer line, facing up.
		for i in STATIONS:
			var s0 := station(i)
			var s1 := station(i + 1)
			var o0 := point(s0, 1.0)
			var o1 := point(s1, 1.0)
			var in0 := o0 - normal(s0, 1.0) * THICKNESS
			var in1 := o1 - normal(s1, 1.0) * THICKNESS
			in0.z = maxf(in0.z, 0.0)
			in1.z = maxf(in1.z, 0.0)
			var c: Array[Vector3] = [
				Vector3(o0.x, o0.y + 0.02, o0.z * side),
				Vector3(o1.x, o1.y + 0.02, o1.z * side),
				Vector3(in1.x, in1.y + 0.02, in1.z * side),
				Vector3(in0.x, in0.y + 0.02, in0.z * side),
			]
			if side < 0.0:
				c.reverse()
			var up: Array[Vector3] = [Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]
			var uv: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
			parts.smooth_quad(c, up, uv, Color(0.62, 0.55, 0.46))

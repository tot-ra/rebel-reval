extends RefCounted

## R-1933: the footing under every city wall that meets the ground, built stone
## by stone so the wall foot never reads as a ruler line. Replaces the R-1760
## straight extruded plinth on plan houses and adds a footing to outbuildings
## and smoke dwellings, which had none.
##
## Families (CityBuildingBuilder picks one from the wall material):
##   DRESSED    - limestone houses: a dressed course, nearly regular blocks
##   FIELDSTONE - plastered houses: an irregular fieldstone plinth
##   PLANK      - plank houses: a fieldstone sill under a squared timber sill
##                beam that laps past the outer corners
##   LOG        - log houses, outbuildings and smoke dwellings: low fieldstone
##                pads under a protruding round sill log whose ends cross past
##                the outer corners
##
## WHY irregular: every stone draws its own length, height, proud and a small
## belly from a per-building RNG, its front vertices are nudged, and its foot is
## sunk 5-15 cm below the local ground (ground_at) at each end with a different
## depth, so the terrain cuts the footing along a broken line. A dark bed just
## proud of the wall shows in the joints. All draws come from one RNG seeded by
## the building id, so the city stays deterministic.
##
## Canon: timber buildings on fieldstone footings or pads with a timber sill
## are `plausible composite` (docs/CANON.md, building families; typology
## sections 2-3); no measured 1343 Reval footing survives.

enum Kind { DRESSED, FIELDSTONE, PLANK, LOG }

const FIELDSTONE_TINT := Color(0.56, 0.54, 0.5)
const LIMESTONE_TINT := Color(0.76, 0.74, 0.69)
const BED_TINT := Color(0.3, 0.29, 0.27)
const BEAM_TINT := Color(0.52, 0.44, 0.36)
const LOG_TINT := Color(0.36, 0.26, 0.18)
const END_GRAIN_TINT := Color(0.66, 0.56, 0.42)
## Foot of each stone below the local ground, drawn per stone end.
const SINK_MIN := 0.05
const SINK_MAX := 0.15
## Gap left between neighbouring stones (the bed shows through it).
const JOINT := 0.014
## The bed: a dark face this far proud of the wall behind the stones.
const BED_PROUD := 0.02
## Face of the coursed masonry under the top course of a tall footing.
const MASONRY_PROUD := 0.075
const BEAM_H := 0.2
const BEAM_PROUD := 0.06
## Beam and sill-log ends run this far past an outer corner.
const BEAM_LAP := 0.12
const LOG_LAP := 0.24
const LOG_R_MIN := 0.12
const LOG_R_MAX := 0.16
const LOG_SIDES := 10
## Stones top out this far above (below) the floor; the beam or log sits on them.
const TOP := {
	Kind.DRESSED: 0.22,
	Kind.FIELDSTONE: 0.3,
	Kind.PLANK: 0.12,
	Kind.LOG: 0.1,
}


## Footing family for a wall material.
static func kind_for(family: StringName) -> Kind:
	match family:
		&"limestone":
			return Kind.DRESSED
		&"plank":
			return Kind.PLANK
		&"log":
			return Kind.LOG
	return Kind.FIELDSTONE


## Builds the footing round `ring` (raw, unfilleted footprint) into `shell`
## under material key "stone" (and "timber" for beams and logs). `ground_at`
## maps world XZ to ground height; when it is not valid, `ground` is used
## everywhere. `bottom` is the deepest point any face reaches (the wall's own
## sunk base). Leaves the door span door_a..door_b open. Returns
## {stones, beams} counts for tests.
static func build(
	shell,
	ring: PackedVector2Array,
	kind: Kind,
	floor_y: float,
	bottom: float,
	ground_at: Callable,
	ground: float,
	seed_value: int,
	door_a := Vector2.INF,
	door_b := Vector2.INF
) -> Dictionary:
	var out := {"stones": 0, "beams": 0}
	var count := ring.size()
	if count < 3:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var top := floor_y + float(TOP[kind])
	var tint := LIMESTONE_TINT if kind == Kind.DRESSED else FIELDSTONE_TINT
	var log_r := rng.randf_range(LOG_R_MIN, LOG_R_MAX)
	for i in count:
		var a := ring[i]
		var c := ring[(i + 1) % count]
		var length := a.distance_to(c)
		if length < 0.05:
			continue
		var dir := (c - a) / length
		var n := _outward(ring, (a + c) * 0.5, dir)
		var prev_dir := (a - ring[(i - 1 + count) % count]).normalized()
		var next_dir := (ring[(i + 2) % count] - c).normalized()
		# Outer corner at an end when the neighbouring edge turns back inward.
		var convex_start := prev_dir.dot(n) > 0.2
		var convex_end := next_dir.dot(n) < -0.2
		var spans: Array[Vector2] = [Vector2(0.0, length)]
		var cut := _door_cut(a, dir, length, n, door_a, door_b)
		if cut.y > cut.x:
			spans = [Vector2(0.0, cut.x), Vector2(cut.y, length)]
		for si in spans.size():
			var sp: Vector2 = spans[si]
			var opens_start := si == 0
			var closes_end := si == spans.size() - 1
			# The edge's last stone runs on over an outer corner and fills it.
			var stone_end := sp.y + (0.14 if closes_end and convex_end else 0.0)
			if stone_end - sp.x < 0.08:
				continue
			_bed(shell, a, dir, n, sp.x, sp.y, bottom, top - 0.04)
			out["stones"] += _stones(
				shell, rng, kind, a, dir, n, sp.x, stone_end, top, ground_at, ground, tint,
				stone_end > sp.y
			)
			if kind == Kind.PLANK or kind == Kind.LOG:
				var lap := BEAM_LAP if kind == Kind.PLANK else LOG_LAP
				var s0 := sp.x - (lap if opens_start and convex_start else 0.0)
				var s1 := sp.y + (lap if closes_end and convex_end else 0.0)
				if kind == Kind.PLANK:
					_beam(shell, rng, a, dir, n, s0, s1, top)
				else:
					_sill_log(
						shell, rng, a, dir, n, s0, s1, top, log_r,
						opens_start and convex_start, closes_end and convex_end
					)
				out["beams"] += 1
	return out


## One free-standing footing run from `a` to `c` (outward normal `n`) on flat
## ground at `ground`, for site models (ADR 0032) that build walls by hand:
## stones up to `top`, plus a sill beam (PLANK) or sill log (LOG) lapping past
## both ends. Returns the stone count.
static func run(
	shell, a: Vector2, c: Vector2, n: Vector2, kind: Kind, top: float, ground: float, seed_value: int
) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var length := a.distance_to(c)
	var dir := (c - a) / maxf(length, 0.001)
	var tint := LIMESTONE_TINT if kind == Kind.DRESSED else FIELDSTONE_TINT
	_bed(shell, a, dir, n, 0.0, length, ground - SINK_MAX, top - 0.04)
	var stones := _stones(shell, rng, kind, a, dir, n, 0.0, length, top, Callable(), ground, tint)
	if kind == Kind.PLANK:
		_beam(shell, rng, a, dir, n, -BEAM_LAP, length + BEAM_LAP, top)
	elif kind == Kind.LOG:
		_sill_log(shell, rng, a, dir, n, -LOG_LAP, length + LOG_LAP, top, LOG_R_MIN, true, true)
	return stones


## A fieldstone pad under a post: a squat block `half` wide (x, z) and `height`
## tall standing on `ground` at `at` (XZ), sunk SINK_MIN..SINK_MAX into it, with
## seeded corner nudges and a narrower top so it reads as a dressed boulder.
static func pad(
	shell, at: Vector2, ground: float, half: Vector2, height: float, seed_value: int
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var lo := ground - rng.randf_range(SINK_MIN, SINK_MAX)
	var hi := ground + height + rng.randf_range(-0.02, 0.02)
	var shade := FIELDSTONE_TINT * rng.randf_range(0.82, 1.08)
	shade.a = 1.0
	var bottom: Array[Vector3] = []
	var top: Array[Vector3] = []
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var off := corner * half
		var nudge := Vector2(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.03, 0.03))
		bottom.append(Vector3(at.x + off.x * 1.1 + nudge.x, lo, at.y + off.y * 1.1 + nudge.y))
		top.append(
			Vector3(
				at.x + off.x * 0.8 + nudge.x, hi + rng.randf_range(-0.015, 0.015), at.y + off.y * 0.8 + nudge.y
			)
		)
	var centre := Vector3(at.x, (lo + hi) * 0.5, at.y)
	for k in 4:
		var k2 := (k + 1) % 4
		var out := ((bottom[k] + bottom[k2] + top[k] + top[k2]) * 0.25 - centre)
		out.y = maxf(out.y, 0.0)
		shell.quad_out("stone", bottom[k], bottom[k2], top[k2], top[k], shade * 0.92, out)
	shell.tri_out("stone", top[0], top[1], top[2], shade * 1.06, Vector3.UP)
	shell.tri_out("stone", top[0], top[2], top[3], shade * 1.06, Vector3.UP)


## Fieldstones (or dressed blocks) from s0 to s1 metres along the edge.
static func _stones(
	shell,
	rng: RandomNumberGenerator,
	kind: Kind,
	a: Vector2,
	dir: Vector2,
	n: Vector2,
	s0: float,
	s1: float,
	top: float,
	ground_at: Callable,
	ground: float,
	tint: Color,
	corner_back := false
) -> int:
	var dressed := kind == Kind.DRESSED
	var carries := kind == Kind.PLANK or kind == Kind.LOG
	var stones := 0
	var s := s0
	while s1 - s > 0.04:
		var length := rng.randf_range(0.5, 0.85) if dressed else rng.randf_range(0.28, 0.66)
		# Do not leave a sliver at the end of the run: let the last stone take it.
		if s1 - (s + length) < 0.22:
			length = s1 - s
		var e0 := s + JOINT * 0.5
		var e1 := s + length - JOINT * 0.5
		s += length
		var proud := rng.randf_range(0.075, 0.085) if dressed else rng.randf_range(0.05, 0.11)
		var belly := 0.0 if dressed else rng.randf_range(0.0, 0.03)
		# A beam or log rests on the stones, so they only drop below its seat.
		var lift := 0.0
		if dressed:
			lift = rng.randf_range(-0.012, 0.012)
		elif carries:
			lift = -rng.randf_range(0.0, 0.06)
		else:
			lift = rng.randf_range(-0.06, 0.05)
		var stone_top := top + lift
		var chamfer := 0.06 if dressed else rng.randf_range(0.03, 0.08)
		var jitter := 0.004 if dressed else 0.02
		var shade := tint * (rng.randf_range(0.97, 1.03) if dressed else rng.randf_range(0.82, 1.1))
		shade.a = 1.0
		var p0 := a + dir * e0
		var p1 := a + dir * e1
		var mid := (p0 + p1) * 0.5
		var g_mid := _ground(ground_at, ground, mid + n * proud)
		var g0 := _ground(ground_at, ground, p0 + n * proud)
		var g1 := _ground(ground_at, ground, p1 + n * proud)
		var foot0 := minf(g0, g_mid) - rng.randf_range(SINK_MIN, SINK_MAX)
		var foot1 := minf(g1, g_mid) - rng.randf_range(SINK_MIN, SINK_MAX)
		# Seeded nudges of the front corners (along, up, out), drawn even when
		# the stone is skipped so later stones do not shift.
		var nudge: Array[Vector3] = []
		for _k in 6:
			nudge.append(
				Vector3(
					rng.randf_range(-jitter, jitter),
					rng.randf_range(-jitter, jitter) * 0.8,
					rng.randf_range(-jitter, jitter) * 0.6
				)
			)
		var course := 0.34 if dressed else rng.randf_range(0.22, 0.42)
		# Fully buried on the uphill side of a sloped plot: nothing to show.
		if stone_top < maxf(maxf(g0, g1), g_mid) + 0.02:
			continue
		var rise0 := stone_top - chamfer
		var rise1 := stone_top + lift * 0.3 - chamfer
		# A tall footing (downhill side of a slope) is coursed masonry under
		# one top course laid stone by stone: no metre-tall single "stones".
		# The masonry runs joint to joint and its top steps with every stone.
		if stone_top - minf(foot0, foot1) > course + 0.2:
			var seat0 := stone_top - course
			var seat1 := stone_top + lift * 0.3 - course
			_masonry(
				shell, a + dir * (e0 - JOINT * 0.5), a + dir * (e1 + JOINT * 0.5), dir, n,
				foot0, foot1, seat0, seat1, shade * 0.94
			)
			foot0 = seat0
			foot1 = seat1
		var belly_y0 := lerpf(foot0, rise0, 0.35)
		var belly_y1 := lerpf(foot1, rise1, 0.35)
		# Front profile at each end: foot, belly, shoulder; then the sloped top
		# back to the wall line.
		var f0 := _at(p0, dir, n, proud, foot0, nudge[0])
		var f1 := _at(p1, dir, n, proud, foot1, nudge[1])
		var b0 := _at(p0, dir, n, proud + belly, belly_y0, nudge[2])
		var b1 := _at(p1, dir, n, proud + belly, belly_y1, nudge[3])
		var h0 := _at(p0, dir, n, proud, rise0, nudge[4])
		var h1 := _at(p1, dir, n, proud, rise1, nudge[5])
		var t0 := Vector3(p0.x, stone_top, p0.y)
		var t1 := Vector3(p1.x, stone_top + lift * 0.3, p1.y)
		var w0 := Vector3(p0.x, foot0, p0.y)
		var w1 := Vector3(p1.x, foot1, p1.y)
		var face := Vector3(n.x, 0.0, n.y)
		var up_out := (face + Vector3.UP * 1.3).normalized()
		shell.quad_out("stone", f0, f1, b1, b0, shade * 0.9, (face - Vector3.UP * 0.3).normalized())
		shell.quad_out("stone", b0, b1, h1, h0, shade, face)
		shell.quad_out("stone", h0, h1, t1, t0, shade * 1.06, up_out)
		# Stone ends: the steps between neighbours of different proud and height.
		var side := Vector3(dir.x, 0.0, dir.y)
		_end_fan(shell, [w0, f0, b0, h0, t0], -side, shade * 0.8)
		_end_fan(shell, [w1, f1, b1, h1, t1], side, shade * 0.8)
		# The corner stone runs on past the wall line of the next edge, so its
		# back shows beside that edge's (shallower) first stone.
		if corner_back and s1 - s < 0.04:
			shell.quad_out("stone", w0, w1, t1, t0, shade * 0.85, -face)
		stones += 1
	return stones


## Coursed masonry face from p0 to p1 between the sunk feet and the seats of
## the top course, MASONRY_PROUD out of the wall, with a ledge where the stone
## above sits back.
static func _masonry(
	shell, p0: Vector2, p1: Vector2, dir: Vector2, n: Vector2,
	foot0: float, foot1: float, seat0: float, seat1: float, shade: Color
) -> void:
	var o0 := p0 + n * MASONRY_PROUD
	var o1 := p1 + n * MASONRY_PROUD
	var face := Vector3(n.x, 0.0, n.y)
	shell.quad_out(
		"stone", Vector3(o0.x, foot0, o0.y), Vector3(o1.x, foot1, o1.y),
		Vector3(o1.x, seat1, o1.y), Vector3(o0.x, seat0, o0.y), shade, face
	)
	shell.quad_out(
		"stone", Vector3(o0.x, seat0, o0.y), Vector3(o1.x, seat1, o1.y),
		Vector3(p1.x, seat1, p1.y), Vector3(p0.x, seat0, p0.y), shade * 1.04, Vector3.UP
	)
	var side := Vector3(dir.x, 0.0, dir.y)
	for end: Array in [[p0, o0, foot0, seat0, -side], [p1, o1, foot1, seat1, side]]:
		var w: Vector2 = end[0]
		var o: Vector2 = end[1]
		shell.quad_out(
			"stone", Vector3(w.x, end[2], w.y), Vector3(o.x, end[2], o.y),
			Vector3(o.x, end[3], o.y), Vector3(w.x, end[3], w.y), shade * 0.8, end[4]
		)


## Dark bed behind the stones from s0 to s1, seen only through the joints.
static func _bed(
	shell, a: Vector2, dir: Vector2, n: Vector2, s0: float, s1: float, y0: float, y1: float
) -> void:
	if y1 - y0 < 0.02:
		return
	var p0 := a + dir * s0 + n * BED_PROUD
	var p1 := a + dir * s1 + n * BED_PROUD
	shell.quad_out(
		"stone",
		Vector3(p0.x, y0, p0.y),
		Vector3(p1.x, y0, p1.y),
		Vector3(p1.x, y1, p1.y),
		Vector3(p0.x, y1, p0.y),
		BED_TINT,
		Vector3(n.x, 0.0, n.y)
	)


## Squared timber sill beam on the stones of a plank wall, s0..s1 along the
## edge, hewn a little out of true (height and proud drift along its length).
static func _beam(
	shell,
	rng: RandomNumberGenerator,
	a: Vector2,
	dir: Vector2,
	n: Vector2,
	s0: float,
	s1: float,
	y: float
) -> void:
	var drift0 := rng.randf_range(-0.012, 0.012)
	var drift1 := rng.randf_range(-0.012, 0.012)
	var proud0 := BEAM_PROUD + rng.randf_range(-0.01, 0.01)
	var proud1 := BEAM_PROUD + rng.randf_range(-0.01, 0.01)
	var shade := BEAM_TINT * rng.randf_range(0.86, 1.08)
	shade.a = 1.0
	var p0 := a + dir * s0
	var p1 := a + dir * s1
	var o0 := p0 + n * proud0
	var o1 := p1 + n * proud1
	# Back face sits inside the wall; a lapped end shows its full section.
	var i0 := p0 - n * 0.04
	var i1 := p1 - n * 0.04
	var lo0 := y + drift0
	var lo1 := y + drift1
	var hi0 := lo0 + BEAM_H
	var hi1 := lo1 + BEAM_H
	var face := Vector3(n.x, 0.0, n.y)
	shell.quad_out(
		"timber", Vector3(o0.x, lo0, o0.y), Vector3(o1.x, lo1, o1.y),
		Vector3(o1.x, hi1, o1.y), Vector3(o0.x, hi0, o0.y), shade, face
	)
	shell.quad_out(
		"timber", Vector3(o0.x, hi0, o0.y), Vector3(o1.x, hi1, o1.y),
		Vector3(i1.x, hi1, i1.y), Vector3(i0.x, hi0, i0.y), shade * 1.1, Vector3.UP
	)
	shell.quad_out(
		"timber", Vector3(o0.x, lo0, o0.y), Vector3(o1.x, lo1, o1.y),
		Vector3(i1.x, lo1, i1.y), Vector3(i0.x, lo0, i0.y), shade * 0.55, Vector3.DOWN
	)
	var side := Vector3(dir.x, 0.0, dir.y)
	for end: Array in [[o0, i0, lo0, hi0, -side], [o1, i1, lo1, hi1, side]]:
		var o: Vector2 = end[0]
		var inner: Vector2 = end[1]
		shell.quad_out(
			"timber", Vector3(o.x, end[2], o.y), Vector3(inner.x, end[2], inner.y),
			Vector3(inner.x, end[3], inner.y), Vector3(o.x, end[3], o.y), END_GRAIN_TINT * 0.8, end[4]
		)


## Round sill log on the pads of a log wall, s0..s1 along the edge; its ends
## cross past outer corners and show end grain there.
static func _sill_log(
	shell,
	rng: RandomNumberGenerator,
	a: Vector2,
	dir: Vector2,
	n: Vector2,
	s0: float,
	s1: float,
	seat: float,
	radius: float,
	cap_start: bool,
	cap_end: bool
) -> void:
	# Butt end a little thicker than the top end, and a slight sag.
	var r0 := radius * rng.randf_range(1.0, 1.08)
	var r1 := radius * rng.randf_range(0.92, 1.0)
	var shade := LOG_TINT * rng.randf_range(0.86, 1.08)
	shade.a = 1.0
	var c0 := a + dir * s0 + n * (radius * 0.45)
	var c1 := a + dir * s1 + n * (radius * 0.45)
	var y0 := seat + r0 + rng.randf_range(-0.01, 0.01)
	var y1 := seat + r1 + rng.randf_range(-0.01, 0.01)
	var face := Vector3(n.x, 0.0, n.y)
	var ring0: Array[Vector3] = []
	var ring1: Array[Vector3] = []
	for k in LOG_SIDES:
		var ang := TAU * float(k) / LOG_SIDES
		var off := face * cos(ang) + Vector3.UP * sin(ang)
		ring0.append(Vector3(c0.x, y0, c0.y) + off * r0)
		ring1.append(Vector3(c1.x, y1, c1.y) + off * r1)
	for k in LOG_SIDES:
		var k2 := (k + 1) % LOG_SIDES
		var mid_ang := TAU * (float(k) + 0.5) / LOG_SIDES
		var normal := face * cos(mid_ang) + Vector3.UP * sin(mid_ang)
		# Facets that face into the wall are never seen.
		if normal.dot(face) < -0.7:
			continue
		# Baked falloff away from the front so the sun-lit top does not read as
		# one flat pale board and the underside goes dark.
		var lit := 0.55 + 0.35 * normal.dot(face) - 0.25 * maxf(-normal.y, 0.0)
		shell.quad_out("timber", ring0[k], ring1[k], ring1[k2], ring0[k2], shade * lit, normal)
	var side := Vector3(dir.x, 0.0, dir.y)
	if cap_start:
		_cap(shell, ring0, -side)
	if cap_end:
		_cap(shell, ring1, side)


static func _cap(shell, ring: Array[Vector3], out: Vector3) -> void:
	var centre := Vector3.ZERO
	for p in ring:
		centre += p
	centre /= float(ring.size())
	for k in ring.size():
		shell.tri_out("timber", centre, ring[k], ring[(k + 1) % ring.size()], END_GRAIN_TINT, out)


## Triangle fan over an end profile (wall foot, front foot, belly, shoulder, top).
static func _end_fan(shell, pts: Array, out: Vector3, color: Color) -> void:
	for k in range(1, pts.size() - 1):
		shell.tri_out("stone", pts[0], pts[k], pts[k + 1], color, out)


static func _at(
	p: Vector2, dir: Vector2, n: Vector2, proud: float, y: float, nudge: Vector3
) -> Vector3:
	var q := p + dir * nudge.x + n * (proud + nudge.z)
	return Vector3(q.x, y + nudge.y, q.y)


static func _ground(ground_at: Callable, fallback: float, p: Vector2) -> float:
	return float(ground_at.call(p)) if ground_at.is_valid() else fallback


## Metres (from, to) along edge a + dir * s hidden by the door span
## door_a..door_b, or (0, 0) when the door is not on this edge.
static func _door_cut(
	a: Vector2, dir: Vector2, length: float, n: Vector2, door_a: Vector2, door_b: Vector2
) -> Vector2:
	if door_a == Vector2.INF:
		return Vector2.ZERO
	var door_dir := (door_b - door_a).normalized()
	if absf(door_dir.dot(dir)) < 0.95:
		return Vector2.ZERO
	if absf(((door_a + door_b) * 0.5 - a).dot(n)) > 0.3:
		return Vector2.ZERO
	var ta := (door_a - a).dot(dir)
	var tb := (door_b - a).dot(dir)
	return Vector2(clampf(minf(ta, tb), 0.0, length), clampf(maxf(ta, tb), 0.0, length))


## Unit normal of a ring edge (direction `dir`, through `p`) pointing outside.
static func _outward(ring: PackedVector2Array, p: Vector2, dir: Vector2) -> Vector2:
	var n := Vector2(-dir.y, dir.x)
	if Geometry2D.is_point_in_polygon(p + n * 0.05, ring):
		n = -n
	return n

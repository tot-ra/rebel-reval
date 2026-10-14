extends RefCounted

## R-1760: small architectural depth on city houses (CityBuildingBuilder):
## verge (barge) boards along the gable rakes of board, shingle and tile
## roofs and dressed limestone quoins at the outer corners of stone houses (the
## footing under every wall moved to CityFooting, R-1933). All geometry goes
## into the building's own Shell under existing material keys ("timber",
## "stone"), so chunk merging, the interior cutaway split and the roof lift keep
## working unchanged.
##
## Canon: timber houses on a stone footing and dressed quoins on ashlar-cornered
## limestone houses are `plausible composite` (docs/CANON.md, building
## families); no decorative Fachwerk is added.

const VERGE_DROP := 0.28
const VERGE_RISE := 0.05
const VERGE_THICK := 0.04
const QUOIN_COURSE := 0.34
const QUOIN_JOINT := 0.018
const QUOIN_LONG := 0.52
const QUOIN_SHORT := 0.3
const QUOIN_PROUD := 0.035
const QUOIN_TINT := Color(1.1, 1.08, 1.02)
const VERGE_TINT := Color(0.78, 0.74, 0.7)


## True for an outline edge that runs across the ridge (a gable rake).
static func is_rake(p0: Vector2, p1: Vector2, ridge_dir: Vector2) -> bool:
	var e := p1 - p0
	return e.length() > 0.3 and absf(e.normalized().dot(ridge_dir)) < 0.35


## One verge board hanging under the roof edge from p0 to p1 (cover top at
## heights h0, h1), set `out` metres beyond the cut line along `side`.
static func verge_board(
	roof, p0: Vector2, p1: Vector2, h0: float, h1: float, side: Vector2, out: float
) -> void:
	var o := side * out
	var i := side * (out - VERGE_THICK)
	var face := Vector3(side.x, 0.0, side.y)
	var t0 := Vector3(p0.x + o.x, h0 + VERGE_RISE, p0.y + o.y)
	var t1 := Vector3(p1.x + o.x, h1 + VERGE_RISE, p1.y + o.y)
	var b0 := Vector3(t0.x, h0 - VERGE_DROP, t0.z)
	var b1 := Vector3(t1.x, h1 - VERGE_DROP, t1.z)
	roof.quad_out("timber", b0, b1, t1, t0, VERGE_TINT, face)
	var ti0 := Vector3(p0.x + i.x, t0.y, p0.y + i.y)
	var ti1 := Vector3(p1.x + i.x, t1.y, p1.y + i.y)
	roof.quad_out("timber", t0, t1, ti1, ti0, VERGE_TINT * 1.05, Vector3.UP)
	var bi0 := Vector3(ti0.x, b0.y, ti0.z)
	var bi1 := Vector3(ti1.x, b1.y, ti1.z)
	roof.quad_out("timber", b0, b1, bi1, bi0, VERGE_TINT * 0.6, Vector3.DOWN)
	# Inner face: seen from the street under a steep gable.
	roof.quad_out("timber", bi0, bi1, ti1, ti0, VERGE_TINT * 0.7, -face)


## Alternating long and short dressed blocks up every convex outer corner of
## the raw (unfilleted) footprint, from `y0` to `y1`.
static func quoins(shell, ring: PackedVector2Array, y0: float, y1: float) -> int:
	var blocks := 0
	var count := ring.size()
	if count < 3 or y1 - y0 < QUOIN_COURSE:
		return 0
	var courses := int((y1 - y0) / QUOIN_COURSE)
	for idx in count:
		var p := ring[idx]
		var a := ring[(idx - 1 + count) % count]
		var c := ring[(idx + 1) % count]
		var la := p.distance_to(a)
		var lc := p.distance_to(c)
		if la < 1.4 or lc < 1.4:
			continue
		var d1 := (a - p) / la
		var d2 := (c - p) / lc
		# Only real corners (roughly 60-120 deg), not shallow kinks.
		if absf(d1.dot(d2)) > 0.5:
			continue
		var n1 := _outward(ring, p, d1)
		var n2 := _outward(ring, p, d2)
		if not Geometry2D.is_point_in_polygon(p - (n1 + n2).normalized() * 0.3, ring):
			continue  # re-entrant corner: no quoins
		var oc := p + (n1 + n2) * QUOIN_PROUD
		for k in courses:
			var lo := y0 + float(k) * QUOIN_COURSE + QUOIN_JOINT * 0.5
			var hi := lo + QUOIN_COURSE - QUOIN_JOINT
			var long_first := k % 2 == 0
			_quoin_face(shell, oc, p, d1, n1, QUOIN_LONG if long_first else QUOIN_SHORT, lo, hi)
			_quoin_face(shell, oc, p, d2, n2, QUOIN_SHORT if long_first else QUOIN_LONG, lo, hi)
			blocks += 1
	return blocks


static func _quoin_face(
	shell, oc: Vector2, p: Vector2, d: Vector2, n: Vector2, length: float, lo: float, hi: float
) -> void:
	var far := p + d * length + n * QUOIN_PROUD
	var root := p + d * length
	var face := Vector3(n.x, 0.0, n.y)
	shell.quad_out(
		"stone", Vector3(oc.x, lo, oc.y), Vector3(far.x, lo, far.y),
		Vector3(far.x, hi, far.y), Vector3(oc.x, hi, oc.y), QUOIN_TINT, face
	)
	# Block end and top catch the light, so the corner reads as stacked stones.
	shell.quad_out(
		"stone", Vector3(root.x, lo, root.y), Vector3(far.x, lo, far.y),
		Vector3(far.x, hi, far.y), Vector3(root.x, hi, root.y), QUOIN_TINT * 0.92,
		Vector3(d.x, 0.0, d.y)
	)
	shell.quad_out(
		"stone", Vector3(oc.x, hi, oc.y), Vector3(far.x, hi, far.y),
		Vector3(root.x, hi, root.y), Vector3(p.x, hi, p.y), QUOIN_TINT * 1.04, Vector3.UP
	)


## Unit normal of a ring edge (direction `dir`, through `p`) pointing outside.
static func _outward(ring: PackedVector2Array, p: Vector2, dir: Vector2) -> Vector2:
	var n := Vector2(-dir.y, dir.x)
	var probe := p + dir * 0.05 + n * 0.05
	if Geometry2D.is_point_in_polygon(probe, ring):
		n = -n
	return n

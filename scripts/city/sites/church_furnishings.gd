class_name CityChurchFurnishings
extends RefCounted

## Furnishings shared by the city's church sites (ADR 0032), in site-local
## metres: plank floors, oak benches, the font, altars with a winged retable,
## the rood, a pulpit, saint figures and hanging candle crowns. Forms follow
## the maintainer's period rule: where the 1343 state is unrecorded, a plainer
## form of what the churches have later.

const Kit := preload("res://scripts/city/sites/site_kit.gd")
const GILT := Color(0.78, 0.6, 0.24)
const BRASS := Color(0.72, 0.55, 0.25)
const RED := Color(0.58, 0.12, 0.1)
const BLUE := Color(0.16, 0.24, 0.5)
## Retable wings stand open this far from the shrine plane.
const WING_OPEN := deg_to_rad(55.0)
## Metres of board one repeat of the "board" strip covers along the grain and
## across it (the 1024x128 plate keeps its 8:1 aspect).
const BOARD_GRAIN_M := 2.0
const BOARD_WIDTH_M := 0.25
## Bench joinery in bench-local metres (x towards the altar, y up from the floor).
const BENCH_END_T := 0.055
const BENCH_SEAT_Y := 0.45
const BENCH_SEAT_T := 0.045
const BENCH_SEAT_X := Vector2(-0.22, 0.2)
const BENCH_BACK_X := Vector2(-0.27, -0.235)
const BENCH_BACK_TOP := 0.97
## Longest span between two supports before a middle trestle carries the seat.
const BENCH_SPAN := 2.2


## Wide boards along the nave, each its own tone, with dark joints.
static func planks(
	shell: CityBuildingBuilder.Shell, r: Rect2, y: float, rng: RandomNumberGenerator
) -> void:
	var z := r.position.y
	while z < r.end.y - 0.01:
		var w := minf(rng.randf_range(0.26, 0.36), r.end.y - z)
		var x := r.position.x - rng.randf_range(0.0, 3.0)
		while x < r.end.x - 0.01:
			var l := rng.randf_range(3.0, 6.0)
			var x0 := maxf(x, r.position.x)
			var x1 := minf(x + l, r.end.x)
			var tone := Color.WHITE * rng.randf_range(0.82, 1.05)
			tone.a = 1.0
			shell.quad_out(
				"planks",
				Vector3(x0 + 0.004, y, z + 0.006),
				Vector3(x1 - 0.004, y, z + 0.006),
				Vector3(x1 - 0.004, y, z + w - 0.006),
				Vector3(x0 + 0.004, y, z + w - 0.006),
				tone,
				Vector3.UP
			)
			x += l
		z += w
	shell.quad_out(
		"dark",
		Vector3(r.position.x, y - 0.008, r.position.y),
		Vector3(r.end.x, y - 0.008, r.position.y),
		Vector3(r.end.x, y - 0.008, r.end.y),
		Vector3(r.position.x, y - 0.008, r.end.y),
		Color(0.25, 0.2, 0.16),
		Vector3.UP
	)


## Plain oak bench facing the altar (+x), joined like the later pews in a
## simpler 14th-century form: two shaped end boards (arched cut between the
## feet, a low arm, the back post rising to a rounded head), a seat of two
## boards housed into them, a two-board back under a capping rail, an apron
## under the seat front, and a middle trestle on long benches. Every board
## gets UVs along its own length so the grain runs the way it was sawn.
static func bench(shell: CityBuildingBuilder.Shell, at: Vector3, length: float) -> Array[AABB]:
	var z0 := at.z - length * 0.5
	var z1 := at.z + length * 0.5
	var zi0 := z0 + BENCH_END_T
	var zi1 := z1 - BENCH_END_T
	var oak := Kit.OAK_DARK
	var seed_value := absi(hash(Vector2(at.x, at.z)))
	var tone := func(k: int) -> Color:
		var c := oak * (0.9 + 0.2 * float((seed_value >> (k * 3)) % 8) / 7.0)
		c.a = 1.0
		return c
	var slide := func(k: int) -> float:
		return float((seed_value >> (k * 2)) % 97) * 0.037
	# Board corners carry absolute z (z0..z1): the base only places x and y.
	var b := Vector3(at.x, at.y, 0.0)
	var top := BENCH_SEAT_Y
	var seat_lo := top - BENCH_SEAT_T
	# Seat: two boards with a hairline gap, overhanging the front a little.
	var mid := (BENCH_SEAT_X.x + BENCH_SEAT_X.y) * 0.5
	_board(
		shell,
		b + Vector3(BENCH_SEAT_X.x, seat_lo, zi0),
		b + Vector3(mid - 0.006, top, zi1),
		2,
		tone.call(0),
		slide.call(0)
	)
	_board(
		shell,
		b + Vector3(mid + 0.006, seat_lo, zi0),
		b + Vector3(BENCH_SEAT_X.y + 0.02, top, zi1),
		2,
		tone.call(1),
		slide.call(1)
	)
	# Apron under the seat front, set back from the edge.
	_board(
		shell,
		b + Vector3(BENCH_SEAT_X.y - 0.06, seat_lo - 0.11, zi0),
		b + Vector3(BENCH_SEAT_X.y - 0.035, seat_lo, zi1),
		2,
		tone.call(2),
		slide.call(2)
	)
	# Back: two horizontal boards and a capping rail, housed in the back posts.
	_board(
		shell,
		b + Vector3(BENCH_BACK_X.x, 0.55, zi0),
		b + Vector3(BENCH_BACK_X.y, 0.73, zi1),
		2,
		tone.call(3),
		slide.call(3)
	)
	_board(
		shell,
		b + Vector3(BENCH_BACK_X.x, 0.745, zi0),
		b + Vector3(BENCH_BACK_X.y, 0.93, zi1),
		2,
		tone.call(4),
		slide.call(4)
	)
	_board(
		shell,
		b + Vector3(BENCH_BACK_X.x - 0.015, 0.93, zi0),
		b + Vector3(BENCH_BACK_X.y + 0.015, BENCH_BACK_TOP, zi1),
		2,
		tone.call(5),
		slide.call(5)
	)
	_bench_end(shell, b, z0, tone.call(6), true)
	_bench_end(shell, b, zi1, tone.call(7), true)
	# Middle trestles: plain boards under the seat, tenoned into the back.
	var spans := maxi(1, ceili((zi1 - zi0) / BENCH_SPAN))
	for k in range(1, spans):
		var zc := lerpf(zi0, zi1, float(k) / spans) - BENCH_END_T * 0.5
		_bench_end(shell, b, zc, tone.call(8 + k), false)
	# Seat and back shade the window light (ChurchSunlight occluders); the end
	# boards are too slim to matter.
	return [
		AABB(
			b + Vector3(BENCH_SEAT_X.x, seat_lo, z0),
			Vector3(BENCH_SEAT_X.y + 0.02 - BENCH_SEAT_X.x, BENCH_SEAT_T, length)
		),
		AABB(
			b + Vector3(BENCH_BACK_X.x, 0.55, z0),
			Vector3(BENCH_BACK_X.y - BENCH_BACK_X.x, BENCH_BACK_TOP - 0.55, length)
		),
	]


## Bench end board (or, with `full` false, a middle trestle that stops under
## the seat and back), one plank thick from `z`, grain running up.
static func _bench_end(
	shell: CityBuildingBuilder.Shell, b: Vector3, z: float, color: Color, full: bool
) -> void:
	var pts := PackedVector2Array()
	var back := BENCH_BACK_X.x - 0.05
	pts.append(Vector2(back, 0.0))
	pts.append(Vector2(-0.17, 0.0))
	# Arched cut between the feet.
	for j in range(1, 8):
		var a := PI - PI * j / 8.0
		pts.append(Vector2(-0.015 + cos(a) * 0.155, sin(a) * 0.13))
	pts.append(Vector2(0.14, 0.0))
	var front := BENCH_SEAT_X.y + 0.03 if full else BENCH_SEAT_X.y - 0.035
	pts.append(Vector2(front, 0.0))
	if full:
		# Low arm with a rounded front, sweeping up into the back post.
		pts.append(Vector2(front, 0.6))
		for j in range(1, 4):
			var a := PI * 0.5 * j / 4.0
			pts.append(Vector2(front - 0.05 + cos(a) * 0.05, 0.6 + sin(a) * 0.05))
		pts.append(Vector2(0.0, 0.65))
		for j in range(1, 6):
			var t := float(j) / 6.0
			var p0 := Vector2(0.0, 0.65)
			var p1 := Vector2(BENCH_BACK_X.y + 0.02, 0.66)
			var p2 := Vector2(BENCH_BACK_X.y + 0.01, 0.92)
			pts.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))
		# Rounded head of the back post.
		var head_c := Vector2((back + BENCH_BACK_X.y + 0.01) * 0.5, BENCH_BACK_TOP)
		var head_r := (BENCH_BACK_X.y + 0.01 - back) * 0.5
		for j in 7:
			var a := PI * j / 6.0
			pts.append(head_c + Vector2(cos(a) * head_r, sin(a) * head_r * 0.8))
	else:
		pts.append(Vector2(front, BENCH_SEAT_Y - BENCH_SEAT_T))
		pts.append(Vector2(BENCH_BACK_X.y, BENCH_SEAT_Y - BENCH_SEAT_T))
		pts.append(Vector2(BENCH_BACK_X.y, 0.55))
		pts.append(Vector2(back, 0.55))
	var tris := Geometry2D.triangulate_polygon(pts)
	var z1 := z + BENCH_END_T
	var uv := func(p: Vector2) -> Vector2:
		return Vector2(p.y / BOARD_GRAIN_M, p.x / BOARD_WIDTH_M)
	for side: float in [z, z1]:
		var out := Vector3(0, 0, -1 if side == z else 1)
		for t in range(0, tris.size(), 3):
			var p0 := pts[tris[t]]
			var p1 := pts[tris[t + 1]]
			var p2 := pts[tris[t + 2]]
			shell.tri_out(
				"board",
				b + Vector3(p0.x, p0.y, side),
				b + Vector3(p1.x, p1.y, side),
				b + Vector3(p2.x, p2.y, side),
				color,
				out,
				uv.call(p0),
				uv.call(p1),
				uv.call(p2)
			)
	# Sawn edges round the profile.
	var ccw := Geometry2D.is_polygon_clockwise(pts) == false
	for k in pts.size():
		var p: Vector2 = pts[k]
		var q: Vector2 = pts[(k + 1) % pts.size()]
		var e := q - p
		var n2 := Vector2(e.y, -e.x) if ccw else Vector2(-e.y, e.x)
		var out := Vector3(n2.x, n2.y, 0.0)
		var ua := Vector2((p.x + p.y) / BOARD_GRAIN_M, z / BOARD_WIDTH_M)
		var ub := Vector2((q.x + q.y) / BOARD_GRAIN_M, z / BOARD_WIDTH_M)
		var dz := Vector2(0.0, BENCH_END_T / BOARD_WIDTH_M)
		var pa := b + Vector3(p.x, p.y, z)
		var pb := b + Vector3(q.x, q.y, z)
		var pc := b + Vector3(q.x, q.y, z1)
		var pd := b + Vector3(p.x, p.y, z1)
		shell.tri_out("board", pa, pb, pc, color, out, ua, ub, ub + dz)
		shell.tri_out("board", pa, pc, pd, color, out, ua, ub + dz, ua + dz)


## Box-shaped sawn board from `lo` to `hi` whose grain runs along `axis`
## (0 x, 1 y, 2 z): each face gets UVs with U along the grain in metres of
## the "board" strip, `slide` shifting it so neighbouring boards differ.
static func _board(
	shell: CityBuildingBuilder.Shell,
	lo: Vector3,
	hi: Vector3,
	axis: int,
	color: Color,
	slide: float
) -> void:
	var c := (lo + hi) * 0.5
	var p := [
		Vector3(lo.x, lo.y, lo.z),
		Vector3(hi.x, lo.y, lo.z),
		Vector3(hi.x, hi.y, lo.z),
		Vector3(lo.x, hi.y, lo.z),
		Vector3(lo.x, lo.y, hi.z),
		Vector3(hi.x, lo.y, hi.z),
		Vector3(hi.x, hi.y, hi.z),
		Vector3(lo.x, hi.y, hi.z),
	]
	for f: Array in [
		[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]
	]:
		var q: Array[Vector3] = [p[f[0]], p[f[1]], p[f[2]], p[f[3]]]
		var out: Vector3 = (q[0] + q[1] + q[2] + q[3]) * 0.25 - c
		var normal_axis := Vector3(absf(out.x), absf(out.y), absf(out.z)).max_axis_index()
		# Across-grain coordinate: the face's other in-plane axis (on the end
		# grain both in-plane axes are across the grain).
		var across := 3 - axis - normal_axis if normal_axis != axis else (axis + 1) % 3
		var along := axis if normal_axis != axis else (axis + 2) % 3
		var uvs: Array[Vector2] = []
		for v: Vector3 in q:
			uvs.append(
				Vector2((v[along] - lo[along]) / BOARD_GRAIN_M + slide, v[across] / BOARD_WIDTH_M)
			)
		shell.tri_out("board", q[0], q[1], q[2], color, out, uvs[0], uvs[1], uvs[2])
		shell.tri_out("board", q[0], q[2], q[3], color, out, uvs[0], uvs[2], uvs[3])


static func font(shell: CityBuildingBuilder.Shell, at: Vector3) -> void:
	CitySiteProps._box(
		shell, "ashlar", at + Vector3(-0.55, 0.0, -0.55), at + Vector3(0.55, 0.15, 0.55), Kit.ASHLAR
	)
	Kit.pillar(shell, at + Vector3(0, 0.15, 0), 0.18, 0.45)
	Kit.pillar(shell, at + Vector3(0, 0.6, 0), 0.45, 0.38)
	CitySiteProps._box(
		shell,
		"timber",
		at + Vector3(-0.42, 0.98, -0.42),
		at + Vector3(0.42, 1.04, 0.42),
		Kit.OAK_DARK
	)
	Kit.bar(shell, "dark", at + Vector3(0, 1.04, 0), at + Vector3(0, 1.3, 0), 0.04, Kit.IRON)


## Stone mensa with linen, a red frontal, candlesticks and a cross; the high
## altar carries a painted and gilded winged retable (a plain form of the
## later Notke altar): a raised shrine with saints under canopies, two
## painted wings, a cresting.
static func altar(shell: CityBuildingBuilder.Shell, at: Vector3, width: float, high: bool) -> void:
	var h := 1.02
	CitySiteProps._box(
		shell,
		"ashlar",
		at + Vector3(-0.55, 0.0, -width * 0.5),
		at + Vector3(0.55, h - 0.05, width * 0.5),
		Kit.ASHLAR
	)
	CitySiteProps._box(
		shell,
		"limewash",
		at + Vector3(-0.57, h - 0.05, -width * 0.5 - 0.02),
		at + Vector3(0.57, h, width * 0.5 + 0.02),
		Color(0.95, 0.93, 0.86)
	)
	CitySiteProps._box(
		shell,
		"limewash",
		at + Vector3(-0.58, 0.15, -width * 0.45),
		at + Vector3(-0.56, h - 0.06, width * 0.45),
		RED
	)
	for z: float in [-width * 0.35, width * 0.35]:
		Kit.bar(shell, "dark", at + Vector3(0.0, h, z), at + Vector3(0.0, h + 0.4, z), 0.04, BRASS)
		CitySiteProps._box(
			shell,
			"limewash",
			at + Vector3(-0.025, h + 0.4, z - 0.025),
			at + Vector3(0.025, h + 0.62, z + 0.025),
			Color(0.95, 0.9, 0.75)
		)
	Kit.bar(shell, "dark", at + Vector3(0.15, h, 0), at + Vector3(0.15, h + 0.65, 0), 0.04, BRASS)
	Kit.bar(
		shell,
		"dark",
		at + Vector3(0.15, h + 0.45, -0.17),
		at + Vector3(0.15, h + 0.45, 0.17),
		0.04,
		BRASS
	)
	if not high:
		CitySiteProps._box(
			shell, "limewash", at + Vector3(0.4, h, -0.5), at + Vector3(0.45, h + 0.9, 0.5), BLUE
		)
		return
	retable(shell, Vector3(at.x + 0.42, at.y + h, at.z))


## Winged retable (a plain, smaller form of the later carved altar): a predella
## with painted half-figures, a gilded shrine of five saints in niches under
## pointed canopies, two open wings with painted scenes, and a cresting of
## gilt finials. Faces -x (towards the nave).
static func retable(shell: CityBuildingBuilder.Shell, at: Vector3) -> void:
	var sw := 2.0
	var sh := 1.7
	var depth := 0.32
	var x := at.x
	var y0 := at.y
	var z := at.z
	var gold := GILT
	var gold_dark := GILT * 0.7
	gold_dark.a = 1.0
	# Predella: a low painted box with three arched fields.
	CitySiteProps._box(
		shell,
		"timber",
		Vector3(x, y0, z - sw * 0.5),
		Vector3(x + depth, y0 + 0.42, z + sw * 0.5),
		gold_dark
	)
	for k in 3:
		var zc := z - sw * 0.32 + k * sw * 0.32
		CitySiteProps._box(
			shell,
			"limewash",
			Vector3(x - 0.012, y0 + 0.08, zc - 0.26),
			Vector3(x, y0 + 0.34, zc + 0.26),
			BLUE * 0.85
		)
		CitySiteProps._box(
			shell,
			"limewash",
			Vector3(x - 0.02, y0 + 0.12, zc - 0.08),
			Vector3(x - 0.01, y0 + 0.3, zc + 0.08),
			Color(0.85, 0.7, 0.55)
		)
	var sy := y0 + 0.42
	# Shrine case: back, sides, floor, deep enough for figures.
	CitySiteProps._box(
		shell,
		"timber",
		Vector3(x + depth - 0.06, sy, z - sw * 0.5),
		Vector3(x + depth, sy + sh, z + sw * 0.5),
		gold
	)
	CitySiteProps._box(
		shell,
		"limewash",
		Vector3(x + depth - 0.07, sy + 0.05, z - sw * 0.47),
		Vector3(x + depth - 0.06, sy + sh - 0.05, z + sw * 0.47),
		BLUE * 0.7
	)
	for zs: float in [z - sw * 0.5, z + sw * 0.5 - 0.06]:
		CitySiteProps._box(
			shell, "timber", Vector3(x, sy, zs), Vector3(x + depth, sy + sh, zs + 0.06), gold
		)
	# Five niches: slender gilt shafts, saints, pointed canopies with crockets.
	var niches := 5
	var nw := sw / niches
	for k in niches:
		var z0 := z - sw * 0.5 + k * nw
		var zc := z0 + nw * 0.5
		if k > 0:
			Kit.bar(
				shell,
				"timber",
				Vector3(x + 0.03, sy, z0),
				Vector3(x + 0.03, sy + sh - 0.1, z0),
				0.035,
				gold
			)
		var tall := 1.05 if k == 2 else 0.85
		var robe: Color = [RED, BLUE, Color(0.9, 0.85, 0.75), BLUE, RED][k]
		var mantle: Color = [GILT, RED, BLUE, RED, GILT][k]
		figure(shell, Vector3(x + 0.12, sy + 0.04, zc), tall, robe, mantle)
		# Canopy: a pointed arch band with a crocketed gable above it.
		var a0 := Vector3(x + 0.0, sy + 0.04 + tall + 0.15, z0 + 0.03)
		var a1 := Vector3(x + 0.0, sy + 0.04 + tall + 0.15, z0 + nw - 0.03)
		var apex := Vector3(x + 0.0, a0.y + nw * 0.55, zc)
		Kit.bar(shell, "timber", a0, apex, 0.03, gold)
		Kit.bar(shell, "timber", a1, apex, 0.03, gold)
		Kit.bar(shell, "timber", apex, apex + Vector3(0, 0.16, 0), 0.025, gold)
		for t: float in [0.3, 0.6]:
			CitySiteProps._box(
				shell,
				"timber",
				a0.lerp(apex, t) - Vector3(0.02, 0.0, 0.02),
				a0.lerp(apex, t) + Vector3(0.0, 0.05, 0.02),
				gold
			)
			CitySiteProps._box(
				shell,
				"timber",
				a1.lerp(apex, t) - Vector3(0.02, 0.0, 0.02),
				a1.lerp(apex, t) + Vector3(0.0, 0.05, 0.02),
				gold
			)
	# Cresting along the top of the shrine: pinnacles and fleurons.
	CitySiteProps._box(
		shell,
		"timber",
		Vector3(x - 0.02, sy + sh, z - sw * 0.5),
		Vector3(x + depth, sy + sh + 0.08, z + sw * 0.5),
		gold
	)
	for k in 11:
		var zc := z - sw * 0.5 + (k + 0.5) * sw / 11.0
		var top := sy + sh + (0.34 if k % 2 == 0 else 0.22)
		Kit.bar(
			shell,
			"timber",
			Vector3(x + 0.1, sy + sh + 0.08, zc),
			Vector3(x + 0.1, top, zc),
			0.04,
			gold
		)
		CitySiteProps._box(
			shell,
			"timber",
			Vector3(x + 0.06, top, zc - 0.05),
			Vector3(x + 0.14, top + 0.07, zc + 0.05),
			gold
		)
	# Wings hinged on the shrine's front edges, swung open towards the nave
	# (x decreasing) by WING_OPEN; each has two painted scenes on its inner
	# face: figures on a gold or blue ground.
	for side: float in [-1.0, 1.0]:
		var hinge := Vector2(x, z + side * sw * 0.5)
		var dir := Vector2(-sin(WING_OPEN), side * cos(WING_OPEN))
		var tip := hinge + dir * sw * 0.5
		var n3 := Vector3(-dir.y, 0, dir.x) * side  # inner face normal (towards the shrine axis)
		if n3.x > 0.0:
			n3 = -n3
		for row in 2:
			var ry := sy + 0.06 + row * sh * 0.5
			var ground: Color = GILT if (row + int(side > 0)) % 2 == 0 else BLUE * 0.8
			panel(shell, hinge, tip, ry, ry + sh * 0.5 - 0.1, n3, ground)
			for f in 2:
				var t := 0.3 + f * 0.4
				var fp := hinge.lerp(tip, t)
				var robe2: Color = [RED, BLUE, Color(0.2, 0.4, 0.25), RED][
					(row * 2 + f + int(side > 0)) % 4
				]
				var off := n3 * 0.012
				var half := dir * 0.1
				panel(shell, fp - half, fp + half, ry + 0.06, ry + sh * 0.5 - 0.36, n3, robe2, off)
				panel(
					shell,
					fp - half * 0.55,
					fp + half * 0.55,
					ry + sh * 0.5 - 0.36,
					ry + sh * 0.5 - 0.24,
					n3,
					Color(0.85, 0.7, 0.55),
					off
				)
		# Gilt frame: the wing's outer board.
		panel(shell, hinge, tip, sy, sy + sh, -n3, GILT * 0.8, -n3 * 0.02)


## A flat painted panel between two plan points from y0 to y1, facing `n`.
static func panel(
	shell: CityBuildingBuilder.Shell,
	a: Vector2,
	b: Vector2,
	y0: float,
	y1: float,
	n: Vector3,
	color: Color,
	off := Vector3.ZERO
) -> void:
	shell.quad_out(
		"limewash",
		Vector3(a.x, y0, a.y) + off,
		Vector3(b.x, y0, b.y) + off,
		Vector3(b.x, y1, b.y) + off,
		Vector3(a.x, y1, a.y) + off,
		color,
		n
	)


## A carved, painted saint: robe, mantle, head with a gilt halo, on a plinth.
static func figure(
	shell: CityBuildingBuilder.Shell, at: Vector3, tall: float, robe: Color, mantle: Color
) -> void:
	var w := 0.13
	CitySiteProps._box(
		shell, "timber", at + Vector3(-0.08, 0.0, -0.12), at + Vector3(0.08, 0.06, 0.12), GILT
	)
	# Robe widening to the hem, in three stacked blocks.
	for k in 3:
		var y0 := 0.06 + k * tall * 0.26
		var hw := w * (1.15 - k * 0.15)
		CitySiteProps._box(
			shell,
			"limewash",
			at + Vector3(-0.07, y0, -hw),
			at + Vector3(0.07, y0 + tall * 0.26, hw),
			robe
		)
	CitySiteProps._box(
		shell,
		"limewash",
		at + Vector3(-0.08, 0.06 + tall * 0.35, -w * 0.95),
		at + Vector3(-0.05, 0.06 + tall * 0.78, w * 0.95),
		mantle
	)
	var head := at + Vector3(0, 0.06 + tall * 0.78, 0)
	CitySiteProps._box(
		shell,
		"limewash",
		head + Vector3(-0.055, 0.0, -0.05),
		head + Vector3(0.055, 0.13, 0.05),
		Color(0.86, 0.72, 0.58)
	)
	for j in 10:
		var a0 := TAU * j / 10.0
		var a1 := TAU * (j + 1) / 10.0
		var c := head + Vector3(0.05, 0.08, 0)
		shell.tri_out(
			"timber",
			c,
			c + Vector3(0, sin(a0) * 0.1, cos(a0) * 0.1),
			c + Vector3(0, sin(a1) * 0.1, cos(a1) * 0.1),
			GILT,
			Vector3(1, 0, 0)
		)


## A painted saint on a stone console against a pier face, facing `out`.
static func statue(
	shell: CityBuildingBuilder.Shell, at: Vector3, out: Vector3, robe: Color
) -> void:
	var o := out * 0.3
	CitySiteProps._box(
		shell,
		"ashlar",
		at + Vector3(-0.25, -0.2, -0.0) + Vector3(0, 0, minf(o.z, 0.0)),
		at + Vector3(0.25, 0.0, 0.0) + Vector3(0, 0, maxf(o.z, 0.0)),
		Kit.ASHLAR
	)
	var c := at + o * 0.5
	CitySiteProps._box(
		shell, "limewash", c + Vector3(-0.17, 0.0, -0.12), c + Vector3(0.17, 1.05, 0.12), robe
	)
	CitySiteProps._box(
		shell,
		"limewash",
		c + Vector3(-0.1, 1.05, -0.09),
		c + Vector3(0.1, 1.28, 0.09),
		Color(0.85, 0.7, 0.55)
	)
	CitySiteProps._box(
		shell, "timber", c + Vector3(-0.2, 1.3, -0.04), c + Vector3(0.2, 1.33, 0.04), GILT
	)


## Plain timber pulpit on the north face of a pier: a polygonal tub on a post,
## a stair along the pier, a sounding board above.
## `stair_z` is the face of the pier the stair runs along; `floor_y` the floor.
static func pulpit(
	shell: CityBuildingBuilder.Shell, at: Vector3, stair_z: float, floor_y: float
) -> void:
	var floor_h := 1.9
	Kit.bar(shell, "timber", at, at + Vector3(0, floor_h, 0), 0.22, Kit.OAK_DARK)
	var c := at + Vector3(0, floor_h, -0.2)
	for j in 6:
		var a0 := PI + PI * j / 6.0
		var a1 := PI + PI * (j + 1) / 6.0
		var p0 := Vector3(cos(a0) * 0.65, 0, sin(a0) * 0.55)
		var p1 := Vector3(cos(a1) * 0.65, 0, sin(a1) * 0.55)
		var n := (p0 + p1).normalized()
		shell.quad_out(
			"timber",
			c + p0,
			c + p1,
			c + p1 + Vector3(0, 1.05, 0),
			c + p0 + Vector3(0, 1.05, 0),
			Kit.OAK,
			n
		)
		shell.quad_out(
			"limewash",
			c + p0 * 0.98 + Vector3(0, 0.25, 0) + n * 0.01,
			c + p1 * 0.98 + Vector3(0, 0.25, 0) + n * 0.01,
			c + p1 * 0.98 + Vector3(0, 0.85, 0) + n * 0.01,
			c + p0 * 0.98 + Vector3(0, 0.85, 0) + n * 0.01,
			RED if j % 2 == 0 else BLUE,
			n
		)
		shell.tri_out("timber", c, c + p0, c + p1, Kit.OAK_DARK, Vector3.DOWN)
	CitySiteProps._box(
		shell, "timber", c + Vector3(-0.75, 3.2, -0.6), c + Vector3(0.75, 3.3, 0.25), Kit.OAK_DARK
	)
	for k in 8:
		var y := floor_y + 0.24 * (k + 1)
		var x := at.x + 0.9 + 0.22 * k
		CitySiteProps._box(
			shell,
			"timber",
			Vector3(x - 0.12, y - 0.04, stair_z - 0.75),
			Vector3(x + 0.12, y, stair_z - 0.05),
			Kit.OAK
		)


## Rood beam across the triumphal arch with the crucifix between Mary and John.
static func rood(
	shell: CityBuildingBuilder.Shell, x: float, y: float, z0: float, z1: float
) -> void:
	var zc := (z0 + z1) * 0.5
	CitySiteProps._box(
		shell,
		"timber",
		Vector3(x - 0.16, y - 0.28, z0),
		Vector3(x + 0.16, y, z1),
		Color(0.45, 0.16, 0.11)
	)
	Kit.bar(shell, "timber", Vector3(x, y, zc), Vector3(x, y + 2.3, zc), 0.15, Kit.OAK_DARK)
	Kit.bar(
		shell,
		"timber",
		Vector3(x, y + 1.7, zc - 0.85),
		Vector3(x, y + 1.7, zc + 0.85),
		0.13,
		Kit.OAK_DARK
	)
	CitySiteProps._box(
		shell,
		"limewash",
		Vector3(x - 0.13, y + 0.6, zc - 0.13),
		Vector3(x - 0.08, y + 1.75, zc + 0.13),
		Color(0.82, 0.74, 0.62)
	)
	CitySiteProps._box(
		shell,
		"limewash",
		Vector3(x - 0.13, y + 1.62, zc - 0.7),
		Vector3(x - 0.08, y + 1.72, zc + 0.7),
		Color(0.82, 0.74, 0.62)
	)
	for z: float in [zc - 1.6, zc + 1.6]:
		CitySiteProps._box(
			shell,
			"limewash",
			Vector3(x - 0.12, y, z - 0.2),
			Vector3(x + 0.12, y + 1.2, z + 0.2),
			BLUE if z < zc else RED
		)
		CitySiteProps._box(
			shell,
			"limewash",
			Vector3(x - 0.09, y + 1.2, z - 0.09),
			Vector3(x + 0.09, y + 1.38, z + 0.09),
			Color(0.85, 0.7, 0.55)
		)


## Hanging candle crowns: an iron ring with brass cups and candles on a chain
## from the ceiling (a plain form of the later brass chandeliers).
static func coronas(parent: Node3D, spots: Array, hang_y: float, top_y: float) -> void:
	var shell := CityBuildingBuilder.Shell.new()
	for spot: Vector2 in spots:
		var c := Vector3(spot.x, hang_y, spot.y)
		Kit.bar(shell, "dark", c, Vector3(spot.x, top_y, spot.y), 0.03, Kit.IRON)
		for j in 12:
			var a0 := TAU * j / 12.0
			var a1 := TAU * (j + 1) / 12.0
			Kit.bar(
				shell,
				"dark",
				c + Vector3(cos(a0) * 0.8, 0, sin(a0) * 0.8),
				c + Vector3(cos(a1) * 0.8, 0, sin(a1) * 0.8),
				0.05,
				BRASS
			)
		for j in 8:
			var a := TAU * j / 8.0
			var p := c + Vector3(cos(a) * 0.8, 0.02, sin(a) * 0.8)
			Kit.bar(shell, "dark", c + Vector3(0, 0.6, 0), p, 0.015, Kit.IRON)
			CitySiteProps._box(
				shell, "dark", p + Vector3(-0.05, 0, -0.05), p + Vector3(0.05, 0.04, 0.05), BRASS
			)
			CitySiteProps._box(
				shell,
				"limewash",
				p + Vector3(-0.02, 0.04, -0.02),
				p + Vector3(0.02, 0.24, 0.02),
				Color(0.96, 0.92, 0.78)
			)
	parent.add_child(Kit.mesh("Coronas", shell))


## Warm candle lights (OmniLight3D) at the given site-local points.
static func lights(node: Node3D, spots: Array) -> void:
	for spot: Vector3 in spots:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.72, 0.45)
		light.light_energy = 1.5
		light.omni_range = 10.0
		light.position = spot
		CityDoors.keep_indoors(light)
		node.add_child(light)


## Small plain wooden crucifix hung on a wall (obj.crucifix_wall has no model
## yet): `at` is the centre of the cross on the wall face, `into` the unit
## direction from the wall into the room. A dark oak cross with a pale corpus.
static func wall_crucifix(shell: CityBuildingBuilder.Shell, at: Vector3, into: Vector3) -> void:
	var side := Vector3.UP.cross(into).normalized()
	var off := into * 0.035
	var post := Vector3(0.035, 0.32, 0.035)
	var beam := Vector3(0.17, 0.03, 0.035)
	for half: Vector3 in [post, beam]:
		var h := side * half.x + Vector3.UP * half.y
		var y0 := at + off + Vector3.UP * (0.08 if half == beam else 0.0)
		CitySiteProps._box(
			shell,
			"timber",
			_lo(y0 - h - into * 0.035, y0 + h + into * 0.035),
			_hi(y0 - h - into * 0.035, y0 + h + into * 0.035),
			Kit.OAK_DARK * 0.8
		)
	var body := at + into * 0.08 + Vector3.UP * 0.01
	var bh := side * 0.03 + Vector3.UP * 0.14 + into * 0.012
	var pale := Color(0.82, 0.74, 0.62)
	CitySiteProps._box(shell, "limewash", _lo(body - bh, body + bh), _hi(body - bh, body + bh), pale)
	var arm := body + Vector3.UP * 0.07
	var ah := side * 0.13 + Vector3.UP * 0.018 + into * 0.012
	CitySiteProps._box(shell, "limewash", _lo(arm - ah, arm + ah), _hi(arm - ah, arm + ah), pale)


static func _lo(a: Vector3, b: Vector3) -> Vector3:
	return Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))


static func _hi(a: Vector3, b: Vector3) -> Vector3:
	return Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))

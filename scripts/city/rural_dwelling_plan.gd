extends RefCounted

## Plan of a 1343 smoke dwelling (R-1929, docs/SYSTEMS/FARMLAND.md "Rural dwelling
## plan"). Reads a building's `rural_plan` (written by rural_plan() in
## tools/city/build_reval_city_plan.py) and builds its structure, so the walls
## (CityBuildingBuilder), the collision (CityCollisionBuilder) and the furnished
## rooms (HouseholdLayout) all agree on one seam, one oven and one gate.
##
## - `smoke_cottage`: one heated log room, a stone heap oven in a back corner, no
##   chimney, no glazed window, one low door.
## - `barn_dwelling` (the elurehi): a log partition across the ridge axis splits a
##   heated bay (heap oven in its back corner, mouth to the front wall) from a
##   threshing bay that holds the outer door, a broad boarded gate on the yard
##   side and the low inner door to the warm room. No chambers (17th c.).

const SMOKE_COTTAGE := &"smoke_cottage"
const BARN_DWELLING := &"barn_dwelling"
## Outer door of every smoke dwelling (width, height): low, as the period's doors
## with their high sills were, but wider than Kalev's 1 m collision capsule.
const DOOR := Vector2(1.2, 1.75)
## Smoke-blackened logs, a dark beaten-earth floor in the heated room and the
## paler trodden clay of the threshing floor.
const SMOKED := Color(0.42, 0.36, 0.31)
const HEATED_FLOOR := Color(0.36, 0.3, 0.25)
const THRESHING_FLOOR := Color(0.74, 0.64, 0.5)
const STONE := Color(0.6, 0.58, 0.54)
const GATE_WOOD := Color(0.62, 0.52, 0.42)
## Smoke vent: a small dark hole high in the log wall, with a board shutter.
const VENT_SIZE := Vector2(0.34, 0.25)
## Oven heap height (m): low enough to read under the interior cutaway.
const OVEN_HEIGHT := 1.3


static func of(b: Dictionary) -> Dictionary:
	return b.get("rural_plan", {})


static func form(b: Dictionary) -> StringName:
	return StringName(String(of(b).get("form", "")))


static func is_barn(b: Dictionary) -> bool:
	return form(b) == BARN_DWELLING


## Unit direction along the ridge toward the heated end (barn-dwelling).
static func heated_dir(b: Dictionary) -> Vector2:
	var ra := float(b["ridge_angle"])
	return Vector2(cos(ra), sin(ra)) * float(of(b).get("heated_end", 1))


## Unit direction the front wall faces (gate side; the oven mouth looks there).
static func front_dir(b: Dictionary) -> Vector2:
	var plan := of(b)
	var angle: float = (
		float(plan["gate"]["at"][2]) if plan.has("gate") else float(plan["oven"]["mouth"])
	)
	return Vector2(cos(angle), sin(angle))


## The two points of the seam line (outside the walls at both ends).
static func seam_line(b: Dictionary) -> PackedVector2Array:
	var s: Array = of(b).get("seam", [])
	if s.size() < 2:
		return PackedVector2Array()
	return PackedVector2Array([Vector2(s[0][0], s[0][1]), Vector2(s[1][0], s[1][1])])


## Where the seam crosses `inner` (the room outline): [a, c], or empty.
static func seam_span(b: Dictionary, inner: PackedVector2Array) -> PackedVector2Array:
	var line := seam_line(b)
	if line.is_empty():
		return line
	var dir := (line[1] - line[0]).normalized()
	var hits: Array = []
	for i in inner.size():
		var hit: Variant = Geometry2D.segment_intersects_segment(
			inner[i], inner[(i + 1) % inner.size()], line[0] - dir * 50.0, line[1] + dir * 50.0
		)
		if hit != null:
			hits.append([(hit as Vector2 - line[0]).dot(dir), hit])
	if hits.size() < 2:
		return PackedVector2Array()
	hits.sort()
	return PackedVector2Array([hits[0][1], hits[-1][1]])


## Inner door centre on the seam span a-c (projected from the plan point).
static func inner_door(b: Dictionary, span: PackedVector2Array) -> Vector2:
	var d: Array = of(b)["inner_door"]["at"]
	return Geometry2D.get_closest_point_to_segment(Vector2(d[0], d[1]), span[0], span[1])


static func inner_door_size(b: Dictionary) -> Vector2:
	var d: Dictionary = of(b)["inner_door"]
	return Vector2(float(d["w"]), float(d["h"]))


## Wall pieces of the partition either side of the inner doorway: [[p, q], ...].
static func partition_walls(b: Dictionary, inner: PackedVector2Array) -> Array:
	var span := seam_span(b, inner)
	if span.is_empty():
		return []
	var door := inner_door(b, span)
	var dir := (span[1] - span[0]).normalized()
	var half := inner_door_size(b).x * 0.5
	return [[span[0], door - dir * half], [door + dir * half, span[1]]]


## True when `p` lies on the heated side of the seam (always, for a cottage).
static func in_heated_bay(b: Dictionary, p: Vector2) -> bool:
	var line := seam_line(b)
	if line.is_empty():
		return true
	return (p - line[0]).dot(heated_dir(b)) >= 0.0


## Heap oven: {id, at, size, mouth (unit dir)}.
static func oven(b: Dictionary) -> Dictionary:
	var o: Dictionary = of(b)["oven"]
	var m := float(o["mouth"])
	return {
		"id": String(o["id"]),
		"at": Vector2(o["at"][0], o["at"][1]),
		"size": float(o["size"]),
		"mouth": Vector2(cos(m), sin(m)),
	}


## Oven footprint square, turned to its mouth.
static func oven_poly(b: Dictionary) -> PackedVector2Array:
	var o := oven(b)
	var f: Vector2 = o["mouth"]
	var s := Vector2(-f.y, f.x)
	var h := float(o["size"]) * 0.5
	var c: Vector2 = o["at"]
	return PackedVector2Array(
		[c - f * h - s * h, c + f * h - s * h, c + f * h + s * h, c - f * h + s * h]
	)


## Logic-plane solids of an enterable smoke dwelling: the partition pieces
## (`thick` deep) and the oven. `inner` is the room outline.
static func solids(
	b: Dictionary, inner: PackedVector2Array, thick: float
) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = [oven_poly(b)]
	var n := heated_dir(b) * thick * 0.5
	for w: Array in partition_walls(b, inner) if is_barn(b) else []:
		var p: Vector2 = w[0]
		var q: Vector2 = w[1]
		if p.distance_to(q) > 0.05:
			out.append(PackedVector2Array([p - n, q - n, q + n, p + n]))
	return out


# ---------------------------------------------------------------------------
# Geometry (CityBuildingBuilder)
# ---------------------------------------------------------------------------


## Outside: threshing gate, smoke vents and the partition's log ends where it is
## notched through the long walls. `ring` is the wall ring (outer face); `frame`
## the roof frame, so nothing that stands proud of the wall pierces the eaves.
static func build_exterior(
	shell: CityBuildingBuilder.Shell,
	b: Dictionary,
	ring: PackedVector2Array,
	thick: float,
	floor_y: float,
	eave: float,
	frame: Dictionary
) -> void:
	var plan := of(b)
	var front := front_dir(b)
	if plan.has("gate"):
		var g: Dictionary = plan["gate"]
		var at := _on_wall(ring, Vector2(g["at"][0], g["at"][1]) - front * 2.0, front)
		_gate(shell, at, front, float(g["w"]), float(g["h"]), thick, floor_y)
	# Vents: one in the front wall and one in the back wall over the heated room.
	var o := oven(b)
	var heated_mid: Vector2 = o["at"]
	if is_barn(b):
		var line := seam_line(b)
		var hd := heated_dir(b)
		var far := -INF
		for p in ring:
			far = maxf(far, (p - line[0]).dot(hd))
		heated_mid = (line[0] + line[1]) * 0.5 + hd * far * 0.5
	var vent_y := floor_y + minf(float(b["wall_h"]) - 0.3, 1.85)
	for dir: Vector2 in [front, -front]:
		_vent(shell, _on_wall(ring, heated_mid, dir), dir, vent_y, thick)
	if is_barn(b):
		# The partition logs run through the long walls and show as a column of
		# notched log ends: the two-part plan reads from the yard.
		var line := seam_line(b)
		var mid := (line[0] + line[1]) * 0.5
		var hd := heated_dir(b)
		for dir: Vector2 in [front, -front]:
			var p := _on_wall(ring, mid, dir)
			# Top under the roof skin at the log ends' outer face.
			var top := minf(eave, CityBuildingBuilder.roof_height(frame, p + dir * 0.21) - 0.06)
			_obox(
				shell,
				"wall:log",
				Vector3(p.x + dir.x * 0.1, (floor_y - 0.25 + top) * 0.5, p.y + dir.y * 0.1),
				Vector3(0.3, top - floor_y + 0.25, 0.22),
				dir,
				SMOKED.lerp(Color(0.58, 0.45, 0.33), 0.6)
			)
			# Seam boards up the wall either side, so the bay line reads at a distance.
			for k: float in [-1.0, 1.0]:
				var q := p + hd * 0.2 * k
				var board_top := minf(
					eave, CityBuildingBuilder.roof_height(frame, q + dir * 0.05) - 0.06
				)
				_obox(
					shell,
					"timber",
					Vector3(q.x + dir.x * 0.02, (floor_y + board_top) * 0.5, q.y + dir.y * 0.02),
					Vector3(0.06, board_top - floor_y, 0.05),
					dir,
					_shade(GATE_WOOD, 0.8)
				)


## Inside (enterable only, before the cutaway split): threshing floor, log
## partition with the low inner door, and the heap oven. `inner` is the room
## outline the builder used for the inner wall faces.
static func build_interior(
	shell: CityBuildingBuilder.Shell,
	b: Dictionary,
	inner: PackedVector2Array,
	thick: float,
	floor_y: float,
	ceiling: float
) -> void:
	if is_barn(b):
		var line := seam_line(b)
		var hd := heated_dir(b)
		var along := (line[1] - line[0]).normalized()
		# The threshing bay's paler clay over the dark floor, on its side of the seam.
		var cut := PackedVector2Array(
			[
				line[0] - along * 60.0,
				line[1] + along * 60.0,
				line[1] + along * 60.0 - hd * 80.0,
				line[0] - along * 60.0 - hd * 80.0,
			]
		)
		for poly: PackedVector2Array in Geometry2D.intersect_polygons(inner, cut):
			CityBuildingBuilder._floor(shell, poly, floor_y + 0.01, "clay", THRESHING_FLOOR)
		var door_h := minf(inner_door_size(b).y, ceiling - floor_y - 0.1)
		var span := seam_span(b, inner)
		if not span.is_empty():
			var door := inner_door(b, span)
			var half := inner_door_size(b).x * 0.5
			var dir := (span[1] - span[0]).normalized()
			for w: Array in partition_walls(b, inner):
				_wall_box(shell, w[0], w[1], floor_y, ceiling, thick, hd)
			# Lintel logs over the low inner door.
			_wall_box(
				shell, door - dir * half, door + dir * half, floor_y + door_h, ceiling, thick, hd
			)
			# A high sill log, as the period's doors had.
			_wall_box(
				shell, door - dir * half, door + dir * half, floor_y, floor_y + 0.12, thick, hd
			)
	_oven(shell, b, floor_y)


## Section cap over the partition where the cutaway slices it (after split_at).
static func cap_partition(
	shell: CityBuildingBuilder.Shell,
	b: Dictionary,
	inner: PackedVector2Array,
	thick: float,
	y: float
) -> void:
	if not is_barn(b):
		return
	var span := seam_span(b, inner)
	if span.is_empty():
		return
	var n := heated_dir(b) * thick * 0.5
	var a := span[0]
	var c := span[1]
	shell.quad_out(
		"stone",
		Vector3(a.x - n.x, y, a.y - n.y),
		Vector3(c.x - n.x, y, c.y - n.y),
		Vector3(c.x + n.x, y, c.y + n.y),
		Vector3(a.x + n.x, y, a.y + n.y),
		Color(0.62, 0.58, 0.52),
		Vector3.UP
	)


## Stone heap oven (kerisahi): stacked rough courses of fieldstone, a heap of
## loose stones on top, a dark mouth to the front and a flat hearth stone (lee)
## before it. Seeded by the oven id, so it never changes between loads.
static func _oven(shell: CityBuildingBuilder.Shell, b: Dictionary, floor_y: float) -> void:
	var o := oven(b)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(o["id"]))
	var c: Vector2 = o["at"]
	var f: Vector2 = o["mouth"]
	var size := float(o["size"])
	var y := floor_y
	for course: Array in [[1.0, 0.5], [0.86, 0.42], [0.66, 0.3]]:
		var w := size * float(course[0])
		var h := OVEN_HEIGHT * float(course[1]) * 0.86
		var turn := f.rotated(rng.randf_range(-0.06, 0.06))
		var shade := _shade(STONE, rng.randf_range(0.82, 1.0))
		_obox(shell, "stone", Vector3(c.x, y + h * 0.5, c.y), Vector3(w, h, w), turn, shade)
		y += h
	# The open heap of heating stones (keris) on top.
	for k in 7:
		var p := c + Vector2(rng.randf_range(-0.28, 0.28), rng.randf_range(-0.28, 0.28)) * size
		var s := rng.randf_range(0.16, 0.28)
		var shade := _shade(STONE, rng.randf_range(0.55, 0.85))
		_obox(
			shell,
			"stone",
			Vector3(p.x, y + s * 0.4, p.y),
			Vector3(s, s * 0.8, s),
			f.rotated(rng.randf_range(0.0, PI)),
			shade
		)
	# Mouth: a dark opening in the front face, sooted above it.
	var mouth := c + f * (size * 0.5 + 0.01)
	_obox(
		shell,
		"dark",
		Vector3(mouth.x, floor_y + 0.38, mouth.y),
		Vector3(0.6, 0.48, 0.04),
		f,
		Color(1, 1, 1)
	)
	# Hearth stone before the mouth, where the pot stood on the embers.
	var lee := c + f * (size * 0.5 + 0.4)
	_obox(
		shell,
		"stone",
		Vector3(lee.x, floor_y + 0.03, lee.y),
		Vector3(1.0, 0.06, 0.7),
		f,
		_shade(STONE, 0.7)
	)


## Broad boarded double gate, flush through the wall so it reads from both
## sides, with posts and a lintel log.
static func _gate(
	shell: CityBuildingBuilder.Shell,
	at: Vector2,
	out: Vector2,
	width: float,
	height: float,
	thick: float,
	floor_y: float
) -> void:
	var c := at - out * thick * 0.5
	var side := Vector2(-out.y, out.x)
	for k: float in [-1.0, 1.0]:
		var leaf := c + side * k * (width * 0.25 + 0.01)
		_obox(
			shell,
			"timber",
			Vector3(leaf.x, floor_y + height * 0.5, leaf.y),
			Vector3(width * 0.5 - 0.03, height, thick + 0.06),
			out,
			GATE_WOOD
		)
		var post := c + side * k * (width * 0.5 + 0.07)
		_obox(
			shell,
			"timber",
			Vector3(post.x, floor_y + height * 0.5 + 0.05, post.y),
			Vector3(0.14, height + 0.1, thick + 0.12),
			out,
			_shade(GATE_WOOD, 0.85)
		)
		# Ledger battens across each leaf.
		for yk: float in [0.25, 0.75]:
			_obox(
				shell,
				"timber",
				Vector3(
					leaf.x + out.x * (thick * 0.5 + 0.04),
					floor_y + height * yk,
					leaf.y + out.y * (thick * 0.5 + 0.04)
				),
				Vector3(width * 0.5 - 0.1, 0.12, 0.04),
				out,
				_shade(GATE_WOOD, 0.9)
			)
	_obox(
		shell,
		"timber",
		Vector3(c.x, floor_y + height + 0.08, c.y),
		Vector3(width + 0.36, 0.16, thick + 0.12),
		out,
		_shade(GATE_WOOD, 0.85)
	)


## Small unglazed smoke vent with a board shutter pushed aside above it.
static func _vent(
	shell: CityBuildingBuilder.Shell, at: Vector2, out: Vector2, y: float, thick: float
) -> void:
	var c := at - out * thick * 0.5
	_obox(
		shell,
		"dark",
		Vector3(c.x, y, c.y),
		Vector3(VENT_SIZE.x, VENT_SIZE.y, thick + 0.04),
		out,
		Color(1, 1, 1)
	)
	var side := Vector2(-out.y, out.x)
	var board := at + out * 0.03 + side * (VENT_SIZE.x * 0.9)
	_obox(
		shell,
		"timber",
		Vector3(board.x, y, board.y),
		Vector3(VENT_SIZE.x + 0.06, VENT_SIZE.y + 0.08, 0.04),
		out,
		_shade(GATE_WOOD, 0.75)
	)


## Log wall box p-q from y0 to y1, `thick` deep across `normal`.
static func _wall_box(
	shell: CityBuildingBuilder.Shell,
	p: Vector2,
	q: Vector2,
	y0: float,
	y1: float,
	thick: float,
	normal: Vector2
) -> void:
	var length := p.distance_to(q)
	if length < 0.05 or y1 <= y0:
		return
	var m := (p + q) * 0.5
	_obox(
		shell,
		"wall:log",
		Vector3(m.x, (y0 + y1) * 0.5, m.y),
		Vector3(length, y1 - y0, thick),
		normal,
		SMOKED
	)


## Closed box at `center` of `size` (x along the face, y up, z along `front`).
static func _obox(
	shell: CityBuildingBuilder.Shell,
	key: String,
	center: Vector3,
	size: Vector3,
	front: Vector2,
	color: Color
) -> void:
	var f := front.normalized() * size.z * 0.5
	var s := Vector2(-front.y, front.x).normalized() * size.x * 0.5
	var c := Vector2(center.x, center.z)
	var y0 := center.y - size.y * 0.5
	var y1 := center.y + size.y * 0.5
	var corners := [c - s - f, c + s - f, c + s + f, c - s + f]
	for i in 4:
		var a: Vector2 = corners[i]
		var d: Vector2 = corners[(i + 1) % 4]
		var out := (a + d) * 0.5 - c
		shell.quad_out(
			key,
			Vector3(a.x, y0, a.y),
			Vector3(d.x, y0, d.y),
			Vector3(d.x, y1, d.y),
			Vector3(a.x, y1, a.y),
			color,
			Vector3(out.x, 0.0, out.y)
		)
	for level: Array in [[y1, Vector3.UP], [y0, Vector3.DOWN]]:
		var h := float(level[0])
		var pts: Array[Vector3] = []
		for v: Vector2 in corners:
			pts.append(Vector3(v.x, h, v.y))
		shell.quad_out(key, pts[0], pts[1], pts[2], pts[3], color, level[1])


## Point on the wall ring hit by the ray from `from` along `dir` (nearest hit).
static func _on_wall(ring: PackedVector2Array, from: Vector2, dir: Vector2) -> Vector2:
	var best := from
	var best_d := INF
	for i in ring.size():
		var hit: Variant = Geometry2D.segment_intersects_segment(
			from, from + dir * 100.0, ring[i], ring[(i + 1) % ring.size()]
		)
		if hit != null and from.distance_to(hit) < best_d:
			best_d = from.distance_to(hit)
			best = hit
	return best


## `c` darkened by `k`, alpha kept opaque.
static func _shade(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k)

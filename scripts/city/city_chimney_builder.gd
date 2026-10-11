extends RefCounted

## A house's stone chimney and the hearth under it (docs/SYSTEMS/SEAMLESS_CITY.md,
## step 5; docs/SYSTEMS/HOUSEHOLDS.md). Split out of CityBuildingBuilder, which
## calls `build` for every house and `flue_cap` after the interior cutaway.

const SECTION := Color(0.62, 0.58, 0.52)


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
	# Dark flue mouth.
	_square(roof, c, dir * half * 0.7, inward * half * 0.7, top - 0.02, "dark", Color(1, 1, 1))
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
	_square(shell, w + inward * depth * 0.5, dir * half, inward * depth * 0.5, y, "stone", SECTION)
	var c: Vector3 = flue["top"]
	var m := half * 0.45
	_square(shell, Vector2(c.x, c.z), dir * m, inward * m, y + 0.01, "dark", Color(1, 1, 1))


## Upward-facing quad at height `y`: `centre` plus/minus the half-extents `u`, `v`.
static func _square(
	shell: CityBuildingBuilder.Shell,
	centre: Vector2,
	u: Vector2,
	v: Vector2,
	y: float,
	key: String,
	tint: Color
) -> void:
	var q: Array[Vector2] = [centre - u - v, centre + u - v, centre + u + v, centre - u + v]
	shell.quad_out(
		key,
		Vector3(q[0].x, y, q[0].y),
		Vector3(q[1].x, y, q[1].y),
		Vector3(q[2].x, y, q[2].y),
		Vector3(q[3].x, y, q[3].y),
		tint,
		Vector3.UP
	)


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

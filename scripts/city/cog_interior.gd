class_name CogInterior
extends RefCounted

## Deck, rooms and fittings of the cog (metres, same frame as CogHull): the
## planked weather deck with its covered cargo hatch, the stern cabin under the
## sterncastle, the forecastle store, the hold access well with a ladder-stair,
## through-beams with fairings, posts, keel and the stern rudder. Every piece
## here is solid from both sides, so nothing seen from above, inside or from
## the water shows a gap into the void.
##
## Rooms (what the player can walk into) are listed in `walk_height()`; the
## hold is a well reached by the stair, because the 2D logic plane gives one
## standing height per x/z (no room can sit under the deck it shares a footprint with).

const DECK := CogHull.DECK_Y
const CABIN_WALL_X := -4.6
const CABIN_ROOF_Y := 4.4
const STORE_WALL_X := 6.3
const STORE_ROOF_Y := 4.25
const DOOR_HALF := 0.5
const DOOR_HEIGHT := 1.9
## Just above the still waterline: the sea surface is one plane, so a hold floor
## under it would show water inside the hull.
const HOLD_FLOOR_Y := 0.45
## Hold access well: stair from the deck down to the landing.
const WELL_X0 := -3.8
const WELL_X1 := 1.0
const WELL_STAIR_END_X := -1.4
const WELL_HALF := 1.0
## Covered cargo hatch (raised boards, not walkable as a hole).
const HATCH_X0 := 2.8
const HATCH_X1 := 5.4
const HATCH_HALF := 1.25
const MAST_X := 2.0

const OAK := Color(0.9, 0.82, 0.7)
const PINE := Color(0.95, 0.86, 0.68)
const DARK := Color(0.52, 0.44, 0.36)
const TAR := Color(0.36, 0.3, 0.25)


## Standing height at hull-local (x, z), or NAN outside the walkable decks.
static func walk_height(x: float, z: float) -> float:
	var hw := CogHull.half_width_at(x, DECK, true) - 0.15
	var x_min := CogHull.x_aft(DECK) + 0.8
	var x_max := CogHull.x_fore(DECK) - 1.1
	if x < x_min or x > x_max or absf(z) > hw:
		return NAN
	if x >= WELL_X0 and x <= WELL_X1 and absf(z) <= WELL_HALF:
		if x >= WELL_STAIR_END_X:
			return HOLD_FLOOR_Y
		return lerpf(DECK, HOLD_FLOOR_Y, (x - WELL_X0) / (WELL_STAIR_END_X - WELL_X0))
	return DECK


static func add_all(timber: CogParts, dark: CogParts) -> void:
	_add_posts_and_keel(timber, dark)
	_add_deck(timber)
	_add_through_beams(timber)
	_add_well(timber)
	_add_hatch(timber, dark)
	_add_cabin(timber, dark)
	_add_store(timber, dark)
	_add_windlass_and_bitts(timber, dark)
	_add_hold_floor(timber)
	_add_deck_cargo(timber, dark)
	_add_boarding_ladder(timber, dark)


static func _add_posts_and_keel(t: CogParts, iron: CogParts) -> void:
	var y0 := CogHull.KEEL_Y
	t.beam(
		Vector3(CogHull.x_aft(y0) - 0.1, y0 - 0.1, 0),
		Vector3(CogHull.x_fore(y0) + 0.1, y0 - 0.1, 0),
		0.5,
		0.24,
		DARK
	)
	t.beam(
		Vector3(CogHull.x_aft(y0), y0, 0),
		Vector3(CogHull.x_aft(CogHull.STERNCASTLE_Y), CogHull.STERNCASTLE_Y + 0.15, 0),
		0.36,
		0.34,
		OAK,
		Vector3.FORWARD
	)
	t.beam(
		Vector3(CogHull.x_fore(y0), y0, 0),
		Vector3(CogHull.x_fore(CogHull.FORECASTLE_Y), CogHull.FORECASTLE_Y + 0.4, 0),
		0.36,
		0.34,
		OAK,
		Vector3.FORWARD
	)
	# Keelson inside, with the mast step block.
	t.beam(
		Vector3(-6.0, HOLD_FLOOR_Y - 0.5, 0), Vector3(6.5, HOLD_FLOOR_Y - 0.5, 0), 0.34, 0.3, DARK
	)
	t.box(Vector3(MAST_X, HOLD_FLOOR_Y - 0.15, 0), Vector3(1.0, 0.5, 0.7), DARK)
	# Floor timbers every ~0.9 m and frames that climb the inner skin.
	var x := -6.4
	while x < 7.0:
		var y_floor := HOLD_FLOOR_Y - 0.6
		var hw := CogHull.half_width_at(x, y_floor, true)
		t.box(Vector3(x, y_floor, 0), Vector3(0.2, 0.18, hw * 2.0), DARK)
		for side: float in [-1.0, 1.0]:
			var prev := Vector3(x, y_floor, hw * side)
			var yy := y_floor
			while yy < CogHull.SHEER_Y - 0.4:
				yy += 0.7
				var cur := Vector3(x, yy, (CogHull.half_width_at(x, yy, true) - 0.05) * side)
				t.beam(prev, cur, 0.16, 0.18, DARK, Vector3(1, 0, 0))
				prev = cur
		x += 0.9
	# Gudgeon straps on the stern post, at the same heights as the rudder's pintles.
	var pivot := CogRig.rudder_pivot_position()
	var rake := CogRig.rudder_rake()
	for l: float in CogRig.pintle_heights():
		var p := pivot + Vector3(-sin(rake), cos(rake), 0.0) * l
		iron.box(Vector3(p.x + 0.12, p.y, 0), Vector3(0.18, 0.12, 0.5), Color(0.18, 0.18, 0.2))


static func _x_breaks(x0: float, x1: float, step: float, extra: Array[float]) -> Array[float]:
	var xs: Array[float] = [x0, x1]
	var x := x0 + step
	while x < x1 - 0.01:
		xs.append(x)
		x += step
	for e in extra:
		if e > x0 + 0.01 and e < x1 - 0.01:
			xs.append(e)
	xs.sort()
	return xs


## Weather deck: planked top and underside, with the hold well cut out.
static func _add_deck(t: CogParts) -> void:
	var x0 := CogHull.x_aft(DECK) + 0.25
	var x1 := CogHull.x_fore(DECK) - 0.25
	var xs := _x_breaks(x0, x1, 0.7, [WELL_X0, WELL_X1, HATCH_X0, HATCH_X1])
	for i in xs.size() - 1:
		var xa := xs[i]
		var xb := xs[i + 1]
		var in_well := xa >= WELL_X0 - 0.001 and xb <= WELL_X1 + 0.001
		var ha := CogHull.half_width_at(xa, DECK, true) + 0.08
		var hb := CogHull.half_width_at(xb, DECK, true) + 0.08
		var strips: Array[Vector2] = [Vector2(-1, 1)]
		if in_well:
			strips = [Vector2(-1, -WELL_HALF), Vector2(WELL_HALF, 1)]
		for strip in strips:
			var za0 := ha * strip.x if strip.x == -1.0 else strip.x
			var za1 := ha * strip.y if strip.y == 1.0 else strip.y
			var zb0 := hb * strip.x if strip.x == -1.0 else strip.x
			var zb1 := hb * strip.y if strip.y == 1.0 else strip.y
			_slab(t, xa, xb, za0, za1, zb0, zb1, DECK, PINE)


static func _slab(
	t: CogParts,
	xa: float,
	xb: float,
	za0: float,
	za1: float,
	zb0: float,
	zb1: float,
	y: float,
	color: Color
) -> void:
	var top: Array[Vector3] = [
		Vector3(xa, y, za0), Vector3(xa, y, za1), Vector3(xb, y, zb1), Vector3(xb, y, zb0)
	]
	t.quad(
		top[0],
		top[1],
		top[2],
		top[3],
		Vector3.UP,
		color,
		Vector2(xa / 1.6, za0 / 0.32),
		Vector2(xa / 1.6, za1 / 0.32),
		Vector2(xb / 1.6, zb1 / 0.32),
		Vector2(xb / 1.6, zb0 / 0.32)
	)
	var yb := y - 0.12
	t.quad(
		Vector3(xa, yb, za0),
		Vector3(xb, yb, zb0),
		Vector3(xb, yb, zb1),
		Vector3(xa, yb, za1),
		Vector3.DOWN,
		color * 0.7,
		Vector2(xa / 1.6, za0 / 0.32),
		Vector2(xb / 1.6, zb0 / 0.32),
		Vector2(xb / 1.6, zb1 / 0.32),
		Vector2(xa / 1.6, za1 / 0.32)
	)


## Athwartship deck beams; five of them (attested on Lootsi) stand through the
## hull with a conical fairing on each end.
static func _add_through_beams(t: CogParts) -> void:
	var y := DECK - 0.3
	var x := CogHull.x_aft(DECK) + 1.2
	var through: Array[float] = [-3.0, -0.2, 2.6, 4.9, 6.9]
	while x < CogHull.x_fore(DECK) - 1.0:
		var hw := CogHull.half_width_at(x, y, true)
		var is_through := false
		for tx in through:
			if absf(tx - x) < 0.8:
				is_through = true
		if is_through:
			var out := CogHull.half_width_at(x, y, false) + 0.45
			t.box(Vector3(x, y, 0), Vector3(0.34, 0.34, out * 2.0), DARK)
			for side: float in [-1.0, 1.0]:
				var prof: Array[Vector2] = [
					Vector2(0.17, 0.0), Vector2(0.24, 0.1), Vector2(0.1, 0.38), Vector2(0.06, 0.45)
				]
				var b := Basis.from_euler(Vector3(PI * 0.5 * side, 0, 0))
				t.lathe(Vector3(x, y, (out - 0.38) * side), prof, 8, DARK, b)
		else:
			t.box(Vector3(x, y, 0), Vector3(0.22, 0.28, hw * 2.0), DARK)
		x += 1.35


## Hold well: planked walls, a steep stair, a landing and the cargo around it.
static func _add_well(t: CogParts) -> void:
	var wall_top := DECK + 0.4
	for side: float in [-1.0, 1.0]:
		var z := WELL_HALF * side
		# Side wall as one box; the stair end stays open.
		t.box(
			Vector3((WELL_X0 + WELL_X1) * 0.5, (HOLD_FLOOR_Y + wall_top) * 0.5, z + 0.06 * side),
			Vector3(WELL_X1 - WELL_X0, wall_top - HOLD_FLOOR_Y, 0.12),
			PINE * 0.85
		)
	t.box(
		Vector3(WELL_X1 + 0.06, (HOLD_FLOOR_Y + wall_top) * 0.5, 0),
		Vector3(0.12, wall_top - HOLD_FLOOR_Y, WELL_HALF * 2.0 + 0.24),
		PINE * 0.85
	)
	# Landing floor and the stair: 8 treads.
	var steps := 8
	var run := (WELL_STAIR_END_X - WELL_X0) / steps
	var rise := (DECK - HOLD_FLOOR_Y) / steps
	for i in steps:
		var top_y := DECK - rise * float(i + 1)
		var x := WELL_X0 + run * (float(i) + 0.5)
		t.box(Vector3(x, top_y - 0.05, 0), Vector3(run * 1.02, 0.1, WELL_HALF * 2.0 - 0.1), PINE)
		# Riser so the stair is solid from the side.
		t.box(
			Vector3(x + run * 0.5, top_y - rise * 0.5, 0),
			Vector3(0.06, rise, WELL_HALF * 2.0 - 0.1),
			PINE * 0.8
		)
	t.box(
		Vector3((WELL_STAIR_END_X + WELL_X1) * 0.5, HOLD_FLOOR_Y - 0.06, 0),
		Vector3(WELL_X1 - WELL_STAIR_END_X, 0.12, WELL_HALF * 2.0),
		PINE * 0.8
	)
	# A hand rope-rail along the stair.
	t.beam(
		Vector3(WELL_X0, DECK + 0.95, WELL_HALF - 0.08),
		Vector3(WELL_STAIR_END_X, HOLD_FLOOR_Y + 0.95, WELL_HALF - 0.08),
		0.06,
		0.06,
		DARK
	)


## Covered cargo hatch: raised coaming and loose boards.
static func _add_hatch(t: CogParts, iron: CogParts) -> void:
	var h := 0.32
	var cx := (HATCH_X0 + HATCH_X1) * 0.5
	var len := HATCH_X1 - HATCH_X0
	for side: float in [-1.0, 1.0]:
		t.box(Vector3(cx, DECK + h * 0.5, HATCH_HALF * side), Vector3(len, h, 0.14), DARK)
	for xe: float in [HATCH_X0, HATCH_X1]:
		t.box(Vector3(xe, DECK + h * 0.5, 0), Vector3(0.14, h, HATCH_HALF * 2.0), DARK)
	# Cover boards, each its own plank so the surface reads as hatch boards.
	var i := 0
	var z := -HATCH_HALF + 0.12
	while z < HATCH_HALF - 0.1:
		t.box(
			Vector3(cx, DECK + h + 0.03, z + 0.17),
			Vector3(len - 0.05, 0.06, 0.32),
			PINE * (0.9 + 0.1 * float(i % 2))
		)
		z += 0.34
		i += 1
	# Batten bars with iron wedges across the boards.
	for xb: float in [HATCH_X0 + 0.5, HATCH_X1 - 0.5]:
		t.box(Vector3(xb, DECK + h + 0.09, 0), Vector3(0.16, 0.06, HATCH_HALF * 2.0 - 0.1), DARK)
		for side: float in [-1.0, 1.0]:
			iron.box(
				Vector3(xb, DECK + h + 0.14, 0.9 * side),
				Vector3(0.1, 0.06, 0.22),
				Color(0.16, 0.16, 0.18)
			)


## Stern cabin under the sterncastle: forward wall with a door, roof, bunk,
## table, chest and shelf. The tiller comes in through the stern post.
static func _add_cabin(t: CogParts, iron: CogParts) -> void:
	var x_back := CogHull.x_aft(DECK) + 0.3
	# Forward wall: two panels and a lintel around the door.
	for side: float in [-1.0, 1.0]:
		var y0 := DECK
		var y1 := CABIN_ROOF_Y
		var hw0 := CogHull.half_width_at(CABIN_WALL_X, y0, true) + 0.05
		var hw1 := CogHull.half_width_at(CABIN_WALL_X, y1, true) + 0.05
		_panel(
			t,
			Vector3(CABIN_WALL_X, y0, DOOR_HALF * side),
			Vector3(CABIN_WALL_X, y0, hw0 * side),
			Vector3(CABIN_WALL_X, y1, hw1 * side),
			Vector3(CABIN_WALL_X, y1, DOOR_HALF * side),
			PINE * 0.9
		)
	t.box(
		Vector3(CABIN_WALL_X, (DECK + DOOR_HEIGHT + CABIN_ROOF_Y) * 0.5, 0),
		Vector3(0.12, CABIN_ROOF_Y - DECK - DOOR_HEIGHT, DOOR_HALF * 2.0),
		PINE * 0.9
	)
	# Door frame and the leaf, ajar.
	for side: float in [-1.0, 1.0]:
		t.box(
			Vector3(CABIN_WALL_X, DECK + DOOR_HEIGHT * 0.5, (DOOR_HALF + 0.04) * side),
			Vector3(0.2, DOOR_HEIGHT, 0.08),
			DARK
		)
	t.box(
		Vector3(CABIN_WALL_X + 0.3, DECK + DOOR_HEIGHT * 0.5, -DOOR_HALF - 0.28),
		Vector3(0.7, DOOR_HEIGHT - 0.1, 0.06),
		PINE,
		Basis(Vector3.UP, 0.9)
	)
	iron.box(
		Vector3(CABIN_WALL_X + 0.02, DECK + 0.5, -DOOR_HALF),
		Vector3(0.1, 0.1, 0.16),
		Color(0.16, 0.16, 0.18)
	)
	iron.box(
		Vector3(CABIN_WALL_X + 0.02, DECK + 1.5, -DOOR_HALF),
		Vector3(0.1, 0.1, 0.16),
		Color(0.16, 0.16, 0.18)
	)
	# Roof: planks above, beams below.
	var xs := _x_breaks(x_back, CABIN_WALL_X, 0.8, [])
	for i in xs.size() - 1:
		var ha := CogHull.half_width_at(xs[i], CABIN_ROOF_Y, true) + 0.08
		var hb := CogHull.half_width_at(xs[i + 1], CABIN_ROOF_Y, true) + 0.08
		_slab(t, xs[i], xs[i + 1], -ha, ha, -hb, hb, CABIN_ROOF_Y, PINE)
	var x := CABIN_WALL_X - 0.5
	while x > x_back + 0.5:
		var hw := CogHull.half_width_at(x, CABIN_ROOF_Y - 0.25, true)
		t.box(Vector3(x, CABIN_ROOF_Y - 0.28, 0), Vector3(0.2, 0.24, hw * 2.0), DARK)
		x -= 1.2
	# Furniture: bunk on the starboard side, table, stools, chest, shelf, lantern.
	var bz := CogHull.half_width_at(-6.8, DECK + 0.5, true) - 0.5
	t.box(Vector3(-6.6, DECK + 0.45, bz), Vector3(2.0, 0.1, 0.9), PINE)
	t.box(Vector3(-6.6, DECK + 0.58, bz), Vector3(1.9, 0.12, 0.8), Color(0.62, 0.55, 0.45))
	for dx: float in [-0.95, 0.95]:
		t.box(Vector3(-6.6 + dx, DECK + 0.22, bz), Vector3(0.1, 0.44, 0.9), DARK)
	t.box(Vector3(-6.6, DECK + 1.1, bz + 0.46), Vector3(2.0, 0.08, 0.04), DARK)
	t.box(Vector3(-6.0, DECK + 0.78, -0.2), Vector3(1.1, 0.07, 0.7), PINE)
	for corner: Vector2 in [
		Vector2(-0.45, -0.28), Vector2(0.45, -0.28), Vector2(-0.45, 0.28), Vector2(0.45, 0.28)
	]:
		t.box(
			Vector3(-6.0 + corner.x, DECK + 0.38, -0.2 + corner.y), Vector3(0.07, 0.76, 0.07), DARK
		)
	t.box(Vector3(-5.2, DECK + 0.26, 0.55), Vector3(0.36, 0.52, 0.36), DARK)
	t.box(Vector3(-5.4, DECK + 0.4, -1.0), Vector3(0.8, 0.8, 0.55), Color(0.7, 0.58, 0.44))
	iron.box(Vector3(-5.4, DECK + 0.56, -1.0), Vector3(0.82, 0.05, 0.57), Color(0.16, 0.16, 0.18))
	var wall_hw := CogHull.half_width_at(-7.5, DECK + 1.4, true)
	t.box(Vector3(-7.6, DECK + 1.5, -wall_hw + 0.2), Vector3(1.5, 0.06, 0.32), PINE)
	t.box(Vector3(-7.6, DECK + 1.75, -wall_hw + 0.1), Vector3(1.5, 0.3, 0.05), DARK)
	# Lantern hanging from a roof beam.
	t.tube(
		Vector3(-5.6, CABIN_ROOF_Y - 0.4, -0.2),
		Vector3(-5.6, CABIN_ROOF_Y - 0.8, -0.2),
		0.012,
		0.012,
		4,
		DARK
	)
	iron.box(
		Vector3(-5.6, CABIN_ROOF_Y - 0.95, -0.2), Vector3(0.2, 0.28, 0.2), Color(0.2, 0.19, 0.18)
	)


## Forecastle store: aft wall with a door, roof, anchor cable coil, barrels and bundles.
static func _add_store(t: CogParts, iron: CogParts) -> void:
	for side: float in [-1.0, 1.0]:
		var hw0 := CogHull.half_width_at(STORE_WALL_X, DECK, true) + 0.05
		var hw1 := CogHull.half_width_at(STORE_WALL_X, STORE_ROOF_Y, true) + 0.05
		_panel(
			t,
			Vector3(STORE_WALL_X, DECK, DOOR_HALF * side),
			Vector3(STORE_WALL_X, DECK, hw0 * side),
			Vector3(STORE_WALL_X, STORE_ROOF_Y, hw1 * side),
			Vector3(STORE_WALL_X, STORE_ROOF_Y, DOOR_HALF * side),
			PINE * 0.9
		)
	t.box(
		Vector3(STORE_WALL_X, (DECK + DOOR_HEIGHT + STORE_ROOF_Y) * 0.5, 0),
		Vector3(0.12, STORE_ROOF_Y - DECK - DOOR_HEIGHT, DOOR_HALF * 2.0),
		PINE * 0.9
	)
	for side: float in [-1.0, 1.0]:
		t.box(
			Vector3(STORE_WALL_X, DECK + DOOR_HEIGHT * 0.5, (DOOR_HALF + 0.04) * side),
			Vector3(0.2, DOOR_HEIGHT, 0.08),
			DARK
		)
	var x_front := CogHull.x_fore(DECK) - 0.3
	var xs := _x_breaks(STORE_WALL_X, x_front, 0.8, [])
	for i in xs.size() - 1:
		var ha := CogHull.half_width_at(xs[i], STORE_ROOF_Y, true) + 0.08
		var hb := CogHull.half_width_at(xs[i + 1], STORE_ROOF_Y, true) + 0.08
		_slab(t, xs[i], xs[i + 1], -ha, ha, -hb, hb, STORE_ROOF_Y, PINE)
	# Anchor cable coil: stacked flat rings of hemp.
	var rope_col := Color(0.62, 0.52, 0.36)
	for ring in 5:
		var prof: Array[Vector2] = [
			Vector2(0.62, 0.0), Vector2(0.62, 0.1), Vector2(0.28, 0.1), Vector2(0.28, 0.0)
		]
		t.lathe(Vector3(7.7, DECK + 0.02 + 0.11 * ring, 0.5), prof, 18, rope_col)
	for k in 3:
		barrel(t, iron, Vector3(8.1, DECK, -0.9 + 0.5 * k), 0.0)
	# Spare spars and a bundle of staves along the wall.
	t.tube(Vector3(7.0, DECK + 0.2, -1.4), Vector3(9.0, DECK + 0.2, -1.1), 0.1, 0.07, 6, OAK)
	t.tube(Vector3(7.0, DECK + 0.36, -1.35), Vector3(9.0, DECK + 0.34, -1.0), 0.09, 0.06, 6, OAK)


static func _panel(
	t: CogParts, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color
) -> void:
	# Two-sided so a bulkhead reads from both rooms. a..d run counter-clockwise from +x.
	var n := (b - a).cross(d - a).normalized()
	t.quad(a, b, c, d, n, color)
	t.quad(a, d, c, b, -n, color * 0.85)


static func _add_windlass_and_bitts(t: CogParts, iron: CogParts) -> void:
	var x := 5.9
	var y := DECK + 0.75
	var hw := CogHull.half_width_at(x, DECK, true) - 0.4
	for side: float in [-1.0, 1.0]:
		t.box(Vector3(x, DECK + 0.4, hw * side), Vector3(0.3, 0.8, 0.2), DARK)
	t.tube(Vector3(x, y, -hw), Vector3(x, y, hw), 0.2, 0.2, 10, OAK)
	# Handspike sockets round the drum.
	for k in 4:
		var ang := TAU * float(k) / 4.0 + 0.4
		t.tube(
			Vector3(x, y, 0.4),
			Vector3(x, y + sin(ang) * 0.6, 0.4 + cos(ang) * 0.6),
			0.03,
			0.03,
			5,
			DARK
		)
	# Mooring bitts abaft the mast, mid-deck.
	for side: float in [-1.0, 1.0]:
		var bz := (CogHull.half_width_at(-1.6, DECK, true) - 0.5) * side
		t.tube(Vector3(-1.6, DECK, bz), Vector3(-1.6, DECK + 0.6, bz), 0.12, 0.12, 8, DARK)
		iron.lathe(
			Vector3(-1.6, DECK + 0.58, bz),
			[Vector2(0.12, 0.0), Vector2(0.17, 0.04), Vector2(0.17, 0.08)],
			8,
			DARK
		)
	# Mast partners and wedges where the mast passes the deck.
	t.box(Vector3(MAST_X, DECK + 0.1, 0), Vector3(1.0, 0.2, 1.0), DARK)


static func _add_hold_floor(t: CogParts) -> void:
	var x0 := CogHull.x_aft(HOLD_FLOOR_Y) + 0.6
	var x1 := CogHull.x_fore(HOLD_FLOOR_Y) - 0.6
	var xs := _x_breaks(x0, x1, 0.9, [])
	for i in xs.size() - 1:
		var ha := CogHull.half_width_at(xs[i], HOLD_FLOOR_Y, true) + 0.05
		var hb := CogHull.half_width_at(xs[i + 1], HOLD_FLOOR_Y, true) + 0.05
		t.quad(
			Vector3(xs[i], HOLD_FLOOR_Y - 0.12, -ha),
			Vector3(xs[i], HOLD_FLOOR_Y - 0.12, ha),
			Vector3(xs[i + 1], HOLD_FLOOR_Y - 0.12, hb),
			Vector3(xs[i + 1], HOLD_FLOOR_Y - 0.12, -hb),
			Vector3.UP,
			DARK,
			Vector2(xs[i] / 1.6, -ha / 0.32),
			Vector2(xs[i] / 1.6, ha / 0.32),
			Vector2(xs[i + 1] / 1.6, hb / 0.32),
			Vector2(xs[i + 1] / 1.6, -hb / 0.32)
		)


static func barrel(t: CogParts, iron: CogParts, at: Vector3, yaw: float, height := 0.9) -> void:
	var r := height * 0.36
	var prof: Array[Vector2] = [
		Vector2(r * 0.86, 0.0),
		Vector2(r * 0.97, height * 0.25),
		Vector2(r, height * 0.5),
		Vector2(r * 0.97, height * 0.75),
		Vector2(r * 0.86, height),
	]
	var b := Basis(Vector3.UP, yaw)
	t.lathe(at, prof, 10, Color(0.8, 0.68, 0.5), b)
	for frac: float in [0.18, 0.82]:
		var rr := r * (0.88 + 0.1 * (1.0 - absf(frac - 0.5) * 2.0))
		var hoop: Array[Vector2] = [Vector2(rr + 0.015, -0.025), Vector2(rr + 0.015, 0.025)]
		iron.lathe(at + Vector3(0, height * frac, 0), hoop, 10, Color(0.2, 0.19, 0.18), b)


## Barrels, sacks and a coil of rope on the weather deck, stowed along the sides.
static func _add_deck_cargo(t: CogParts, iron: CogParts) -> void:
	var hw := CogHull.half_width_at(-2.0, DECK, true)
	# Barrels lashed beside the hold well and abaft the hatch.
	for k in 3:
		barrel(t, iron, Vector3(-2.6 + 0.65 * k, DECK, -hw + 0.45), 0.2 * k)
	barrel(t, iron, Vector3(-2.3 + 0.65, DECK + 0.9, -hw + 0.45), 0.5)
	for k in 2:
		barrel(t, iron, Vector3(0.2 + 0.7 * k, DECK, hw - 0.5), 0.4 * k)
	# Grain sacks: lumpy lathes lying on the deck.
	for k in 4:
		var prof: Array[Vector2] = [
			Vector2(0.14, 0.0),
			Vector2(0.25, 0.1),
			Vector2(0.24, 0.3),
			Vector2(0.12, 0.42),
			Vector2(0.0, 0.46)
		]
		t.lathe(
			Vector3(0.3 + 0.55 * k, DECK, -hw + 0.55 + (k % 2) * 0.2),
			prof,
			8,
			Color(0.82, 0.76, 0.6),
			Basis.from_euler(Vector3(PI * 0.5, 0.0, 0.6 * k))
		)
	# Bales on the hatch, lashed.
	t.box(Vector3(3.6, DECK + 0.85, -0.3), Vector3(0.9, 0.5, 0.6), Color(0.72, 0.6, 0.42))
	t.box(Vector3(4.5, DECK + 0.85, 0.35), Vector3(0.8, 0.5, 0.6), Color(0.66, 0.56, 0.4))


## Rope ladder with wooden rungs over the port waist: how Kalev climbs aboard.
static func _add_boarding_ladder(t: CogParts, _iron: CogParts) -> void:
	var x := 0.6
	var top_z := -(CogHull.half_width_at(x, CogHull.SHEER_Y, false) + 0.05)
	var low_z := -(CogHull.half_width_at(x, 0.0, false) + 0.35)
	var rungs := 9
	for k in rungs:
		var f := float(k) / (rungs - 1)
		var y := lerpf(CogHull.SHEER_Y - 0.1, 0.2, f)
		var z := lerpf(top_z, low_z, f) - 0.02
		t.box(Vector3(x, y, z), Vector3(0.1, 0.07, 0.62), OAK)
	t.box(Vector3(x, CogHull.SHEER_Y + 0.02, top_z + 0.04), Vector3(0.6, 0.08, 0.2), DARK)

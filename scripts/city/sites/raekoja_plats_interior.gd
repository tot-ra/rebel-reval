extends "res://scripts/city/sites/raekoja_plats_parts.gd"

## Inside the council hall (site.raekoja_plats, ADR 0032): the diele with the
## Vogt's court and the Kämmerer, the dornse with the sitting council and the
## scribe, the partition between them, and their furniture. See the site
## manifest's `program_1343` for the sources.


static func _interior(
	shell: CityBuildingBuilder.Shell, roof: CityBuildingBuilder.Shell, rng: RandomNumberGenerator
) -> void:
	var ix := LENGTH * 0.5 - WALL
	var iz := DEPTH * 0.5 - WALL
	# Limestone flags in courses, each slab its own tone and a hair of relief.
	var z := -iz
	var row := 0
	while z < iz - 0.01:
		var dz := minf(rng.randf_range(0.55, 0.8), iz - z)
		var x := -ix + (0.0 if row % 2 == 0 else -0.3)
		while x < ix - 0.01:
			var dx := rng.randf_range(0.6, 1.0)
			var x0 := maxf(x, -ix)
			var x1 := minf(x + dx, ix)
			var tone := Color(1, 1, 1) * rng.randf_range(0.78, 1.0)
			tone.a = 1.0
			var lift := rng.randf_range(-0.006, 0.006)
			shell.quad_out(
				"flags",
				Vector3(x0 + 0.008, FLOOR + lift, z + 0.008),
				Vector3(x1 - 0.008, FLOOR + lift, z + 0.008),
				Vector3(x1 - 0.008, FLOOR + lift, z + dz - 0.008),
				Vector3(x0 + 0.008, FLOOR + lift, z + dz - 0.008),
				tone,
				Vector3.UP
			)
			x += dx
		z += dz
		row += 1
	# Mortar bed under the joints.
	shell.quad_out(
		"dark",
		Vector3(-ix, FLOOR - 0.012, -iz),
		Vector3(ix, FLOOR - 0.012, -iz),
		Vector3(ix, FLOOR - 0.012, iz),
		Vector3(-ix, FLOOR - 0.012, iz),
		Color(0.55, 0.5, 0.44),
		Vector3.UP
	)
	# Diele | dornse: a limestone partition with its own door (ADR 0032 notes).
	_partition(shell)
	# Oak posts on stone pads carry the summer beam, clear of every walking line
	# (portal -> court, portal -> dornse door). Joists and boards above.
	var beam_y := EAVE - 0.35
	for post: Vector2 in POSTS:
		CitySiteProps._box(
			shell,
			"ashlar",
			Vector3(post.x - 0.32, FLOOR - 0.01, post.y - 0.32),
			Vector3(post.x + 0.32, FLOOR + 0.16, post.y + 0.32),
			ASHLAR
		)
		CitySiteProps._box(
			shell,
			"timber",
			Vector3(post.x - 0.15, FLOOR + 0.16, post.y - 0.15),
			Vector3(post.x + 0.15, beam_y, post.y + 0.15),
			OAK
		)
		for sgn: float in [-1.0, 1.0]:
			_bar(
				shell,
				"timber",
				Vector3(post.x, beam_y - 1.0, post.y),
				Vector3(post.x + sgn * 0.9, beam_y - 0.05, post.y),
				0.12,
				OAK
			)
	CitySiteProps._box(
		roof, "timber", Vector3(-ix, beam_y, -0.18), Vector3(ix, beam_y + 0.35, 0.18), OAK_DARK
	)
	var j := -ix + 0.5
	while j < ix:
		CitySiteProps._box(
			roof,
			"timber",
			Vector3(j - 0.1, beam_y + 0.02, -iz),
			Vector3(j + 0.1, beam_y + 0.32, iz),
			OAK
		)
		j += 1.1
	roof.quad_out(
		"timber",
		Vector3(-ix, EAVE, -iz),
		Vector3(ix, EAVE, -iz),
		Vector3(ix, EAVE, iz),
		Vector3(-ix, EAVE, iz),
		OAK_DARK,
		Vector3.DOWN
	)
	_diele(shell, rng)
	_dornse(shell)


static func _partition(shell: CityBuildingBuilder.Shell) -> void:
	var iz := DEPTH * 0.5 - WALL
	var door := [Rect2(PART_DOOR.x + iz, FLOOR, PART_DOOR.y - PART_DOOR.x, PART_DOOR_H)]
	for face_x: float in [PART_X, PART_X + PART_T]:
		var west := face_x == PART_X
		var at := func(sv: float, y: float) -> Vector3: return Vector3(face_x, y, sv - iz)
		_holed_face(
			shell,
			"painted",
			at,
			0.0,
			iz * 2.0,
			FLOOR,
			EAVE,
			door,
			Vector3(-1 if west else 1, 0, 0),
			Color.WHITE
		)
	# Door reveal and lintel soffit.
	for z: float in [PART_DOOR.x, PART_DOOR.y]:
		shell.quad_out(
			"limewash",
			Vector3(PART_X, FLOOR, z),
			Vector3(PART_X + PART_T, FLOOR, z),
			Vector3(PART_X + PART_T, FLOOR + PART_DOOR_H, z),
			Vector3(PART_X, FLOOR + PART_DOOR_H, z),
			Color.WHITE,
			Vector3(0, 0, 1 if z == PART_DOOR.x else -1)
		)
	shell.quad_out(
		"limewash",
		Vector3(PART_X, FLOOR + PART_DOOR_H, PART_DOOR.x),
		Vector3(PART_X + PART_T, FLOOR + PART_DOOR_H, PART_DOOR.x),
		Vector3(PART_X + PART_T, FLOOR + PART_DOOR_H, PART_DOOR.y),
		Vector3(PART_X, FLOOR + PART_DOOR_H, PART_DOOR.y),
		Color.WHITE,
		Vector3.DOWN
	)
	CitySiteProps._box(
		shell,
		"ashlar",
		Vector3(PART_X - 0.02, FLOOR - 0.01, PART_DOOR.x),
		Vector3(PART_X + PART_T + 0.02, FLOOR + 0.02, PART_DOOR.y),
		ASHLAR
	)


## The great hall: the Vogt's court at the west end (dais, bench, barrier,
## oath lectern, the town arms), petitioners' bench, the Kämmerer's counting
## table and strongbox, candle stands, the cellar trapdoor.
static func _diele(shell: CityBuildingBuilder.Shell, rng: RandomNumberGenerator) -> void:
	var ix := LENGTH * 0.5 - WALL
	var iz := DEPTH * 0.5 - WALL
	# Dais: oak boards on a stone kerb, two steps in front.
	var d := DAIS
	CitySiteProps._box(
		shell,
		"ashlar",
		Vector3(d.position.x, FLOOR - 0.01, d.position.y),
		Vector3(d.end.x, FLOOR + DAIS_H - 0.04, d.end.y),
		ASHLAR * 0.9
	)
	CitySiteProps._box(
		shell,
		"timber",
		Vector3(d.position.x, FLOOR + DAIS_H - 0.04, d.position.y),
		Vector3(d.end.x, FLOOR + DAIS_H, d.end.y),
		OAK
	)
	CitySiteProps._box(
		shell,
		"ashlar",
		Vector3(d.end.x, FLOOR - 0.01, -0.9),
		Vector3(d.end.x + 0.32, FLOOR + DAIS_H * 0.5, 0.9),
		ASHLAR * 0.9
	)
	var top := FLOOR + DAIS_H
	_chair(shell, Vector3(-11.2, top, 0.0), 1.0)
	for sgn: float in [-1.0, 1.0]:
		_bench(shell, Vector3(-11.2, top, sgn * 1.9), 1.5, true)
	_table(shell, Vector3(-10.25, top, 0.0), 2.2, 0.75, true, Color(0.5, 0.13, 0.1))
	_candle_stand(shell, Vector3(-10.0, top, -2.9))
	_candle_stand(shell, Vector3(-10.0, top, 2.9))
	# The court barrier (Schranke) with a gap for the parties.
	for seg: Vector2 in [Vector2(-3.2, -0.7), Vector2(0.7, 3.2)]:
		_rail(shell, Vector3(-8.9, FLOOR, seg.x), Vector3(-8.9, FLOOR, seg.y))
	_lectern(shell, Vector3(-9.3, FLOOR, -2.5))
	# Town arms painted above the Vogt: red field, white cross.
	_arms(shell, Vector3(-ix + 0.01, FLOOR + 1.35, 0.0), 1.0, Vector3(1, 0, 0))
	# Petitioners' bench along the market wall.
	_bench(shell, Vector3(-5.0, FLOOR, -iz + 0.3), 4.8, false)
	# The Kämmerer's counting table (reckoning cloth, coin, scales) and strongbox.
	_table(shell, Vector3(1.8, FLOOR, 4.6), 2.0, 0.9, false, Color(0.22, 0.3, 0.22))
	for k in 5:
		var c := Vector3(1.2 + k * 0.28, FLOOR + 0.775, 4.45 + rng.randf_range(-0.1, 0.1))
		CitySiteProps._box(
			shell,
			"dark",
			c - Vector3(0.05, 0, 0.05),
			c + Vector3(0.05, 0.02 + k % 3 * 0.015, 0.05),
			Color(0.62, 0.5, 0.25)
		)
	_scales(shell, Vector3(2.5, FLOOR + 0.775, 4.75))
	_chest(shell, Vector3(3.3, FLOOR, 5.85), true)
	_candle_stand(shell, Vector3(0.3, FLOOR, 5.6))
	# Cellar trapdoor (the store below): boards, ledges and a ring.
	var tz := 4.6
	var tx := -3.8
	CitySiteProps._box(
		shell,
		"timber",
		Vector3(tx - 0.6, FLOOR, tz - 0.8),
		Vector3(tx + 0.6, FLOOR + 0.025, tz + 0.8),
		OAK_DARK
	)
	for k in 2:
		var lz := tz - 0.5 + k * 1.0
		CitySiteProps._box(
			shell,
			"timber",
			Vector3(tx - 0.58, FLOOR + 0.025, lz - 0.06),
			Vector3(tx + 0.58, FLOOR + 0.04, lz + 0.06),
			OAK
		)
	CitySiteProps._box(
		shell,
		"dark",
		Vector3(tx - 0.08, FLOOR + 0.025, tz - 0.03),
		Vector3(tx + 0.08, FLOOR + 0.045, tz + 0.03),
		IRON
	)


## The council chamber: council table with the seal, wax and documents,
## benches either side, the burgomasters' seat under a woollen hanging and the
## town arms, the scribe's desk at the window, the book cupboard, the
## three-lock town chest, hypocaust floor grilles.
static func _dornse(shell: CityBuildingBuilder.Shell) -> void:
	var ix := LENGTH * 0.5 - WALL
	var iz := DEPTH * 0.5 - WALL
	_table(shell, Vector3(8.2, FLOOR, 0.0), 4.4, 1.2, false, Color(0.2, 0.3, 0.2))
	var t := FLOOR + 0.775
	CitySiteProps._box(
		shell,
		"dark",
		Vector3(9.9, t, -0.12),
		Vector3(10.0, t + 0.09, -0.02),
		Color(0.62, 0.48, 0.2)
	)
	CitySiteProps._box(
		shell,
		"limewash",
		Vector3(9.7, t, 0.15),
		Vector3(9.95, t + 0.02, 0.2),
		Color(0.55, 0.12, 0.1)
	)
	for k in 4:
		var px := 6.8 + k * 0.8
		CitySiteProps._box(
			shell,
			"limewash",
			Vector3(px - 0.2, t, -0.35),
			Vector3(px + 0.2, t + 0.004, -0.05),
			Color(0.9, 0.84, 0.68)
		)
	_candle_stand(shell, Vector3(8.2, t, 0.3), true)
	for sgn: float in [-1.0, 1.0]:
		_bench(shell, Vector3(8.0, FLOOR, sgn * 1.05), 4.0, false)
	# Burgomasters' high-backed seat against the east wall, the hanging behind.
	CitySiteProps._box(
		shell, "timber", Vector3(ix - 0.75, FLOOR, -1.1), Vector3(ix - 0.25, FLOOR + 0.48, 1.1), OAK
	)
	CitySiteProps._box(
		shell,
		"timber",
		Vector3(ix - 0.25, FLOOR, -1.15),
		Vector3(ix - 0.1, FLOOR + 1.6, 1.15),
		OAK_DARK
	)
	for z: float in [-1.15, 1.1]:
		CitySiteProps._box(
			shell,
			"timber",
			Vector3(ix - 0.8, FLOOR, z),
			Vector3(ix - 0.1, FLOOR + 0.8, z + 0.05),
			OAK_DARK
		)
	var stripes := [Color(0.5, 0.12, 0.1), Color(0.26, 0.36, 0.26)]
	for k in 8:
		var z0 := -2.0 + k * 0.5
		shell.quad_out(
			"limewash",
			Vector3(ix - 0.03, FLOOR + 0.55, z0),
			Vector3(ix - 0.03, FLOOR + 0.55, z0 + 0.5),
			Vector3(ix - 0.03, FLOOR + 2.25, z0 + 0.5),
			Vector3(ix - 0.03, FLOOR + 2.25, z0),
			stripes[k % 2],
			Vector3(-1, 0, 0)
		)
	_arms(shell, Vector3(ix - 0.01, FLOOR + 2.55, 0.0), 0.9, Vector3(-1, 0, 0))
	# Scribe's slanted desk under the south window, with a stool.
	_desk(shell, Vector3(9.0, FLOOR, iz - 0.45))
	# Book cupboard against the partition, the three-lock town chest.
	_cupboard(shell, Vector3(PART_X + PART_T + 0.3, FLOOR, -4.4))
	_chest(shell, Vector3(ix - 0.5, FLOOR, -4.9), true)
	# Hypocaust vents: perforated stones over the warm-air channels.
	for z: float in [-3.1, 3.1]:
		for x: float in [6.6, 9.8]:
			CitySiteProps._box(
				shell,
				"ashlar",
				Vector3(x - 0.25, FLOOR - 0.005, z - 0.25),
				Vector3(x + 0.25, FLOOR + 0.008, z + 0.25),
				ASHLAR * 0.8
			)
			for a in 3:
				for b in 3:
					var c := Vector3(x - 0.14 + a * 0.14, FLOOR + 0.009, z - 0.14 + b * 0.14)
					CitySiteProps._box(
						shell,
						"dark",
						c - Vector3(0.03, 0, 0.03),
						c + Vector3(0.03, 0.002, 0.03),
						IRON
					)


## Trestle table (oak board on two trestles and a stretcher) with a cloth
## runner; `along_z` turns it a quarter.
static func _table(
	shell: CityBuildingBuilder.Shell,
	at: Vector3,
	length: float,
	width: float,
	along_z := false,
	cloth := Color(0.55, 0.15, 0.12)
) -> void:
	var top := 0.76
	var box := func(lo: Vector3, hi: Vector3, key: String, c: Color) -> void:
		if along_z:
			lo = Vector3(lo.z, lo.y, lo.x)
			hi = Vector3(hi.z, hi.y, hi.x)
		CitySiteProps._box(shell, key, at + lo, at + hi, c)
	box.call(
		Vector3(-length * 0.5, top - 0.07, -width * 0.5),
		Vector3(length * 0.5, top, width * 0.5),
		"timber",
		OAK
	)
	for sx: float in [-0.4, 0.4]:
		var x := sx * length
		box.call(
			Vector3(x - 0.07, 0.0, -width * 0.4),
			Vector3(x + 0.07, top - 0.07, width * 0.4),
			"timber",
			OAK_DARK
		)
		box.call(
			Vector3(x - 0.09, 0.0, -width * 0.45),
			Vector3(x + 0.09, 0.08, width * 0.45),
			"timber",
			OAK_DARK
		)
	box.call(
		Vector3(-length * 0.4, 0.25, -0.05), Vector3(length * 0.4, 0.33, 0.05), "timber", OAK_DARK
	)
	box.call(
		Vector3(-length * 0.32, top, -width * 0.32),
		Vector3(length * 0.32, top + 0.006, width * 0.32),
		"limewash",
		cloth
	)


## Plank bench on three stub legs; `along_z` turns it a quarter.
static func _bench(
	shell: CityBuildingBuilder.Shell, at: Vector3, length: float, along_z := false
) -> void:
	for k in 4:
		var lo: Vector3 = [
			Vector3(-length * 0.5, 0.42, -0.17),
			Vector3(-length * 0.45 - 0.05, 0.0, -0.13),
			Vector3(-0.05, 0.0, -0.13),
			Vector3(length * 0.45 - 0.05, 0.0, -0.13)
		][k]
		var hi: Vector3 = [
			Vector3(length * 0.5, 0.48, 0.17),
			Vector3(-length * 0.45 + 0.05, 0.42, 0.13),
			Vector3(0.05, 0.42, 0.13),
			Vector3(length * 0.45 + 0.05, 0.42, 0.13)
		][k]
		if along_z:
			lo = Vector3(lo.z, lo.y, lo.x)
			hi = Vector3(hi.z, hi.y, hi.x)
		CitySiteProps._box(shell, "timber", at + lo, at + hi, OAK if k == 0 else OAK_DARK)


## High-backed chair facing +x (`facing` 1) or -x (-1).
static func _chair(shell: CityBuildingBuilder.Shell, at: Vector3, facing := 1.0) -> void:
	var f := facing
	CitySiteProps._box(
		shell, "timber", at + Vector3(-0.3, 0.45, -0.34), at + Vector3(0.3, 0.52, 0.34), OAK
	)
	var back_x := -0.3 * f
	CitySiteProps._box(
		shell,
		"timber",
		at + Vector3(minf(back_x, back_x - 0.1 * f), 0.0, -0.34),
		at + Vector3(maxf(back_x, back_x - 0.1 * f), 1.75, 0.34),
		OAK_DARK
	)
	CitySiteProps._box(
		shell,
		"timber",
		at + Vector3(minf(back_x, back_x - 0.1 * f), 1.75, -0.4),
		at + Vector3(maxf(back_x, back_x - 0.1 * f), 1.85, 0.4),
		OAK_DARK
	)
	for sz: float in [-0.34, 0.3]:
		CitySiteProps._box(
			shell,
			"timber",
			at + Vector3(-0.3, 0.0, sz),
			at + Vector3(0.3, 0.75, sz + 0.04),
			OAK_DARK
		)


## Iron-bound chest; `locks` adds the three hasps of the town chest.
static func _chest(shell: CityBuildingBuilder.Shell, at: Vector3, locks := false) -> void:
	CitySiteProps._box(
		shell, "timber", at + Vector3(-0.32, 0.0, -0.62), at + Vector3(0.32, 0.62, 0.62), OAK_DARK
	)
	for z: float in [-0.45, 0.0, 0.45]:
		CitySiteProps._box(
			shell,
			"dark",
			at + Vector3(-0.33, 0.0, z - 0.04),
			at + Vector3(0.33, 0.63, z + 0.04),
			IRON
		)
		if locks:
			CitySiteProps._box(
				shell,
				"dark",
				at + Vector3(-0.36, 0.38, z - 0.07),
				at + Vector3(-0.32, 0.52, z + 0.07),
				IRON
			)


## Lectern for oaths: post, foot, sloped top with an open book and a relic box.
static func _lectern(shell: CityBuildingBuilder.Shell, at: Vector3) -> void:
	CitySiteProps._box(
		shell, "timber", at + Vector3(-0.06, 0.0, -0.06), at + Vector3(0.06, 1.0, 0.06), OAK_DARK
	)
	CitySiteProps._box(
		shell, "timber", at + Vector3(-0.25, 0.0, -0.25), at + Vector3(0.25, 0.06, 0.25), OAK_DARK
	)
	CitySiteProps._box(
		shell, "timber", at + Vector3(-0.24, 1.0, -0.3), at + Vector3(0.24, 1.06, 0.3), OAK
	)
	CitySiteProps._box(
		shell,
		"limewash",
		at + Vector3(-0.18, 1.06, -0.24),
		at + Vector3(0.18, 1.1, 0.24),
		Color(0.88, 0.82, 0.66)
	)
	CitySiteProps._box(
		shell,
		"dark",
		at + Vector3(-0.08, 1.1, 0.05),
		at + Vector3(0.08, 1.2, 0.2),
		Color(0.62, 0.48, 0.2)
	)


## Court barrier: posts every 0.6 m with a top rail and a lower rail.
static func _rail(shell: CityBuildingBuilder.Shell, a: Vector3, b: Vector3) -> void:
	var n := maxi(1, int(a.distance_to(b) / 0.6))
	for k in n + 1:
		var p := a.lerp(b, float(k) / n)
		CitySiteProps._box(
			shell, "timber", p + Vector3(-0.05, 0.0, -0.05), p + Vector3(0.05, 1.0, 0.05), OAK_DARK
		)
	_bar(shell, "timber", a + Vector3(0, 1.0, 0), b + Vector3(0, 1.0, 0), 0.1, OAK)
	_bar(shell, "timber", a + Vector3(0, 0.35, 0), b + Vector3(0, 0.35, 0), 0.06, OAK_DARK)


## The town's lesser arms painted on a wall: a red heater shield with a white
## cross, `size` m tall, facing `out`.
static func _arms(shell: CityBuildingBuilder.Shell, at: Vector3, size: float, out: Vector3) -> void:
	var w := size * 0.8
	var side := Vector3(-out.z, 0, out.x)
	var red := Color(0.58, 0.13, 0.1)
	var white := Color(0.9, 0.87, 0.78)
	var pts: Array[Vector2] = []
	for k in 13:
		var t := float(k) / 12.0
		# Heater outline: flat top, straight sides, curving to the point.
		var y := 1.0 - t
		var half := 0.5 if y > 0.45 else 0.5 * sqrt(maxf(0.0, y / 0.45))
		pts.append(Vector2(half, y))
	var poly := PackedVector2Array()
	for p in pts:
		poly.append(Vector2(p.x * w, p.y * size))
	for k in range(pts.size() - 1, -1, -1):
		poly.append(Vector2(-pts[k].x * w, pts[k].y * size))
	var tris := Geometry2D.triangulate_polygon(poly)
	for k in range(0, tris.size(), 3):
		var v: Array[Vector3] = []
		for q in 3:
			var p2 := poly[tris[k + q]]
			v.append(at + side * p2.x + Vector3(0, p2.y - size * 0.5, 0) + out * 0.002)
		shell.tri_out("limewash", v[0], v[1], v[2], red, out)
	var cw := w * 0.11
	for bar: Array in [
		[Vector2(-cw, -size * 0.42), Vector2(cw, size * 0.5)],
		[Vector2(-w * 0.5, size * 0.12), Vector2(w * 0.5, size * 0.12 + cw * 2.0)]
	]:
		var lo: Vector2 = bar[0]
		var hi: Vector2 = bar[1]
		var o := out * 0.004
		shell.quad_out(
			"limewash",
			at + side * lo.x + Vector3(0, lo.y, 0) + o,
			at + side * hi.x + Vector3(0, lo.y, 0) + o,
			at + side * hi.x + Vector3(0, hi.y, 0) + o,
			at + side * lo.x + Vector3(0, hi.y, 0) + o,
			white,
			out
		)


## Iron pricket candle stand with a tallow candle; `on_table` makes it short.
static func _candle_stand(shell: CityBuildingBuilder.Shell, at: Vector3, on_table := false) -> void:
	var h := 0.25 if on_table else 1.35
	if not on_table:
		for k in 3:
			var a := TAU * k / 3.0
			_bar(
				shell,
				"dark",
				at + Vector3(0, 0.25, 0),
				at + Vector3(cos(a) * 0.25, 0.0, sin(a) * 0.25),
				0.03,
				IRON
			)
	_bar(
		shell,
		"dark",
		at + Vector3(0, 0.0 if on_table else 0.25, 0),
		at + Vector3(0, h, 0),
		0.03,
		IRON
	)
	CitySiteProps._box(
		shell, "dark", at + Vector3(-0.08, h, -0.08), at + Vector3(0.08, h + 0.02, 0.08), IRON
	)
	CitySiteProps._box(
		shell,
		"limewash",
		at + Vector3(-0.025, h + 0.02, -0.025),
		at + Vector3(0.025, h + 0.2, 0.025),
		Color(0.95, 0.9, 0.75)
	)


## Hand balance: post, beam and two pans.
static func _scales(shell: CityBuildingBuilder.Shell, at: Vector3) -> void:
	var brass := Color(0.62, 0.5, 0.25)
	_bar(shell, "dark", at, at + Vector3(0, 0.38, 0), 0.025, IRON)
	_bar(shell, "dark", at + Vector3(-0.2, 0.36, 0), at + Vector3(0.2, 0.36, 0), 0.015, brass)
	for sx: float in [-0.2, 0.2]:
		_bar(shell, "dark", at + Vector3(sx, 0.36, 0), at + Vector3(sx, 0.12, 0), 0.006, IRON)
		CitySiteProps._box(
			shell,
			"dark",
			at + Vector3(sx - 0.07, 0.1, -0.07),
			at + Vector3(sx + 0.07, 0.12, 0.07),
			brass
		)


## The scribe's slanted desk with parchment, inkhorn and quill, and a stool.
static func _desk(shell: CityBuildingBuilder.Shell, at: Vector3) -> void:
	for sx: float in [-0.5, 0.5]:
		CitySiteProps._box(
			shell,
			"timber",
			at + Vector3(sx - 0.05, 0.0, -0.25),
			at + Vector3(sx + 0.05, 0.85, 0.25),
			OAK_DARK
		)
	var lo := at + Vector3(-0.6, 0.85, -0.3)
	var hi := at + Vector3(0.6, 1.05, 0.3)
	# Sloped top: low edge toward the writer (-z), high edge toward the wall.
	shell.quad_out(
		"timber",
		Vector3(lo.x, lo.y, lo.z),
		Vector3(hi.x, lo.y, lo.z),
		Vector3(hi.x, hi.y, hi.z),
		Vector3(lo.x, hi.y, hi.z),
		OAK,
		Vector3(0, 1, -0.3)
	)
	shell.quad_out(
		"limewash",
		Vector3(lo.x + 0.3, lo.y + 0.03, lo.z + 0.08),
		Vector3(hi.x - 0.3, lo.y + 0.03, lo.z + 0.08),
		Vector3(hi.x - 0.3, hi.y - 0.02, hi.z - 0.08),
		Vector3(lo.x + 0.3, hi.y - 0.02, hi.z - 0.08),
		Color(0.9, 0.84, 0.68),
		Vector3(0, 1, -0.3)
	)
	CitySiteProps._box(
		shell,
		"dark",
		at + Vector3(0.45, 1.05, 0.15),
		at + Vector3(0.52, 1.13, 0.22),
		Color(0.2, 0.16, 0.12)
	)
	_bar(
		shell,
		"limewash",
		at + Vector3(0.48, 1.12, 0.18),
		at + Vector3(0.3, 1.3, 0.1),
		0.012,
		Color(0.95, 0.93, 0.88)
	)
	CitySiteProps._box(
		shell, "timber", at + Vector3(-0.2, 0.0, -0.75), at + Vector3(0.2, 0.46, -0.45), OAK
	)


## Book cupboard (armarium) with two doors; the town books lie flat inside.
static func _cupboard(shell: CityBuildingBuilder.Shell, at: Vector3) -> void:
	CitySiteProps._box(
		shell, "timber", at + Vector3(-0.25, 0.0, -0.75), at + Vector3(0.25, 2.0, 0.75), OAK_DARK
	)
	for z: float in [-0.37, 0.37]:
		CitySiteProps._box(
			shell,
			"timber",
			at + Vector3(0.25, 0.15, z - 0.34),
			at + Vector3(0.28, 1.85, z + 0.34),
			OAK
		)
		CitySiteProps._box(
			shell,
			"dark",
			at + Vector3(0.28, 0.95, z - 0.02 * signf(z) - 0.03),
			at + Vector3(0.3, 1.1, z - 0.02 * signf(z) + 0.03),
			IRON
		)
	for y: float in [0.5, 1.4]:
		CitySiteProps._box(
			shell, "dark", at + Vector3(0.28, y, -0.72), at + Vector3(0.3, y + 0.05, 0.72), IRON
		)

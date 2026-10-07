extends "res://scripts/city/sites/raekoja_plats_parts.gd"

## site.raekoja_plats (ADR 0032): the forum and the council hall as they stood
## in spring 1343 (history/dossiers/topography/raekoja-plats-extents-1343.md).
##
## The hall: one tall storey of grey limestone rubble, 26 x 14.8 m, walls
## ~0.95 m thick, a steep monk-and-nun tile roof between stone parapet gables,
## an attic storeroom with a loft door and hoist in the east gable. The market
## (north) front has a pointed-arch portal and rectangular windows in dressed
## stone frames with plank shutters; the rear has smaller lights. No arcade,
## no tower, no upper storey (all after 1343).
##
## Inside (raekoja_plats_interior.gd): the diele with the Vogt's court and the
## Kämmerer's table, the dornse with the sitting council and the scribe, under
## a painted wash (false ashlar, dado, frieze) on a limestone-flag floor.
##
## Everything above CUT (head height) is built into the "Upper" node, the roof
## and ceiling into "Roof"; the room hides both while Kalev is inside, so the
## cameras look into a cleanly cut building (cut wall tops get a stone section).
## Interim GDScript model; a Blender-generated GLB replaces it later.

const Interior := preload("res://scripts/city/sites/raekoja_plats_interior.gd")


static func build(site: CitySite, plan: CityPlan) -> Node3D:
	var root := Node3D.new()
	root.name = "Site_%s" % String(site.id).replace(".", "_")
	root.add_child(_hall(site))
	for item: Dictionary in site.data.get("dressing", []):
		var world := site.to_world(Vector2(item["at"][0], item["at"][1]))
		CitySiteProps.add(root, item, plan.ground_height(world) - site.level)
	return root


# --- the hall --------------------------------------------------------------


static func _hall(site: CitySite) -> Node3D:
	var hall := Node3D.new()
	hall.name = "CouncilHall"
	(_material_for("limewash") as ShaderMaterial).set_shader_parameter(
		"floor_y", site.level + FLOOR
	)
	var painted := _material_for("painted") as ShaderMaterial
	painted.set_shader_parameter("floor_y", site.level + FLOOR)
	painted.set_shader_parameter("site_origin", site.origin)
	painted.set_shader_parameter("site_axis", Vector2(cos(site.rotation), sin(site.rotation)))
	painted.set_shader_parameter("rich_from", PART_X + PART_T * 0.5)
	var body := CityBuildingBuilder.Shell.new()
	var roof := CityBuildingBuilder.Shell.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(site.id))
	var hx := LENGTH * 0.5
	var hz := DEPTH * 0.5
	var rise := hz * tan(deg_to_rad(PITCH_DEG))

	# Openings per facade, in that facade's own (s along it, y) coordinates.
	var north := _openings_north()
	var south := _openings_south()
	_facade(body, Vector2(-hx, -hz), Vector2(hx, -hz), north, -SINK, EAVE)
	_facade(body, Vector2(hx, hz), Vector2(-hx, hz), south, -SINK, EAVE)
	_facade(body, Vector2(hx, -hz), Vector2(hx, hz), [], -SINK, EAVE)
	_facade(
		body,
		Vector2(-hx, hz),
		Vector2(-hx, -hz),
		[_win(DEPTH * 0.5, WIN_SILL, WIN_W, WIN_H)],
		-SINK,
		EAVE
	)
	# Gables (parapet above the roof plane) with blind niches; loft door east.
	_gable(body, 1.0, rise, true)
	_gable(body, -1.0, rise, false)
	_plinth_and_quoins(body, rng)
	_portal(body)
	for o: Rect2 in north:
		if o.size.x < PORTAL_W:
			_window_dressing(body, rng, Vector2(-hx, -hz), Vector2(hx, -hz), o, true)
	for o: Rect2 in south:
		_window_dressing(body, rng, Vector2(hx, hz), Vector2(-hx, hz), o, false)
	_window_dressing(
		body,
		rng,
		Vector2(-hx, hz),
		Vector2(-hx, -hz),
		_win(DEPTH * 0.5, WIN_SILL, WIN_W, WIN_H),
		true
	)
	Interior._interior(body, roof, rng)
	_roof(roof, rise)

	# Cutaway split: below the cut stays; the rest lifts with the roof.
	var parts := body.split_at(CUT)
	var lower: CityBuildingBuilder.Shell = parts[0]
	var upper: CityBuildingBuilder.Shell = parts[1]
	_cut_caps(lower)
	var lower_node := _mesh("Lower", lower)
	hall.add_child(lower_node)
	# Candlelight on the council table: warm fill for the dim hall.
	var candle := OmniLight3D.new()
	candle.name = "CouncilCandles"
	candle.light_color = Color(1.0, 0.72, 0.45)
	candle.light_energy = 1.6
	candle.omni_range = 9.0
	candle.position = Vector3(-9.8, FLOOR + 1.6, 0.0)
	lower_node.add_child(candle)
	for spot: Vector3 in [Vector3(8.2, FLOOR + 1.4, 0.3), Vector3(1.6, FLOOR + 1.6, 4.4)]:
		var light := candle.duplicate() as OmniLight3D
		light.name = "Candles_%d" % int(spot.x)
		light.position = spot
		light.light_energy = 1.3
		lower_node.add_child(light)
	var upper_node := _mesh("Upper", upper)
	hall.add_child(upper_node)
	_banners(upper_node)
	hall.add_child(_mesh("Roof", roof))
	return hall


static func _win(center_s: float, sill: float, w: float, h: float) -> Rect2:
	return Rect2(center_s - w * 0.5, sill, w, h)


## Market front (s from the west corner): portal in the middle, three
## windows each side.
static func _openings_north() -> Array[Rect2]:
	var out: Array[Rect2] = [Rect2(LENGTH * 0.5 - PORTAL_W * 0.5, FLOOR, PORTAL_W, PORTAL_H)]
	for d: float in [3.4, 7.1, 10.8]:
		out.append(_win(LENGTH * 0.5 - d, WIN_SILL, WIN_W, WIN_H))
		out.append(_win(LENGTH * 0.5 + d, WIN_SILL, WIN_W, WIN_H))
	return out


static func _openings_south() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for d: float in [-9.0, -3.0, 3.0, 9.0]:
		out.append(_win(LENGTH * 0.5 + d, 1.8, 0.8, 1.2))
	return out


## A wall slab between corners a (outer, start) and b along the outer face,
## WALL thick, from y0 to y1, with rectangular openings (s, y, w, h). Outer
## face in limestone, inner face lime-washed from the floor up, reveals
## through the thickness. Faces are built as grid cells between all opening
## edges, so any number of openings cuts cleanly.
static func _facade(
	shell: CityBuildingBuilder.Shell, a: Vector2, b: Vector2, openings: Array, y0: float, y1: float
) -> void:
	var length := a.distance_to(b)
	var dir := (b - a) / length
	var out := Vector2(dir.y, -dir.x)
	if out.dot(a + b) < 0.0:
		out = -out
	var inward := -out
	var outer := func(s: float, y: float) -> Vector3:
		var p := a + dir * s
		return Vector3(p.x, y, p.y)
	var inner := func(s: float, y: float) -> Vector3:
		var p := a + dir * s + inward * WALL
		return Vector3(p.x, y, p.y)
	var o3 := Vector3(out.x, 0.0, out.y)
	_holed_face(shell, "wall:limestone", outer, 0.0, length, y0, y1, openings, o3, STONE)
	# Windows splay inward (wider inside, the sill sloping down), as thick
	# medieval walls were built to let the light in; doors keep straight jambs.
	var inner_openings: Array = []
	for o: Rect2 in openings:
		var door := o.position.y <= FLOOR + 0.01
		inner_openings.append(o if door else o.grow_individual(SPLAY, SPLAY * 0.5, SPLAY, 0.15))
	# Inner face spans between the inner corners.
	_holed_face(
		shell, "painted", inner, WALL, length - WALL, FLOOR, y1, inner_openings, -o3, Color.WHITE
	)
	for k in openings.size():
		var o: Rect2 = openings[k]
		var io: Rect2 = inner_openings[k]
		var door := o.position.y <= FLOOR + 0.01
		var key := "limewash"
		var tone := Color.WHITE
		var d3 := Vector3(dir.x, 0, dir.y)
		# Jambs, sill, head through the wall (outer opening to inner opening).
		shell.quad_out(
			key,
			outer.call(o.position.x, o.position.y),
			inner.call(io.position.x, io.position.y),
			inner.call(io.position.x, io.end.y),
			outer.call(o.position.x, o.end.y),
			tone,
			d3
		)
		shell.quad_out(
			key,
			outer.call(o.end.x, o.position.y),
			inner.call(io.end.x, io.position.y),
			inner.call(io.end.x, io.end.y),
			outer.call(o.end.x, o.end.y),
			tone,
			-d3
		)
		shell.quad_out(
			key,
			outer.call(o.position.x, o.position.y),
			outer.call(o.end.x, o.position.y),
			inner.call(io.end.x, io.position.y),
			inner.call(io.position.x, io.position.y),
			tone,
			Vector3.UP
		)
		shell.quad_out(
			key,
			outer.call(o.position.x, o.end.y),
			outer.call(o.end.x, o.end.y),
			inner.call(io.end.x, io.end.y),
			inner.call(io.position.x, io.end.y),
			tone,
			Vector3.DOWN
		)
	# Wall head under the roof.
	shell.quad_out(
		"wall:limestone",
		outer.call(0.0, y1),
		outer.call(length, y1),
		inner.call(length, y1),
		inner.call(0.0, y1),
		STONE,
		Vector3.UP
	)


## Gable end at x = side * LENGTH/2: a triangle of masonry from the eave to
## PARAPET above the roof line, both faces and the coping. East (side +1)
## carries the loft door and hoist, both carry three stepped blind niches.
static func _gable(shell: CityBuildingBuilder.Shell, side: float, rise: float, loft: bool) -> void:
	var hz := DEPTH * 0.5
	var x_out := side * LENGTH * 0.5
	var x_in := side * (LENGTH * 0.5 - WALL)
	var apex := EAVE + rise + PARAPET
	var top := func(z: float) -> float: return EAVE + PARAPET + (hz - absf(z)) * (rise / hz)
	# Recesses on the outer face (z0, z1, y0, y1): blind lancet niches and the loft door.
	var holes: Array[Rect2] = []
	for k: float in [-1.0, 0.0, 1.0]:
		var hgt := 2.4 - absf(k) * 0.8
		var z := k * 2.0
		holes.append(Rect2(z - 0.35, EAVE + 1.2 + absf(k) * 0.5, 0.7, hgt))
	if loft:
		holes[1] = Rect2(-0.6, EAVE + 0.6, 1.2, 1.6)
	var zs: Array[float] = [-hz, hz]
	for h in holes:
		zs.append_array([h.position.x, h.end.x])
	zs.sort()
	var o3 := Vector3(side, 0, 0)
	for i in zs.size() - 1:
		var z0: float = zs[i]
		var z1: float = zs[i + 1]
		if z1 - z0 < 0.001:
			continue
		var bands: Array[Vector2] = [Vector2(EAVE, INF)]
		for h in holes:
			if h.position.x <= (z0 + z1) * 0.5 and (z0 + z1) * 0.5 <= h.end.x:
				var last: Vector2 = bands.pop_back()
				bands.append(Vector2(last.x, h.position.y))
				bands.append(Vector2(h.end.y, INF))
		for band in bands:
			var y0 := band.x
			if band.y == INF:
				shell.quad_out(
					"wall:limestone",
					Vector3(x_out, y0, z0),
					Vector3(x_out, y0, z1),
					Vector3(x_out, top.call(z1), z1),
					Vector3(x_out, top.call(z0), z0),
					STONE,
					o3
				)
			else:
				shell.quad_out(
					"wall:limestone",
					Vector3(x_out, y0, z0),
					Vector3(x_out, y0, z1),
					Vector3(x_out, band.y, z1),
					Vector3(x_out, band.y, z0),
					STONE,
					o3
				)
	# Niche backs (lime-washed recess 0.2 m deep) and their reveals.
	for idx in holes.size():
		var h := holes[idx]
		var depth := 0.2
		var xb := x_out - side * depth
		var is_door := loft and idx == 1
		var back_key := "timber" if is_door else "limewash"
		var back_col := OAK_DARK if is_door else Color.WHITE
		shell.quad_out(
			back_key,
			Vector3(xb, h.position.y, h.position.x),
			Vector3(xb, h.position.y, h.end.x),
			Vector3(xb, h.end.y, h.end.x),
			Vector3(xb, h.end.y, h.position.x),
			back_col,
			o3
		)
		for z: float in [h.position.x, h.end.x]:
			var f := Vector3(0, 0, 1.0 if z == h.position.x else -1.0)
			shell.quad_out(
				"ashlar",
				Vector3(x_out, h.position.y, z),
				Vector3(xb, h.position.y, z),
				Vector3(xb, h.end.y, z),
				Vector3(x_out, h.end.y, z),
				ASHLAR,
				f
			)
		for y: float in [h.position.y, h.end.y]:
			var f := Vector3.UP if y == h.position.y else Vector3.DOWN
			shell.quad_out(
				"ashlar",
				Vector3(x_out, y, h.position.x),
				Vector3(x_out, y, h.end.x),
				Vector3(xb, y, h.end.x),
				Vector3(xb, y, h.position.x),
				ASHLAR,
				f
			)
		# Pointed head over each niche: two sloping ashlar voussoir bars.
		if not is_door:
			var cz := h.get_center().x
			var w := h.size.x * 0.5 + 0.08
			_bar(
				shell,
				"ashlar",
				Vector3(x_out + side * 0.03, h.end.y, cz - w),
				Vector3(x_out + side * 0.03, h.end.y + w * 1.1, cz),
				0.16,
				ASHLAR
			)
			_bar(
				shell,
				"ashlar",
				Vector3(x_out + side * 0.03, h.end.y, cz + w),
				Vector3(x_out + side * 0.03, h.end.y + w * 1.1, cz),
				0.16,
				ASHLAR
			)
	# Inner gable face (attic side) and the gable thickness at the rakes.
	shell.quad_out(
		"wall:limestone",
		Vector3(x_in, EAVE, -hz),
		Vector3(x_in, EAVE, hz),
		Vector3(x_in, top.call(hz), hz),
		Vector3(x_in, top.call(-hz), -hz),
		STONE,
		-o3
	)
	shell.tri_out(
		"wall:limestone",
		Vector3(x_in, top.call(-hz), -hz),
		Vector3(x_in, top.call(hz), hz),
		Vector3(x_in, apex, 0.0),
		STONE,
		-o3
	)
	# Coping slabs along both rakes, overhanging the faces, and kneelers.
	for rake: float in [-1.0, 1.0]:
		var e := Vector3(0.0, top.call(rake * hz), rake * hz)
		var t := Vector3(0.0, apex, 0.0)
		var xc := (x_out + x_in) * 0.5
		_slab(shell, Vector3(xc, e.y, e.z), Vector3(xc, t.y, t.z), WALL + 0.24, 0.18)
		CitySiteProps._box(
			shell,
			"ashlar",
			Vector3(
				minf(x_out, x_in) - 0.12,
				EAVE + PARAPET - 0.1,
				rake * hz - 0.35 - (0.0 if rake > 0 else 0.0)
			),
			Vector3(maxf(x_out, x_in) + 0.12, EAVE + PARAPET + 0.35, rake * hz + 0.35),
			ASHLAR
		)
	# Apex finial.
	CitySiteProps._box(
		shell,
		"ashlar",
		Vector3(minf(x_out, x_in) - 0.1, apex - 0.05, -0.28),
		Vector3(maxf(x_out, x_in) + 0.1, apex + 0.55, 0.28),
		ASHLAR
	)
	# Putlog holes in two rows (left from the scaffolding).
	for row: float in [EAVE + 0.4, EAVE + 2.9]:
		for k in 5:
			var z := -hz + 1.4 + k * (DEPTH - 2.8) / 4.0
			if row > top.call(z) - 0.6:
				continue
			CitySiteProps._box(
				shell,
				"dark",
				Vector3(x_out - side * 0.01 - 0.01, row, z - 0.09),
				Vector3(x_out + side * 0.01 + 0.01, row + 0.16, z + 0.09),
				IRON
			)
	if loft:
		# Hoist beam out of the loft door with a rope and hook.
		var bx := x_out + side * 1.4
		CitySiteProps._box(
			shell,
			"timber",
			Vector3(minf(x_out - side * 0.4, bx), EAVE + 2.5, -0.13),
			Vector3(maxf(x_out - side * 0.4, bx), EAVE + 2.75, 0.13),
			OAK_DARK
		)
		_bar(
			shell,
			"timber",
			Vector3(bx - side * 0.05, EAVE + 2.5, 0.0),
			Vector3(bx - side * 0.05, EAVE + 0.4, 0.0),
			0.035,
			Color(0.62, 0.55, 0.42)
		)
		CitySiteProps._box(
			shell,
			"dark",
			Vector3(bx - side * 0.05 - 0.06, EAVE + 0.25, -0.05),
			Vector3(bx - side * 0.05 + 0.06, EAVE + 0.42, 0.05),
			IRON
		)


## Coping slab from a to b (centre line), `width` across x, `thick` high.
static func _slab(
	shell: CityBuildingBuilder.Shell, a: Vector3, b: Vector3, width: float, thick: float
) -> void:
	var d := (b - a).normalized()
	var side := Vector3(1, 0, 0) * width * 0.5
	var up := d.cross(Vector3(1, 0, 0)).normalized()
	if up.y < 0.0:
		up = -up
	var lo := up * 0.02
	var hi := up * thick
	var corners := [
		a - side + lo,
		b - side + lo,
		b + side + lo,
		a + side + lo,
		a - side + hi,
		b - side + hi,
		b + side + hi,
		a + side + hi
	]
	var c := (a + b) * 0.5 + up * thick * 0.5
	for f: Array in [
		[4, 5, 6, 7], [0, 1, 5, 4], [3, 2, 6, 7], [0, 3, 7, 4], [1, 2, 6, 5], [0, 1, 2, 3]
	]:
		var p0: Vector3 = corners[f[0]]
		var p1: Vector3 = corners[f[1]]
		var p2: Vector3 = corners[f[2]]
		var p3: Vector3 = corners[f[3]]
		shell.quad_out("ashlar", p0, p1, p2, p3, ASHLAR, (p0 + p1 + p2 + p3) * 0.25 - c)


## Footing plinth of large darker stones, proud of the wall, open at the
## portal; dressed quoins at the four corners.
static func _plinth_and_quoins(
	shell: CityBuildingBuilder.Shell, rng: RandomNumberGenerator
) -> void:
	var hx := LENGTH * 0.5
	var hz := DEPTH * 0.5
	var proud := 0.14
	var h := 0.5
	var dark := STONE * 0.78
	dark.a = 1.0
	var pw := PORTAL_W * 0.5 + 0.25
	# North in two runs either side of the portal, then the other three sides.
	CitySiteProps._box(
		shell,
		"wall:limestone",
		Vector3(-hx - proud, -SINK, -hz - proud),
		Vector3(-pw, h, -hz + 0.02),
		dark
	)
	CitySiteProps._box(
		shell,
		"wall:limestone",
		Vector3(pw, -SINK, -hz - proud),
		Vector3(hx + proud, h, -hz + 0.02),
		dark
	)
	CitySiteProps._box(
		shell,
		"wall:limestone",
		Vector3(-hx - proud, -SINK, hz - 0.02),
		Vector3(hx + proud, h, hz + proud),
		dark
	)
	CitySiteProps._box(
		shell,
		"wall:limestone",
		Vector3(hx - 0.02, -SINK, -hz - proud),
		Vector3(hx + proud, h, hz + proud),
		dark
	)
	CitySiteProps._box(
		shell,
		"wall:limestone",
		Vector3(-hx - proud, -SINK, -hz - proud),
		Vector3(-hx + 0.02, h, hz + proud),
		dark
	)
	# Chamfered weathering course on top of the plinth.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var y := h
			var k := 0
			while y < EAVE - 0.35:
				var long := k % 2 == 0
				var lx := 0.62 if long else 0.34
				var lz := 0.34 if long else 0.62
				var tone := ASHLAR * rng.randf_range(0.92, 1.02)
				tone.a = 1.0
				var cx := sx * hx
				var cz := sz * hz
				CitySiteProps._box(
					shell,
					"ashlar",
					Vector3(minf(cx, cx - sx * lx) - 0.025, y, minf(cz, cz - sz * lz) - 0.025),
					Vector3(
						maxf(cx, cx - sx * lx) + 0.025, y + 0.32, maxf(cz, cz - sz * lz) + 0.025
					),
					tone
				)
				y += 0.34
				k += 1


## Pointed-arch portal on the market front: dressed jambs with a chamfer,
## lintel, a plain tympanum under a two-centred arch, and a worn threshold
## stone flush with the floor (no plinth across the door).
static func _portal(shell: CityBuildingBuilder.Shell) -> void:
	var z := -DEPTH * 0.5
	var w := PORTAL_W * 0.5
	var head := FLOOR + PORTAL_H
	var j := 0.24
	for s: float in [-1.0, 1.0]:
		CitySiteProps._box(
			shell,
			"ashlar",
			Vector3(minf(s * w, s * (w + j)), 0.0, z - 0.12),
			Vector3(maxf(s * w, s * (w + j)), head, z + 0.02),
			ASHLAR
		)
	CitySiteProps._box(
		shell,
		"ashlar",
		Vector3(-w - j, head, z - 0.12),
		Vector3(w + j, head + 0.24, z + 0.02),
		ASHLAR
	)
	# Tympanum (recessed) and the arch ring as segments.
	var r := w + j
	var tymp_tint := ASHLAR * 0.9
	tymp_tint.a = 1.0
	var segs := 10
	for k in segs:
		for side: float in [-1.0, 1.0]:
			var t0 := float(k) / segs
			var t1 := float(k + 1) / segs
			var p0 := _arch_point(side, t0, r, head + 0.24)
			var p1 := _arch_point(side, t1, r, head + 0.24)
			var q0 := _arch_point(side, t0, r - j, head + 0.24)
			var q1 := _arch_point(side, t1, r - j, head + 0.24)
			shell.quad_out(
				"ashlar",
				Vector3(p0.x, p0.y, z - 0.12),
				Vector3(p1.x, p1.y, z - 0.12),
				Vector3(q1.x, q1.y, z - 0.12),
				Vector3(q0.x, q0.y, z - 0.12),
				ASHLAR,
				Vector3(0, 0, -1)
			)
			shell.quad_out(
				"ashlar",
				Vector3(p0.x, p0.y, z - 0.12),
				Vector3(p1.x, p1.y, z - 0.12),
				Vector3(p1.x, p1.y, z + 0.02),
				Vector3(p0.x, p0.y, z + 0.02),
				ASHLAR,
				Vector3(p0.x + p1.x, p0.y + p1.y - 2.0 * (head + 0.24), 0.0)
			)
			shell.tri_out(
				"ashlar",
				Vector3(0.0, head + 0.24, z - 0.05),
				Vector3(q0.x, q0.y, z - 0.05),
				Vector3(q1.x, q1.y, z - 0.05),
				tymp_tint,
				Vector3(0, 0, -1)
			)
	# Threshold: worn limestone step from the forum up to the floor.
	CitySiteProps._box(
		shell,
		"ashlar",
		Vector3(-w - 0.15, -0.2, z - 0.55),
		Vector3(w + 0.15, FLOOR - 0.005, z + WALL),
		ASHLAR * 0.85
	)


## Point on one half of a two-centred (equilateral) arch of span radius r.
static func _arch_point(side: float, t: float, r: float, spring: float) -> Vector2:
	var c := Vector2(-side * r, spring)  # centre on the opposite springer
	var ang := lerpf(0.0, PI / 3.0, t)
	var span := 2.0 * r
	return c + Vector2(side * cos(ang), sin(ang)) * span


## Stone frame, iron grille and plank shutters for one window.
static func _window_dressing(
	shell: CityBuildingBuilder.Shell,
	rng: RandomNumberGenerator,
	a: Vector2,
	b: Vector2,
	o: Rect2,
	big: bool
) -> void:
	var dir := (b - a).normalized()
	var out := Vector2(dir.y, -dir.x)
	if out.dot(a + b) < 0.0:
		out = -out
	var at := func(s: float, y: float, off: float) -> Vector3:
		var p := a + dir * s + out * off
		return Vector3(p.x, y, p.y)
	var f := 0.16
	var proud := 0.07
	var s0 := o.position.x
	var s1 := o.end.x
	var y0 := o.position.y
	var y1 := o.end.y
	# Frame: jambs, lintel, projecting sill with drip.
	_frame_box(shell, at, s0 - f, s0, y0 - 0.02, y1 + 0.02, 0.0, proud)
	_frame_box(shell, at, s1, s1 + f, y0 - 0.02, y1 + 0.02, 0.0, proud)
	_frame_box(shell, at, s0 - f, s1 + f, y1, y1 + 0.22, 0.0, proud)
	_frame_box(shell, at, s0 - f - 0.06, s1 + f + 0.06, y0 - 0.14, y0, 0.0, proud + 0.07)
	# Iron grille set in the reveal, a third of the way in.
	for k in 2:
		var s := lerpf(s0, s1, (k + 1) / 3.0)
		_bar(shell, "dark", at.call(s, y0, -0.3), at.call(s, y1, -0.3), 0.025, IRON)
	_bar(
		shell,
		"dark",
		at.call(s0, y0 + o.size.y * 0.5, -0.3),
		at.call(s1, y0 + o.size.y * 0.5, -0.3),
		0.025,
		IRON
	)
	# Shutters: two leaves exactly half the opening each, hung on the frame.
	# Closed, ajar or folded back against the wall, per window.
	var state := rng.randf()
	var swing := 0.0 if state < 0.25 else (deg_to_rad(55.0) if state < 0.45 else deg_to_rad(172.0))
	var leaf_w := o.size.x * 0.5
	for side: float in [-1.0, 1.0]:
		var hinge_s := s0 if side < 0.0 else s1
		var hinge := a + dir * hinge_s + out * (proud + 0.02)
		var along := dir * (-side)  # closed leaf runs toward the middle
		var open_dir := along.rotated(side * swing) if big else along.rotated(side * swing)
		var leaf_end := hinge + open_dir.rotated(0.0) * leaf_w
		# Rotate outward, not into the wall.
		if open_dir.dot(out) < -0.01:
			leaf_end = hinge + (open_dir - out * 2.0 * open_dir.dot(out)) * leaf_w
		_leaf(shell, hinge, leaf_end, y0 + 0.02, y1 - 0.02, out)


static func _frame_box(
	shell: CityBuildingBuilder.Shell,
	at: Callable,
	s0: float,
	s1: float,
	y0: float,
	y1: float,
	off0: float,
	off1: float
) -> void:
	var p := [
		at.call(s0, y0, off0),
		at.call(s1, y0, off0),
		at.call(s1, y1, off0),
		at.call(s0, y1, off0),
		at.call(s0, y0, off1),
		at.call(s1, y0, off1),
		at.call(s1, y1, off1),
		at.call(s0, y1, off1),
	]
	var c: Vector3 = (p[0] + p[6]) * 0.5
	for face: Array in [[4, 5, 6, 7], [0, 1, 5, 4], [3, 2, 6, 7], [0, 3, 7, 4], [1, 2, 6, 5]]:
		var q0: Vector3 = p[face[0]]
		var q1: Vector3 = p[face[1]]
		var q2: Vector3 = p[face[2]]
		var q3: Vector3 = p[face[3]]
		shell.quad_out("ashlar", q0, q1, q2, q3, ASHLAR, (q0 + q1 + q2 + q3) * 0.25 - c)


## One plank shutter leaf from the hinge to its free edge, with boards,
## two ledges and iron strap hinges.
static func _leaf(
	shell: CityBuildingBuilder.Shell, h: Vector2, e: Vector2, y0: float, y1: float, out: Vector2
) -> void:
	var t := 0.05
	var d := (e - h).normalized()
	var n := Vector2(-d.y, d.x)
	if n.dot(out) < 0.0:
		n = -n
	var tone := OAK * 0.85
	tone.a = 1.0
	var boards := 3
	for k in boards:
		var p0 := h.lerp(e, float(k) / boards) + d * 0.004
		var p1 := h.lerp(e, float(k + 1) / boards) - d * 0.004
		var shade := tone * (0.9 + 0.08 * float(k % 2))
		shade.a = 1.0
		_quad_box(shell, "timber", p0, p1, n, y0, y1, 0.0, t, shade)
	for y: float in [y0 + 0.2, y1 - 0.32]:
		_quad_box(
			shell, "timber", h + d * 0.04, e - d * 0.04, n, y, y + 0.12, t, t + 0.03, OAK_DARK
		)
		_quad_box(
			shell,
			"dark",
			h - d * 0.03,
			h.lerp(e, 0.7),
			n,
			y + 0.03,
			y + 0.09,
			t + 0.03,
			t + 0.045,
			IRON
		)


# --- inside ------------------------------------------------------------------

# --- roof --------------------------------------------------------------------


## Two tile pitches between the parapet gables, an eave overhang, a corrugated
## eave edge of tile ends, half-round ridge tiles, and the boarded underside.
static func _roof(roof: CityBuildingBuilder.Shell, rise: float) -> void:
	var hz := DEPTH * 0.5
	var x0 := -LENGTH * 0.5 + WALL * 0.5
	var x1 := LENGTH * 0.5 - WALL * 0.5
	var slope := rise / hz
	var ridge := EAVE + rise
	var thick := 0.14
	for side: float in [-1.0, 1.0]:
		var ze := side * (hz + EAVE_OVERHANG)
		var ye := EAVE - EAVE_OVERHANG * slope
		var run := sqrt((hz + EAVE_OVERHANG) * (hz + EAVE_OVERHANG) + (ridge - ye) * (ridge - ye))
		var face := Vector3(0.0, 1.0, side * slope).normalized()
		var u0 := x0
		var u1 := x1
		# Tile surface: UV u along the ridge, v down the slope from the ridge (m).
		var a := Vector3(x0, ridge + thick, 0.0)
		var b := Vector3(x1, ridge + thick, 0.0)
		var c := Vector3(x1, ye + thick, ze)
		var d := Vector3(x0, ye + thick, ze)
		_tri_uv(roof, "roof:tile", a, b, c, Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, run), face)
		_tri_uv(
			roof, "roof:tile", a, c, d, Vector2(u0, 0), Vector2(u1, run), Vector2(u0, run), face
		)
		# Underside boards.
		roof.quad_out(
			"timber",
			Vector3(x0, ridge, 0.0),
			Vector3(x1, ridge, 0.0),
			Vector3(x1, ye, ze),
			Vector3(x0, ye, ze),
			OAK_DARK * 0.8,
			-face
		)
		# Corrugated eave edge: monk caps and nun channels end-on.
		var pitch := 0.34
		var u := x0
		while u < x1 - 0.01:
			var w := minf(pitch, x1 - u)
			var nun := minf(w, pitch * 0.6)
			var p := [
				Vector3(u, ye + thick, ze),
				Vector3(u + nun, ye + thick, ze),
				Vector3(u + nun, ye - 0.02, ze),
				Vector3(u, ye - 0.02, ze)
			]
			roof.quad_out(
				"roof:tile", p[0], p[1], p[2], p[3], Color(0.9, 0.9, 0.9), Vector3(0, -0.2, side)
			)
			if w > nun:
				var m0 := u + nun
				var m1 := u + w
				var segs := 4
				for k in segs:
					var t0 := PI * float(k) / segs
					var t1 := PI * float(k + 1) / segs
					var cx := (m0 + m1) * 0.5
					var r := (m1 - m0) * 0.5
					var q0 := Vector3(cx - cos(t0) * r, ye + thick + sin(t0) * 0.09, ze)
					var q1 := Vector3(cx - cos(t1) * r, ye + thick + sin(t1) * 0.09, ze)
					roof.quad_out(
						"roof:tile",
						q0,
						q1,
						Vector3(q1.x, ye - 0.02, ze),
						Vector3(q0.x, ye - 0.02, ze),
						Color(1, 1, 1),
						Vector3(0, 0, side)
					)
					roof.quad_out(
						"roof:tile",
						q0,
						q1,
						q1 + Vector3(0, -0.04 * 0, -side * 0.35),
						q0 + Vector3(0, 0, -side * 0.35),
						Color(1.05, 1.05, 1.05),
						Vector3(0, 1, side * 0.3)
					)
			u += pitch
	# Half-round ridge tiles laid in 0.4 m lengths with mortar joints.
	var rr := 0.17
	var x := x0
	while x < x1 - 0.01:
		var x2 := minf(x + 0.4, x1)
		var segs := 6
		for k in segs:
			var t0 := PI * float(k) / segs
			var t1 := PI * float(k + 1) / segs
			var p0 := Vector3(x, ridge + thick + sin(t0) * rr * 0.8, cos(t0) * rr)
			var p1 := Vector3(x, ridge + thick + sin(t1) * rr * 0.8, cos(t1) * rr)
			var swell := Vector3(0, 0.015, 0)
			_tri_uv(
				roof,
				"roof:tile",
				p0,
				Vector3(x2, p0.y, p0.z) + swell,
				Vector3(x2, p1.y, p1.z) + swell,
				Vector2(x, t0 * rr),
				Vector2(x2, t0 * rr),
				Vector2(x2, t1 * rr),
				Vector3(0, sin((t0 + t1) * 0.5), cos((t0 + t1) * 0.5))
			)
			_tri_uv(
				roof,
				"roof:tile",
				p0,
				Vector3(x2, p1.y, p1.z) + swell,
				p1,
				Vector2(x, t0 * rr),
				Vector2(x2, t1 * rr),
				Vector2(x, t1 * rr),
				Vector3(0, sin((t0 + t1) * 0.5), cos((t0 + t1) * 0.5))
			)
		x = x2


static func _tri_uv(
	shell: CityBuildingBuilder.Shell,
	key: String,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	ua: Vector2,
	ub: Vector2,
	uc: Vector2,
	out: Vector3
) -> void:
	shell.tri_out(key, a, b, c, Color(1, 1, 1), out, ua, ub, uc)


# --- cutaway, banners, materials ---------------------------------------------


## Section caps on top of every wall stub at the cut.
static func _cut_caps(shell: CityBuildingBuilder.Shell) -> void:
	var hx := LENGTH * 0.5
	var hz := DEPTH * 0.5
	var c := Color(0.62, 0.58, 0.52)
	var w := PORTAL_W * 0.5
	var spans := [
		[Vector2(-hx, -hz), Vector2(-w, -hz)],
		[Vector2(w, -hz), Vector2(hx, -hz)],
		[Vector2(hx, -hz), Vector2(hx, hz)],
		[Vector2(hx, hz), Vector2(-hx, hz)],
		[Vector2(-hx, hz), Vector2(-hx, -hz)],
	]
	for sp: Array in spans:
		var a: Vector2 = sp[0]
		var b: Vector2 = sp[1]
		var dir := (b - a).normalized()
		var n := Vector2(-dir.y, dir.x)
		if n.dot(-(a + b)) < 0.0:
			n = -n
		var a2 := a + n * WALL
		var b2 := b + n * WALL
		shell.quad_out(
			"ashlar",
			Vector3(a.x, CUT, a.y),
			Vector3(b.x, CUT, b.y),
			Vector3(b2.x, CUT, b2.y),
			Vector3(a2.x, CUT, a2.y),
			c,
			Vector3.UP
		)
	# The diele | dornse partition, open at its door.
	var iz := DEPTH * 0.5 - WALL
	for span: Vector2 in [Vector2(-iz, PART_DOOR.x), Vector2(PART_DOOR.y, iz)]:
		shell.quad_out(
			"ashlar",
			Vector3(PART_X, CUT, span.x),
			Vector3(PART_X + PART_T, CUT, span.x),
			Vector3(PART_X + PART_T, CUT, span.y),
			Vector3(PART_X, CUT, span.y),
			c,
			Vector3.UP
		)


## The red-and-white banners on iron rods over the market front, either side
## of the portal (the Danish royal banner; see MapViewTownHallModel).
static func _banners(parent: Node3D) -> void:
	var width := 1.05
	var top := EAVE - 0.4
	var face := -DEPTH * 0.5
	for side: float in [-1.0, 1.0]:
		var x := side * 1.95
		var rod := MeshInstance3D.new()
		rod.name = "BannerRod%d" % int(side)
		var rod_mesh := CylinderMesh.new()
		rod_mesh.top_radius = 0.025
		rod_mesh.bottom_radius = 0.025
		rod_mesh.height = width + 0.3
		rod_mesh.radial_segments = 6
		rod.mesh = rod_mesh
		rod.rotation.z = PI * 0.5
		rod.position = Vector3(x, top, face - 0.34)
		rod.material_override = MapViewMaterials.door_iron()
		parent.add_child(rod)
		for end: float in [-1.0, 1.0]:
			var arm := MeshInstance3D.new()
			var arm_mesh := BoxMesh.new()
			arm_mesh.size = Vector3(0.04, 0.05, 0.36)
			arm.mesh = arm_mesh
			arm.position = Vector3(x + end * (width * 0.5 + 0.08), top, face - 0.17)
			arm.material_override = MapViewMaterials.door_iron()
			parent.add_child(arm)
		var banner := MeshInstance3D.new()
		banner.name = "Banner%d" % int(side)
		banner.mesh = BannerMesh._banner_mesh(width, 1.6, false, int(side > 0.0))
		banner.position = Vector3(x - width * 0.5, top - 0.03, face - 0.34)
		banner.material_override = MapViewMaterials.hanging_banner_cloth(null, true)
		parent.add_child(banner)


static func _mesh(node_name: String, shell: CityBuildingBuilder.Shell) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = shell.to_mesh(_material_for)
	return inst


static func _material_for(key: String) -> Material:
	if _materials.has(key):
		return _materials[key]
	var mat: Material
	match key:
		"limewash":
			var sm := ShaderMaterial.new()
			sm.shader = LIMEWASH
			mat = sm
		"painted":
			# Hall walls: false ashlar, dado and frieze; the vine frieze in the dornse.
			var pm := ShaderMaterial.new()
			pm.shader = LIMEWASH
			pm.set_shader_parameter("paint", 1.0)
			mat = pm
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
		"flags":
			var fs := ShaderMaterial.new()
			fs.shader = FLAGSTONE
			mat = fs
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

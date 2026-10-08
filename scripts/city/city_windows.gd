class_name CityWindows
extends RefCounted

## Seeded house windows, matching interior relief and glazing. Late carved
## platbands remain callable for legacy tools, never automatically selected.
## See docs/SYSTEMS/COTTAGE_WINDOWS.md.

## Conservative earth-pigment palette. These are visual reconstructions, not
## claims that blue/green paint was cheap in Reval in 1343.
const TRIM_PAINTS := [
	Color(0.48, 0.37, 0.25),
	Color(0.69, 0.65, 0.53),
	Color(0.58, 0.43, 0.23),
	Color(0.43, 0.24, 0.17),
	Color(0.34, 0.37, 0.28),
	Color(0.29, 0.34, 0.36),
]
const SHUTTER_PAINTS := TRIM_PAINTS
const RURAL_STYLES: Array[StringName] = [
	&"plain", &"shutters_open", &"shutters_open", &"shutters_closed", &"slit", &"slit", &"plain"
]
const TOWN_STYLES: Array[StringName] = [
	&"plain", &"shutters_open", &"shutters_closed", &"surround", &"leaded", &"panelled"
]
const GLAZING: Array[StringName] = [&"open", &"horn", &"forest", &"clear"]


static func look(look_rng: RandomNumberGenerator, family: StringName) -> Dictionary:
	var rural := family == &"log" or family == &"plank"
	# Wealth is a visual tier only, never a new household/save-state value.
	var tier := look_rng.randi_range(0, 1) if rural else look_rng.randi_range(0, 2)
	var palette := look_rng.randi() % (4 if tier < 2 else TRIM_PAINTS.size())
	var styles := RURAL_STYLES if rural else TOWN_STYLES
	var style: StringName = styles[look_rng.randi() % styles.size()]
	if not rural and tier == 0 and style in [&"leaded", &"panelled"]:
		style = &"shutters_open"
	if tier == 2:
		style = &"leaded" if look_rng.randf() < 0.5 else &"panelled"
	return {
		"rural": rural,
		"tier": tier,
		"trim": TRIM_PAINTS[palette],
		"shutter": SHUTTER_PAINTS[look_rng.randi() % (4 if tier < 2 else 6)],
		"style": style,
		"panes": 1 + tier,
		"glazing":
		(
			(&"open" if tier == 0 else &"horn")
			if rural
			else (&"horn" if tier == 0 else &"forest" if tier == 1 else &"clear")
		),
	}


## Placement is calculated once, then shared by wall cutting and both faces.
## Keep the legacy RNG draw schedule here: roofs/chimneys must not move just
## because a window's decorative mesh or material changes.
static func placements(
	a: Vector2,
	c: Vector2,
	floor_y: float,
	eave: float,
	gap: Vector2,
	rng: RandomNumberGenerator,
	house_look: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var length := a.distance_to(c)
	if length < 2.6:
		return result
	var dir := (c - a) / length
	var nrm := Vector2(-dir.y, dir.x)
	var storeys := maxi(1, int((eave - floor_y) / 3.1))
	var count := int(length / CityBuildingBuilder.WINDOW_SPACING)
	var rural: bool = house_look["rural"]
	for s in storeys:
		var y0 := floor_y + 1.05 + float(s) * 3.0
		if y0 + CityBuildingBuilder.WINDOW_H > eave - 0.35:
			break
		for k in count:
			var t := (float(k) + 0.5) / float(count)
			if gap.x >= 0.0 and s == 0 and t > gap.x - 0.12 and t < gap.y + 0.12:
				continue
			if rng.randf() < 0.18:
				continue
			var style: StringName = house_look["style"]
			if rural and rng.randf() < 0.25:
				style = RURAL_STYLES[rng.randi() % RURAL_STYLES.size()]
			var jitter := rng.randf()
			var w := CityBuildingBuilder.WINDOW_W * (0.8 if rural else 1.0)
			var h := CityBuildingBuilder.WINDOW_H * (0.85 + jitter * 0.25)
			var wy := y0
			if style == &"slit":
				w = 0.62
				h = 0.3
				wy += 0.35
			# Include the lintel and sill, not just the old nominal pane height.
			if wy + h + 0.18 > eave - 0.05:
				continue
			(
				result
				. append(
					{
						"m": a + dir * (t * length),
						"dir": dir,
						"nrm": nrm,
						"y": wy,
						"w": w,
						"h": h,
						"style": style,
						"look": house_look,
						"jitter": jitter,
						"base_y": y0,
					}
				)
			)
	return result


static func add_wall(
	shell: CityBuildingBuilder.Shell,
	a: Vector2,
	c: Vector2,
	floor_y: float,
	eave: float,
	gap: Vector2,
	rng: RandomNumberGenerator,
	house_look: Dictionary
) -> void:
	for window in placements(a, c, floor_y, eave, gap, rng, house_look):
		add_placed(shell, window)


static func add_placed(shell: CityBuildingBuilder.Shell, window: Dictionary) -> void:
	add_window(
		shell,
		window["m"],
		window["dir"],
		window["nrm"],
		window["base_y"],
		window["w"],
		window["style"],
		window["look"],
		window["jitter"]
	)


## One box in a window's local frame: u along the wall, y up, z out of the wall.
static func _wbox(
	shell: CityBuildingBuilder.Shell,
	key: String,
	m: Vector2,
	dir: Vector2,
	nrm: Vector2,
	u0: float,
	u1: float,
	y0: float,
	y1: float,
	z0: float,
	z1: float,
	color: Color
) -> void:
	if u1 <= u0 or y1 <= y0 or z1 <= z0:
		return
	var p := func(u: float, y: float, z: float) -> Vector3:
		var q: Vector2 = m + dir * u + nrm * z
		return Vector3(q.x, y, q.y)
	var out2 := Vector3(nrm.x, 0, nrm.y)
	var along := Vector3(dir.x, 0, dir.y)
	# Six faces: closed shutters and bars must also occlude the interior view.
	shell.quad_out(
		key,
		p.call(u1, y0, z0),
		p.call(u0, y0, z0),
		p.call(u0, y1, z0),
		p.call(u1, y1, z0),
		color,
		-out2
	)
	shell.quad_out(
		key,
		p.call(u0, y0, z1),
		p.call(u1, y0, z1),
		p.call(u1, y1, z1),
		p.call(u0, y1, z1),
		color,
		out2
	)
	shell.quad_out(
		key,
		p.call(u0, y1, z0),
		p.call(u1, y1, z0),
		p.call(u1, y1, z1),
		p.call(u0, y1, z1),
		color,
		Vector3.UP
	)
	shell.quad_out(
		key,
		p.call(u0, y0, z0),
		p.call(u1, y0, z0),
		p.call(u1, y0, z1),
		p.call(u0, y0, z1),
		color,
		Vector3.DOWN
	)
	shell.quad_out(
		key,
		p.call(u0, y0, z0),
		p.call(u0, y1, z0),
		p.call(u0, y1, z1),
		p.call(u0, y0, z1),
		color,
		-along
	)
	shell.quad_out(
		key,
		p.call(u1, y0, z0),
		p.call(u1, y1, z0),
		p.call(u1, y1, z1),
		p.call(u1, y0, z1),
		color,
		along
	)


## A window with real depth: two-sided glazing, bars, frame, and the
## surround the style calls for. `jitter` (0..1) varies sizes a little.
static func add_window(
	shell: CityBuildingBuilder.Shell,
	m: Vector2,
	dir: Vector2,
	nrm: Vector2,
	y0: float,
	w: float,
	style: StringName,
	look: Dictionary,
	jitter: float
) -> void:
	var trim: Color = look["trim"]
	var shut: Color = look["shutter"]
	var h := CityBuildingBuilder.WINDOW_H * (0.85 + jitter * 0.25)
	if style == &"slit":
		# Volokovoe: a low, wide smoke-house slit closed by a sliding board.
		w = 0.62
		h = 0.3
		y0 += 0.35
	var hw := w * 0.5
	var fr := 0.06
	var glazing := StringName(look.get("glazing", &"forest"))
	if style == &"slit":
		glazing = &"open"
	if glazing != &"open":
		var p0 := m - dir * hw - nrm * 0.025
		var p1 := m + dir * hw - nrm * 0.025
		shell.quad_out(
			"glass:%s" % glazing,
			Vector3(p0.x, y0, p0.y),
			Vector3(p1.x, y0, p1.y),
			Vector3(p1.x, y0 + h, p1.y),
			Vector3(p0.x, y0 + h, p0.y),
			Color.WHITE,
			Vector3(nrm.x, 0, nrm.y)
		)
	# Frame: four bars standing 7 cm off the wall.
	var fc := trim if style != &"surround" else Color(0.74, 0.70, 0.62)
	var fkey := "paint" if style != &"surround" else "stone"
	_wbox(shell, fkey, m, dir, nrm, -hw - fr, -hw, y0 - fr, y0 + h + fr, 0.0, 0.08, fc)
	_wbox(shell, fkey, m, dir, nrm, hw, hw + fr, y0 - fr, y0 + h + fr, 0.0, 0.08, fc)
	_wbox(shell, fkey, m, dir, nrm, -hw, hw, y0 + h, y0 + h + fr, 0.0, 0.08, fc)
	_wbox(shell, fkey, m, dir, nrm, -hw, hw, y0 - fr, y0, 0.0, 0.08, fc)
	if style == &"slit":
		# Sliding board left half-open over the slit.
		_wbox(
			shell,
			"timber",
			m,
			dir,
			nrm,
			-hw * 0.1,
			hw + fr,
			y0,
			y0 + h,
			0.05,
			0.09,
			Color(0.9, 0.85, 0.8)
		)
		return
	# Sash bars: a cross for one pane layout, a grid for two, a leaded lattice for three.
	var panes: int = look["panes"] if glazing != &"open" else 0
	# Glazing bars are stained timber or dark lead, not modern white sashes.
	var sash := trim.darkened(0.12) if style != &"leaded" else Color(0.22, 0.21, 0.18)
	var bar := 0.022
	var mid := y0 + h * 0.5
	if style == &"leaded" and panes > 0:
		_lead_lattice(shell, m, dir, nrm, y0, w, h)
	elif panes > 0:
		_wbox(shell, "paint", m, dir, nrm, -hw, hw, mid - bar, mid + bar, 0.0, 0.065, sash)
		_wbox(shell, "paint", m, dir, nrm, -bar, bar, y0, y0 + h, 0.0, 0.065, sash)
		if panes >= 2:
			for q: float in [-0.5, 0.5]:
				_wbox(
					shell,
					"paint",
					m,
					dir,
					nrm,
					q * hw - bar * 0.6,
					q * hw + bar * 0.6,
					y0,
					y0 + h,
					0.0,
					0.055,
					sash
				)
		if panes >= 3:
			for q: float in [-0.5, 0.5]:
				_wbox(
					shell,
					"paint",
					m,
					dir,
					nrm,
					-hw,
					hw,
					mid + q * h * 0.5 - bar * 0.6,
					mid + q * h * 0.5 + bar * 0.6,
					0.0,
					0.055,
					sash
				)
	# Sill board projecting beneath.
	_wbox(
		shell,
		"paint" if style != &"surround" else "stone",
		m,
		dir,
		nrm,
		-hw - fr * 1.6,
		hw + fr * 1.6,
		y0 - fr - 0.04,
		y0 - fr,
		0.0,
		0.14,
		fc
	)
	match style:
		&"platband":
			_platband(shell, m, dir, nrm, y0, w, h, trim)
		&"gable_cap":
			# Legacy explicit decorative cap; not in the period-conscious automatic pool.
			_pediment(shell, m, dir, nrm, y0 + h + fr, hw + fr * 2.0, 0.2, trim)
		&"shutters_open", &"panelled":
			_shutters(shell, m, dir, nrm, y0, hw + fr, h, shut, false)
			if style == &"panelled":
				_panel_details(shell, m, dir, nrm, y0, hw + fr, h, shut)
		&"shutters_closed":
			_shutters(shell, m, dir, nrm, y0, hw + fr, h, shut, true)
		&"surround":
			# Dressed lintel and projecting stone jambs.
			var st := Color(0.78, 0.74, 0.66)
			_wbox(
				shell,
				"stone",
				m,
				dir,
				nrm,
				-hw - 0.12,
				hw + 0.12,
				y0 + h + fr,
				y0 + h + fr + 0.12,
				0.0,
				0.1,
				st
			)
			_wbox(
				shell,
				"stone",
				m,
				dir,
				nrm,
				-hw - 0.12,
				-hw - fr,
				y0 - fr,
				y0 + h + fr,
				0.0,
				0.09,
				st
			)
			_wbox(
				shell, "stone", m, dir, nrm, hw + fr, hw + 0.12, y0 - fr, y0 + h + fr, 0.0, 0.09, st
			)


## Carved platband (nalichnik): broad boards around the frame with a saw-tooth
## lower fringe, a pierced-looking cornice and a pediment above.
static func _platband(
	shell: CityBuildingBuilder.Shell,
	m: Vector2,
	dir: Vector2,
	nrm: Vector2,
	y0: float,
	w: float,
	h: float,
	trim: Color
) -> void:
	var hw := w * 0.5 + 0.06
	var bw := 0.17
	var top := y0 + h + 0.06
	_wbox(shell, "paint", m, dir, nrm, -hw - bw, -hw, y0 - 0.06, top, 0.0, 0.05, trim)
	_wbox(shell, "paint", m, dir, nrm, hw, hw + bw, y0 - 0.06, top, 0.0, 0.05, trim)
	_wbox(shell, "paint", m, dir, nrm, -hw - bw, hw + bw, top, top + 0.12, 0.0, 0.06, trim)
	# Saw-tooth apron under the sill, and notches on the lintel board: the
	# carved fringe that makes the pattern read from a distance.
	var teeth := 6
	var tw := (w + 2.0 * bw + 0.12) / float(teeth)
	for i in teeth:
		var u := -hw - bw + float(i) * tw
		_wbox(
			shell,
			"paint",
			m,
			dir,
			nrm,
			u + tw * 0.2,
			u + tw * 0.8,
			y0 - 0.32,
			y0 - 0.1,
			0.0,
			0.04,
			trim
		)
		if i % 2 == 0:
			_wbox(
				shell,
				"paint",
				m,
				dir,
				nrm,
				u + tw * 0.25,
				u + tw * 0.75,
				top + 0.12,
				top + 0.2,
				0.0,
				0.05,
				trim
			)
	_pediment(shell, m, dir, nrm, top + 0.12, hw + bw, 0.26, trim)


## Triangular boarded cap over a window: two sloping faces from base width
## to a central apex, thickened with a front board.
static func _pediment(
	shell: CityBuildingBuilder.Shell,
	m: Vector2,
	dir: Vector2,
	nrm: Vector2,
	y: float,
	half: float,
	rise: float,
	color: Color
) -> void:
	var p := func(u: float, yy: float, z: float) -> Vector3:
		var q: Vector2 = m + dir * u + nrm * z
		return Vector3(q.x, yy, q.y)
	var out2 := Vector3(nrm.x, 0, nrm.y)
	shell.tri_out(
		"paint",
		p.call(-half, y, 0.07),
		p.call(half, y, 0.07),
		p.call(0.0, y + rise, 0.07),
		color,
		out2
	)
	# Thin return along the underside so the cap does not look like a decal.
	shell.quad_out(
		"paint",
		p.call(-half, y, 0.0),
		p.call(half, y, 0.0),
		p.call(half, y, 0.07),
		p.call(-half, y, 0.07),
		color,
		Vector3.DOWN
	)


## Individually weathered shutter boards with horizontal battens and iron
## straps. Closed boards are solid on both sides; open leaves cover the wall.
static func _shutters(
	shell: CityBuildingBuilder.Shell,
	m: Vector2,
	dir: Vector2,
	nrm: Vector2,
	y0: float,
	hw: float,
	h: float,
	color: Color,
	closed: bool
) -> void:
	var sw := hw * 0.98
	for side: float in [-1.0, 1.0]:
		var left := -sw if side < 0.0 else 0.0
		if not closed:
			left = -hw - 0.03 - sw if side < 0.0 else hw + 0.03
		var front := 0.1 if closed else 0.065
		for i in 3:
			var u := left + sw * float(i) / 3.0
			# No through-cracks in a closed leaf. Slight depth and tint offsets
			# make planks legible without letting daylight leak through it.
			_wbox(
				shell,
				"paint",
				m,
				dir,
				nrm,
				u,
				u + sw / 3.0,
				y0 - 0.04,
				y0 + h + 0.04,
				front - 0.04,
				front + float(i % 2) * 0.006,
				color.darkened(float(i) * 0.055)
			)
		for yy: float in [y0 + h * 0.2, y0 + h * 0.8]:
			_wbox(
				shell,
				"paint",
				m,
				dir,
				nrm,
				left,
				left + sw,
				yy,
				yy + 0.05,
				front,
				front + 0.025,
				color.darkened(0.18)
			)
			_wbox(
				shell,
				"iron",
				m,
				dir,
				nrm,
				left + 0.025,
				left + sw - 0.025,
				yy + 0.012,
				yy + 0.032,
				front + 0.026,
				front + 0.035,
				Color.WHITE
			)


## Interior frame and deep sill use the same centre, width and height as the
## exterior. The reveal is four solid boards/stone returns, never a dark decal.
static func add_interior(
	shell: CityBuildingBuilder.Shell, window: Dictionary, thick: float
) -> void:
	var m: Vector2 = window["m"]
	var dir: Vector2 = window["dir"]
	var nrm: Vector2 = window["nrm"]
	var hw: float = window["w"] * 0.5
	var y: float = window["y"]
	var h: float = window["h"]
	var trim: Color = window["look"]["trim"]
	var stone: bool = window["style"] == &"surround"
	var key := "stone" if stone else "paint"
	var color := Color(0.65, 0.61, 0.53) if stone else trim.darkened(0.15)
	_wbox(shell, key, m, dir, nrm, -hw - 0.05, -hw, y, y + h, -thick - 0.05, 0.0, color)
	_wbox(shell, key, m, dir, nrm, hw, hw + 0.05, y, y + h, -thick - 0.05, 0.0, color)
	_wbox(
		shell,
		key,
		m,
		dir,
		nrm,
		-hw - 0.05,
		hw + 0.05,
		y + h,
		y + h + 0.05,
		-thick - 0.05,
		0.0,
		color
	)
	# Broad enough to read from inside even in the thick limestone shell.
	_wbox(shell, key, m, dir, nrm, -hw - 0.1, hw + 0.1, y - 0.08, y, -thick - 0.18, 0.0, color)


## Restrained raised panel borders and iron strap hinges. Not the late
## pierced-heart shutters previously implied by a painted centre rectangle.
static func _panel_details(
	shell: CityBuildingBuilder.Shell,
	m: Vector2,
	dir: Vector2,
	nrm: Vector2,
	y: float,
	hw: float,
	h: float,
	color: Color
) -> void:
	for side: float in [-1.0, 1.0]:
		var u0 := side * (hw + 0.03)
		var u1 := side * (hw + 0.33)
		var left := minf(u0, u1)
		var right := maxf(u0, u1)
		for u: float in [left + 0.02, right - 0.05]:
			_wbox(
				shell,
				"paint",
				m,
				dir,
				nrm,
				u,
				u + 0.03,
				y + 0.04,
				y + h - 0.04,
				0.04,
				0.075,
				color.lightened(0.1)
			)
		for yy: float in [y + 0.04, y + h * 0.5, y + h - 0.07]:
			_wbox(
				shell,
				"paint",
				m,
				dir,
				nrm,
				left + 0.02,
				right - 0.02,
				yy,
				yy + 0.03,
				0.04,
				0.075,
				color.lightened(0.1)
			)


## Small diamond panes are a cost cue, not a modern wide sheet of glass.
## Clip each diagonal to the aperture so no lead strip crosses the frame.
static func _lead_lattice(
	shell: CityBuildingBuilder.Shell,
	m: Vector2,
	dir: Vector2,
	nrm: Vector2,
	y: float,
	w: float,
	h: float
) -> void:
	var hw := w * 0.5
	var out := Vector3(nrm.x, 0, nrm.y)
	for slope: float in [-1.5, 1.5]:
		for i in range(-4, 8):
			var intercept := float(i) * 0.24
			var low := maxf(-hw, minf(-intercept / slope, (h - intercept) / slope))
			var high := minf(hw, maxf(-intercept / slope, (h - intercept) / slope))
			if high - low < 0.01:
				continue
			var a := Vector2(low, slope * low + intercept)
			var b := Vector2(high, slope * high + intercept)
			var cross := Vector2(-(b - a).y, (b - a).x).normalized() * 0.004
			var verts: Array[Vector3] = []
			for point: Vector2 in [a - cross, b - cross, b + cross, a + cross]:
				point.x = clampf(point.x, -hw, hw)
				point.y = clampf(point.y, 0.0, h)
				var q := m + dir * point.x + nrm * 0.035
				verts.append(Vector3(q.x, y + point.y, q.y))
			shell.quad_out("iron", verts[0], verts[1], verts[2], verts[3], Color.WHITE, out)
			shell.quad_out("iron", verts[3], verts[2], verts[1], verts[0], Color.WHITE, -out)

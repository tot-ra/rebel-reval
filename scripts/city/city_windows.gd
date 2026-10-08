class_name CityWindows
extends RefCounted

## Village and house window relief for CityBuildingBuilder walls (see
## docs/SYSTEMS/COTTAGE_WINDOWS.md): painted frames, sash bars, carved
## platbands, shutters, the sliding smoke-house slit and stone surrounds.

## Painted-trim palettes seen on village houses: whitewash and ochre are the
## common ones, blue and green the cheap pigments, red the rich man's colour.
const TRIM_PAINTS := [
	Color(0.90, 0.88, 0.80),
	Color(0.78, 0.60, 0.26),
	Color(0.28, 0.42, 0.58),
	Color(0.30, 0.46, 0.34),
	Color(0.62, 0.22, 0.16),
	Color(0.42, 0.31, 0.21),
]
const SHUTTER_PAINTS := [
	Color(0.28, 0.42, 0.58),
	Color(0.30, 0.46, 0.34),
	Color(0.62, 0.22, 0.16),
	Color(0.45, 0.34, 0.24),
	Color(0.78, 0.60, 0.26),
]
## Rural window styles (Russian "nalichniki" carving, Baltic plain shutters,
## the small sliding "volokovoe" smoke-house slit). Weights in pick order.
const RURAL_STYLES: Array[StringName] = [
	&"plain", &"platband", &"platband", &"shutters_open", &"shutters_closed", &"slit", &"gable_cap"
]


static func look(look_rng: RandomNumberGenerator, family: StringName) -> Dictionary:
	var rural := family == &"log" or family == &"plank"
	var look := {
		"rural": rural,
		"trim": TRIM_PAINTS[look_rng.randi() % TRIM_PAINTS.size()],
		"shutter": SHUTTER_PAINTS[look_rng.randi() % SHUTTER_PAINTS.size()],
		"style": RURAL_STYLES[look_rng.randi() % RURAL_STYLES.size()] if rural else &"surround",
		"panes": 1 + look_rng.randi() % 3,
	}
	return look


static func add_wall(
	shell: CityBuildingBuilder.Shell,
	a: Vector2,
	c: Vector2,
	floor_y: float,
	eave: float,
	gap: Vector2,
	rng: RandomNumberGenerator,
	look: Dictionary
) -> void:
	var length := a.distance_to(c)
	if length < 2.6:
		return
	var dir := (c - a) / length
	var nrm := Vector2(-dir.y, dir.x)
	var storeys := maxi(1, int((eave - floor_y) / 3.1))
	var count := int(length / CityBuildingBuilder.WINDOW_SPACING)
	if count < 1:
		return
	var rural: bool = look["rural"]
	var w := CityBuildingBuilder.WINDOW_W * (0.8 if rural else 1.0)
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
			var m := a + dir * (t * length)
			# One window in four breaks from the house's style, as hand-built
			# houses do: a farmer fits what he has, not a pattern book.
			var style: StringName = look["style"]
			if rural and rng.randf() < 0.25:
				style = RURAL_STYLES[rng.randi() % RURAL_STYLES.size()]
			add_window(shell, m, dir, nrm, y0, w, style, look, rng.randf())


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
	# Front, top, bottom, left, right. The back faces the wall and is never seen.
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


## A window with real depth: dark glazed opening, sash bars, frame, and the
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
	var dark := Color(1, 1, 1)
	# Glass / opening, set just proud of the wall plane.
	_wbox(shell, "opening", m, dir, nrm, -hw, hw, y0, y0 + h, 0.0, 0.03, dark)
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
	var panes: int = look["panes"]
	# Sash bars stay pale whatever the trim: glazing bars read against the dark
	# glass, and a platband in the same colour would swallow them.
	var sash := Color(0.88, 0.85, 0.77) if style != &"surround" else Color(0.2, 0.2, 0.2)
	var bar := 0.022
	var mid := y0 + h * 0.5
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
			# Plain frame under a small boarded pediment (a kokoshnik in miniature).
			_pediment(shell, m, dir, nrm, y0 + h + fr, hw + fr * 2.0, 0.2, trim)
		&"shutters_open":
			_shutters(shell, m, dir, nrm, y0, hw + fr, h, shut, false)
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


## Plank shutters: parked open flat against the wall on both sides, or
## closed across the opening with a Z-batten.
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
	if closed:
		for side: float in [-1.0, 1.0]:
			var u0: float = side * 0.01
			var u1: float = side * sw
			_wbox(
				shell,
				"paint",
				m,
				dir,
				nrm,
				minf(u0, u1),
				maxf(u0, u1),
				y0 - 0.04,
				y0 + h + 0.04,
				0.07,
				0.1,
				color
			)
		var dk := color.darkened(0.25)
		_wbox(
			shell, "paint", m, dir, nrm, -sw, sw, y0 + h * 0.2, y0 + h * 0.2 + 0.05, 0.1, 0.12, dk
		)
		_wbox(
			shell, "paint", m, dir, nrm, -sw, sw, y0 + h * 0.8, y0 + h * 0.8 + 0.05, 0.1, 0.12, dk
		)
		return
	var lw := 0.3
	for side: float in [-1.0, 1.0]:
		var u0: float = side * (hw + 0.03)
		var u1: float = side * (hw + 0.03 + lw)
		_wbox(
			shell,
			"paint",
			m,
			dir,
			nrm,
			minf(u0, u1),
			maxf(u0, u1),
			y0 - 0.04,
			y0 + h + 0.04,
			0.0,
			0.04,
			color
		)
		# A cut-out heart or diamond is hinted by a darker centre board.
		var dk := color.darkened(0.3)
		var c0: float = minf(u0, u1) + lw * 0.3
		_wbox(
			shell,
			"paint",
			m,
			dir,
			nrm,
			c0,
			c0 + lw * 0.4,
			y0 + h * 0.4,
			y0 + h * 0.62,
			0.04,
			0.05,
			dk
		)

class_name CityWindows
extends RefCounted

## Seeded house windows, matching interior relief and glazing. The census
## wealth tier (CityHouseWealth) picks the repertoire: bare openings for the
## poor, hoods and notched boards for masters, chip-carved boards for the rich.
## Late carved platbands remain callable for legacy tools, never automatically
## selected. See docs/SYSTEMS/COTTAGE_WINDOWS.md.

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
## Window repertoire by wealth tier (poor, middling, rich). Repeats weight the
## draw. Every window of one house shares one style and one size; variety
## comes from house to house, never within a facade.
const TIMBER_POOLS := [
	[&"plain", &"plain", &"shutters_closed", &"shutters_open", &"slit"],
	[&"shutters_open", &"shutters_closed", &"hood", &"notched", &"notched", &"plain"],
	[&"carved", &"carved", &"carved_shutters", &"notched", &"hood"],
]
const STONE_POOLS := [
	[&"plain", &"shutters_open", &"shutters_closed"],
	[&"shutters_open", &"surround", &"hood", &"panelled"],
	[&"leaded", &"panelled", &"surround", &"carved_shutters"],
]
## Trim palette entries reachable per tier: the poor keep bare or red-washed
## wood; only the rich reach the costlier green and blue-grey.
const TIER_PALETTE := [[0, 0, 3], [0, 1, 2, 3], [0, 1, 2, 3, 4, 5]]
## Night light leaking from lived-in houses (docs/SYSTEMS/NIGHT_LIGHTING.md).
const WINDOW_GLOW := preload("res://scripts/city/city_window_glow.gdshader")

static var _glow_material: ShaderMaterial


## `wealth` (0..2, CityHouseWealth) selects the tier's pools; -1 keeps the
## older purely random tier for tools without a plan.
static func look(
	look_rng: RandomNumberGenerator, family: StringName, wealth := -1
) -> Dictionary:
	var rural := family == &"log" or family == &"plank"
	# Wealth is a visual tier only, never a new household/save-state value.
	var tier := look_rng.randi_range(0, 1) if rural else look_rng.randi_range(0, 2)
	if wealth >= 0:
		return _wealth_look(look_rng, rural, clampi(wealth, 0, 2))
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
		# Last draw, so earlier keys keep their seeded values.
		"jitter": look_rng.randf(),
	}


static func _wealth_look(look_rng: RandomNumberGenerator, rural: bool, tier: int) -> Dictionary:
	var pool: Array = (TIMBER_POOLS if rural else STONE_POOLS)[tier]
	var palette: Array = TIER_PALETTE[tier]
	var glazings: Array = [&"open", &"horn", &"forest"] if rural else [&"horn", &"forest", &"clear"]
	var glazing: StringName = glazings[tier]
	# Some poor cottages afford a horn pane; most keep the bare opening.
	if rural and tier == 0 and look_rng.randf() < 0.3:
		glazing = &"horn"
	return {
		"rural": rural,
		"tier": tier,
		"trim": TRIM_PAINTS[palette[look_rng.randi() % palette.size()]],
		"shutter": SHUTTER_PAINTS[palette[look_rng.randi() % palette.size()]],
		"style": pool[look_rng.randi() % pool.size()],
		"pool": pool,
		"panes": 1 + tier,
		"glazing": glazing,
		"jitter": look_rng.randf(),
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
	# One size and one style per house: a facade with mixed windows reads as
	# patchwork. Older looks without a house jitter fall back to the window draw.
	var house_jitter: float = house_look.get("jitter", -1.0)
	var style := _house_style(house_look, floor_y, storeys, eave, house_jitter)
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
			if rural and rng.randf() < 0.25:
				# Former per-window style swap: draws kept so roofs and chimneys
				# downstream stay put, result discarded.
				rng.randi()
			var jitter := rng.randf() if house_jitter < 0.0 else _keep_draw(rng, house_jitter)
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


## Consumes the legacy per-window jitter draw and returns the house value.
static func _keep_draw(rng: RandomNumberGenerator, house_jitter: float) -> float:
	rng.randf()
	return house_jitter


## The house style, already downgraded for the highest storey that gets a
## window: a carved head board that would not fit under the eave there falls
## back on every storey, so the facade stays uniform.
static func _house_style(
	house_look: Dictionary, floor_y: float, storeys: int, eave: float, jitter: float
) -> StringName:
	var style: StringName = house_look["style"]
	if style == &"slit":
		return style
	var h := CityBuildingBuilder.WINDOW_H * (0.85 + maxf(jitter, 0.0) * 0.25)
	var top := -INF
	for s in storeys:
		var y0 := floor_y + 1.05 + float(s) * 3.0
		if y0 + CityBuildingBuilder.WINDOW_H > eave - 0.35:
			break
		if y0 + h + 0.18 <= eave - 0.05:
			top = y0
	if top == -INF:
		return style
	if style in [&"carved", &"carved_shutters", &"hood"] and top + h + 0.45 > eave:
		return &"notched" if top + h + 0.3 <= eave else &"plain"
	if style == &"notched" and top + h + 0.3 > eave:
		return &"plain"
	return style


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


## Additive night light card material (city_window_glow.gdshader), one for the city.
static func glow_material() -> Material:
	if _glow_material == null:
		_glow_material = ShaderMaterial.new()
		_glow_material.shader = WINDOW_GLOW
	return _glow_material


## Pushes the clock the window glow reads: hour, darkness 0..1 and flicker seconds.
static func set_night_clock(hour: float, darkness: float, seconds: float) -> void:
	RenderingServer.global_shader_parameter_set(
		&"city_night_clock", Vector4(hour, clampf(darkness, 0.0, 1.0), seconds, 0.0)
	)


## Night light card of a lived-in house (city_window_glow.gdshader): one outward
## quad inside the opening, 10 cm behind the wall face and so behind the glazing,
## hidden by closed shutters and invisible from inside the room (back-face culled).
## `glow` carries the house inputs; blue is replaced by a per-window pick from the
## window's position so rooms of one house light differently.
static func _glow_card(
	shell: CityBuildingBuilder.Shell,
	m: Vector2,
	dir: Vector2,
	nrm: Vector2,
	y0: float,
	hw: float,
	h: float,
	glow: Color
) -> void:
	var color := glow
	color.b = float(absi(hash(Vector2i(roundi(m.x * 10.0), roundi(m.y * 10.0)))) % 1000) / 1000.0
	var p0 := m - dir * hw - nrm * 0.1
	var p1 := m + dir * hw - nrm * 0.1
	# UV y runs from the sill (0) to the head (1): the shader brightens the sill.
	shell.tri_out(
		"window_glow",
		Vector3(p0.x, y0, p0.y),
		Vector3(p1.x, y0, p1.y),
		Vector3(p1.x, y0 + h, p1.y),
		color,
		Vector3(nrm.x, 0, nrm.y),
		Vector2(0, 0),
		Vector2(1, 0),
		Vector2(1, 1)
	)
	shell.tri_out(
		"window_glow",
		Vector3(p0.x, y0, p0.y),
		Vector3(p1.x, y0 + h, p1.y),
		Vector3(p0.x, y0 + h, p0.y),
		color,
		Vector3(nrm.x, 0, nrm.y),
		Vector2(0, 0),
		Vector2(1, 1),
		Vector2(0, 1)
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
	if look.has("glow"):
		_glow_card(shell, m, dir, nrm, y0, hw, h, look["glow"])
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
		&"hood":
			_hood(shell, m, dir, nrm, y0 + h + fr, hw + fr, trim)
		&"notched":
			_notched_lintel(shell, m, dir, nrm, y0 + h + fr, hw + fr, trim)
		&"carved":
			_carved_surround(shell, m, dir, nrm, y0, w, h, trim)
		&"carved_shutters":
			_shutters(shell, m, dir, nrm, y0, hw + fr, h, shut, false)
			for side: float in [-1.0, 1.0]:
				# Carved frieze across the head of each open leaf.
				var u0 := side * (hw + fr + 0.03)
				var u1 := side * (hw + fr + 0.03 + (hw + fr) * 0.98)
				_carved_frieze(
					shell, m, dir, nrm, minf(u0, u1), maxf(u0, u1), y0 + h - 0.16, 0.065, shut
				)
			_notched_lintel(shell, m, dir, nrm, y0 + h + fr, hw + fr, trim)
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


## Point in a window's local frame: u along the wall, y up, z out of the wall.
static func _wp(m: Vector2, dir: Vector2, nrm: Vector2, u: float, y: float, z: float) -> Vector3:
	var q: Vector2 = m + dir * u + nrm * z
	return Vector3(q.x, y, q.y)


## Plain drip board over the head on two small brackets: sheds rain off the
## frame. The common middling-house upgrade.
static func _hood(
	shell: CityBuildingBuilder.Shell,
	m: Vector2,
	dir: Vector2,
	nrm: Vector2,
	y: float,
	hw: float,
	color: Color
) -> void:
	_wbox(shell, "paint", m, dir, nrm, -hw - 0.12, hw + 0.12, y + 0.04, y + 0.09, 0.0, 0.2, color)
	for u: float in [-hw - 0.06, hw + 0.06]:
		_wbox(
			shell,
			"paint",
			m,
			dir,
			nrm,
			u - 0.03,
			u + 0.03,
			y - 0.08,
			y + 0.04,
			0.0,
			0.15,
			color.darkened(0.08)
		)


## Lintel board whose lower edge is chip-notched into a row of triangular
## teeth, the simplest carving a householder could cut with an axe and knife.
static func _notched_lintel(
	shell: CityBuildingBuilder.Shell,
	m: Vector2,
	dir: Vector2,
	nrm: Vector2,
	y: float,
	hw: float,
	color: Color
) -> void:
	var left := -hw - 0.1
	var right := hw + 0.1
	_wbox(shell, "paint", m, dir, nrm, left, right, y + 0.03, y + 0.17, 0.0, 0.06, color)
	_teeth(shell, m, dir, nrm, left, right, y + 0.03, -0.07, 0.06, color, 7)


## Downward (rise < 0) or upward teeth hanging from a board edge at `y`.
static func _teeth(
	shell: CityBuildingBuilder.Shell,
	m: Vector2,
	dir: Vector2,
	nrm: Vector2,
	left: float,
	right: float,
	y: float,
	rise: float,
	z: float,
	color: Color,
	count: int
) -> void:
	var out := Vector3(nrm.x, 0, nrm.y)
	var tw := (right - left) / float(count)
	for i in count:
		var u := left + float(i) * tw
		var tip := _wp(m, dir, nrm, u + tw * 0.5, y + rise, z)
		var a := _wp(m, dir, nrm, u, y, z)
		var b := _wp(m, dir, nrm, u + tw, y, z)
		shell.tri_out("paint", a, b, tip, color, out)
		# Back face so the tooth is not a one-sided decal from below/inside.
		var a0 := _wp(m, dir, nrm, u, y, z - 0.03)
		var b0 := _wp(m, dir, nrm, u + tw, y, z - 0.03)
		var tip0 := _wp(m, dir, nrm, u + tw * 0.5, y + rise, z - 0.03)
		shell.tri_out("paint", a0, b0, tip0, color, -out)
		shell.quad_out("paint", a, tip, tip0, a0, color.darkened(0.2), Vector3(-dir.x, 0, -dir.y))
		shell.quad_out("paint", tip, b, b0, tip0, color.darkened(0.2), Vector3(dir.x, 0, dir.y))


## Six-petal chip-carved rosette: a disc of wedge facets cut alternately deep
## and shallow, so it reads as incised relief under raking light.
static func _rosette(
	shell: CityBuildingBuilder.Shell,
	m: Vector2,
	dir: Vector2,
	nrm: Vector2,
	u: float,
	y: float,
	r: float,
	z: float,
	color: Color
) -> void:
	var out := Vector3(nrm.x, 0, nrm.y)
	var segments := 12
	var centre := _wp(m, dir, nrm, u, y, z + 0.012)
	for i in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var p0 := _wp(m, dir, nrm, u + cos(a0) * r, y + sin(a0) * r, z)
		var p1 := _wp(m, dir, nrm, u + cos(a1) * r, y + sin(a1) * r, z)
		var shade := color.darkened(0.32) if i % 2 == 0 else color.lightened(0.06)
		shell.tri_out("paint", centre, p0, p1, shade, out)


## Rich timber window: broad side boards, a carved head board with rosettes
## between notched edges, a toothed apron under the sill on stepped corbels.
## Chip carving in the Baltic/Scandinavian medieval manner, not a later
## pedimented nalichnik (that stays the manual `platband`).
static func _carved_surround(
	shell: CityBuildingBuilder.Shell,
	m: Vector2,
	dir: Vector2,
	nrm: Vector2,
	y0: float,
	w: float,
	h: float,
	color: Color
) -> void:
	var hw := w * 0.5 + 0.06
	var bw := 0.13
	var top := y0 + h + 0.06
	var cut := color.darkened(0.3)
	# Side boards with an incised groove down the middle.
	for side: float in [-1.0, 1.0]:
		var u0 := -hw - bw if side < 0.0 else hw
		_wbox(shell, "paint", m, dir, nrm, u0, u0 + bw, y0 - 0.1, top, 0.0, 0.05, color)
		var g := u0 + bw * 0.5
		_wbox(shell, "paint", m, dir, nrm, g - 0.012, g + 0.012, y0, top - 0.04, 0.05, 0.056, cut)
	# Head board with a rosette frieze, notched below and toothed on top.
	var head := 0.26
	var edge := hw + bw + 0.04
	_wbox(shell, "paint", m, dir, nrm, -edge, edge, top, top + head, 0.0, 0.06, color)
	var span := 2.0 * (hw + bw)
	var count := maxi(2, int(span / 0.26))
	for i in count:
		var u := -hw - bw + span * (float(i) + 0.5) / float(count)
		_rosette(shell, m, dir, nrm, u, top + head * 0.5, 0.085, 0.061, color)
	_teeth(shell, m, dir, nrm, -edge, edge, top, -0.06, 0.06, color, count * 2)
	_teeth(shell, m, dir, nrm, -edge, edge, top + head, 0.07, 0.05, color, count)
	# Apron board under the sill with a toothed lower edge, on two corbels.
	var apron := y0 - 0.12
	_wbox(shell, "paint", m, dir, nrm, -hw - bw, hw + bw, apron - 0.14, apron, 0.0, 0.05, color)
	_teeth(shell, m, dir, nrm, -hw - bw, hw + bw, apron - 0.14, -0.08, 0.05, color, count * 2)
	for u: float in [-hw - bw * 0.5, hw + bw * 0.5]:
		var upper := color.darkened(0.1)
		var lower := color.darkened(0.14)
		_wbox(shell, "paint", m, dir, nrm, u - 0.05, u + 0.05, apron - 0.1, apron, 0.0, 0.17, upper)
		_wbox(shell, "paint", m, dir, nrm, u - 0.04, u + 0.04, apron - 0.2, apron - 0.1, 0.0, 0.11, lower)


## Narrow carved band across a shutter leaf: a notched rail with small rosettes.
static func _carved_frieze(
	shell: CityBuildingBuilder.Shell,
	m: Vector2,
	dir: Vector2,
	nrm: Vector2,
	left: float,
	right: float,
	y: float,
	z: float,
	color: Color
) -> void:
	_wbox(shell, "paint", m, dir, nrm, left, right, y, y + 0.12, z, z + 0.03, color.lightened(0.05))
	var count := maxi(1, int((right - left) / 0.16))
	for i in count:
		var u := left + (right - left) * (float(i) + 0.5) / float(count)
		_rosette(shell, m, dir, nrm, u, y + 0.06, 0.045, z + 0.031, color)
	_teeth(shell, m, dir, nrm, left, right, y, -0.04, z + 0.03, color, count * 2)

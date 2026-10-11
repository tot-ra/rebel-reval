class_name CityDoorDetails
extends RefCounted

## R-1692: visual profiles only. No new doorway, collision or persistent state.
## Explicit entrance IDs keep service doors humble, even on wealthy sites.
const SITE_STYLES := {
	&"door.council_hall.north": &"civic",
	&"door.council_hall.dornse": &"merchant",
	&"door.holy_spirit.north": &"parish",
	&"door.st_olaf.west": &"ecclesiastical",
	&"door.st_olaf.south": &"parish",
	&"door.st_nicholas.north": &"ecclesiastical",
	&"door.st_nicholas.west": &"parish",
	&"door.st_mary.priests": &"ecclesiastical",
	&"door.st_mary.south": &"parish",
}
const POOLS := [[&"ledged", &"plank"], [&"braced", &"plank"], [&"merchant", &"studded"]]
const PAINTS := [Color(0.53, 0.46, 0.36), Color(0.56, 0.40, 0.25), Color(0.39, 0.26, 0.16)]
const THICKNESS := 0.09
static var _cache: Dictionary = {}
static var _iron: StandardMaterial3D


static func look(building: Dictionary, tier: int) -> Dictionary:
	var seed_value := absi(hash(String(building["id"]) + ":door"))
	var rough := String(building.get("kind", "")) == "outbuilding"
	var pool: Array = POOLS[clampi(tier, 0, 2)]
	return {
		"style": &"rough" if rough else pool[seed_value % pool.size()],
		"paint": PAINTS[0 if rough else clampi(tier, 0, 2)],
		"variant": seed_value % 3,
	}


static func site_style(door: Dictionary) -> StringName:
	return SITE_STYLES.get(StringName(door["id"]), StringName(door["style"]))


static func iron_material() -> StandardMaterial3D:
	if _iron == null:
		_iron = StandardMaterial3D.new()
		_iron.albedo_color = Color(0.24, 0.23, 0.21)
		_iron.metallic = 0.72
		_iron.roughness = 0.64
		_iron.vertex_color_use_as_albedo = true
	return _iron


## One cached mesh, two surfaces. Hardware is never wood-textured or paint-tinted.
static func mesh(style: StringName, w: float, h: float, variant := 0) -> ArrayMesh:
	var key := [style, w, h, variant]
	if _cache.has(key):
		return _cache[key]
	var shell := CityBuildingBuilder.Shell.new()
	var count := maxi(3, int(w / (0.19 + variant * 0.015)))
	for i in count:
		var x0 := w * i / count + 0.002
		var x1 := w * (i + 1) / count - 0.002
		var shade := 0.88 + 0.035 * ((i * 7 + variant * 3) % 5)
		# Chamfered individual boards catch light on the joints from either side.
		_board(shell, x0, x1, h, Color(shade, shade, shade))
	# Interior ledges are structural, not expensive facade ironwork.
	for y: float in [h * 0.16, h * 0.79]:
		box(
			shell,
			"wood",
			Vector3(w * 0.04, y, -0.095),
			Vector3(w * 0.96, y + 0.10, -0.044),
			Color(0.78, 0.78, 0.78)
		)
	if style in [&"braced", &"rough"]:
		_bar(
			shell,
			"wood",
			Vector2(w * 0.08, h * 0.2),
			Vector2(w * 0.91, h * 0.78),
			0.09,
			-0.092,
			Color(0.8, 0.8, 0.8)
		)
	if style == &"rough":
		box(
			shell,
			"wood",
			Vector3(w * 0.7, h * 0.46, 0.045),
			Vector3(w * 0.93, h * 0.49, 0.10),
			Color(0.7, 0.7, 0.7)
		)
	else:
		_hardware(shell, style, w, h, variant)
	var result := shell.to_mesh(
		func(k: String) -> Material: return iron_material() if k == "iron" else null
	)
	var keys := shell.surfaces.keys()
	keys.sort()
	for i in keys.size():
		result.surface_set_name(i, keys[i])
	_cache[key] = result
	return result


static func _hardware(
	s: CityBuildingBuilder.Shell, style: StringName, w: float, h: float, variant: int
) -> void:
	var rich := style in [&"merchant", &"studded", &"civic", &"parish", &"ecclesiastical"]
	var ornate := style in [&"civic", &"parish", &"ecclesiastical"]
	var rows: Array[float] = [h * 0.19, h * 0.81]
	if style in [&"civic", &"ecclesiastical"]:
		rows.insert(1, h * 0.52)
	if style == &"ledged":
		for y in rows:
			box(
				s,
				"wood",
				Vector3(0.015, y - 0.055, 0.045),
				Vector3(w - 0.02, y + 0.055, 0.051),
				Color(0.78, 0.78, 0.78)
			)
	for y in rows:
		var end := w * (0.86 if ornate else 0.72)
		var breadth := 0.065 if rich else 0.045
		_bar(s, "iron", Vector2(0.015, y), Vector2(end, y), breadth, 0.062, Color.WHITE)
		# Forged lance terminal, not a modern machined strap end.
		_prism(
			s,
			"iron",
			PackedVector2Array(
				[
					Vector2(end - 0.045, y),
					Vector2(end + 0.01, y - breadth),
					Vector2(minf(w - 0.025, end + 0.11), y),
					Vector2(end + 0.01, y + breadth)
				]
			),
			0.053,
			0.074,
			Color.WHITE
		)
		for x: float in [w * 0.12, w * 0.38, w * 0.64]:
			_rivet(s, Vector2(x, y), 0.079, 0.013)
		# Hinge knuckles remain within the authored leaf width.
		box(
			s,
			"iron",
			Vector3(0.005, y - 0.072, 0.043),
			Vector3(0.046, y + 0.072, 0.105),
			Color(0.85, 0.85, 0.85)
		)
		if ornate:
			for sign_y: float in [-1.0, 1.0]:
				var rise := minf(h * 0.095, 0.25)
				var start := Vector2(w * 0.25, y)
				for j in 8:
					var f := float(j + 1) / 8.0
					var point := Vector2(
						w * (0.25 + 0.48 * f), y + sign_y * rise * sin(f * PI * 0.8)
					)
					_bar(s, "iron", start, point, 0.027, 0.062, Color.WHITE)
					start = point
				_rivet(s, start, 0.078, 0.017)
	if rich:
		# Border nails and a restrained chip-cut edge, no Renaissance panels.
		for x: float in [w * 0.07, w * 0.93]:
			for row in 9:
				_rivet(s, Vector2(x, h * (0.07 + row * 0.105)), 0.055, 0.016)
		for x: float in [w * 0.035, w * 0.965]:
			box(
				s,
				"wood",
				Vector3(x - 0.012, 0.03, 0.044),
				Vector3(x + 0.012, h - 0.03, 0.061),
				Color(0.72, 0.72, 0.72)
			)
	var handle := Vector2(w * 0.81, minf(h * 0.48, 1.22))
	# Escutcheon, key slit and free-standing ring are distinct relief geometry.
	var plate_w := 0.065 if rich else 0.045
	_prism(
		s,
		"iron",
		PackedVector2Array(
			[
				handle + Vector2(-plate_w, -0.10),
				handle + Vector2(0, -0.14),
				handle + Vector2(plate_w, -0.10),
				handle + Vector2(plate_w, 0.07),
				handle + Vector2(0, 0.13),
				handle + Vector2(-plate_w, 0.07)
			]
		),
		0.047,
		0.061,
		Color(0.8, 0.8, 0.8)
	)
	box(
		s,
		"iron",
		Vector3(handle.x - 0.007, handle.y - 0.1, 0.062),
		Vector3(handle.x + 0.007, handle.y - 0.054, 0.064),
		Color(0.08, 0.08, 0.08)
	)
	_rivet(s, handle + Vector2(0, 0.055), 0.09, 0.022)
	_ring(s, handle + Vector2(0, -0.012), 0.115, 0.063 if rich else 0.048)
	# The back gets a plain latch and pull, not a second ceremonial facade.
	box(
		s,
		"iron",
		Vector3(w * 0.63, handle.y - 0.015, -0.073),
		Vector3(w * 0.94, handle.y + 0.015, -0.046),
		Color.WHITE
	)
	_ring(s, handle, -0.12, 0.045)
	if style == &"merchant":
		for row in 3:
			var y := h * (0.33 + row * 0.16)
			_rivet(s, Vector2(w * (0.34 + variant * 0.06), y), 0.05, 0.018)


static func _board(
	s: CityBuildingBuilder.Shell, x0: float, x1: float, h: float, color: Color
) -> void:
	var bevel := 0.007
	var t := THICKNESS * 0.5
	var edge := [Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, h), Vector2(x0, h)]
	var inset := [
		Vector2(x0 + bevel, bevel),
		Vector2(x1 - bevel, bevel),
		Vector2(x1 - bevel, h - bevel),
		Vector2(x0 + bevel, h - bevel)
	]
	for side: float in [-1.0, 1.0]:
		var normal := Vector3(0, 0, side)
		s.quad_out(
			"wood",
			Vector3(inset[0].x, inset[0].y, t * side),
			Vector3(inset[1].x, inset[1].y, t * side),
			Vector3(inset[2].x, inset[2].y, t * side),
			Vector3(inset[3].x, inset[3].y, t * side),
			color,
			normal
		)
		for i in 4:
			var j := (i + 1) % 4
			s.quad_out(
				"wood",
				Vector3(edge[i].x, edge[i].y, (t - bevel) * side),
				Vector3(edge[j].x, edge[j].y, (t - bevel) * side),
				Vector3(inset[j].x, inset[j].y, t * side),
				Vector3(inset[i].x, inset[i].y, t * side),
				color,
				normal
			)
	_prism(s, "wood", PackedVector2Array(edge), -t + bevel, t - bevel, color)


static func _rivet(s: CityBuildingBuilder.Shell, at: Vector2, z: float, r: float) -> void:
	var points := PackedVector2Array()
	for i in 6:
		points.append(at + Vector2(cos(i * TAU / 6), sin(i * TAU / 6)) * r)
	_prism(s, "iron", points, z, z + 0.012, Color(1.1, 1.1, 1.1))


static func _ring(s: CityBuildingBuilder.Shell, at: Vector2, z: float, radius: float) -> void:
	for i in 20:
		for j in 6:
			var points: Array[Vector3] = []
			for ij: Vector2i in [
				Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)
			]:
				var a := ij.x * TAU / 20.0
				var b := ij.y * TAU / 6.0
				var r := radius + cos(b) * 0.010
				points.append(Vector3(at.x + cos(a) * r, at.y + sin(a) * r, z + sin(b) * 0.010))
			var mid := (points[0] + points[2]) * 0.5
			var radial := Vector2(mid.x - at.x, mid.y - at.y).normalized() * radius
			s.quad_out(
				"iron",
				points[0],
				points[1],
				points[2],
				points[3],
				Color.WHITE,
				mid - Vector3(at.x + radial.x, at.y + radial.y, z)
			)


static func _bar(
	s: CityBuildingBuilder.Shell,
	key: String,
	a: Vector2,
	b: Vector2,
	width: float,
	z: float,
	color: Color
) -> void:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x) * width * 0.5
	_prism(s, key, PackedVector2Array([a - n, b - n, b + n, a + n]), z - 0.01, z + 0.01, color)


static func _prism(
	s: CityBuildingBuilder.Shell,
	key: String,
	points: PackedVector2Array,
	z0: float,
	z1: float,
	color: Color
) -> void:
	var center := Vector2.ZERO
	for p in points:
		center += p / points.size()
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var a0 := Vector3(a.x, a.y, z0)
		var b0 := Vector3(b.x, b.y, z0)
		var a1 := Vector3(a.x, a.y, z1)
		var b1 := Vector3(b.x, b.y, z1)
		s.tri_out(key, Vector3(center.x, center.y, z1), a1, b1, color, Vector3.BACK)
		s.tri_out(key, Vector3(center.x, center.y, z0), a0, b0, color, Vector3.FORWARD)
		s.quad_out(
			key,
			a0,
			b0,
			b1,
			a1,
			color,
			Vector3((a.x + b.x) * 0.5 - center.x, (a.y + b.y) * 0.5 - center.y, 0)
		)


static func box(
	s: CityBuildingBuilder.Shell, key: String, lo: Vector3, hi: Vector3, color := Color.WHITE
) -> void:
	_prism(
		s,
		key,
		PackedVector2Array(
			[Vector2(lo.x, lo.y), Vector2(hi.x, lo.y), Vector2(hi.x, hi.y), Vector2(lo.x, hi.y)]
		),
		lo.z,
		hi.z,
		color
	)

extends RefCounted
## P0-212: deterministic, cached by MapViewBirdMeshes. All dimensions derive
## from the existing ecological catalogue; no spawning or gameplay state here.
const Species := preload("res://scripts/map/view3d/map_view_bird_species.gd")
const Plumage := preload("res://assets/birds/catalog_plumage.gdshader")
static var _material: ShaderMaterial
var surface: SurfaceTool
var species: StringName
var group: StringName
var colors: Array[Color]
var breast: Color
var unit: float
var center: Vector3
var radius: Vector3
var head: Vector3
var head_size: float
var pattern := 0.0
var section_flatten := 1.0
var rig_part := 0
var rig_regions := PackedInt32Array()
var rig_anchors: Dictionary = {}
# Spread-wing state for the flight_wing() helpers (R-1188).
var w_side := 1.0
var w_shoulder := Vector3.ZERO
var w_wrist := Vector3.ZERO
var w_len := 1.0
var w_arm := 0.5
var w_chord := 0.2
var w_plan: Dictionary = {}
var w_lift := 0.0
var w_sweep := 0.0

static func build(id: StringName, pose: StringName, lift: float = 0.0, sweep: float = 0.0) -> ArrayMesh:
	return new()._build(id, pose, lift, sweep)

func _build(id: StringName, pose: StringName, lift: float, sweep: float) -> ArrayMesh:
	species = id
	group = Species.group_for(id)
	colors = Species.colors_for(id)
	breast = Species.breast_color_for(id)
	var g := Species.geometry_for(id)
	var body: Vector3 = g["body"]
	unit = Species.scale_m(id) / body.x
	radius = Vector3(body.z, body.y, body.x) * unit * 0.5
	head_size = float(g["head"]) * unit * 0.67
	var leg := float(g["legs"]) * unit * (0.48 if group in [&"songbird", &"corvid", &"swallow", &"woodpecker", &"owl"] else 0.68)
	var neck := float(g["neck"]) * unit
	var flying := pose == Species.POSE_GLIDING
	center = Vector3(0, leg + radius.y, 0)
	surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	if id in [&"common_buzzard", &"common_kestrel", &"tawny_owl", &"greylag_goose"]:
		pattern = 1.0
	if id == &"song_thrush":
		pattern = 2.0
	if id in [&"skylark", &"common_snipe", &"yellowhammer"]:
		pattern = 3.0
	# Full breast tapers into the rump. Pigmentation is evaluated per vertex,
	# avoiding the old horizontal bands on each latitude ring.

	var start := center + Vector3(0, radius.y * 0.2, -radius.z * 0.55)
	var neck_top := start + Vector3(0, neck * 0.8 + head_size * 0.48, -neck * 0.20)
	var neck_points: Array[Vector3] = []
	if neck > radius.y * 0.7:
		var p1 := start + Vector3(0, neck * 0.32, neck * 0.18)
		var p2 := neck_top + Vector3(0, -neck * 0.25, -neck * 0.28)
		if flying and id == &"grey_heron":
			neck_top = start + Vector3(0, head_size * 0.8, -radius.z * 0.24)
			p1 = start + Vector3(0, neck * 0.2, neck * 0.05)
			p2 = neck_top + Vector3(0, neck * 0.10, neck * 0.05)
		elif flying:
			neck_top = start + Vector3(0, head_size * 0.2, -neck * 0.88)
			p1 = start.lerp(neck_top, 0.32)
			p2 = start.lerp(neck_top, 0.68)
		for i in range(1, 5):
			neck_points.append(start.bezier_interpolate(p1, p2, neck_top, float(i) / 5))

	head = neck_top + Vector3(0, head_size * 0.2, -head_size * 0.14)
	hull(neck_points)
	if group == &"owl":
		owl_face()
	bill(float(g["beak"]) * unit)
	eyes()
	if Species.has_crest(id) or id == &"skylark":
		for i in 5:
			var root := head + Vector3((i - 2) * head_size * 0.09, head_size * 0.84, 0)
			feather(root, root + Vector3(0, head_size * (0.75 - absf(i - 2) * 0.12), head_size * 0.65), head_size * 0.065, Color("30332b"))
	wings(float(g["wing_span"]) * unit, float(g["wing_chord"]) * unit, flying, lift, sweep)
	tail(float(g["tail"]) * unit)
	feet(leg, flying)
	surface.generate_tangents()
	var mesh := surface.commit()
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = Plumage
	mesh.surface_set_material(0, _material)
	mesh.set_meta(&"bird_catalog_revision", 214)
	mesh.set_meta(&"bird_rig_regions", rig_regions)
	mesh.set_meta(&"bird_rig_anchors", rig_anchors)
	return mesh

func hull(neck_points: Array[Vector3]) -> void:
	var path: Array[Vector3] = [center + Vector3(0, -radius.y * 0.12, radius.z * 1.02), center + Vector3(0, 0, radius.z * 0.65), center, center + Vector3(0, radius.y * 0.10, -radius.z * 0.60)]
	var sizes: Array[Vector2] = [Vector2.ONE * radius.x * 0.03, Vector2(radius.x * 0.73, radius.y * 0.76), Vector2(radius.x, radius.y), Vector2(radius.x * 0.82, radius.y * 0.87)]
	for point in neck_points:
		path.append(point)
		sizes.append(Vector2.ONE * head_size * 0.65)
	path.append(head + Vector3(0, -head_size * 0.25, head_size * 0.42))
	sizes.append(Vector2(head_size * 0.72, head_size * 0.83))
	path.append(head + Vector3(0, 0, -head_size * 0.1))
	sizes.append(Vector2(head_size * 0.84, head_size * 0.93))
	path.append(head + Vector3(0, -head_size * 0.08, -head_size * 0.8))
	sizes.append(Vector2(head_size * 0.40, head_size * 0.45))
	path.append(head + Vector3(0, -head_size * 0.1, -head_size * 1.02))
	sizes.append(Vector2.ONE * head_size * 0.04)
	var rings: Array[PackedVector3Array] = []
	for segment in path.size() - 1:
		for row in 3:
			var t := float(row) / 3
			var previous := maxi(0, segment - 1)
			var following := mini(path.size() - 1, segment + 2)
			var at := path[segment].cubic_interpolate(path[segment + 1], path[previous], path[following], t)
			var size := sizes[segment].cubic_interpolate(sizes[segment + 1], sizes[previous], sizes[following], t).max(Vector2.ONE * head_size * 0.015)
			var ahead := path[segment].cubic_interpolate(path[segment + 1], path[previous], path[following], minf(1.0, t+0.01))
			var behind := path[segment].cubic_interpolate(path[segment + 1], path[previous], path[following], maxf(0.0, t-0.01))
			var axis := (ahead - behind).normalized()
			var up := Vector3.RIGHT.cross(axis).normalized()
			up = up.lerp(Vector3.UP, smoothstep(float(path.size()-5), float(path.size()-4), float(segment)+t)).normalized()
			var ring := PackedVector3Array()
			for i in 25:
				var angle := TAU * float(i) / 24
				var cx := cos(angle)
				var cy := sin(angle)
				# Body rings were circles, so every species read as an egg.
				# A deeper keel and flatter back keep the head round.
				if segment <= 2:
					if cy < 0.0:
						cx *= lerpf(1.0, 0.76, -cy)
						cy *= lerpf(1.0, 1.1, -cy)
					else:
						cy *= lerpf(1.0, 0.88, cy)
				ring.append(at + Vector3.RIGHT * cx * size.x + up * cy * size.y)
			rings.append(ring)
	for j in rings.size() - 1:
		for i in 24:
			for corner: Vector2i in [Vector2i(i,j), Vector2i(i+1,j), Vector2i(i+1,j+1), Vector2i(i,j), Vector2i(i+1,j+1), Vector2i(i,j+1)]:
				var x := corner.x % 24
				var y := corner.y
				var p := rings[y][x]
				var across := rings[y][(x+1)%24] - rings[y][(x+23)%24]
				var along := rings[mini(y+1,rings.size()-1)][x] - rings[maxi(0,y-1)][x]
				var normal := along.cross(across).normalized()
				var head_mix := smoothstep(float(rings.size()-11), float(rings.size()-7), float(y))
				var color := pigment(p, colors[0], 0).lerp(pigment(p, colors[1], 1), head_mix)
				if not neck_points.is_empty() and y > 10 and head_mix < 0.5: color = Color("c5c8c1") if species == &"grey_heron" else colors[0]
				vertex(p, normal, Vector2(float(corner.x)/24*4, float(y)/rings.size()*3), color, 0, pattern * (1.0 - head_mix))

func pigment(p: Vector3, base: Color, region: int) -> Color:
	if region == 0:
		var q := (p - center) / radius
		var belly_mix := smoothstep(0.3, -0.5, q.y)
		var result := base.lerp(breast, belly_mix)
		result = result.darkened(smoothstep(0.05, 0.8, q.y) * 0.1)
		if species == &"great_tit" and absf(q.x) < 0.18 and q.y < 0.05:
			result = Color("25272a")
		if species == &"northern_lapwing" and q.y < -0.05: result = Color("d1d0c0")
		if species == &"eurasian_magpie" and q.y < 0.05:
			result = Color("d7d5c8")
		if species in [&"song_thrush", &"osprey", &"common_nightingale", &"barn_swallow"]:
			result = base.lerp(Color("d3c7ac"), belly_mix)
		return result
	if region == 1:
		if group == &"gull": return Color("d6d6cc")
		var q := (p - head) / head_size
		match species:
			&"great_tit", &"great_spotted_woodpecker":
				if absf(q.x) > 0.5 and q.y < 0.22 and q.y > -0.45 and q.z < 0.30:
					return Color("deddd1")
			&"osprey":
				return Color("302b28") if q.y > -0.06 and q.y < 0.28 and q.z < 0.4 else Color("d8d5c6")
			&"house_sparrow":
				if q.y > 0.5: return Color("777777")
				if q.y < -0.3 and q.z < -0.2: return Color("242629")
				if absf(q.x) > 0.6 and q.y < 0.10: return Color("c6c2b5")
			&"yellowhammer":
				return Color("c4ad47").lerp(base, smoothstep(0.3, 0.75, q.z))
			&"common_tern", &"barn_swallow":
				return Color("1e252a") if q.y > -0.05 else Color("d5d2c6")
			&"white_tailed_eagle": return Color("ac9c79")
			&"western_jackdaw": return Color("66696a") if q.z > 0.1 else Color("292d31")
			&"rook":
				if q.z < -0.8: return Color("9c9b91")
			&"european_robin": return colors[0] if q.z > -0.1 else base
			&"grey_heron": return Color("353a3d") if q.y > 0.2 and absf(q.x) > 0.5 else Color("c5c8c1")
			&"northern_lapwing": return Color("242d2b") if q.y > 0.35 or q.y < -0.3 else Color("cdd0c4")
			&"great_cormorant": return Color("c7bd9b") if q.y < -0.48 else base
	return base

func oval(at: Vector3, size: Vector3, color: Color, segments: int = 12, rings: int = 8, region: int = -1, material: float = 0.0) -> void:
	for j in rings:
		for i in segments:
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			for corner: Vector2 in [Vector2(i, j), Vector2(i + 1, j), Vector2(i + 1, j + 1), Vector2(i, j + 1)]:
				var uv := corner / Vector2(segments, rings)
				var lat := PI * (uv.y - 0.5)
				var lon := TAU * uv.x
				var n := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
				points.append(at + n * size)
				normals.append((n / size).normalized())
				uvs.append(uv * Vector2(4, 3))
			for index in [0, 1, 2, 0, 2, 3]:
				vertex(points[index], normals[index], uvs[index], pigment(points[index], color, region), material, pattern if region == 0 else 0.0)

func vertex(p: Vector3, n: Vector3, uv: Vector2, color: Color, material: float = 0.0, markings: float = 0.0) -> void:
	surface.set_normal(n)
	surface.set_uv(uv)
	surface.set_uv2(Vector2(material, markings))
	surface.set_color(color)
	surface.add_vertex(p)
	rig_regions.append(rig_part)

func curve_tube(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ra: float, rb: float, color: Color, steps: int = 5, segments: int = 8, material: float = 0.0) -> void:
	for j in steps:
		var points: Array[Vector3] = []
		var normals: Array[Vector3] = []
		for row in 2:
			var t := float(j + row) / steps
			var p := a.bezier_interpolate(b, c, d, t)
			var axis := a.bezier_derivative(b, c, d, t).normalized()
			var right := axis.cross(Vector3.RIGHT).normalized()
			if right.length_squared() < 0.1: right = axis.cross(Vector3.FORWARD).normalized()
			var up := right.cross(axis).normalized()
			var r := lerpf(ra, rb, t)
			for i in segments + 1:
				var angle := TAU * i / segments
				var n := (right * cos(angle) + up * sin(angle) * section_flatten).normalized()
				points.append(p + n * r)
				normals.append(n)
		for i in segments:
			for index in [i, i + 1, i + segments + 2, i, i + segments + 2, i + segments + 1]:
				vertex(points[index], normals[index], Vector2(float(index % (segments + 1)) / segments, float(j + index / (segments + 1)) / steps), color, material)

func tube(a: Vector3, b: Vector3, ra: float, rb: float, color: Color, material: float = 0.6) -> void:
	curve_tube(a, a.lerp(b, 0.33), a.lerp(b, 0.67), b, ra, rb, color, 1, 8, material)

func bill(length: float) -> void:
	var base := head + Vector3(0, -head_size * 0.1, -head_size * 0.78)
	var hooked := group in [&"raptor", &"owl"] or species == &"great_cormorant"
	var broad := species in [&"mallard", &"mute_swan", &"greylag_goose"]
	var width := head_size * (0.46 if broad else (0.19 if group == &"wader" else 0.28))
	var color := colors[2]
	if species == &"white_tailed_eagle": color = Color("b9a34c")
	if species == &"northern_lapwing": color = Color("30302b")
	if species == &"great_cormorant": color = Color("827f68")
	if group in [&"corvid", &"songbird", &"swallow", &"woodpecker"] and species != &"common_blackbird": color = Color("524b3e")
	if broad:
		oval(base + Vector3(0, -head_size * 0.03, -length * 0.34), Vector3(width, head_size * 0.1, length * 0.66), color, 16, 8, -1, 0.6)
	else:
		var tip := base + Vector3(0, -length * (0.36 if hooked else 0.04), -length)
		# Flatten keeps the culmen from reading as a round hose. Legs reset this.
		section_flatten = 0.52
		curve_tube(base, base + Vector3(0, head_size * 0.20, -length * 0.38), tip + Vector3(0, length * 0.23 if hooked else 0.0, 0), tip, width, head_size * 0.012, color, 6, 8, 0.6)
		var lower := base + Vector3(0, -head_size * 0.16, 0)
		section_flatten = 0.48
		tube(lower, lower + Vector3(0, 0, -length * 0.8), width * 0.62, head_size * 0.015, color.darkened(0.18))
		section_flatten = 1.0
	for sign_value in [-1.0, 1.0]:
		oval(base + Vector3(sign_value * width * 0.83, head_size * 0.035, -length * 0.15), Vector3(head_size * 0.026, head_size * 0.025, head_size * 0.065), Color("292523"), 8, 4, -1, 0.6)

func eyes() -> void:
	for side in [-1.0, 1.0]:
		var at := head + Vector3(side * head_size * 0.58, head_size * 0.17, -head_size * 0.49)
		var r := head_size * 0.09
		if group == &"owl":
			at = head + Vector3(side * head_size * 0.37, head_size * 0.1, -head_size * 0.84)
			r = head_size * 0.18
		var iris := Color("65513a")
		if species == &"western_jackdaw": iris = Color("a2b6b9")
		if group == &"raptor": iris = Color("ac8141")
		if species == &"common_blackbird": iris = Color("c89942")
		oval(at, Vector3.ONE * r * 0.97, iris, 10, 6, -1, 0.6)
		var outward := Vector3(side * 0.8, 0.08, -0.65).normalized() if group != &"owl" else Vector3.FORWARD
		oval(at + outward * r * 0.45, Vector3.ONE * r * 0.84, Color("0c1012"), 10, 6, -1, 1.0)
		oval(at + outward * r * 0.82 + Vector3(0, r * 0.28, 0), Vector3.ONE * r * 0.2, Color("f3f0e8"), 6, 3, -1, 1.0)

func owl_face() -> void:
	for side in [-1.0, 1.0]:
		oval(head + Vector3(side * head_size * 0.36, -head_size * 0.06, -head_size * 0.72), Vector3(head_size * 0.48, head_size * 0.69, head_size * 0.25), Color("aa9679"), 16, 10)

func feather(a: Vector3, b: Vector3, width: float, color: Color, normal: Vector3 = Vector3.UP, marking: float = 0.0, notch: float = 0.0, blunt: float = 0.0) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(normal).normalized()
	if side.length_squared() < 0.1: side = Vector3.RIGHT
	var up := side.cross(axis).normalized()
	var rows: Array[float] = [0.0, 0.18, 0.38, 0.60, 0.80, 0.92, 0.98, 1.0]
	for j in 7:
		for column in 2:
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			for corner: Vector2 in [Vector2(column, j), Vector2(column + 1, j), Vector2(column + 1, j + 1), Vector2(column, j + 1)]:
				var uv := Vector2(corner.x / 2.0, rows[int(corner.y)])
				var t := uv.y
				var x := uv.x * 2.0 - 1.0
				var breadth := pow(maxf(0.0, sin(PI * (0.19 + t * 0.81))), 0.6)
				if blunt > 0.0:
					# Secondaries and coverts end in a rounded vane, not a spear point.
					var rounded := minf(1.0, 0.55 + t * 3.0) * sqrt(maxf(0.0, 1.0 - pow(maxf(0.0, t - 0.6) / 0.4, 2.0)))
					breadth = lerpf(breadth, rounded, blunt)
				# Notch cuts the distal outer vane so primaries separate into fingers.
				var outer := 1.0
				if x > 0.0:
					outer = lerpf(1.0, 0.34, notch * smoothstep(0.4, 0.78, t))
				var p := a.lerp(b, t) + side * x * width * breadth * (0.78 if x < 0.0 else outer)
				p += up * (sin(t * PI) * width * 0.24 + (1.0 - absf(x)) * width * 0.1)
				p += side * x * notch * sin(t * PI) * width * 0.08
				points.append(p)
				normals.append((up * (1.0 - t * 0.2) + axis * t * 0.42 + side * x * 0.34).normalized())
				uvs.append(uv)
			for index in front_order(points[0], points[1], points[2], up):
				vertex(points[index], normals[index], uvs[index], color, 0.0, marking)

## Quad corner order whose winding faces `normal`. Bird materials are double
## sided and Godot flips NORMAL on back faces, so a quad wound against its own
## normal is lit as if seen from below. Feathers were all wound that way, which
## left every wing and tail darker and flatter than the body (R-1188).
func front_order(p0: Vector3, p1: Vector3, p2: Vector3, normal: Vector3) -> Array[int]:
	# Godot front faces are clockwise: their edge cross product opposes the normal.
	if (p1 - p0).cross(p2 - p0).dot(normal) > 0.0:
		return [0, 2, 1, 0, 3, 2]
	return [0, 1, 2, 0, 2, 3]

func wing_color(t: float) -> Color:
	var result := colors[1].darkened(0.06 + t * 0.10)
	if species in [&"common_chaffinch", &"great_tit", &"eurasian_magpie", &"great_spotted_woodpecker"]:
		result = Color("373e43")
	if group in [&"gull", &"tern"]:
		# Black outer hand: the field mark of Baltic gulls and terns in flight.
		result = Color("a2a9ab").lerp(Color("272d32"), smoothstep(0.8, 0.86, t))
	if species == &"mallard": result = Color("7a705f")
	if species == &"mute_swan": result = Color("e8e7df").darkened(t * 0.06)
	if species == &"greylag_goose": result = Color("817d72").darkened(t * 0.12)
	if species == &"northern_lapwing": result = Color("293d36")
	if species == &"grey_heron": result = Color("75828b")
	if species == &"european_robin": result = colors[0].darkened(0.08)
	if species == &"common_nightingale": result = Color("825738")
	if group not in [&"gull", &"tern"]:
		result = result.darkened(smoothstep(0.62, 1.0, t) * 0.16)
	return result

func wings(span: float, chord: float, flying: bool, lift: float, sweep: float) -> void:
	for sign_value in [-1.0, 1.0]:
		var s := float(sign_value)
		var shoulder := center + Vector3(s * radius.x * 0.62, radius.y * 0.44, -radius.z * 0.22)
		if flying:
			flight_wing(s, shoulder, span * 0.5 * 0.96, chord, lift, sweep)
		else:
			var wing_center := center + Vector3(s * radius.x * 0.87, radius.y * 0.16, radius.z * 0.08)
			oval(wing_center, Vector3(radius.x * 0.07, radius.y * 0.22, radius.z * 0.34), wing_color(0.25), 8, 4)
			var normal := Vector3(s, 0.3, 0).normalized()
			for i in 3:
				var t := float(i) / 2.0
				var root := wing_center + Vector3(s * radius.x * 0.04, radius.y * (0.48 - t * 0.12), -radius.z * (0.42 + t * 0.06))
				feather(root, root + Vector3(s * radius.x * 0.2, radius.y * 0.14, -radius.z * 0.22), radius.y * 0.07, wing_color(0.12), normal, pattern, 0.25)
			for i in 10:
				var t := float(i) / 9
				var root := wing_center + Vector3(s * radius.x * (0.14 - absf(t - 0.5) * 0.15), radius.y * (0.42 - t * 0.77), -radius.z * 0.25)
				var tip := center + Vector3(s * radius.x * (0.78 - t * 0.08), radius.y * (-0.05 - t * 0.44), radius.z * (1.35 - t * 0.32))
				feather(root, tip, radius.y * 0.15, wing_color(0.4 + t * 0.6), normal, pattern, smoothstep(0.55, 1.0, t) * 0.45)
			for row in 2:
				for i in 9:
					var t := float(i) / 8
					var root := wing_center + Vector3(s * radius.x * (0.17 + 0.018 * row - pow((t - 0.5) * 2, 2) * 0.12), radius.y * (0.51 - t * 0.95), radius.z * (-0.70 + row * 0.47))
					var color := wing_color(t * 0.4).lightened(0.025)
					if row == 1 and species in [&"common_chaffinch", &"great_tit", &"great_spotted_woodpecker", &"eurasian_magpie"]: color = Color("c9c9bc")
					feather(root, root + Vector3(0, -radius.y * 0.07, radius.z * 0.67), radius.y * 0.145, color, normal, pattern)

	rig_part = 0

## Spread-wing planform per family (R-1188). `arm` is the shoulder-to-wrist share
## of the wing; `tip` picks the hand outline; `le_back` sweeps the hand's leading
## edge back (in chords); `hand` scales the hand chord; `fingers` counts the
## emarginated outer primaries that separate into slots on broad soaring wings.
func wing_plan() -> Dictionary:
	match species:
		&"common_kestrel":
			return plan(0.44, &"pointed", 0.45, 0.8, 0)
		&"grey_heron":
			return plan(0.47, &"slotted", 0.12, 0.95, 5)
		&"great_cormorant":
			return plan(0.46, &"slotted", 0.2, 0.85, 3)
		&"northern_lapwing":
			return plan(0.42, &"rounded", 0.1, 1.15, 0)
		&"white_tailed_eagle":
			return plan(0.48, &"slotted", 0.08, 1.0, 7)
		&"osprey":
			return plan(0.50, &"slotted", 0.3, 0.85, 4)
		&"eurasian_magpie":
			return plan(0.42, &"rounded", 0.15, 0.95, 0)
	match group:
		&"gull":
			return plan(0.50, &"pointed", 0.55, 0.8, 0)
		&"tern":
			return plan(0.40, &"pointed", 0.75, 0.7, 0)
		&"swallow":
			return plan(0.32, &"pointed", 0.85, 0.65, 0)
		&"waterfowl", &"wader":
			return plan(0.42, &"pointed", 0.45, 0.8, 0)
		&"raptor":
			return plan(0.47, &"slotted", 0.12, 0.95, 5)
		&"corvid":
			return plan(0.44, &"slotted", 0.15, 0.9, 5)
		&"owl":
			return plan(0.45, &"rounded", 0.2, 1.0, 0)
	return plan(0.42, &"rounded", 0.3, 0.85, 0)

func plan(arm: float, tip: StringName, le_back: float, hand: float, fingers: int) -> Dictionary:
	return {"arm": arm, "tip": tip, "le_back": le_back, "hand": hand, "fingers": fingers}

## Leading edge offset (z, +back) at spanwise distance `a` from the shoulder.
func wing_le(a: float) -> float:
	if a <= w_arm:
		return lerpf(-w_chord * 0.02, -w_chord * 0.18, a / w_arm)
	var u := clampf((a - w_arm) / (w_len - w_arm), 0.0, 1.0)
	return -w_chord * 0.18 + w_chord * float(w_plan["le_back"]) * pow(u, 1.4)

## Chord at spanwise distance `a`. The hand outline is what tells a gull from a
## buzzard at gameplay distance, so it is family-specific.
func wing_cd(a: float) -> float:
	if a <= w_arm:
		return lerpf(w_chord * 1.08, w_chord * 0.98, a / w_arm)
	var u := clampf((a - w_arm) / (w_len - w_arm), 0.0, 1.0)
	var base := w_chord * 0.98 * float(w_plan["hand"])
	match w_plan["tip"]:
		&"pointed":
			return base * (1.0 - pow(u, 2.2)) + w_chord * 0.02
		&"rounded":
			return base * sqrt(maxf(0.0, 1.0 - pow(u, 3.0))) + w_chord * 0.02
	return base * (1.0 - 0.35 * u)

## Wing-space point -> model space. Camber lifts the middle of the chord so the
## plate reads as an aerofoil; `lift`/`sweep` hinge it at shoulder and wrist for
## the baked flap frames, keeping topology identical to the neutral pose.
func wing_point(a: float, c: float, below: bool = false) -> Vector3:
	var cd := wing_cd(a)
	var v := clampf(c / maxf(cd, 0.0001), 0.0, 1.2)
	var u := clampf((a - w_arm) / (w_len - w_arm), 0.0, 1.0) if a > w_arm else 0.0
	var y := w_chord * 0.07 * sin(PI * minf(v, 1.0)) * (1.0 - 0.6 * u)
	if below:
		# Thicker leading edge, thin trailing edge: a real wing section, not a card.
		y -= w_chord * (0.012 + 0.05 * pow(maxf(0.0, 1.0 - v), 2.0)) * (1.0 - 0.7 * u)
	return wing_hinge(w_shoulder + Vector3(w_side * a, y, wing_le(a) + c), a)

func wing_hinge(p: Vector3, a: float) -> Vector3:
	if is_zero_approx(w_lift) and is_zero_approx(w_sweep):
		return p
	# Sweep shears the wing fore and aft (positive = back) so the span, and
	# with it the neutral frame's bounds, stays exact; lift hinges it upward.
	p.z += w_sweep * (0.55 * minf(a, w_arm) + 0.85 * maxf(a - w_arm, 0.0))
	if a > w_arm:
		# The hand lags the arm through the stroke, bending the wing at the wrist.
		p = w_wrist + Basis(Vector3.BACK, w_side * w_lift * 0.35) * (p - w_wrist)
	return w_shoulder + Basis(Vector3.BACK, w_side * w_lift * 0.5) * (p - w_shoulder)

## Feather anchor: a straight feather between two points of the cambered
## plate would sag through its arc and vanish under it, so feathers ride a
## little above the surface (about the arc's sagitta).
func wing_feather(a: float, c: float) -> Vector3:
	return wing_point(a, c) + wing_up(a) * w_chord * 0.035

func wing_up(a: float) -> Vector3:
	var top := wing_hinge(w_shoulder + Vector3.UP * w_chord, a)
	return (top - wing_hinge(w_shoulder, a)).normalized()

## Smooth double-sided wing plate between spanwise `a0..a1`, covering the chord
## up to `v_max`. Feathers lie on top of it, so the wing never shows the sky
## through gaps between cards (the old "comb" silhouette).
func wing_plate(a0: float, a1: float, v_max: float, t0: float, t1: float) -> void:
	var cols := 8
	var rows := 4
	for below in [false, true]:
		var grid: Array[PackedVector3Array] = []
		for i in cols + 1:
			var a := lerpf(a0, a1, float(i) / cols)
			var row := PackedVector3Array()
			for j in rows + 1:
				row.append(wing_point(a, wing_cd(a) * v_max * float(j) / rows, below))
			grid.append(row)
		for i in cols:
			for j in rows:
				var quad: Array[Vector2i] = [
					Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)
				]
				var p0 := grid[i][j]
				var facing := (grid[i][j + 1] - p0).cross(grid[i + 1][j] - p0) * w_side
				if below:
					facing = -facing
				for index in front_order(p0, grid[i + 1][j], grid[i + 1][j + 1], facing):
					var corner := quad[index]
					var p := grid[corner.x][corner.y]
					var along := grid[mini(corner.x + 1, cols)][corner.y] - grid[maxi(corner.x - 1, 0)][corner.y]
					var across := grid[corner.x][mini(corner.y + 1, rows)] - grid[corner.x][maxi(corner.y - 1, 0)]
					var normal := across.cross(along).normalized() * w_side
					if below: normal = -normal
					var t := lerpf(t0, t1, float(corner.x) / cols)
					var color := wing_color(t)
					if below: color = underwing_color(t)
					var a := lerpf(a0, a1, float(corner.x) / cols)
					var uv := Vector2(a / (w_chord * 0.16), float(corner.y) / rows * 2.2)
					vertex(p, normal, uv, color, 0.0, pattern)

func flight_wing(
	s: float, shoulder: Vector3, length: float, chord: float, lift: float, sweep: float
) -> void:
	w_side = s
	w_shoulder = shoulder
	w_len = length
	w_chord = chord
	w_plan = wing_plan()
	w_arm = length * float(w_plan["arm"])
	w_lift = 0.0
	w_sweep = 0.0
	# Wrist pivot sits in the leading third of the chord, where the carpal joint is.
	w_wrist = shoulder + Vector3(s * w_arm, 0.0, wing_le(w_arm) + wing_cd(w_arm) * 0.15)
	w_lift = lift
	w_sweep = sweep
	var hand := w_len - w_arm
	var pointed: bool = w_plan["tip"] == &"pointed"
	var fingers := int(w_plan["fingers"])
	rig_part = 1 if s < 0 else 3
	rig_anchors["left_shoulder" if s < 0 else "right_shoulder"] = wing_hinge(shoulder, 0.0)
	rig_anchors["left_elbow" if s < 0 else "right_elbow"] = wing_hinge(w_wrist, w_arm)
	wing_plate(0.0, w_arm, 0.8, 0.0, 0.5)
	# Secondaries: rounded, overlapping tips form the slightly scalloped trailing edge.
	var spacing := w_arm / 15.0
	for i in 15:
		var a := spacing * (float(i) + 0.6)
		var color := wing_color(0.15 + 0.4 * a / w_arm)
		if species == &"mallard" and i > 4:
			color = Color("3d4c93")  # speculum
		var root := wing_feather(a, wing_cd(a) * 0.38)
		var tip := wing_feather(a, wing_cd(a) * 1.04)
		feather(root, tip, spacing * 0.9, color, wing_up(a), pattern, 0.0, 1.0)
	# Greater and median coverts shingle the arm.
	for i in 13:
		var a := w_arm * (float(i) + 0.5) / 13.0
		var color := wing_color(0.1 + 0.35 * a / w_arm).lightened(0.03)
		var root := wing_feather(a, wing_cd(a) * 0.1)
		var tip := wing_feather(a, wing_cd(a) * 0.56)
		feather(root, tip, w_arm / 13.0 * 0.85, color, wing_up(a), pattern, 0.0, 1.0)
	for i in 9:
		var a := w_arm * (float(i) + 0.5) / 9.0
		var color := wing_color(0.08 + 0.3 * a / w_arm).lightened(0.05)
		var root := wing_feather(a, -wing_cd(a) * 0.02)
		var tip := wing_feather(a, wing_cd(a) * 0.3)
		feather(root, tip, w_arm / 9.0 * 0.8, color, wing_up(a), pattern, 0.0, 1.0)
	rig_part = 2 if s < 0 else 4
	var plate_end := 0.62 if fingers > 0 else 0.8
	wing_plate(w_arm, w_arm + hand * plate_end, 0.8, 0.5, 0.85)
	# Primaries: inner ones continue the trailing edge, outer ones make the tip.
	var plain := 10 - fingers
	for k in plain:
		var reach := plate_end + 0.05 if fingers > 0 else 1.0
		var u := pow(float(k + 1) / float(plain), 0.9) * reach
		var tip_a := w_arm + hand * u
		var tip_c := wing_cd(tip_a) * (1.0 if pointed or u < 0.97 else 0.5)
		var root_a := w_arm + hand * u * 0.3
		var width := w_chord * 0.1 * (1.0 - 0.45 * u)
		var root := wing_feather(root_a, wing_cd(root_a) * 0.35)
		var tip := wing_feather(tip_a, tip_c + w_chord * 0.03)
		var blunt := 0.0 if pointed else 0.7
		feather(root, tip, width, wing_color(0.6 + 0.4 * u), wing_up(tip_a), pattern, 0.0, blunt)
	if fingers > 0:
		# Emarginated "fingers": narrow, separated outer primaries fanning around
		# the hand, the slotted tip of eagles, buzzards, herons and crows.
		var hub_a := w_arm + hand * 0.45
		var hub_c := wing_cd(hub_a) * 0.25
		var reach := hand * 0.58
		for j in fingers:
			var f := float(j) / maxf(float(fingers - 1), 1.0)
			var angle := lerpf(0.05, 0.95, 1.0 - f)
			var tip_a := hub_a + reach * cos(angle) * lerpf(0.85, 1.0, 1.0 - absf(f - 0.65))
			var tip := wing_feather(tip_a, hub_c + reach * sin(angle) * 0.9)
			var color := wing_color(0.9 + 0.1 * f)
			feather(wing_feather(hub_a, hub_c), tip, w_chord * 0.075, color, wing_up(tip_a), pattern, 1.0)
	for i in 7:
		var a := w_arm + hand * (float(i) + 0.5) / 7.0 * plate_end * 0.85
		var color := wing_color(0.45 + 0.3 * float(i) / 6.0).lightened(0.03)
		var root := wing_feather(a, wing_cd(a) * 0.05)
		var tip := wing_feather(a + hand * 0.05, wing_cd(a) * 0.5)
		feather(root, tip, hand / 7.0 * 0.85, color, wing_up(a), pattern, 0.0, 1.0)
	# Alula: the thumb feathers at the leading edge of the wrist.
	for i in 2:
		var a := w_arm + hand * 0.02 * i
		var root := wing_feather(a, wing_cd(a) * 0.02)
		var tip := wing_feather(a + hand * 0.16, -w_chord * 0.02)
		feather(root, tip, w_chord * 0.035, wing_color(0.2), wing_up(a), pattern, 0.3)
	w_lift = 0.0
	w_sweep = 0.0

func underwing_color(t: float) -> Color:
	var top := wing_color(t)
	var dark_under := species in [&"great_cormorant", &"common_blackbird"]
	if group in [&"corvid", &"swallow"] or dark_under:
		return top.lightened(0.04)
	if group in [&"gull", &"tern"]:
		return Color("dcdcd5").lerp(top, smoothstep(0.82, 1.0, t))
	return top.lightened(0.24)

func tail(length: float) -> void:
	var forked := group in [&"swallow", &"tern"]
	var root := center + Vector3(0, 0, radius.z * 0.70)
	for i in 12:
		var t := (float(i) / 11) * 2.0 - 1.0
		var extent := length * (0.48 + 0.52 * pow(absf(t), 2)) if forked else length * (1.0 - absf(t) * 0.12)
		var tip := root + Vector3(t * radius.x * 0.72, -radius.y * 0.08 + length * 0.06 * (1.0 - absf(t)), extent)
		var color := Color("d3d0bf") if species == &"white_tailed_eagle" else wing_color(0.6)
		feather(root + Vector3(t * radius.x * 0.25, 0, 0), tip, radius.x * 0.105, color, Vector3.UP, pattern)

func feet(leg: float, flying: bool) -> void:
	var color := colors[2].darkened(0.30)
	if group in [&"songbird", &"corvid", &"woodpecker"]: color = Color("766758")
	if group == &"raptor": color = Color("b49d54")
	if species == &"great_cormorant": color = Color("363b37")
	if species == &"northern_lapwing": color = Color("80645d")
	var webbed := group in [&"waterfowl", &"gull", &"tern"]
	for sign_value in [-1.0, 1.0]:
		var s := float(sign_value)
		var hip := center + Vector3(s * radius.x * 0.45, -radius.y * 0.55, radius.z * 0.02)
		var ankle := Vector3(hip.x, leg * 0.45, radius.z * 0.15)
		var foot := Vector3(hip.x, leg * 0.05, -radius.z * 0.03)
		if flying:
			ankle = hip + Vector3(0, -radius.y * 0.30, leg * 0.38)
			foot = ankle + Vector3(0, radius.y * 0.06, leg * (0.6 if group == &"wader" else 0.32))
		var r := radius.x * 0.044
		tube(hip, ankle, r * 1.55, r * 1.1, color)
		tube(ankle, foot, r * 1.1, r * 0.8, color)
		oval(ankle, Vector3.ONE * r * 1.5, color, 8, 5, -1, 0.6)
		for i in 4:
			var back := i == 3 or (group == &"woodpecker" and i == 2)
			var spread := (i - 1) * radius.x * 0.23 if i < 3 else radius.x * -0.12
			var tip := foot + Vector3(spread, -leg * 0.03, radius.z * (0.20 if back else -0.33))
			if flying: tip = foot + Vector3(spread * 0.5, -radius.y * 0.08, radius.z * 0.22)
			var knuckle := foot.lerp(tip, 0.55) + Vector3(0, r, 0)
			tube(foot, knuckle, r * 0.8, r * 0.6, color)
			tube(knuckle, tip, r * 0.6, r * 0.25, color)
			var claw := tip + (tip - foot).normalized() * r * 2.8 + Vector3(0, -r, 0)
			tube(tip, claw, r * 0.45, r * 0.02, Color("39322b"))
			if webbed and i < 2:
				var next := foot + Vector3(i * radius.x * 0.23, -leg * 0.03, -radius.z * 0.33)
				for point in [foot, tip, next]: vertex(point, Vector3.UP, Vector2(point.x, point.z), color, 0.6)

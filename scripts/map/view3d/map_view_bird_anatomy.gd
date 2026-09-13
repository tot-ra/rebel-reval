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
var rig_part := 0
var rig_regions := PackedInt32Array()
var rig_anchors: Dictionary = {}

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
	mesh.set_meta(&"bird_catalog_revision", 212)
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
				ring.append(at + Vector3.RIGHT * cos(angle) * size.x + up * sin(angle) * size.y)
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
				var n := right * cos(angle) + up * sin(angle)
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
		oval(base + Vector3(0, -head_size * 0.03, -length * 0.34), Vector3(width, head_size * 0.16, length * 0.66), color, 16, 8, -1, 0.6)
	else:
		var tip := base + Vector3(0, -length * (0.36 if hooked else 0.04), -length)
		curve_tube(base, base + Vector3(0, head_size * 0.20, -length * 0.38), tip + Vector3(0, length * 0.23 if hooked else 0.0, 0), tip, width, head_size * 0.012, color, 6, 8, 0.6)
		var lower := base + Vector3(0, -head_size * 0.16, 0)
		tube(lower, lower + Vector3(0, 0, -length * 0.8), width * 0.62, head_size * 0.015, color.darkened(0.18))
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
		oval(at, Vector3.ONE * r * 0.97, iris, 12, 8, -1, 0.6)
		var outward := Vector3(side * 0.8, 0.08, -0.65).normalized() if group != &"owl" else Vector3.FORWARD
		oval(at + outward * r * 0.45, Vector3.ONE * r * 0.84, Color("0c1012"), 12, 8, -1, 1.0)

func owl_face() -> void:
	for side in [-1.0, 1.0]:
		oval(head + Vector3(side * head_size * 0.36, -head_size * 0.06, -head_size * 0.72), Vector3(head_size * 0.48, head_size * 0.69, head_size * 0.25), Color("aa9679"), 16, 10)

func feather(a: Vector3, b: Vector3, width: float, color: Color, normal: Vector3 = Vector3.UP, marking: float = 0.0) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(normal).normalized()
	if side.length_squared() < 0.1: side = Vector3.RIGHT
	var up := side.cross(axis).normalized()
	var rows: Array[float] = [0.0, 0.18, 0.38, 0.60, 0.80, 0.92, 0.98, 1.0]
	for j in 7:
		for column in 2:
			var points: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			for corner: Vector2 in [Vector2(column, j), Vector2(column + 1, j), Vector2(column + 1, j + 1), Vector2(column, j + 1)]:
				var uv := Vector2(corner.x / 2.0, rows[int(corner.y)])
				var t := uv.y
				var x := uv.x * 2.0 - 1.0
				var breadth := pow(maxf(0.0, sin(PI * (0.19 + t * 0.81))), 0.6)
				var p := a.lerp(b, t) + side * x * width * breadth * (0.83 if x < 0 else 1.0)
				p += up * (sin(t * PI) * width * 0.16 + (1.0 - absf(x)) * width * 0.07)
				points.append(p)
				uvs.append(uv)
			for index in [0, 1, 2, 0, 2, 3]:
				vertex(points[index], up, uvs[index], color, 0.0, marking)

func wing_color(t: float) -> Color:
	var result := colors[1].darkened(0.06 + t * 0.10)
	if species in [&"common_chaffinch", &"great_tit", &"eurasian_magpie", &"great_spotted_woodpecker"]:
		result = Color("373e43")
	if group in [&"gull", &"tern"]:
		result = Color("a2a9ab").lerp(Color("272d32"), smoothstep(0.72, 1.0, t))
	if species == &"mallard": result = Color("675e4b")
	if species == &"northern_lapwing": result = Color("293d36")
	if species == &"grey_heron": result = Color("75828b")
	if species == &"european_robin": result = colors[0].darkened(0.08)
	if species == &"common_nightingale": result = Color("825738")
	return result

func wings(span: float, chord: float, flying: bool, lift: float, sweep: float) -> void:
	for sign_value in [-1.0, 1.0]:
		var s := float(sign_value)
		var shoulder := center + Vector3(s * radius.x * 0.62, radius.y * 0.44, -radius.z * 0.22)
		if flying:
			rig_part = 1 if s < 0 else 3
			var half := span * 0.50
			var wrist := shoulder + Vector3(s * half * 0.54, lift * half * 0.40, -chord * 0.15 + sweep * half * 0.35)
			rig_anchors["left_shoulder" if s < 0 else "right_shoulder"] = shoulder
			rig_anchors["left_elbow" if s < 0 else "right_elbow"] = wrist
			oval(shoulder.lerp(wrist, 0.42) + Vector3(0, 0, chord * 0.12), Vector3(half * 0.32, radius.y * 0.22, chord * 0.28), wing_color(0.2), 12, 6)
			for i in 12:
				var t := float(i) / 11
				var root := shoulder.lerp(wrist, t)
				feather(root, root + Vector3(s * half * 0.04, -half * 0.025, chord * (0.86 - t * 0.1)), half * 0.057, wing_color(t * 0.55), Vector3.UP, pattern)
			rig_part = 2 if s < 0 else 4
			for i in 10:
				var t := float(i) / 9
				var root := wrist + Vector3(s * half * t * 0.14, lift * half * t * 0.08, chord * t * 0.15)
				var length_factor := sin((0.25 + t * 0.67) * PI)
				var tip := wrist + Vector3(s * half * (0.38 + 0.08 * length_factor - t * 0.26), lift * half * 0.27, chord * (0.10 + t * 0.90) + sweep * half * 0.16)
				feather(root, tip, half * (0.046 if group in [&"raptor", &"corvid"] else 0.058), wing_color(0.6 + (1.0 - t) * 0.4), Vector3.UP, pattern)
			for i in 10:
				var t := float(i) / 9
				var root := wrist + Vector3(s * half * (t * 0.26 - 0.025), lift * half * t * 0.16 + radius.y * 0.03, chord * t * 0.20)
				feather(root, root + Vector3(s * half * 0.08, 0, chord * 0.43), half * 0.045, wing_color(0.5 + t * 0.3), Vector3.UP, pattern)

			rig_part = 1 if s < 0 else 3
			for row in 2:
				for i in 14:
					var t := float(i) / 13
					var root := shoulder.lerp(wrist, t) + Vector3(0, radius.y * (0.12 - row * 0.04), chord * row * 0.18)
					feather(root, root + Vector3(s * half * 0.03, 0, chord * 0.36), half * 0.048, wing_color(t * 0.5).lightened(0.03 * row), Vector3.UP, pattern)
		else:
			var wing_center := center + Vector3(s * radius.x * 0.87, radius.y * 0.16, radius.z * 0.08)
			oval(wing_center, Vector3(radius.x * 0.13, radius.y * 0.58, radius.z * 0.76), wing_color(0.25), 12, 8)
			var normal := Vector3(s, 0.3, 0).normalized()
			for i in 10:
				var t := float(i) / 9
				var root := wing_center + Vector3(s * radius.x * (0.14 - absf(t - 0.5) * 0.15), radius.y * (0.42 - t * 0.77), -radius.z * 0.25)
				var tip := center + Vector3(s * radius.x * (0.78 - t * 0.08), radius.y * (-0.05 - t * 0.44), radius.z * (1.35 - t * 0.32))
				feather(root, tip, radius.y * 0.12, wing_color(0.4 + t * 0.6), normal, pattern)
			for row in 2:
				for i in 9:
					var t := float(i) / 8
					var root := wing_center + Vector3(s * radius.x * (0.17 + 0.018 * row - pow((t - 0.5) * 2, 2) * 0.12), radius.y * (0.51 - t * 0.95), radius.z * (-0.70 + row * 0.47))
					var color := wing_color(t * 0.4).lightened(0.025)
					if row == 1 and species in [&"common_chaffinch", &"great_tit", &"great_spotted_woodpecker", &"eurasian_magpie"]: color = Color("c9c9bc")
					feather(root, root + Vector3(0, -radius.y * 0.07, radius.z * 0.67), radius.y * 0.115, color, normal, pattern)

	rig_part = 0

func tail(length: float) -> void:
	var forked := group in [&"swallow", &"tern"]
	var root := center + Vector3(0, 0, radius.z * 0.70)
	for i in 12:
		var t := (float(i) / 11) * 2.0 - 1.0
		var extent := length * (0.48 + 0.52 * pow(absf(t), 2)) if forked else length * (1.0 - absf(t) * 0.12)
		var tip := root + Vector3(t * radius.x * 0.66, -radius.y * 0.20, extent)
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

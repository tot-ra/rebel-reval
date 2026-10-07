class_name CityBuildingBuilder
extends RefCounted

## Builds city buildings from plan footprints (ADR 0031). Footprints are real,
## possibly irregular polygons at any angle. Walls are extruded from the ring,
## the roof is a gable split along the plan's ridge line (gable to the street
## for merchant houses), and gable infill rises to meet the roof exactly.
## Enterable houses get an interior shell inset by the wall thickness, a floor,
## and a door gap; their roofs live in their own node so the runtime can hide
## the roof when Kalev is inside.

const SINK := 0.7
const OVERHANG := 0.38
const ROOF_THICKNESS := 0.16
const DOOR_WIDTH := 1.5
const DOOR_HEIGHT := 2.55
const WINDOW_W := 0.72
const WINDOW_H := 0.95
const WINDOW_SPACING := 3.4
const MAX_ROOF_RISE := 10.5
const CHUNK := 64.0
const STONE_WALL := 0.62
const TIMBER_WALL := 0.32

const WALL_COLORS := {
	&"limestone": Color(0.80, 0.77, 0.70),
	&"plaster": Color(0.88, 0.85, 0.78),
	&"log": Color(0.58, 0.45, 0.33),
	&"plank": Color(0.62, 0.50, 0.37),
}
const ROOF_COLORS := {
	&"thatch": Color(0.52, 0.44, 0.31),
	&"shingle": Color(0.36, 0.31, 0.27),
	&"tile": Color(0.55, 0.27, 0.19),
}

static var _materials: Dictionary = {}


static func wall_material(family: StringName) -> Material:
	var key := "wall:%s" % family
	if not _materials.has(key):
		var mat := (
			(
				MapViewMaterials
				. wall_surface_triplanar(family, WALL_COLORS.get(family, Color.WHITE))
				. duplicate()
			)
			as StandardMaterial3D
		)
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_BACK
		_materials[key] = mat
	return _materials[key]


static func roof_material(family: StringName) -> Material:
	var key := "roof:%s" % family
	if not _materials.has(key):
		var mat := (
			MapViewMaterials.roof_surface(family, ROOF_COLORS.get(family, Color.WHITE)).duplicate()
			as StandardMaterial3D
		)
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[key] = mat
	return _materials[key]


static func interior_material() -> Material:
	if not _materials.has("interior"):
		var mat := (
			MapViewMaterials.wall_surface_triplanar(&"plaster", Color(0.84, 0.80, 0.72)).duplicate()
			as StandardMaterial3D
		)
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_BACK
		_materials["interior"] = mat
	return _materials["interior"]


static func floor_material() -> Material:
	if not _materials.has("floor"):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = (
			load("res://assets/materials/pbr/timber_floor/timber_floor_albedo.png")
			if ResourceLoader.exists(
				"res://assets/materials/pbr/timber_floor/timber_floor_albedo.png"
			)
			else null
		)
		mat.albedo_color = Color(0.78, 0.66, 0.52)
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3(0.35, 0.35, 0.35)
		mat.roughness = 0.85
		mat.vertex_color_use_as_albedo = true
		_materials["floor"] = mat
	return _materials["floor"]


static func opening_material() -> Material:
	if not _materials.has("opening"):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.09, 0.075, 0.06)
		mat.roughness = 0.9
		mat.vertex_color_use_as_albedo = true
		_materials["opening"] = mat
	return _materials["opening"]


static func timber_material() -> Material:
	if not _materials.has("timber"):
		var mat := (
			MapViewMaterials.wall_surface_triplanar(&"plank", Color(0.45, 0.34, 0.24)).duplicate()
			as StandardMaterial3D
		)
		mat.vertex_color_use_as_albedo = true
		_materials["timber"] = mat
	return _materials["timber"]


## One material's triangle soup. Packed arrays live as members and are only
## mutated inside this object's own methods: a packed array read out of a
## Dictionary or another object is a copy, so appending to it would be lost.
class Surf:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()

	func add(
		a: Vector3,
		b: Vector3,
		c: Vector3,
		n: Vector3,
		color: Color,
		uv_a: Vector2,
		uv_b: Vector2,
		uv_c: Vector2
	) -> void:
		verts.append(a)
		verts.append(b)
		verts.append(c)
		normals.append(n)
		normals.append(n)
		normals.append(n)
		colors.append(color)
		colors.append(color)
		colors.append(color)
		uvs.append(uv_a)
		uvs.append(uv_b)
		uvs.append(uv_c)

	func absorb(other: Surf, offset: Vector3) -> void:
		var start := verts.size()
		verts.append_array(other.verts)
		if offset != Vector3.ZERO:
			for i in range(start, verts.size()):
				verts[i] += offset
		normals.append_array(other.normals)
		colors.append_array(other.colors)
		uvs.append_array(other.uvs)


## Geometry for one building or a merged chunk: one Surf per material key.
class Shell:
	var surfaces: Dictionary = {}

	func surface(key: String) -> Surf:
		if not surfaces.has(key):
			surfaces[key] = Surf.new()
		return surfaces[key]

	func tri(
		key: String,
		a: Vector3,
		b: Vector3,
		c: Vector3,
		color: Color,
		uv_a := Vector2.ZERO,
		uv_b := Vector2.ZERO,
		uv_c := Vector2.ZERO
	) -> void:
		var n := (c - a).cross(b - a)
		if n.length_squared() < 1e-10:
			return
		surface(key).add(a, b, c, n.normalized(), color, uv_a, uv_b, uv_c)

	## Triangle wound so its face normal agrees with `out` (robust to input order).
	func tri_out(
		key: String,
		a: Vector3,
		b: Vector3,
		c: Vector3,
		color: Color,
		out: Vector3,
		uv_a := Vector2.ZERO,
		uv_b := Vector2.ZERO,
		uv_c := Vector2.ZERO
	) -> void:
		if (c - a).cross(b - a).dot(out) < 0.0:
			tri(key, a, c, b, color, uv_a, uv_c, uv_b)
		else:
			tri(key, a, b, c, color, uv_a, uv_b, uv_c)

	## Planar quad a-b-c-d (any winding) facing `out`.
	func quad_out(
		key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, out: Vector3
	) -> void:
		tri_out(key, a, b, c, color, out)
		tri_out(key, a, c, d, color, out)

	func quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
		# a-b bottom edge, c-d top edge (c above b, d above a); front faces the viewer
		# when a->b runs left-to-right as seen from outside.
		tri(key, a, d, c, color)
		tri(key, a, c, b, color)

	func merge(other: Shell, offset := Vector3.ZERO) -> void:
		for key: String in other.surfaces:
			surface(key).absorb(other.surfaces[key], offset)

	func triangle_count() -> int:
		var count := 0
		for key: String in surfaces:
			count += (surfaces[key] as Surf).verts.size() / 3
		return count

	func to_mesh(material_for: Callable) -> ArrayMesh:
		var mesh := ArrayMesh.new()
		var keys := surfaces.keys()
		keys.sort()
		for key: String in keys:
			var s: Surf = surfaces[key]
			if s.verts.is_empty():
				continue
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = s.verts
			arrays[Mesh.ARRAY_NORMAL] = s.normals
			arrays[Mesh.ARRAY_COLOR] = s.colors
			arrays[Mesh.ARRAY_TEX_UV] = s.uvs
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(mesh.get_surface_count() - 1, material_for.call(key))
		return mesh


static func material_for_key(key: String) -> Material:
	var parts := key.split(":")
	var family := StringName(parts[1]) if parts.size() > 1 else &""
	match parts[0]:
		"wall":
			return wall_material(family if family != &"" else &"plaster")
		"roof":
			return roof_material(family if family != &"" else &"shingle")
		"tile":
			return roof_material(&"tile")
		"stone":
			return wall_material(&"limestone")
		"dark":
			return opening_material()
		"interior":
			return interior_material()
		"floor":
			return floor_material()
		"opening":
			return opening_material()
		"timber":
			return timber_material()
	return wall_material(&"plaster")


## Roof frame for a footprint: ridge direction r, perpendicular n, ridge offset
## along n, half-width and the eave/ridge heights.
static func roof_frame(
	ring: PackedVector2Array, ridge_angle: float, eave_y: float, pitch_deg: float
) -> Dictionary:
	var r := Vector2(cos(ridge_angle), sin(ridge_angle))
	var n := Vector2(-r.y, r.x)
	var dmin := INF
	var dmax := -INF
	var amin := INF
	var amax := -INF
	for p in ring:
		dmin = minf(dmin, p.dot(n))
		dmax = maxf(dmax, p.dot(n))
		amin = minf(amin, p.dot(r))
		amax = maxf(amax, p.dot(r))
	var half := (dmax - dmin) * 0.5
	var slope := tan(deg_to_rad(pitch_deg))
	var rise := minf(half * slope, MAX_ROOF_RISE)
	slope = rise / maxf(half, 0.01)
	return {
		"r": r,
		"n": n,
		"mid": (dmin + dmax) * 0.5,
		"half": half,
		"slope": slope,
		"eave": eave_y,
		"ridge": eave_y + rise,
		"amin": amin,
		"amax": amax,
	}


static func roof_height(frame: Dictionary, p: Vector2) -> float:
	var d := absf(p.dot(frame["n"]) - float(frame["mid"]))
	return float(frame["eave"]) + (float(frame["half"]) - d) * float(frame["slope"])


static func signed_area(ring: PackedVector2Array) -> float:
	var a := 0.0
	for i in ring.size():
		var p := ring[i]
		var q := ring[(i + 1) % ring.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


## Ring in a consistent orientation: negative signed area (x east, z south),
## which makes each edge a->b run left-to-right seen from outside, so the
## Shell.quad winding faces outward.
static func normalized_ring(ring: PackedVector2Array) -> PackedVector2Array:
	if signed_area(ring) > 0.0:
		var out := ring.duplicate()
		out.reverse()
		return out
	return ring


static func build_building(
	b: Dictionary, ring_in: PackedVector2Array, floor_y: float, enterable: bool
) -> Dictionary:
	var ring := normalized_ring(ring_in)
	var shell := Shell.new()
	var roof := Shell.new()
	var family := StringName(b["material"])
	var roof_family := StringName(b["roof"])
	var wall_key := "wall:%s" % family
	var roof_key := "roof:%s" % roof_family
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(b["id"])
	var tint := Color(1, 1, 1) * rng.randf_range(0.86, 1.08)
	tint.a = 1.0
	var roof_tint := Color(1, 1, 1) * rng.randf_range(0.82, 1.1)
	roof_tint.a = 1.0
	var bottom := float(b["base_h"]) - SINK
	var eave := floor_y + float(b["wall_h"])
	var frame := roof_frame(ring, float(b["ridge_angle"]), eave, float(b["roof_pitch_deg"]))
	var thick := STONE_WALL if family == &"limestone" else TIMBER_WALL
	var door: Variant = b.get("door")
	var door_edge := -1
	var door_t := 0.5
	if door != null:
		door_edge = _closest_edge(ring, Vector2(door[0], door[1]))
		var a := ring[door_edge]
		var c := ring[(door_edge + 1) % ring.size()]
		door_t = clampf(
			(Vector2(door[0], door[1]) - a).dot(c - a) / maxf((c - a).length_squared(), 0.001),
			0.2,
			0.8
		)
	# Exterior walls with gable infill, windows and the door opening.
	for i in ring.size():
		var a := ring[i]
		var c := ring[(i + 1) % ring.size()]
		var gap := Vector2(-1, -1)
		if i == door_edge:
			var length := a.distance_to(c)
			var half_gap := minf(DOOR_WIDTH * 0.5, length * 0.35) / maxf(length, 0.01)
			gap = Vector2(door_t - half_gap, door_t + half_gap)
		_wall_edge(shell, wall_key, a, c, bottom, frame, tint, gap, floor_y, enterable)
		if String(b.get("landmark_id", "")) == "":
			_windows(shell, a, c, floor_y, eave, gap, rng, family)
		else:
			_lancets(shell, a, c, floor_y, eave)
	# Roof halves.
	_roof(roof, roof_key, ring, frame, roof_tint)
	if enterable:
		_interior(shell, ring, thick, floor_y, eave, frame, door_edge, door_t)
	else:
		# Flat cap under the roof so a raised camera never sees into a hollow house.
		var inner := ring
		_cap(shell, wall_key, inner, eave - 0.02, tint)
	return {"shell": shell, "roof": roof, "frame": frame}


static func _closest_edge(ring: PackedVector2Array, p: Vector2) -> int:
	var best := 0
	var best_d := INF
	for i in ring.size():
		var q := Geometry2D.get_closest_point_to_segment(p, ring[i], ring[(i + 1) % ring.size()])
		var d := q.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


## One footprint edge from `bottom` up to the roof underside, split for a door
## gap (gap.x..gap.y as fractions along the edge, or negative for none).
static func _wall_edge(
	shell: Shell,
	key: String,
	a: Vector2,
	c: Vector2,
	bottom: float,
	frame: Dictionary,
	tint: Color,
	gap: Vector2,
	floor_y: float,
	enterable: bool
) -> void:
	var pts: Array[Vector2] = [a]
	# Ridge crossing makes the gable peak.
	var n: Vector2 = frame["n"]
	var mid: float = frame["mid"]
	var da := a.dot(n) - mid
	var dc := c.dot(n) - mid
	if da * dc < 0.0:
		var t := da / (da - dc)
		pts.append(a.lerp(c, t))
	pts.append(c)
	if gap.x >= 0.0:
		var g0 := a.lerp(c, gap.x)
		var g1 := a.lerp(c, gap.y)
		var top_y := floor_y + DOOR_HEIGHT
		_wall_strip(shell, key, a, g0, bottom, frame, tint, pts)
		_wall_strip(shell, key, g1, c, bottom, frame, tint, pts)
		# Lintel band over the door up to the roof line.
		_wall_strip_from(shell, key, g0, g1, top_y, frame, tint)
		if not enterable:
			# Threshold below a raised floor.
			shell.quad(
				key,
				Vector3(g0.x, bottom, g0.y),
				Vector3(g1.x, bottom, g1.y),
				Vector3(g1.x, floor_y, g1.y),
				Vector3(g0.x, floor_y, g0.y),
				tint
			)
		else:
			shell.quad(
				key,
				Vector3(g0.x, bottom, g0.y),
				Vector3(g1.x, bottom, g1.y),
				Vector3(g1.x, floor_y - 0.02, g1.y),
				Vector3(g0.x, floor_y - 0.02, g0.y),
				tint
			)
	else:
		_wall_strip(shell, key, a, c, bottom, frame, tint, pts)


static func _wall_strip(
	shell: Shell,
	key: String,
	p0: Vector2,
	p1: Vector2,
	bottom: float,
	frame: Dictionary,
	tint: Color,
	profile: Array[Vector2]
) -> void:
	# Insert any profile break (ridge crossing) lying between p0 and p1.
	var cuts: Array[Vector2] = [p0]
	var dir := p1 - p0
	var len2 := dir.length_squared()
	for q in profile:
		var t := (q - p0).dot(dir) / maxf(len2, 1e-6)
		if t > 0.001 and t < 0.999 and absf((q - p0).cross(dir)) < 0.01 * sqrt(len2):
			cuts.append(q)
	cuts.append(p1)
	for i in cuts.size() - 1:
		var u := cuts[i]
		var v := cuts[i + 1]
		var hu := roof_height(frame, u) - 0.03
		var hv := roof_height(frame, v) - 0.03
		shell.quad(
			key,
			Vector3(u.x, bottom, u.y),
			Vector3(v.x, bottom, v.y),
			Vector3(v.x, hv, v.y),
			Vector3(u.x, hu, u.y),
			tint
		)


static func _wall_strip_from(
	shell: Shell,
	key: String,
	p0: Vector2,
	p1: Vector2,
	from_y: float,
	frame: Dictionary,
	tint: Color
) -> void:
	var h0 := roof_height(frame, p0) - 0.03
	var h1 := roof_height(frame, p1) - 0.03
	if h0 <= from_y and h1 <= from_y:
		return
	shell.quad(
		key,
		Vector3(p0.x, from_y, p0.y),
		Vector3(p1.x, from_y, p1.y),
		Vector3(p1.x, maxf(h1, from_y), p1.y),
		Vector3(p0.x, maxf(h0, from_y), p0.y),
		tint
	)


static func _windows(
	shell: Shell,
	a: Vector2,
	c: Vector2,
	floor_y: float,
	eave: float,
	gap: Vector2,
	rng: RandomNumberGenerator,
	family: StringName
) -> void:
	var length := a.distance_to(c)
	if length < 2.6:
		return
	var dir := (c - a) / length
	var out := Vector2(-dir.y, dir.x) * 0.03
	var storeys := maxi(1, int((eave - floor_y) / 3.1))
	var count := int(length / WINDOW_SPACING)
	if count < 1:
		return
	var w := WINDOW_W * (0.75 if family == &"log" else 1.0)
	for s in storeys:
		var y0 := floor_y + 1.05 + float(s) * 3.0
		if y0 + WINDOW_H > eave - 0.35:
			break
		for k in count:
			var t := (float(k) + 0.5) / float(count)
			if gap.x >= 0.0 and s == 0 and t > gap.x - 0.12 and t < gap.y + 0.12:
				continue
			if rng.randf() < 0.18:
				continue
			var m := a + dir * (t * length)
			var p0 := m - dir * w * 0.5 + out
			var p1 := m + dir * w * 0.5 + out
			shell.quad(
				"opening",
				Vector3(p0.x, y0, p0.y),
				Vector3(p1.x, y0, p1.y),
				Vector3(p1.x, y0 + WINDOW_H, p1.y),
				Vector3(p0.x, y0 + WINDOW_H, p0.y),
				Color(1, 1, 1)
			)


## Tall pointed windows for churches and halls, spaced along the long walls.
static func _lancets(shell: Shell, a: Vector2, c: Vector2, floor_y: float, eave: float) -> void:
	var length := a.distance_to(c)
	if length < 6.0:
		return
	var dir := (c - a) / length
	var out := Vector2(-dir.y, dir.x) * 0.03
	var count := int(length / 6.0)
	var h := minf((eave - floor_y) * 0.55, 7.0)
	var y0 := floor_y + (eave - floor_y) * 0.25
	for k in count:
		var m := a + dir * ((float(k) + 0.5) / float(count) * length)
		var p0 := m - dir * 0.75 + out
		var p1 := m + dir * 0.75 + out
		shell.quad(
			"opening",
			Vector3(p0.x, y0, p0.y),
			Vector3(p1.x, y0, p1.y),
			Vector3(p1.x, y0 + h, p1.y),
			Vector3(p0.x, y0 + h, p0.y),
			Color(1, 1, 1)
		)
		var tip := Vector3(m.x + out.x, y0 + h + 1.1, m.y + out.y)
		shell.tri(
			"opening", Vector3(p0.x, y0 + h, p0.y), tip, Vector3(p1.x, y0 + h, p1.y), Color(1, 1, 1)
		)


static func _roof(
	roof: Shell, key: String, ring: PackedVector2Array, frame: Dictionary, tint: Color
) -> void:
	var grown := Geometry2D.offset_polygon(ring, OVERHANG, Geometry2D.JOIN_MITER)
	if grown.is_empty():
		return
	var outline: PackedVector2Array = grown[0]
	var r: Vector2 = frame["r"]
	var n: Vector2 = frame["n"]
	var mid: float = frame["mid"]
	var big := 400.0
	var center_along := (float(frame["amin"]) + float(frame["amax"])) * 0.5
	var origin := r * center_along + n * mid
	for side: float in [-1.0, 1.0]:
		var half_plane := PackedVector2Array(
			[
				origin - r * big,
				origin + r * big,
				origin + r * big + n * side * big,
				origin - r * big + n * side * big,
			]
		)
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(outline, half_plane):
			var tris := Geometry2D.triangulate_polygon(piece)
			for i in range(0, tris.size(), 3):
				var p := [piece[tris[i]], piece[tris[i + 1]], piece[tris[i + 2]]]
				var v: Array[Vector3] = []
				var uv: Array[Vector2] = []
				for q: Vector2 in p:
					var h := roof_height(frame, q)
					v.append(Vector3(q.x, h, q.y))
					uv.append(
						Vector2(
							q.dot(r),
							absf(q.dot(n) - mid) * sqrt(1.0 + pow(float(frame["slope"]), 2.0))
						)
					)
				# Upward-facing winding.
				var nrm := (v[2] - v[0]).cross(v[1] - v[0])
				if nrm.y < 0.0:
					roof.tri(key, v[0], v[2], v[1], tint, uv[0], uv[2], uv[1])
				else:
					roof.tri(key, v[0], v[1], v[2], tint, uv[0], uv[1], uv[2])
	# Barge boards: thin fascia under the roof edge so the cover has thickness.
	for i in outline.size():
		var p0 := outline[i]
		var p1 := outline[(i + 1) % outline.size()]
		var h0 := roof_height(frame, p0)
		var h1 := roof_height(frame, p1)
		roof.quad(
			key,
			Vector3(p0.x, h0 - ROOF_THICKNESS, p0.y),
			Vector3(p1.x, h1 - ROOF_THICKNESS, p1.y),
			Vector3(p1.x, h1, p1.y),
			Vector3(p0.x, h0, p0.y),
			tint
		)


static func _cap(
	shell: Shell, key: String, ring: PackedVector2Array, y: float, tint: Color
) -> void:
	var tris := Geometry2D.triangulate_polygon(ring)
	for i in range(0, tris.size(), 3):
		var a := ring[tris[i]]
		var b := ring[tris[i + 1]]
		var c := ring[tris[i + 2]]
		var va := Vector3(a.x, y, a.y)
		var vb := Vector3(b.x, y, b.y)
		var vc := Vector3(c.x, y, c.y)
		if (vc - va).cross(vb - va).y > 0.0:
			shell.tri(key, va, vb, vc, tint)
		else:
			shell.tri(key, va, vc, vb, tint)


static func _floor(shell: Shell, ring: PackedVector2Array, y: float) -> void:
	var tris := Geometry2D.triangulate_polygon(ring)
	for i in range(0, tris.size(), 3):
		var a := ring[tris[i]]
		var b := ring[tris[i + 1]]
		var c := ring[tris[i + 2]]
		var va := Vector3(a.x, y, a.y)
		var vb := Vector3(b.x, y, b.y)
		var vc := Vector3(c.x, y, c.y)
		if (vc - va).cross(vb - va).y > 0.0:
			shell.tri("floor", va, vb, vc, Color(1, 1, 1))
		else:
			shell.tri("floor", va, vc, vb, Color(1, 1, 1))


## Inner faces, floor, ceiling and door reveal. Inner dimensions equal the outer
## footprint minus the wall thickness, so the inside matches the outside.
static func _interior(
	shell: Shell,
	ring: PackedVector2Array,
	thick: float,
	floor_y: float,
	eave: float,
	_frame: Dictionary,
	door_edge: int,
	door_t: float
) -> void:
	var inset := Geometry2D.offset_polygon(ring, -thick, Geometry2D.JOIN_MITER)
	if inset.is_empty():
		return
	var inner: PackedVector2Array = normalized_ring(inset[0])
	_floor(shell, inner, floor_y)
	var ceiling := eave - 0.05
	var col := Color(1, 1, 1)
	# Door position projected onto the inner ring.
	var door_inner_edge := -1
	var door_point := Vector2.ZERO
	if door_edge >= 0:
		var a := ring[door_edge]
		var c := ring[(door_edge + 1) % ring.size()]
		door_point = a.lerp(c, door_t)
		door_inner_edge = _closest_edge(inner, door_point)
	for i in inner.size():
		var a := inner[i]
		var c := inner[(i + 1) % inner.size()]
		if i == door_inner_edge:
			var length := a.distance_to(c)
			var t := clampf(
				(door_point - a).dot(c - a) / maxf((c - a).length_squared(), 0.001), 0.15, 0.85
			)
			var hg := minf(DOOR_WIDTH * 0.5, length * 0.35) / maxf(length, 0.01)
			var g0 := a.lerp(c, t - hg)
			var g1 := a.lerp(c, t + hg)
			# Inner faces look inward: reverse the outward winding.
			shell.quad(
				"interior",
				Vector3(g0.x, floor_y, g0.y),
				Vector3(a.x, floor_y, a.y),
				Vector3(a.x, ceiling, a.y),
				Vector3(g0.x, ceiling, g0.y),
				col
			)
			shell.quad(
				"interior",
				Vector3(c.x, floor_y, c.y),
				Vector3(g1.x, floor_y, g1.y),
				Vector3(g1.x, ceiling, g1.y),
				Vector3(c.x, ceiling, c.y),
				col
			)
			shell.quad(
				"interior",
				Vector3(g1.x, floor_y + DOOR_HEIGHT, g1.y),
				Vector3(g0.x, floor_y + DOOR_HEIGHT, g0.y),
				Vector3(g0.x, ceiling, g0.y),
				Vector3(g1.x, ceiling, g1.y),
				col
			)
			# Door reveal through the wall thickness.
			var oa := ring[door_edge]
			var oc := ring[(door_edge + 1) % ring.size()]
			var olen := oa.distance_to(oc)
			var ohg := minf(DOOR_WIDTH * 0.5, olen * 0.35) / maxf(olen, 0.01)
			var o0 := oa.lerp(oc, door_t - ohg)
			var o1 := oa.lerp(oc, door_t + ohg)
			shell.quad(
				"timber",
				Vector3(g0.x, floor_y, g0.y),
				Vector3(o0.x, floor_y, o0.y),
				Vector3(o0.x, floor_y + DOOR_HEIGHT, o0.y),
				Vector3(g0.x, floor_y + DOOR_HEIGHT, g0.y),
				Color(0.8, 0.7, 0.6)
			)
			shell.quad(
				"timber",
				Vector3(o1.x, floor_y, o1.y),
				Vector3(g1.x, floor_y, g1.y),
				Vector3(g1.x, floor_y + DOOR_HEIGHT, g1.y),
				Vector3(o1.x, floor_y + DOOR_HEIGHT, o1.y),
				Color(0.8, 0.7, 0.6)
			)
			shell.quad(
				"timber",
				Vector3(o0.x, floor_y + DOOR_HEIGHT, o0.y),
				Vector3(o1.x, floor_y + DOOR_HEIGHT, o1.y),
				Vector3(g1.x, floor_y + DOOR_HEIGHT, g1.y),
				Vector3(g0.x, floor_y + DOOR_HEIGHT, g0.y),
				Color(0.8, 0.7, 0.6)
			)
			# Threshold step.
			shell.quad(
				"timber",
				Vector3(o1.x, floor_y, o1.y),
				Vector3(o0.x, floor_y, o0.y),
				Vector3(g0.x, floor_y, g0.y),
				Vector3(g1.x, floor_y, g1.y),
				Color(0.8, 0.7, 0.6)
			)
		else:
			shell.quad(
				"interior",
				Vector3(c.x, floor_y, c.y),
				Vector3(a.x, floor_y, a.y),
				Vector3(a.x, ceiling, a.y),
				Vector3(c.x, ceiling, c.y),
				col
			)
	# Ceiling (seen from below): plank boards under the roof.
	var tris := Geometry2D.triangulate_polygon(inner)
	for i in range(0, tris.size(), 3):
		var a := inner[tris[i]]
		var b := inner[tris[i + 1]]
		var c := inner[tris[i + 2]]
		var va := Vector3(a.x, ceiling, a.y)
		var vb := Vector3(b.x, ceiling, b.y)
		var vc := Vector3(c.x, ceiling, c.y)
		if (vc - va).cross(vb - va).y < 0.0:
			shell.tri("timber", va, vb, vc, Color(0.75, 0.65, 0.55))
		else:
			shell.tri("timber", va, vc, vb, Color(0.75, 0.65, 0.55))

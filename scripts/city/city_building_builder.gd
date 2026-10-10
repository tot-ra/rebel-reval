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
## Roof cover thickness by family: a thatch coat is ~0.35 m and ends in a
## rounded roll at eaves and verges; tile and shingle are thin.
const ROOF_COVER := {&"thatch": 0.36, &"shingle": 0.11, &"tile": 0.13}
## Ridge capping radius: half-round ridge tiles, a ridge board roll, or the
## bulky bound ridge of a thatch.
const RIDGE_RADIUS := {&"thatch": 0.32, &"shingle": 0.1, &"tile": 0.13}
## Wall corners are filleted, never knife-sharp: lime render rounds a corner,
## timber corners are eased and worn, dressed limestone quoins only slightly.
const CORNER_RADIUS := {&"limestone": 0.1, &"plaster": 0.22, &"log": 0.16, &"plank": 0.14}
const CORNER_SEGMENTS := 3
const DOOR_WIDTH := 1.5
const DOOR_HEIGHT := 2.55
## Farmstead outbuildings (width, height in metres). A 1343 byre, sty or store
## had a low, narrow opening of plain boards sized for a person stooping or a
## beast led through, never a house-sized portal. Types not listed (houses,
## barn_dwelling) keep DOOR_WIDTH x DOOR_HEIGHT.
const OUTBUILDING_DOORS := {
	&"pigsty": Vector2(0.62, 0.9),
	&"sheep_shed": Vector2(0.9, 1.35),
	&"byre": Vector2(1.0, 1.65),
	&"store": Vector2(0.85, 1.65),
	&"salt_shed": Vector2(0.85, 1.6),
	&"smoke_shed": Vector2(0.75, 1.5),
	&"cargo_shed": Vector2(1.5, 1.9),
	# Walk-in farmstead buildings of the regional sites (Harju, R-1627): low
	# doors, but wide enough for Kalev's 1 m collision capsule to pass.
	&"smoke_room": Vector2(1.3, 1.8),
	&"granary": Vector2(1.2, 1.75),
	&"cattle_shed": Vector2(1.4, 1.75),
	&"sauna": Vector2(1.2, 1.65),
}
const WINDOW_W := 0.72
const WINDOW_H := 0.95
const WINDOW_SPACING := 3.4
const MAX_ROOF_RISE := 10.5
## Share of town houses with a chimney stack, and its plan size in metres.
const CHIMNEY_SHARE := 0.8
## Interior cutaway: walls of an enterable building are cut this far above
## the floor while Kalev is inside (about head height), so the top-down and
## first-person cameras see the room instead of tall walls and gables.
const CUT_HEIGHT := 2.2
## Inside a farmstead building: smoke-blackened logs and grey limestone slabs.
const RURAL_SMOKED := Color(0.42, 0.36, 0.31)
const RURAL_FLOOR := Color(0.58, 0.56, 0.52)
const CHIMNEY_SIZE := 0.75
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

const WindowOpenings := preload("res://scripts/city/city_window_openings.gd")
const WINDOW_WOOD := preload("res://scripts/city/city_window_wood.gdshader")
const WINDOW_GLASS := preload("res://scripts/city/city_window_glass.gdshader")

const WALL_SHADER := preload("res://scripts/city/city_weathered_wall.gdshader")
const ROOF_SHADER := preload("res://scripts/city/city_weathered_roof.gdshader")
const TILE_ROOF_SHADER := preload("res://scripts/city/city_tile_roof.gdshader")
const LIMEWASH_SHADER := preload("res://scripts/city/city_limewash.gdshader")
## The district material plates are sized for 0.87 m units; the city uses 1 m.
const UV_RESCALE := 1.0 / 0.87

static var _materials: Dictionary = {}
static var _ground_texture: Texture2D
static var _ground_rect := Vector4(0, 0, 1, 1)


## Binds the city heightfield so weathering knows each wall's height above
## the street. Call once before building (CityWorld3D does).
static func bind_ground(plan: CityPlan) -> void:
	_ground_texture = plan.height_texture()
	_ground_rect = plan.height_texture_rect()
	_materials.clear()


## Weathered wall material from a library plate (texture, normal, density).
static func weathered_wall(source: StandardMaterial3D, tint: Color, age := 1.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = WALL_SHADER
	_copy_plate(mat, source, tint, age)
	return mat


static func weathered_roof(source: StandardMaterial3D, tint: Color, moss: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = ROOF_SHADER
	_copy_plate(mat, source, tint, 1.0)
	mat.set_shader_parameter("moss", moss)
	return mat


static func _copy_plate(
	mat: ShaderMaterial, source: StandardMaterial3D, tint: Color, age: float
) -> void:
	mat.set_shader_parameter("albedo_tex", source.albedo_texture)
	mat.set_shader_parameter("normal_tex", source.normal_texture)
	mat.set_shader_parameter(
		"base_tint",
		(
			Vector3(tint.r, tint.g, tint.b)
			* Vector3(source.albedo_color.r, source.albedo_color.g, source.albedo_color.b)
		)
	)
	mat.set_shader_parameter("uv_scale", source.uv1_scale * UV_RESCALE)
	mat.set_shader_parameter("roughness_base", source.roughness)
	mat.set_shader_parameter("ground_height", _ground_texture)
	mat.set_shader_parameter("ground_rect", _ground_rect)
	mat.set_shader_parameter("age", age)


static func set_wetness(value: float) -> void:
	for mat: Variant in _materials.values():
		if mat is ShaderMaterial:
			(mat as ShaderMaterial).set_shader_parameter("wetness", value)


static func wall_material(family: StringName) -> Material:
	var key := "wall:%s" % family
	if not _materials.has(key):
		var plate := MapViewMaterials.wall_surface_triplanar(family, Color.WHITE)
		_materials[key] = weathered_wall(plate, WALL_COLORS.get(family, Color.WHITE))
	return _materials[key]


static func roof_material(family: StringName) -> Material:
	var key := "roof:%s" % family
	if family == &"tile" and not _materials.has(key):
		# Procedural monk-and-nun tiles from the roof UVs (metres).
		var tiles := ShaderMaterial.new()
		tiles.shader = TILE_ROOF_SHADER
		tiles.set_shader_parameter("ground_height", _ground_texture)
		tiles.set_shader_parameter("ground_rect", _ground_rect)
		tiles.set_shader_parameter("moss", 0.3)
		_materials[key] = tiles
	if not _materials.has(key):
		var plate := MapViewMaterials.roof_surface(family, Color.WHITE)
		var moss := {&"shingle": 0.5, &"tile": 0.3, &"thatch": 0.2}.get(family, 0.5) as float
		_materials[key] = weathered_roof(plate, ROOF_COLORS.get(family, Color.WHITE), moss)
	return _materials[key]


static func interior_material() -> Material:
	if not _materials.has("interior"):
		# Lime wash, darkened for indoors (see city_limewash.gdshader); the
		# grime band is measured from each wall's own ground, so it is off here.
		var mat := ShaderMaterial.new()
		mat.shader = LIMEWASH_SHADER
		mat.set_shader_parameter("floor_y", -1000.0)
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
		# Boards about 0.2 m wide; darker than outdoors (no ambient occlusion
		# in the Compatibility renderer, so indoor surfaces are toned down).
		mat.albedo_color = Color(0.56, 0.47, 0.37)
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3(0.95, 0.95, 0.95)
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


## Window-only wood shader: worn pigment, exposed grain and rain streaks.
static func paint_material() -> Material:
	if not _materials.has("paint"):
		var mat := ShaderMaterial.new()
		mat.shader = WINDOW_WOOD
		_materials["paint"] = mat
	return _materials["paint"]


static func glass_material(profile: StringName) -> Material:
	var key := "glass:%s" % profile
	if not _materials.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = WINDOW_GLASS
		var opacity := 0.28
		var tint := Vector3(0.57, 0.67, 0.56)
		if profile == &"horn":
			opacity = 0.86
			tint = Vector3(0.55, 0.43, 0.26)
		elif profile == &"forest":
			opacity = 0.56
		mat.set_shader_parameter("opacity", opacity)
		mat.set_shader_parameter("glass_tint", tint)
		_materials[key] = mat
	return _materials[key]


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

	## Splits the shell at height `y`: [below, above]. Triangles crossing the
	## plane are clipped, so walls cut cleanly for the interior cutaway.
	func split_at(y: float) -> Array[Shell]:
		var below := Shell.new()
		var above := Shell.new()
		for key: String in surfaces:
			var src: Surf = surfaces[key]
			var lo := below.surface(key)
			var hi := above.surface(key)
			for t in range(0, src.verts.size(), 3):
				var v := [src.verts[t], src.verts[t + 1], src.verts[t + 2]]
				var uv := [src.uvs[t], src.uvs[t + 1], src.uvs[t + 2]]
				var c: Color = src.colors[t]
				var n: Vector3 = src.normals[t]
				var count := 0
				for k in 3:
					if (v[k] as Vector3).y <= y:
						count += 1
				if count == 3:
					lo.add(v[0], v[1], v[2], n, c, uv[0], uv[1], uv[2])
				elif count == 0:
					hi.add(v[0], v[1], v[2], n, c, uv[0], uv[1], uv[2])
				else:
					_clip_into(lo, v, uv, n, c, y, true)
					_clip_into(hi, v, uv, n, c, y, false)
		return [below, above]

	## Keeps the part of triangle v on one side of the plane (fan-triangulated).
	static func _clip_into(
		out: Surf, v: Array, uv: Array, n: Vector3, c: Color, y: float, keep_below: bool
	) -> void:
		var poly: Array[Vector3] = []
		var puv: Array[Vector2] = []
		for k in 3:
			var a: Vector3 = v[k]
			var b: Vector3 = v[(k + 1) % 3]
			var a_in := a.y <= y if keep_below else a.y > y
			var b_in := b.y <= y if keep_below else b.y > y
			if a_in:
				poly.append(a)
				puv.append(uv[k])
			if a_in != b_in:
				var t := (y - a.y) / (b.y - a.y)
				poly.append(a.lerp(b, t))
				puv.append((uv[k] as Vector2).lerp(uv[(k + 1) % 3], t))
		for k in range(1, poly.size() - 1):
			out.add(poly[0], poly[k], poly[k + 1], n, c, puv[0], puv[k], puv[k + 1])

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
		"paint":
			return paint_material()
		"glass":
			return glass_material(family)
		"iron":
			if not _materials.has("iron"):
				var iron := StandardMaterial3D.new()
				iron.albedo_color = Color(0.12, 0.115, 0.10)
				iron.metallic = 0.65
				iron.roughness = 0.8
				_materials["iron"] = iron
			return _materials["iron"]
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


## The wall outline actually built for a building: the normalized footprint
## with filleted corners. Doors, collision and interiors use the same ring so
## the door gap lines up everywhere.
static func wall_ring(b: Dictionary, ring_in: PackedVector2Array) -> PackedVector2Array:
	var ring := normalized_ring(ring_in)
	return soften_ring(ring, float(CORNER_RADIUS.get(StringName(b.get("material", "")), 0.15)))


## Replaces each corner with a short quadratic-Bezier fillet of `radius`
## (clamped to 30 % of the adjoining edges); nearly straight vertices stay.
static func soften_ring(ring: PackedVector2Array, radius: float) -> PackedVector2Array:
	if ring.size() < 3 or radius <= 0.0:
		return ring
	var out := PackedVector2Array()
	for i in ring.size():
		var p := ring[i]
		var a := ring[(i - 1 + ring.size()) % ring.size()]
		var c := ring[(i + 1) % ring.size()]
		var d1 := a - p
		var d2 := c - p
		var l1 := d1.length()
		var l2 := d2.length()
		if l1 < 0.01 or l2 < 0.01:
			continue
		d1 /= l1
		d2 /= l2
		# Nearly straight (> ~165 deg): keep the vertex as it is.
		if d1.dot(d2) < -0.966:
			out.append(p)
			continue
		var r := minf(radius, minf(l1, l2) * 0.3)
		var t1 := p + d1 * r
		var t2 := p + d2 * r
		for k in CORNER_SEGMENTS + 1:
			var s := float(k) / CORNER_SEGMENTS
			out.append(t1.lerp(p, s).lerp(p.lerp(t2, s), s))
	return out


static func build_building(
	b: Dictionary,
	ring_in: PackedVector2Array,
	floor_y: float,
	enterable: bool,
	ground_at: Callable = Callable(),
	keep_out: Array[PackedVector2Array] = []
) -> Dictionary:
	var ring := wall_ring(b, ring_in)
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
	# Window character is chosen once per building from its own RNG so every
	# wall of one house shares a palette and trim style, without shifting the
	# draws that drive roof tint, chimney and window dropout above/below.
	var look_rng := RandomNumberGenerator.new()
	look_rng.seed = hash(b["id"]) + 7919
	var look := CityWindows.look(look_rng, family)
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
	var windows: Array[Dictionary] = []
	# Exterior walls with gable infill, windows and the door opening.
	for i in ring.size():
		var a := ring[i]
		var c := ring[(i + 1) % ring.size()]
		var gap := Vector2(-1, -1)
		if i == door_edge:
			var length := a.distance_to(c)
			var half_gap := minf(door_size(b).x * 0.5, length * 0.35) / maxf(length, 0.01)
			gap = Vector2(door_t - half_gap, door_t + half_gap)
		_wall_edge(shell, wall_key, a, c, bottom, frame, tint, gap, floor_y, enterable, door_size(b).y)
		# Site models (ADR 0032) bring their own openings.
		if not bool(b.get("openings", true)):
			continue
		if not String(b.get("kind", "house")) in ["church", "chapel", "hall"]:
			windows.append_array(CityWindows.placements(a, c, floor_y, eave, gap, rng, look))
		else:
			_lancets(shell, a, c, floor_y, eave)
	if door_edge >= 0 and ground_at.is_valid():
		_door_steps(shell, ring, door_edge, door_t, floor_y, ground_at, door_size(b).x)
	# Roof halves.
	_roof(roof, roof_key, ring, frame, roof_tint, roof_family, keep_out)
	# Most town houses have a stone flue by 1343 (thatched country cottages keep
	# a smoke hole); it rides with the roof node when the roof lifts.
	var chimney := Vector3.INF
	if String(b.get("kind", "house")) == "house" and roof_family != &"thatch":
		if rng.randf() < CHIMNEY_SHARE:
			chimney = _chimney(roof, ring, frame, rng)
	if enterable:
		# The ceiling belongs with the roof: both lift while Kalev is inside, so
		# top-down and first-person views look into the room, not at boards.
		# Farmstead buildings (only enterable at regional sites): log walls
		# blackened by the smoke room and a limestone-slab floor, not a town
		# house's limewash and boards; door reveal sized to the low door (R-1627).
		var rural := String(b.get("kind", "")) == "outbuilding"
		_interior(
			shell, ring, thick, floor_y, eave, frame, door_edge, door_t, roof, door_size(b), rural
		)
		WindowOpenings.cut(shell, windows, thick)
		for window in windows:
			CityWindows.add_placed(shell, window)
			CityWindows.add_interior(shell, window, thick)
		# Cutaway: everything above head height goes with the roof node, and
		# the cut wall tops get a stone section cap, so the room reads from above.
		var parts := shell.split_at(floor_y + CUT_HEIGHT)
		shell = parts[0]
		roof.merge(parts[1])
		# A door lower than the cut leaves the cap whole over its lintel.
		var cap_gap := door_size(b).x if door_size(b).y > CUT_HEIGHT else 0.0
		wall_top_cap(shell, ring, thick, floor_y + CUT_HEIGHT, door_edge, door_t, cap_gap)
	else:
		WindowOpenings.cut(shell, windows, thick)
		for window in windows:
			CityWindows.add_placed(shell, window)
		# Flat cap under the roof so a raised camera never sees into a hollow house.
		var inner := ring
		_cap(shell, wall_key, inner, eave - 0.02, tint)
	return {"shell": shell, "roof": roof, "frame": frame, "chimney": chimney}


## Section cap on walls cut at `y` for the interior cutaway: one quad per
## ring edge from the outer face `thick` inward, leaving the door gap open.
static func wall_top_cap(
	shell: Shell,
	ring: PackedVector2Array,
	thick: float,
	y: float,
	door_edge: int,
	door_t: float,
	door_width: float = DOOR_WIDTH
) -> void:
	var center := Vector2.ZERO
	for p in ring:
		center += p
	center /= ring.size()
	var section := Color(0.62, 0.58, 0.52)
	for i in ring.size():
		var a := ring[i]
		var c := ring[(i + 1) % ring.size()]
		var length := a.distance_to(c)
		if length < 0.01:
			continue
		var dir := (c - a) / length
		var n := Vector2(-dir.y, dir.x)
		if n.dot(center - (a + c) * 0.5) < 0.0:
			n = -n
		var spans: Array[Vector2] = [Vector2(0.0, 1.0)]
		if i == door_edge and door_width > 0.0:
			var half_gap := minf(door_width * 0.5, length * 0.35) / maxf(length, 0.01)
			spans = [Vector2(0.0, door_t - half_gap), Vector2(door_t + half_gap, 1.0)]
		for sp in spans:
			var p0 := a.lerp(c, sp.x)
			var p1 := a.lerp(c, sp.y)
			var q0 := p0 + n * thick
			var q1 := p1 + n * thick
			shell.quad_out(
				"stone",
				Vector3(p0.x, y, p0.y),
				Vector3(p1.x, y, p1.y),
				Vector3(q1.x, y, q1.y),
				Vector3(q0.x, y, q0.y),
				section,
				Vector3.UP
			)


## Stone chimney stack through the roof slope near the ridge; returns its top.
static func _chimney(
	roof: Shell, ring: PackedVector2Array, frame: Dictionary, rng: RandomNumberGenerator
) -> Vector3:
	var r: Vector2 = frame["r"]
	var n: Vector2 = frame["n"]
	var along := lerpf(float(frame["amin"]), float(frame["amax"]), rng.randf_range(0.22, 0.78))
	var across := float(frame["mid"]) + float(frame["half"]) * rng.randf_range(-0.35, 0.35)
	var c := r * along + n * across
	if not Geometry2D.is_point_in_polygon(c, ring):
		return Vector3.INF
	var half := CHIMNEY_SIZE * 0.5
	var low := INF
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			low = minf(low, roof_height(frame, c + r * sx * half + n * sy * half))
	var top := float(frame["ridge"]) + rng.randf_range(0.6, 1.1)
	var tint := Color(1, 1, 1) * rng.randf_range(0.75, 0.95)
	tint.a = 1.0
	var corners: Array[Vector2] = [
		c - r * half - n * half,
		c + r * half - n * half,
		c + r * half + n * half,
		c - r * half + n * half
	]
	for i in 4:
		var a := corners[i]
		var b := corners[(i + 1) % 4]
		var out := Vector3((a + b).x * 0.5 - c.x, 0.0, (a + b).y * 0.5 - c.y)
		roof.quad_out(
			"stone",
			Vector3(a.x, low - 0.2, a.y),
			Vector3(b.x, low - 0.2, b.y),
			Vector3(b.x, top, b.y),
			Vector3(a.x, top, a.y),
			tint,
			out
		)
	# Dark flue mouth.
	var m := half * 0.7
	roof.quad_out(
		"dark",
		Vector3(c.x - m, top - 0.02, c.y - m),
		Vector3(c.x + m, top - 0.02, c.y - m),
		Vector3(c.x + m, top - 0.02, c.y + m),
		Vector3(c.x - m, top - 0.02, c.y + m),
		Color(1, 1, 1),
		Vector3.UP
	)
	return Vector3(c.x, top, c.y)


## Limestone steps from the street up to a raised floor, so every door sits at
## a walkable threshold rather than floating above the ground.
static func _door_steps(
	shell: Shell,
	ring: PackedVector2Array,
	edge: int,
	door_t: float,
	floor_y: float,
	ground_at: Callable,
	door_width: float = DOOR_WIDTH
) -> void:
	var a := ring[edge]
	var c := ring[(edge + 1) % ring.size()]
	var dir := (c - a).normalized()
	var out := Vector2(-dir.y, dir.x)
	var mid := a.lerp(c, door_t)
	if Geometry2D.is_point_in_polygon(mid + out * 0.3, ring):
		out = -out
	var rise := floor_y - float(ground_at.call(mid + out * 1.0))
	if rise < 0.12:
		return
	# Up to 14 treads keeps the riser near 0.18 m even on the few doors that
	# still face a steep drop; 8 made 0.7 m risers there.
	var steps := clampi(int(ceil(rise / 0.18)), 1, 14)
	var tread := 0.32
	var half_w := door_width * 0.5 + 0.25
	for k in steps:
		var top := floor_y - rise * float(k) / steps
		var depth := tread * float(k + 1)
		var p0 := mid - dir * half_w
		var p1 := mid + dir * half_w
		var o := out * depth
		var bottom := float(ground_at.call(mid + out * depth)) - 0.4
		var corners: Array[Vector3] = [
			Vector3(p0.x, bottom, p0.y),
			Vector3(p1.x, bottom, p1.y),
			Vector3(p1.x + o.x, bottom, p1.y + o.y),
			Vector3(p0.x + o.x, bottom, p0.y + o.y),
		]
		var tops: Array[Vector3] = []
		for v in corners:
			tops.append(Vector3(v.x, top - 0.01, v.z))
		var center := Vector3(mid.x + o.x * 0.5, top, mid.y + o.y * 0.5)
		shell.quad_out(
			"stone", tops[0], tops[1], tops[2], tops[3], Color(0.9, 0.88, 0.84), Vector3.UP
		)
		for i in 4:
			var j := (i + 1) % 4
			var face := (corners[i] + corners[j]) * 0.5 - center
			shell.quad_out(
				"stone",
				corners[i],
				corners[j],
				tops[j],
				tops[i],
				Color(0.82, 0.8, 0.76),
				Vector3(face.x, 0, face.z)
			)


## Door opening (width, height) of a building: reduced for farmstead outbuildings,
## and always under the eave so a low shed never gets a lintel above its wall.
static func door_size(b: Dictionary) -> Vector2:
	var size := Vector2(DOOR_WIDTH, DOOR_HEIGHT)
	if String(b.get("kind", "")) == "outbuilding":
		size = OUTBUILDING_DOORS.get(StringName(String(b.get("type", ""))), size)
		size.y = minf(size.y, float(b.get("wall_h", size.y)) - 0.2)
	return size


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
	enterable: bool,
	door_height: float = DOOR_HEIGHT
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
		var top_y := floor_y + door_height
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
	roof: Shell,
	key: String,
	ring: PackedVector2Array,
	frame: Dictionary,
	tint: Color,
	family: StringName = &"tile",
	keep_out: Array[PackedVector2Array] = []
) -> void:
	var grown := Geometry2D.offset_polygon(ring, OVERHANG, Geometry2D.JOIN_MITER)
	if grown.is_empty():
		return
	var outline: PackedVector2Array = grown[0]
	# Eaves stop at a neighbouring landmark's wall (party wall): no overhang
	# into it. The largest remaining piece is the roof outline.
	for poly in keep_out:
		# The largest piece is the outer roof (a hole piece is always smaller).
		var keep := PackedVector2Array()
		var best := -1.0
		for piece in Geometry2D.clip_polygons(outline, poly):
			var area := absf(signed_area(piece))
			if area > best:
				best = area
				keep = piece
		if not keep.is_empty():
			outline = keep
	if outline.size() < 3:
		return
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
	# The cover's edge: a rounded roll at eaves and verges (quarter-round
	# nose outward from the cut line, then back under), so the roof reads as a
	# thick, soft coat instead of a paper-thin plane.
	var cover := float(ROOF_COVER.get(family, ROOF_THICKNESS))
	var outs: Array[Vector2] = []
	for i in outline.size():
		var prev := outline[(i - 1 + outline.size()) % outline.size()]
		var p := outline[i]
		var next := outline[(i + 1) % outline.size()]
		var e1 := (p - prev).normalized()
		var e2 := (next - p).normalized()
		var bis := Vector2(e1.y, -e1.x) + Vector2(e2.y, -e2.x)
		var centroid_dir := p - _ring_center(outline)
		if bis.dot(centroid_dir) < 0.0:
			bis = -bis
		outs.append(bis.normalized() if bis.length() > 0.01 else centroid_dir.normalized())
	var steps := 4
	for i in outline.size():
		var j := (i + 1) % outline.size()
		var p0 := outline[i]
		var p1 := outline[j]
		if _on_keep_out((p0 + p1) * 0.5, keep_out):
			continue  # the roof stops flush against the landmark's wall
		var h0 := roof_height(frame, p0)
		var h1 := roof_height(frame, p1)
		for k in steps:
			var a0 := PI * 0.5 - PI * float(k) / steps
			var a1 := PI * 0.5 - PI * float(k + 1) / steps
			var rad := cover * 0.5
			var q00 := _roll_point(p0, outs[i], h0, rad, a0)
			var q10 := _roll_point(p1, outs[j], h1, rad, a0)
			var q01 := _roll_point(p0, outs[i], h0, rad, a1)
			var q11 := _roll_point(p1, outs[j], h1, rad, a1)
			var mid_out := Vector3((outs[i] + outs[j]).x, 0.0, (outs[i] + outs[j]).y).normalized()
			var face := mid_out * cos((a0 + a1) * 0.5) + Vector3.UP * sin((a0 + a1) * 0.5)
			var len01 := p0.distance_to(p1)
			var v0 := rad * PI * float(k) / steps
			var v1 := rad * PI * float(k + 1) / steps
			_quad_uv(
				roof,
				key,
				[q00, q10, q11, q01],
				[Vector2(0, v0), Vector2(len01, v0), Vector2(len01, v1), Vector2(0, v1)],
				tint,
				face
			)
	# Ridge capping along the ridge line, overhanging the verges like the cover.
	var rr := float(RIDGE_RADIUS.get(family, 0.12))
	var along0 := float(frame["amin"]) - OVERHANG - cover * 0.5
	var along1 := float(frame["amax"]) + OVERHANG + cover * 0.5
	if not keep_out.is_empty():
		# The cap ends where the (clipped) roof ends.
		var lo := INF
		var hi := -INF
		for p in outline:
			lo = minf(lo, p.dot(r))
			hi = maxf(hi, p.dot(r))
		along0 = maxf(along0, lo)
		along1 = minf(along1, hi)
	var ridge_y := float(frame["ridge"])
	var base0 := r * along0 + n * mid
	var base1 := r * along1 + n * mid
	var cap_tint := tint * 0.9
	cap_tint.a = 1.0
	var segs := 6
	for k in segs:
		var a0 := PI * float(k) / segs
		var a1 := PI * float(k + 1) / segs
		var o0 := n * cos(a0) * rr
		var o1 := n * cos(a1) * rr
		var y0 := ridge_y - rr * 0.35 + sin(a0) * rr
		var y1 := ridge_y - rr * 0.35 + sin(a1) * rr
		var face := Vector3(
			n.x * cos((a0 + a1) * 0.5), sin((a0 + a1) * 0.5), n.y * cos((a0 + a1) * 0.5)
		)
		_quad_uv(
			roof,
			key,
			[
				Vector3(base0.x + o0.x, y0, base0.y + o0.y),
				Vector3(base1.x + o0.x, y0, base1.y + o0.y),
				Vector3(base1.x + o1.x, y1, base1.y + o1.y),
				Vector3(base0.x + o1.x, y1, base0.y + o1.y),
			],
			[
				Vector2(along0, a0 * rr),
				Vector2(along1, a0 * rr),
				Vector2(along1, a1 * rr),
				Vector2(along0, a1 * rr),
			],
			cap_tint,
			face
		)
	# Cap ends.
	for end: Array in [[base0, -r], [base1, r]]:
		var c: Vector2 = end[0]
		var dir: Vector2 = end[1]
		for k in segs:
			var a0 := PI * float(k) / segs
			var a1 := PI * float(k + 1) / segs
			roof.tri_out(
				key,
				Vector3(c.x, ridge_y - rr * 0.35, c.y),
				Vector3(
					c.x + n.x * cos(a0) * rr,
					ridge_y - rr * 0.35 + sin(a0) * rr,
					c.y + n.y * cos(a0) * rr
				),
				Vector3(
					c.x + n.x * cos(a1) * rr,
					ridge_y - rr * 0.35 + sin(a1) * rr,
					c.y + n.y * cos(a1) * rr
				),
				cap_tint,
				Vector3(dir.x, 0.0, dir.y)
			)


## Textured quad (corners a-b-c-d with their UVs) facing `out`.
static func _quad_uv(
	shell: Shell, key: String, q: Array, uv: Array, tint: Color, out: Vector3
) -> void:
	shell.tri_out(key, q[0], q[1], q[2], tint, out, uv[0], uv[1], uv[2])
	shell.tri_out(key, q[0], q[2], q[3], tint, out, uv[0], uv[2], uv[3])


## True when `p` lies on the boundary of one of the keep-out polygons.
static func _on_keep_out(p: Vector2, keep_out: Array[PackedVector2Array]) -> bool:
	for poly in keep_out:
		for k in poly.size():
			var q := Geometry2D.get_closest_point_to_segment(
				p, poly[k], poly[(k + 1) % poly.size()]
			)
			if q.distance_to(p) < 0.05:
				return true
	return false


## Point on the eave roll: angle +90 deg is the top of the cover at the cut
## line, 0 the outermost nose, -90 deg the underside.
static func _roll_point(p: Vector2, out: Vector2, h: float, r: float, angle: float) -> Vector3:
	var o := out * cos(angle) * r
	return Vector3(p.x + o.x, h - r + sin(angle) * r, p.y + o.y)


static func _ring_center(ring: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in ring:
		c += p
	return c / maxf(ring.size(), 1)


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


static func _floor(
	shell: Shell, ring: PackedVector2Array, y: float, key := "floor", tint := Color(1, 1, 1)
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
	door_t: float,
	ceiling_shell: Shell = null,
	door: Vector2 = Vector2(DOOR_WIDTH, DOOR_HEIGHT),
	rural := false
) -> void:
	var inset := Geometry2D.offset_polygon(ring, -thick, Geometry2D.JOIN_MITER)
	if inset.is_empty():
		return
	var inner: PackedVector2Array = normalized_ring(inset[0])
	if rural:
		_floor(shell, inner, floor_y, "stone", RURAL_FLOOR)
	else:
		_floor(shell, inner, floor_y)
	var ceiling := eave - 0.05
	var key := "wall:log" if rural else "interior"
	var col := RURAL_SMOKED if rural else Color(1, 1, 1)
	var door_w := door.x
	# A town door may rise past a low ceiling (the lintel sits in the gable);
	# a farmstead door always stays under it.
	var door_h := minf(door.y, ceiling - 0.05) if rural else door.y
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
			var hg := minf(door_w * 0.5, length * 0.35) / maxf(length, 0.01)
			var g0 := a.lerp(c, t - hg)
			var g1 := a.lerp(c, t + hg)
			# Inner faces look inward: reverse the outward winding.
			shell.quad(
				key,
				Vector3(g0.x, floor_y, g0.y),
				Vector3(a.x, floor_y, a.y),
				Vector3(a.x, ceiling, a.y),
				Vector3(g0.x, ceiling, g0.y),
				col
			)
			shell.quad(
				key,
				Vector3(c.x, floor_y, c.y),
				Vector3(g1.x, floor_y, g1.y),
				Vector3(g1.x, ceiling, g1.y),
				Vector3(c.x, ceiling, c.y),
				col
			)
			shell.quad(
				key,
				Vector3(g1.x, floor_y + door_h, g1.y),
				Vector3(g0.x, floor_y + door_h, g0.y),
				Vector3(g0.x, ceiling, g0.y),
				Vector3(g1.x, ceiling, g1.y),
				col
			)
			# Door reveal through the wall thickness.
			var oa := ring[door_edge]
			var oc := ring[(door_edge + 1) % ring.size()]
			var olen := oa.distance_to(oc)
			var ohg := minf(door_w * 0.5, olen * 0.35) / maxf(olen, 0.01)
			var o0 := oa.lerp(oc, door_t - ohg)
			var o1 := oa.lerp(oc, door_t + ohg)
			shell.quad(
				"timber",
				Vector3(g0.x, floor_y, g0.y),
				Vector3(o0.x, floor_y, o0.y),
				Vector3(o0.x, floor_y + door_h, o0.y),
				Vector3(g0.x, floor_y + door_h, g0.y),
				Color(0.8, 0.7, 0.6)
			)
			shell.quad(
				"timber",
				Vector3(o1.x, floor_y, o1.y),
				Vector3(g1.x, floor_y, g1.y),
				Vector3(g1.x, floor_y + door_h, g1.y),
				Vector3(o1.x, floor_y + door_h, o1.y),
				Color(0.8, 0.7, 0.6)
			)
			shell.quad(
				"timber",
				Vector3(o0.x, floor_y + door_h, o0.y),
				Vector3(o1.x, floor_y + door_h, o1.y),
				Vector3(g1.x, floor_y + door_h, g1.y),
				Vector3(g0.x, floor_y + door_h, g0.y),
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
				key,
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
		var target := ceiling_shell if ceiling_shell != null else shell
		if (vc - va).cross(vb - va).y < 0.0:
			target.tri("timber", va, vb, vc, Color(0.75, 0.65, 0.55))
		else:
			target.tri("timber", va, vc, vb, Color(0.75, 0.65, 0.55))

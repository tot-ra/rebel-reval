class_name MapViewBarrelMeshes
extends RefCounted

## One coopered oak barrel for the `barrels` prop kind (obj.barrel_oak).
##
## A prop always builds exactly one barrel: maps control how many barrels stand
## somewhere by placing more props, so the model never hides a fixed group.
## Every mesh is procedural, cached per dimension and shared by all instances.

const MeshMath := preload("res://scripts/map/view3d/map_view_mesh_builder_math.gd")

## Size follows the object catalog entry obj.barrel_oak (0.62 x 0.9 x 0.62 m).
const HEIGHT := 0.9
const BELLY_RADIUS := 0.31
## Radius at the stave ends relative to the bilge (widest point).
const END_RATIO := 0.82
## Staves run past the heads by this much, forming the chime (protective lip).
const CHIME_DEPTH := 0.035
## Stave wall thickness as a fraction of the end radius. The heads sit inside it.
const STAVE_WALL := 0.09
const HEAD_THICKNESS := 0.03
const STAVE_COUNT := 18
## Iron hoops as (start, end) fractions of the barrel height: a chime hoop and a
## quarter hoop at each end, the usual binding of a 14th-century wet cask.
const HOOP_BANDS: Array[Vector2] = [
	Vector2(0.035, 0.085),
	Vector2(0.2, 0.245),
	Vector2(0.755, 0.8),
	Vector2(0.915, 0.965),
]
## Forged strap iron: dark grey-brown, not the bluish generic "metal" role.
const IRON_ALBEDO := Color(0.3, 0.28, 0.26)
const IRON_TINT := Color(1.0, 1.0, 1.0)
const SEAM_COLOR := Color(0.3, 0.25, 0.2)
const HEAD_BOARDS := 4

## Cached procedural meshes for coopered barrel props.
static var _mesh_cache: Dictionary = {}


## Builds one barrel under `parent`. `yaw` turns the bung hole and stave pattern
## so neighbouring barrels do not look cloned.
static func add_barrel(parent: Node3D, node_name: String, position: Vector3, yaw: float) -> Node3D:
	var barrel := Node3D.new()
	barrel.name = node_name
	barrel.position = position
	barrel.rotation.y = yaw
	parent.add_child(barrel)

	var wood := wood_material()
	_mesh_child(barrel, "Staves", stave_mesh(BELLY_RADIUS, HEIGHT), wood)

	var head_radius := BELLY_RADIUS * END_RATIO * (1.0 - STAVE_WALL)
	for head_spec in [
		{"name": "BottomHead", "y": CHIME_DEPTH, "flip": true},
		{"name": "TopHead", "y": HEIGHT - CHIME_DEPTH - HEAD_THICKNESS, "flip": false},
	]:
		var head := _mesh_child(barrel, head_spec["name"], head_mesh(head_radius), wood)
		head.position.y = float(head_spec["y"])
		if head_spec["flip"]:
			# Boards face down so the bottom head shows its grain when tipped over.
			head.rotation.x = PI
			head.position.y += HEAD_THICKNESS

	var iron := iron_material()
	for band_index in HOOP_BANDS.size():
		var band := HOOP_BANDS[band_index]
		_mesh_child(
			barrel, "Hoop%d" % band_index, hoop_mesh(BELLY_RADIUS, HEIGHT, band.x, band.y), iron
		)

	# Bung: a tapped plug through the middle of one stave at the bilge.
	var bung := _mesh_child(barrel, "Bung", bung_mesh(), wood)
	var bung_angle := TAU / float(STAVE_COUNT) * 0.5
	bung.position = _barrel_point(bung_angle, HEIGHT * 0.5, BELLY_RADIUS * 0.985)
	bung.rotation = Vector3(PI * 0.5, bung_angle, 0.0)
	return barrel


## Close-range oak with longitudinal grain and no plank-course seams (the
## generic "wood" role tiles horizontal board joints across every stave). Vertex
## colours stay on so stave tone, damp and seam grooves survive.
static func wood_material() -> StandardMaterial3D:
	if _mesh_cache.has("wood_material"):
		return _mesh_cache["wood_material"]
	var material := MapViewMaterials.door_wood(0).duplicate() as StandardMaterial3D
	material.vertex_color_use_as_albedo = true
	# Weathered cask oak is matt; the smooth bilge normals otherwise catch a
	# glossy vertical highlight that reads as varnish.
	material.roughness = 0.97
	material.metallic_specular = 0.25
	_mesh_cache["wood_material"] = material
	return material


static func iron_material() -> StandardMaterial3D:
	if _mesh_cache.has("iron_material"):
		return _mesh_cache["iron_material"]
	var material := StandardMaterial3D.new()
	material.albedo_color = IRON_ALBEDO
	# Blackened, scaled strap iron reads as a dielectric oxide skin, not bare
	# metal. A metallic hoop has almost no diffuse, so outdoors it mirrored the
	# saturated sky ambient and turned bright blue in shade.
	material.metallic = 0.1
	material.roughness = 0.8
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh_cache["iron_material"] = material
	return material


## Profile radius at height fraction `t` (0 = bottom, 1 = top): a parabolic bilge
## between the narrower stave ends.
static func profile_radius(radius: float, t: float) -> float:
	var centred := t * 2.0 - 1.0
	return radius * lerpf(1.0, END_RATIO, centred * centred)


## Coopered body: flat-faced staves with smooth normals, recessed seams, a
## visible stave-end thickness and an inner wall down to the inset heads.
static func stave_mesh(radius: float, height: float) -> ArrayMesh:
	var cache_key := "staves:%.4f:%.4f" % [radius, height]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]

	const ROWS := 10
	const FACE_SPLITS := 2
	const SEAM_FRACTION := 0.05
	const SEAM_RECESS := 0.975
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stave_step := TAU / float(STAVE_COUNT)
	var seam_width := stave_step * SEAM_FRACTION
	for stave_index in STAVE_COUNT:
		var sector_start := float(stave_index) * stave_step
		var face_start := sector_start + seam_width * 0.5
		var face_end := sector_start + stave_step - seam_width * 0.5
		# Deterministic tone per stave keeps boards legible without per-instance
		# resources; the texture offset gives each stave its own grain.
		var tone := 0.8 + MeshMath.hash01(stave_index, 19, 617) * 0.26
		var grain_offset := MeshMath.hash01(stave_index, 7, 211) * 4.0
		for row in ROWS:
			var t0 := float(row) / float(ROWS)
			var t1 := float(row + 1) / float(ROWS)
			for split in FACE_SPLITS:
				var a0 := lerpf(face_start, face_end, float(split) / FACE_SPLITS)
				var a1 := lerpf(face_start, face_end, float(split + 1) / FACE_SPLITS)
				# Grain runs along V (the stave height); U spans a thin slice of
				# the tile so each stave shows its own stretch of grain.
				var v0 := grain_offset + (a0 - face_start) / stave_step * 0.3
				var v1 := grain_offset + (a1 - face_start) / stave_step * 0.3
				_stave_quad(surface, a0, a1, t0, t1, radius, height, 1.0, tone, v0, v1)
			var seam_end := face_end + seam_width
			_stave_quad(
				surface, face_end, seam_end, t0, t1, radius, height, SEAM_RECESS, -1.0, 0.0, 0.0
			)

	# Stave ends and the inner wall above each head make the chime read as a
	# thick wooden rim instead of a paper-thin shell.
	var end_radius := radius * END_RATIO
	var inner_radius := end_radius * (1.0 - STAVE_WALL)
	const RIM_SEGMENTS := 36
	for segment in RIM_SEGMENTS:
		var a0 := TAU * float(segment) / RIM_SEGMENTS
		var a1 := TAU * float(segment + 1) / RIM_SEGMENTS
		for rim in [
			{"y": height, "inner_y": height - CHIME_DEPTH, "up": 1.0},
			{"y": 0.0, "inner_y": CHIME_DEPTH, "up": -1.0},
		]:
			var y: float = rim["y"]
			var inner_y: float = rim["inner_y"]
			var up := Vector3.UP * float(rim["up"])
			_quad(
				surface,
				[
					_barrel_point(a0, y, inner_radius),
					_barrel_point(a1, y, inner_radius),
					_barrel_point(a1, y, end_radius),
					_barrel_point(a0, y, end_radius),
				],
				[Vector2(0.0, a0), Vector2(0.0, a1), Vector2(0.04, a1), Vector2(0.04, a0)],
				[up, up, up, up],
				Color(0.86, 0.8, 0.72)
			)
			var n0 := -Vector3(sin(a0), 0.0, cos(a0))
			var n1 := -Vector3(sin(a1), 0.0, cos(a1))
			_quad(
				surface,
				[
					_barrel_point(a0, inner_y, inner_radius),
					_barrel_point(a1, inner_y, inner_radius),
					_barrel_point(a1, y, inner_radius),
					_barrel_point(a0, y, inner_radius),
				],
				[Vector2(0.0, a0), Vector2(0.0, a1), Vector2(0.05, a1), Vector2(0.05, a0)],
				[n0, n1, n1, n0],
				Color(0.62, 0.55, 0.48)
			)
	surface.generate_tangents()
	var mesh := surface.commit()
	_mesh_cache[cache_key] = mesh
	return mesh


## Barrel head of HEAD_BOARDS jointed boards with dark gaps between them and a
## small plugged bung near one edge. The local origin is the bottom face.
static func head_mesh(radius: float) -> ArrayMesh:
	var cache_key := "head:%.4f" % radius
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]
	const SEGMENTS := 36
	const GAP := 0.007
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Dark backing disc shows through the board joints.
	var backing_y := HEAD_THICKNESS * 0.6
	for segment in SEGMENTS:
		var a0 := TAU * float(segment) / SEGMENTS
		var a1 := TAU * float(segment + 1) / SEGMENTS
		_triangle(
			surface,
			[
				Vector3(0.0, backing_y, 0.0),
				_barrel_point(a0, backing_y, radius),
				_barrel_point(a1, backing_y, radius),
			],
			Vector3.UP,
			SEAM_COLOR
		)
		# Head edge: the board ends that sit in the croze groove.
		_quad(
			surface,
			[
				_barrel_point(a0, 0.0, radius),
				_barrel_point(a1, 0.0, radius),
				_barrel_point(a1, HEAD_THICKNESS, radius),
				_barrel_point(a0, HEAD_THICKNESS, radius),
			],
			[Vector2(0.0, a0), Vector2(0.0, a1), Vector2(0.03, a1), Vector2(0.03, a0)],
			[
				Vector3(sin(a0), 0.0, cos(a0)),
				Vector3(sin(a1), 0.0, cos(a1)),
				Vector3(sin(a1), 0.0, cos(a1)),
				Vector3(sin(a0), 0.0, cos(a0)),
			],
			Color(0.7, 0.62, 0.54)
		)
	var board_width := radius * 2.0 / float(HEAD_BOARDS)
	for board in HEAD_BOARDS:
		var x0 := -radius + board_width * board + GAP * 0.5
		var x1 := x0 + board_width - GAP
		var outline := _board_outline(radius, x0, x1)
		var tone := 0.84 + MeshMath.hash01(board, 3, 977) * 0.2
		var grain_offset := MeshMath.hash01(board, 5, 433) * 4.0
		var centre := Vector3.ZERO
		for point in outline:
			centre += point
		centre /= float(outline.size())
		for index in outline.size():
			var p0: Vector3 = outline[index]
			var p1: Vector3 = outline[(index + 1) % outline.size()]
			# Grain runs along each board (z, texture V); boards change across x.
			for point in [centre, p0, p1]:
				surface.set_color(Color(tone, tone, tone))
				surface.set_normal(Vector3.UP)
				surface.set_uv(Vector2(grain_offset + point.x * 1.2, point.z * 1.6))
				surface.add_vertex(Vector3(point.x, HEAD_THICKNESS, point.z))
	# Bung plug on the head, off-centre like a filling hole.
	var bung_centre := Vector3(radius * 0.48, HEAD_THICKNESS + 0.002, 0.0)
	const BUNG_RADIUS := 0.028
	for segment in 12:
		var a0 := TAU * float(segment) / 12.0
		var a1 := TAU * float(segment + 1) / 12.0
		_triangle(
			surface,
			[
				bung_centre,
				bung_centre + _barrel_point(a0, 0.0, BUNG_RADIUS),
				bung_centre + _barrel_point(a1, 0.0, BUNG_RADIUS),
			],
			Vector3.UP,
			Color(0.5, 0.4, 0.32)
		)
	surface.generate_tangents()
	var mesh := surface.commit()
	_mesh_cache[cache_key] = mesh
	return mesh


## Flat iron strap that hugs the stave profile between height fractions t0..t1,
## with a thin outer face and edge strips so it stands proud of the wood.
static func hoop_mesh(radius: float, height: float, t0: float, t1: float) -> ArrayMesh:
	var cache_key := "hoop:%.4f:%.4f:%.4f:%.4f" % [radius, height, t0, t1]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]
	const SEGMENTS := 36
	const STRAP := 0.006
	var r0 := profile_radius(radius, t0) * 1.004
	var r1 := profile_radius(radius, t1) * 1.004
	var y0 := t0 * height
	var y1 := t1 * height
	var slope := (r1 - r0) / (y1 - y0)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in SEGMENTS:
		var a0 := TAU * float(segment) / SEGMENTS
		var a1 := TAU * float(segment + 1) / SEGMENTS
		var radial0 := Vector3(sin(a0), 0.0, cos(a0))
		var radial1 := Vector3(sin(a1), 0.0, cos(a1))
		var n0 := (radial0 - Vector3.UP * slope).normalized()
		var n1 := (radial1 - Vector3.UP * slope).normalized()
		var uv := [Vector2(0.0, a0), Vector2(0.0, a1), Vector2(0.1, a1), Vector2(0.1, a0)]
		_quad(
			surface,
			[
				_barrel_point(a0, y0, r0 + STRAP),
				_barrel_point(a1, y0, r0 + STRAP),
				_barrel_point(a1, y1, r1 + STRAP),
				_barrel_point(a0, y1, r1 + STRAP),
			],
			uv,
			[n0, n1, n1, n0],
			IRON_TINT
		)
		for edge in [
			{"y": y0, "r": r0, "normal": Vector3.DOWN},
			{"y": y1, "r": r1, "normal": Vector3.UP},
		]:
			var edge_y: float = edge["y"]
			var edge_r: float = edge["r"]
			var normal: Vector3 = edge["normal"]
			_quad(
				surface,
				[
					_barrel_point(a0, edge_y, edge_r - 0.002),
					_barrel_point(a1, edge_y, edge_r - 0.002),
					_barrel_point(a1, edge_y, edge_r + STRAP),
					_barrel_point(a0, edge_y, edge_r + STRAP),
				],
				uv,
				[normal, normal, normal, normal],
				IRON_TINT.darkened(0.25)
			)
	surface.generate_tangents()
	var mesh := surface.commit()
	_mesh_cache[cache_key] = mesh
	return mesh


## Short tapered wooden plug along local +Y, base at the origin.
static func bung_mesh() -> ArrayMesh:
	if _mesh_cache.has("bung"):
		return _mesh_cache["bung"]
	const SEGMENTS := 10
	const LENGTH := 0.022
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var colour := Color(0.52, 0.42, 0.33)
	for segment in SEGMENTS:
		var a0 := TAU * float(segment) / SEGMENTS
		var a1 := TAU * float(segment + 1) / SEGMENTS
		var n0 := Vector3(sin(a0), 0.0, cos(a0))
		var n1 := Vector3(sin(a1), 0.0, cos(a1))
		_quad(
			surface,
			[
				_barrel_point(a0, 0.0, 0.03),
				_barrel_point(a1, 0.0, 0.03),
				_barrel_point(a1, LENGTH, 0.025),
				_barrel_point(a0, LENGTH, 0.025),
			],
			[Vector2(0.0, 0.0), Vector2(0.0, 0.1), Vector2(0.05, 0.1), Vector2(0.05, 0.0)],
			[n0, n1, n1, n0],
			colour
		)
		_triangle(
			surface,
			[
				Vector3(0.0, LENGTH, 0.0),
				_barrel_point(a0, LENGTH, 0.025),
				_barrel_point(a1, LENGTH, 0.025),
			],
			Vector3.UP,
			colour.darkened(0.15)
		)
	surface.generate_tangents()
	var mesh := surface.commit()
	_mesh_cache["bung"] = mesh
	return mesh


static func _mesh_child(
	parent: Node3D, node_name: String, mesh: Mesh, material: Material
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance


## One quad of the stave wall. `tone` < 0 marks a recessed seam groove.
static func _stave_quad(
	surface: SurfaceTool,
	a0: float,
	a1: float,
	t0: float,
	t1: float,
	radius: float,
	height: float,
	radial_scale: float,
	tone: float,
	v0: float,
	v1: float
) -> void:
	var r0 := profile_radius(radius, t0) * radial_scale
	var r1 := profile_radius(radius, t1) * radial_scale
	var slope0 := _profile_slope(radius, t0, height)
	var slope1 := _profile_slope(radius, t1, height)
	var vertices := [
		_barrel_point(a0, t0 * height, r0),
		_barrel_point(a1, t0 * height, r0),
		_barrel_point(a1, t1 * height, r1),
		_barrel_point(a0, t1 * height, r1),
	]
	var normals := [
		_wall_normal(a0, slope0),
		_wall_normal(a1, slope0),
		_wall_normal(a1, slope1),
		_wall_normal(a0, slope1),
	]
	# `v0`/`v1` are the across-stave texture coordinates; height maps to V.
	var uvs := [
		Vector2(v0, t0 * 1.2),
		Vector2(v1, t0 * 1.2),
		Vector2(v1, t1 * 1.2),
		Vector2(v0, t1 * 1.2),
	]
	if tone < 0.0:
		_quad(surface, vertices, uvs, normals, SEAM_COLOR)
		return
	# Damp darkens the lowest hand-breadth of the staves, as on a cask standing
	# on wet ground; the colour is interpolated per row edge.
	var colours := [
		_stave_colour(tone, t0),
		_stave_colour(tone, t0),
		_stave_colour(tone, t1),
		_stave_colour(tone, t1),
	]
	for index in [0, 1, 2, 0, 2, 3]:
		surface.set_color(colours[index])
		surface.set_normal(normals[index])
		surface.set_uv(uvs[index])
		surface.add_vertex(vertices[index])


static func _stave_colour(tone: float, t: float) -> Color:
	var damp := lerpf(0.7, 1.0, clampf(t / 0.16, 0.0, 1.0))
	var value := tone * damp
	return Color(value, value, value)


static func _profile_slope(radius: float, t: float, height: float) -> float:
	# d(radius)/d(y) of profile_radius(): r = R * (1 - (1 - END_RATIO) * c^2), c = 2t - 1.
	return radius * -(1.0 - END_RATIO) * 2.0 * (t * 2.0 - 1.0) * 2.0 / height


static func _wall_normal(angle: float, slope: float) -> Vector3:
	return (Vector3(sin(angle), 0.0, cos(angle)) - Vector3.UP * slope).normalized()


## Convex outline of the disc slice x0..x1 (a head board), counter-clockwise
## seen from above.
static func _board_outline(radius: float, x0: float, x1: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	const ARC_STEPS := 8
	# Near edge along +z: from (x0, z0) round the arc to (x1, z1), then back along -z.
	for step in ARC_STEPS + 1:
		var x := lerpf(x0, x1, float(step) / ARC_STEPS)
		points.append(Vector3(x, 0.0, sqrt(maxf(radius * radius - x * x, 0.0))))
	for step in ARC_STEPS + 1:
		var x := lerpf(x1, x0, float(step) / ARC_STEPS)
		points.append(Vector3(x, 0.0, -sqrt(maxf(radius * radius - x * x, 0.0))))
	return points


static func _quad(
	surface: SurfaceTool, vertices: Array, uvs: Array, normals: Array, colour: Color
) -> void:
	for index in [0, 1, 2, 0, 2, 3]:
		surface.set_color(colour)
		surface.set_normal(normals[index])
		surface.set_uv(uvs[index])
		surface.add_vertex(vertices[index])


static func _triangle(
	surface: SurfaceTool, vertices: Array, normal: Vector3, colour: Color
) -> void:
	for vertex in vertices:
		surface.set_color(colour)
		surface.set_normal(normal)
		surface.set_uv(Vector2(vertex.x, vertex.z))
		surface.add_vertex(vertex)


static func _barrel_point(angle: float, y: float, radius: float) -> Vector3:
	return Vector3(sin(angle) * radius, y, cos(angle) * radius)

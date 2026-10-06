class_name MapViewWellModels
extends RefCounted

## Hand-built medieval draw-well for the 3D map view.
##
## WHY: the first rebuild still read as a toy: a 12-facet stone tube, a tiled
## house roof, a bright roller pushed through both posts, a hay-textured rope,
## and water 0.4 m under the curb. This version models a cheap Lower Town well:
## - coursed local limestone slabs with weathered rounded arrises and recessed
##   lime mortar, capped by a ring of large flat curb slabs;
## - a fake-depth shaft (map_view_well_shaft.gdshader) because the opaque
##   terrain hides real geometry below y = 0;
## - a log windlass that turns between the posts on an iron axle and crank;
## - twisted hemp rope wound on the log and slack down to a tinned-iron bucket
##   resting on the curb;
## - a gable roof of old silvered boards laid down-slope on purlins.
## The gameplay footprint stays owned by the map definition; only the visual
## nodes change. All geometry is deterministic (hash-seeded) and cached.

const MeshMath := preload("res://scripts/map/view3d/map_view_mesh_builder_math.gd")
const SHAFT_SHADER := preload("res://scripts/map/view3d/map_view_well_shaft.gdshader")

const WALL_TOP := 0.70
const WALL_FACE := 0.62
const WALL_BACK := 0.55
const MORTAR_RADIUS := 0.603
const CAP_INNER := 0.40
const CAP_OUTER := 0.67
const CAP_TOP := 0.795
const MOUTH_RADIUS := 0.41
const MOUTH_Y := 0.72

const POST_X := 0.77
const POST_SIZE := 0.13
const POST_TOP := 1.66
const WINDLASS_Y := 1.30
const ROLLER_RADIUS := 0.075
const AXLE_RADIUS := 0.022
const ROPE_RADIUS := 0.011
const COIL_HALF_WIDTH := 0.15

## Roof plane: apex line at x-axis, down-slope to the eaves on both sides.
const ROOF_APEX := Vector3(0.0, 1.92, 0.0)
const ROOF_RUN := 0.80
const ROOF_DROP := 0.55
const ROOF_HALF_LENGTH := 1.02
const BOARD_THICKNESS := 0.022
const PURLIN_DEPTH := 0.07

## Bucket rests on the curb slabs at the back-right, clear of the mouth.
const BUCKET_SPOT := Vector2(0.50, -0.21)
const BUCKET_HEIGHT := 0.23
const BUCKET_TOP_RADIUS := 0.13
const BUCKET_BOTTOM_RADIUS := 0.105

const STONE_UV_SCALE := 3.0
const TIMBER_GRAIN_REPEAT := 2.0
const TIMBER_ACROSS_REPEAT := 0.35

static var _mesh_cache: Dictionary = {}
static var _material_cache: Dictionary = {}


static func add_model(parent: Node3D) -> Node3D:
	var model := Node3D.new()
	model.name = "WellModel"
	model.set_meta(&"production_well_model", true)
	parent.add_child(model)

	_add_mesh(model, "Shaft", _cached("shaft", _build_shaft_mesh), _stone_material())
	_add_mesh(model, "Curb", _cached("curb", _build_curb_mesh), _stone_material())
	var mouth := _add_mesh(model, "Water", _cached("mouth", _build_mouth_mesh), _shaft_material())
	mouth.position.y = MOUTH_Y
	mouth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_add_mesh(model, "Frame", _cached("frame", _build_frame_mesh), _timber_material(&"frame"))
	_add_mesh(model, "Roof", _cached("roof", _build_roof_mesh), _timber_material(&"roof"))
	_add_mesh(model, "Windlass", _cached("roller", _build_roller_mesh), _timber_material(&"frame"))
	_add_mesh(model, "Axle", _cached("axle", _build_axle_mesh), MapViewMaterials.door_iron())
	_add_mesh(
		model, "CrankHandle", _cached("grip", _build_grip_mesh), _timber_material(&"frame")
	)
	_add_mesh(model, "Rope", _cached("rope", _build_rope_mesh), _rope_material())
	_add_mesh(model, "Bucket", _cached("bucket", _build_bucket_mesh), _tin_material())
	_add_mesh(model, "BucketHandle", _cached("bail", _build_bail_mesh), _tin_material())
	return model


static func _add_mesh(
	parent: Node3D, node_name: String, mesh: Mesh, material: Material
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance


static func _cached(key: String, builder: Callable) -> ArrayMesh:
	if not _mesh_cache.has(key):
		_mesh_cache[key] = builder.call()
	return _mesh_cache[key]


# --- Materials ---------------------------------------------------------------


## Plain weathered-rock grain with a relief normal. The shared "stone" role
## texture is itself painted as coursed blocks, which doubled up inside every
## modelled slab; here the slabs are geometry, so only the grain is wanted.
## Tinted toward the pale grey-beige of local Reval limestone.
static func _stone_material() -> StandardMaterial3D:
	if not _material_cache.has(&"stone"):
		var material := MapViewMaterials.natural_rock().duplicate() as StandardMaterial3D
		material.albedo_color = Color8(176, 170, 156)
		material.uv1_scale = Vector3.ONE
		_material_cache[&"stone"] = material
	return _material_cache[&"stone"]


static func _shaft_material() -> ShaderMaterial:
	if not _material_cache.has(&"shaft"):
		var material := ShaderMaterial.new()
		material.shader = SHAFT_SHADER
		material.set_shader_parameter("shaft_radius", MOUTH_RADIUS)
		_material_cache[&"shaft"] = material
	return _material_cache[&"shaft"]


## Silvered, weathered oak: the hewn-timber texture with a grey base and
## per-vertex tone so boards and posts do not read as fresh red-brown lumber.
static func _timber_material(kind: StringName) -> StandardMaterial3D:
	if not _material_cache.has(kind):
		var noise_seed := 1 if kind == &"frame" else 2
		var material := MapViewMaterials.hewn_timber(true, noise_seed).duplicate() as StandardMaterial3D
		material.albedo_color = (
			Color8(126, 117, 104) if kind == &"frame" else Color8(122, 118, 110)
		)
		material.vertex_color_use_as_albedo = true
		material.uv1_scale = Vector3.ONE
		_material_cache[kind] = material
	return _material_cache[kind]


static func _rope_material() -> StandardMaterial3D:
	if not _material_cache.has(&"rope"):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color8(102, 89, 70)
		material.roughness = 1.0
		material.vertex_color_use_as_albedo = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material_cache[&"rope"] = material
	return _material_cache[&"rope"]


## Tinned sheet iron: pale, dull metal with darker grime toward the base.
static func _tin_material() -> StandardMaterial3D:
	if not _material_cache.has(&"tin"):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color8(158, 160, 155)
		material.metallic = 0.45
		material.metallic_specular = 0.5
		material.roughness = 0.5
		material.vertex_color_use_as_albedo = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material_cache[&"tin"] = material
	return _material_cache[&"tin"]


# --- Masonry -----------------------------------------------------------------


## Coursed limestone: uneven course heights, staggered slab lengths, each slab
## a rounded pillow face proud of a recessed mortar ring. Only the outer faces
## are built; the mouth disc hides the inside and the curb hides the top.
static func _build_shaft_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_mortar_ring(surface)
	var courses: Array[float] = [0.0]
	var y := 0.0
	var course_index := 0
	while y < WALL_TOP - 0.10:
		y += 0.11 + MeshMath.hash01(course_index, 3, 4021) * 0.07
		courses.append(minf(y, WALL_TOP))
		course_index += 1
	courses[courses.size() - 1] = WALL_TOP
	for course in courses.size() - 1:
		var y0: float = courses[course]
		var y1: float = courses[course + 1]
		var angle := MeshMath.hash01(course, 7, 4022) * TAU
		var end_angle := angle + TAU
		var stone := 0
		while angle < end_angle - 0.05:
			var length := 0.18 + MeshMath.hash01(course, stone, 4023) * 0.2
			var span := minf(length / WALL_FACE, end_angle - angle)
			if end_angle - (angle + span) < 0.2:
				span = end_angle - angle
			var mid_y := (y0 + y1) * 0.5
			var face := (
				WALL_FACE
				- 0.018 * mid_y / WALL_TOP
				+ (MeshMath.hash01(course, stone, 4024) - 0.35) * 0.022
			)
			var tone := 0.58 + MeshMath.hash01(course, stone, 4025) * 0.42
			# Some slabs are bluish-grey, others yellowed: local limestone beds vary.
			var warmth := (MeshMath.hash01(course, stone, 4027) - 0.5) * 0.12
			# Damp, greener footing courses where rain splash and spilt water sit.
			var tint := Color(tone * (1.0 + warmth), tone, tone * (1.0 - warmth))
			if mid_y < 0.2:
				tint = tint.lerp(Color(0.58, 0.62, 0.48), 0.35)
			_add_stone(
				surface,
				{
					"a0": angle + 0.006 / WALL_FACE,
					"a1": angle + span - 0.006 / WALL_FACE,
					"r0": WALL_BACK,
					"r1": face,
					# Uneven bed joints and a slight lean per slab break the brick-like
					# regularity of hand-laid rubble courses.
					"y0": y0 + 0.004 + MeshMath.hash01(course, stone, 4028) * 0.014,
					"y1": y1 - 0.004 - MeshMath.hash01(course, stone, 4029) * 0.014,
					"lean": (MeshMath.hash01(course, stone, 4030) - 0.5) * 0.03,
					"noise": 0.011,
					"round": 0.028,
					"faces": [Vector2i(1, 1)],
					"color": tint,
					"uv": Vector2(MeshMath.hash01(course, stone, 4026), float(course) * 0.37),
				}
			)
			angle += span
			stone += 1
	surface.index()
	return surface.commit()


static func _add_mortar_ring(surface: SurfaceTool) -> void:
	var segments := 32
	var color := Color(0.5, 0.48, 0.44)
	for segment in segments:
		var a0 := TAU * float(segment) / float(segments)
		var a1 := TAU * float(segment + 1) / float(segments)
		var quad := [
			_polar(a0, -0.02, MORTAR_RADIUS),
			_polar(a1, -0.02, MORTAR_RADIUS),
			_polar(a1, WALL_TOP, MORTAR_RADIUS - 0.012),
			_polar(a0, WALL_TOP, MORTAR_RADIUS - 0.012),
		]
		var normals := []
		var uvs := []
		for point: Vector3 in quad:
			normals.append(Vector3(point.x, 0.0, point.z).normalized())
			uvs.append(Vector2(atan2(point.x, point.z) * MORTAR_RADIUS, point.y) * 2.0)
		_emit_quad(surface, quad, normals, uvs, [color, color, color, color])


## Large flat curb slabs around the mouth, each slightly different in height
## and tilt so the rim does not read as a machined ring.
static func _build_curb_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for slab: Dictionary in _curb_layout():
		_add_stone(surface, slab)
	surface.index()
	return surface.commit()


static func _curb_layout() -> Array[Dictionary]:
	var slabs: Array[Dictionary] = []
	var angle := 0.35
	var end_angle := angle + TAU
	var index := 0
	while angle < end_angle - 0.05:
		var span := 0.7 + MeshMath.hash01(index, 1, 4031) * 0.35
		if end_angle - (angle + span) < 0.45:
			span = end_angle - angle
		var tone := 0.7 + MeshMath.hash01(index, 2, 4032) * 0.3
		slabs.append(
			{
				"a0": angle + 0.008 / CAP_OUTER,
				"a1": angle + span - 0.008 / CAP_OUTER,
				"r0": CAP_INNER + MeshMath.hash01(index, 3, 4033) * 0.012,
				"r1": CAP_OUTER + (MeshMath.hash01(index, 4, 4034) - 0.4) * 0.03,
				"y0": WALL_TOP - 0.005,
				"y1": CAP_TOP + (MeshMath.hash01(index, 5, 4035) - 0.5) * 0.024,
				"tilt": (MeshMath.hash01(index, 6, 4036) - 0.5) * 0.018,
				"round": 0.016,
				"noise": 0.008,
				"faces": [
					Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0),
					Vector2i(1, 1), Vector2i(2, 1),
				],
				"color": Color(tone, tone, tone * 0.96),
				"uv": Vector2(float(index) * 0.29, 0.5),
			}
		)
		angle += span
		index += 1
	return slabs


## Top height of the curb slab under a given yaw angle (for resting props).
static func _curb_top_at(angle: float) -> float:
	for slab: Dictionary in _curb_layout():
		var a := angle
		while a < float(slab["a0"]):
			a += TAU
		if a <= float(slab["a1"]):
			return float(slab["y1"])
	return CAP_TOP


## Annular stone block with rounded arrises. The block is authored in
## unrolled coordinates (s along the arc at r1, q radial, y up); every surface
## vertex is pushed onto a rounded box (clamp to the inner box, then out by the
## rounding radius along the offset), which also gives smooth normals.
## faces lists (axis, side) pairs to emit: axis 0 = arc ends, 1 = radial, 2 = y.
static func _add_stone(surface: SurfaceTool, stone: Dictionary) -> void:
	var a0: float = stone["a0"]
	var r0: float = stone["r0"]
	var r1: float = stone["r1"]
	var y0: float = stone["y0"]
	var y1: float = stone["y1"]
	var length := (float(stone["a1"]) - a0) * r1
	var lo := Vector3(0.0, r0, y0)
	var hi := Vector3(length, r1, y1)
	var rounding := minf(float(stone["round"]), minf(length, minf(r1 - r0, y1 - y0)) * 0.3)
	var axis_coords: Array[PackedFloat32Array] = [
		_rounded_axis(0.0, length, rounding, 0.05),
		_rounded_axis(r0, r1, rounding, 0.05),
		_rounded_axis(y0, y1, rounding, 0.05),
	]
	var tilt: float = stone.get("tilt", 0.0)
	var lean: float = stone.get("lean", 0.0)
	var noise_amount: float = stone.get("noise", 0.005)
	var color: Color = stone["color"]
	var uv_offset: Vector2 = stone["uv"]
	for face: Vector2i in stone["faces"]:
		var axis := face.x
		var u_axis := (axis + 1) % 3
		var v_axis := (axis + 2) % 3
		var fixed := hi[axis] if face.y == 1 else lo[axis]
		var us: PackedFloat32Array = axis_coords[u_axis]
		var vs: PackedFloat32Array = axis_coords[v_axis]
		for i in us.size() - 1:
			for j in vs.size() - 1:
				var corners: Array[Vector3] = []
				var cell: Array[Vector2i] = [
					Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)
				]
				for corner: Vector2i in cell:
					var box := Vector3.ZERO
					box[axis] = fixed
					box[u_axis] = us[corner.x]
					box[v_axis] = vs[corner.y]
					corners.append(box)
				var vertices: Array[Vector3] = []
				var normals: Array[Vector3] = []
				var uvs: Array[Vector2] = []
				for box: Vector3 in corners:
					var inner := box.clamp(lo + Vector3.ONE * rounding, hi - Vector3.ONE * rounding)
					var offset := box - inner
					var local_normal := offset.normalized() if offset.length() > 1e-6 else Vector3(0, 1, 0)
					var rounded := inner + local_normal * rounding
					var angle := a0 + rounded.x / r1
					var radial := Vector3(sin(angle), 0.0, cos(angle))
					var tangent := Vector3(cos(angle), 0.0, -sin(angle))
					var normal := (
						tangent * local_normal.x + radial * local_normal.y + Vector3.UP * local_normal.z
					).normalized()
					var height := rounded.z + tilt * (rounded.x / length - 0.5) * (
						(rounded.z - y0) / (y1 - y0)
					)
					var radius := rounded.y + lean * ((rounded.z - y0) / (y1 - y0) - 0.5)
					var point := radial * radius + Vector3.UP * height
					# Offset the noise field per slab so neighbours do not share pits.
					var noise_at := point + Vector3(uv_offset.x * 7.0, 0.0, uv_offset.y * 5.0)
					point += normal * _weather_noise(noise_at) * noise_amount
					vertices.append(point)
					normals.append(normal)
					var uv := Vector2(rounded.x, rounded.z) if axis != 2 else Vector2(rounded.x, rounded.y)
					if axis == 0:
						uv = Vector2(rounded.y, rounded.z)
					uvs.append(uv * STONE_UV_SCALE + uv_offset)
				# Splash grime: the lowest ~0.3 m of the wall is darker and damper.
				var colors := []
				for vertex: Vector3 in vertices:
					var grime := 0.72 + 0.28 * smoothstep(0.0, 0.32, vertex.y)
					colors.append(Color(color.r * grime, color.g * grime, color.b * grime))
				_emit_quad(surface, vertices, normals, uvs, colors)


## Grid coordinates along one block axis: dense at both ends for the rounded
## arris, sparse in the middle (step) so curved faces stay smooth.
static func _rounded_axis(lo: float, hi: float, rounding: float, step: float) -> PackedFloat32Array:
	var coords := PackedFloat32Array([lo, lo + rounding * 0.35, lo + rounding])
	var inner := hi - lo - rounding * 2.0
	var divisions := maxi(1, ceili(inner / step))
	for division in range(1, divisions):
		coords.append(lo + rounding + inner * float(division) / float(divisions))
	coords.append_array([hi - rounding, hi - rounding * 0.35, hi])
	return coords


## Smooth deterministic surface noise for weathered stone (no RNG state).
static func _weather_noise(point: Vector3) -> float:
	return (
		sin(point.x * 23.1 + point.y * 7.3) * sin(point.y * 19.7 + point.z * 11.9)
		+ 0.5 * sin(point.z * 41.3 + point.x * 37.1)
		+ 0.35 * sin(point.y * 67.0 + point.x * 53.0) * sin(point.z * 59.0 - point.y * 31.0)
	) * 0.6


static func _polar(angle: float, y: float, radius: float) -> Vector3:
	return Vector3(sin(angle) * radius, y, cos(angle) * radius)


## Flat disc over the shaft mouth; the shader draws the deep shaft into it.
static func _build_mouth_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 32
	for segment in segments:
		var a0 := TAU * float(segment) / float(segments)
		var a1 := TAU * float(segment + 1) / float(segments)
		var points := [Vector3.ZERO, _polar(a0, 0.0, MOUTH_RADIUS), _polar(a1, 0.0, MOUTH_RADIUS)]
		var uvs := []
		for point: Vector3 in points:
			uvs.append(Vector2(point.x, point.z))
		var white := Color.WHITE
		_emit_tri(
			surface, points, [Vector3.UP, Vector3.UP, Vector3.UP], uvs, [white, white, white], [0, 1, 2]
		)
	return surface.commit()


# --- Timber ------------------------------------------------------------------


## Posts, ridge beam, knee braces, gable rafters and purlins as one mesh.
static func _build_frame_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertical := Basis(Vector3.UP, Vector3.LEFT, Vector3.BACK)
	for side: float in [-1.0, 1.0]:
		var post_index := 0 if side < 0.0 else 1
		# Posts are set into the ground; the foot is darker from splash and soil.
		_add_board(
			surface,
			Transform3D(vertical, Vector3(side * POST_X, (POST_TOP - 0.06) * 0.5, 0.0)),
			Vector3(POST_TOP + 0.06, POST_SIZE, POST_SIZE),
			Color(0.62, 0.6, 0.55),
			_wood_tone(post_index, 11)
		)
		var brace_from := Vector3(side * POST_X, 1.42, 0.0)
		var brace_to := Vector3(side * 0.42, POST_TOP + 0.01, 0.0)
		_add_beam_between(
			surface, brace_from, brace_to, Vector2(0.065, 0.065), _wood_tone(post_index, 12)
		)
	_add_board(
		surface,
		Transform3D(Basis.IDENTITY, Vector3(0.0, POST_TOP + 0.06, 0.0)),
		Vector3(ROOF_HALF_LENGTH * 2.0 - 0.04, 0.12, 0.12),
		_wood_tone(3, 13),
		_wood_tone(4, 13)
	)
	for slope: float in [-1.0, 1.0]:
		var down := _roof_down(slope)
		var normal := _roof_normal(slope)
		var slope_length := Vector2(ROOF_RUN, ROOF_DROP).length()
		for x: float in [-ROOF_HALF_LENGTH + 0.05, ROOF_HALF_LENGTH - 0.05]:
			var start := ROOF_APEX + Vector3(x, 0.0, 0.0) - normal * (PURLIN_DEPTH + 0.045)
			var basis := Basis(down, normal, down.cross(normal))
			_add_board(
				surface,
				Transform3D(basis, start + down * (slope_length * 0.5 + 0.02)),
				Vector3(slope_length + 0.02, 0.09, 0.06),
				_wood_tone(int(x * 10.0) + 20, int(slope)),
				_wood_tone(int(x * 10.0) + 21, int(slope))
			)
		for along: float in [0.14, 0.55, slope_length - 0.06]:
			var center := ROOF_APEX + down * along - normal * (PURLIN_DEPTH * 0.5)
			_add_board(
				surface,
				Transform3D(Basis(Vector3.RIGHT, normal, Vector3.RIGHT.cross(normal)), center),
				Vector3(ROOF_HALF_LENGTH * 2.0, PURLIN_DEPTH, 0.06),
				_wood_tone(int(along * 10.0), 30 + int(slope)),
				_wood_tone(int(along * 10.0) + 1, 30 + int(slope))
			)
	surface.index()
	return surface.commit()


## Old board roof: uneven widths and lengths, open gaps, slight twist, moss
## and darker rot toward the eaves, plus two ridge cap boards.
static func _build_roof_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var slope_length := Vector2(ROOF_RUN, ROOF_DROP).length()
	for slope: float in [-1.0, 1.0]:
		var down := _roof_down(slope)
		var normal := _roof_normal(slope)
		var x := -ROOF_HALF_LENGTH - 0.03
		var board := 0
		var salt := 50 if slope < 0.0 else 70
		while x < ROOF_HALF_LENGTH + 0.03:
			var width := 0.12 + MeshMath.hash01(board, salt, 4041) * 0.06
			width = minf(width, ROOF_HALF_LENGTH + 0.05 - x)
			if width < 0.05:
				break
			var gap := 0.005 + MeshMath.hash01(board, salt, 4042) * 0.012
			var length := slope_length + 0.06 + (MeshMath.hash01(board, salt, 4043) - 0.5) * 0.09
			var yaw := (MeshMath.hash01(board, salt, 4044) - 0.5) * 0.035
			var twist := (MeshMath.hash01(board, salt, 4045) - 0.5) * 0.05
			var lift := MeshMath.hash01(board, salt, 4046) * 0.006
			var basis := Basis(down, normal, down.cross(normal))
			basis = Basis(normal, yaw) * basis
			basis = Basis(basis.x, twist) * basis
			var center := (
				ROOF_APEX
				+ Vector3(x + width * 0.5, 0.0, 0.0)
				+ down * (length * 0.5 - 0.02)
				+ normal * (BOARD_THICKNESS * 0.5 + lift)
			)
			var tone := 0.66 + MeshMath.hash01(board, salt, 4047) * 0.32
			var top := Color(tone, tone * 0.99, tone * 0.97)
			var eave := Color(tone * 0.6, tone * 0.62, tone * 0.54)
			_add_board(
				surface, Transform3D(basis, center), Vector3(length, BOARD_THICKNESS, width - gap), top, eave
			)
			x += width
			board += 1
		# Ridge cap boards overlap the meeting edges of both slopes.
		var cap_center := (
			ROOF_APEX + down * 0.055 + normal * (BOARD_THICKNESS * 1.5 + 0.004)
		)
		var cap_tone := _wood_tone(90, int(slope))
		_add_board(
			surface,
			Transform3D(Basis(Vector3.RIGHT, normal, Vector3.RIGHT.cross(normal)), cap_center),
			Vector3(ROOF_HALF_LENGTH * 2.0 + 0.1, BOARD_THICKNESS, 0.13),
			cap_tone,
			cap_tone
		)
	surface.index()
	return surface.commit()


static func _roof_down(slope: float) -> Vector3:
	return Vector3(0.0, -ROOF_DROP, ROOF_RUN * slope).normalized()


static func _roof_normal(slope: float) -> Vector3:
	return Vector3(0.0, ROOF_RUN, ROOF_DROP * slope).normalized()


static func _wood_tone(index: int, salt: int) -> Color:
	var tone := 0.74 + MeshMath.hash01(index, salt, 4051) * 0.24
	return Color(tone, tone * 0.98, tone * 0.95)


## Box whose local X is the wood grain. UVs are in metres scaled to the
## hewn-timber tile (one repeat per 2 m along the grain, 0.35 m across), and
## the vertex tone runs from color_start (-X end) to color_end (+X end).
static func _add_board(
	surface: SurfaceTool, xform: Transform3D, size: Vector3, color_start: Color, color_end: Color
) -> void:
	var half := size * 0.5
	for axis in 3:
		for side: float in [-1.0, 1.0]:
			var normal := Vector3.ZERO
			normal[axis] = side
			var u_axis := (axis + 1) % 3
			var v_axis := (axis + 2) % 3
			var corners: Array[Vector3] = []
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var point := Vector3.ZERO
				point[axis] = half[axis] * side
				point[u_axis] = half[u_axis] * corner.x
				point[v_axis] = half[v_axis] * corner.y
				corners.append(point)
			var world_normal := (xform.basis * normal).normalized()
			var points := []
			var normals := []
			var uvs := []
			var colors := []
			for local: Vector3 in corners:
				var uv := Vector2(local.x / TIMBER_GRAIN_REPEAT, (local.y + local.z) / TIMBER_ACROSS_REPEAT)
				if axis == 0:
					uv = Vector2(local.y / TIMBER_ACROSS_REPEAT, local.z / TIMBER_ACROSS_REPEAT)
				var t := clampf(local.x / maxf(size.x, 1e-4) + 0.5, 0.0, 1.0)
				points.append(xform * local)
				normals.append(world_normal)
				uvs.append(uv)
				colors.append(color_start.lerp(color_end, t))
			_emit_quad(surface, points, normals, uvs, colors)


static func _add_beam_between(
	surface: SurfaceTool, from: Vector3, to: Vector3, section: Vector2, color: Color
) -> void:
	var along := (to - from).normalized()
	var side := along.cross(Vector3.BACK).normalized()
	var basis := Basis(along, side, along.cross(side))
	_add_board(
		surface,
		Transform3D(basis, (from + to) * 0.5),
		Vector3(from.distance_to(to), section.x, section.y),
		color,
		color
	)


# --- Windlass, rope and bucket -----------------------------------------------


## Debarked log drum that turns between the posts (clear of both posts), with
## a slightly irregular radius so it reads as a hewn log, not a lathe dowel.
static func _build_roller_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_length := POST_X - POST_SIZE * 0.5 - 0.025
	var sides := 12
	var rings := 8
	var points: Array = []
	for ring in rings + 1:
		var x := -half_length + half_length * 2.0 * float(ring) / float(rings)
		var row: Array[Vector3] = []
		for side in sides:
			var angle := TAU * float(side) / float(sides)
			var radius := ROLLER_RADIUS * (0.94 + MeshMath.hash01(ring, side, 4061) * 0.1)
			row.append(Vector3(x, WINDLASS_Y + cos(angle) * radius, sin(angle) * radius))
		points.append(row)
	for ring in rings:
		var tone := _wood_tone(ring, 61)
		for side in sides:
			var next := (side + 1) % sides
			var quad: Array[Vector3] = [
				points[ring][side], points[ring + 1][side],
				points[ring + 1][next], points[ring][next],
			]
			var normals := []
			var uvs := []
			for index in 4:
				var point := quad[index]
				normals.append((point - Vector3(point.x, WINDLASS_Y, 0.0)).normalized())
				uvs.append(
					Vector2(point.x / TIMBER_GRAIN_REPEAT, float(side + int(index >= 2)) * 0.04)
				)
			_emit_quad(surface, quad, normals, uvs, [tone, tone, tone, tone])
	# End grain discs.
	for end: float in [-1.0, 1.0]:
		var ring_index := 0 if end < 0.0 else rings
		var center := Vector3(end * half_length, WINDLASS_Y, 0.0)
		for side in sides:
			var a: Vector3 = points[ring_index][side]
			var b: Vector3 = points[ring_index][(side + 1) % sides]
			var tri := [center, a, b]
			var cap_normal := Vector3(end, 0.0, 0.0)
			var cap_tone := Color(0.7, 0.66, 0.6)
			var uvs := []
			for point: Vector3 in tri:
				uvs.append(Vector2(point.y, point.z) * 3.0)
			_emit_tri(
				surface, tri, [cap_normal, cap_normal, cap_normal], uvs,
				[cap_tone, cap_tone, cap_tone], [0, 1, 2]
			)
	return surface.commit()


## Iron axle through both posts plus the forged crank arm and handle pin.
static func _build_axle_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var white := Color.WHITE
	var axle_end := POST_X + POST_SIZE * 0.5 + 0.06
	_add_tube(
		surface,
		PackedVector3Array([
			Vector3(-axle_end + 0.02, WINDLASS_Y, 0.0), Vector3(axle_end, WINDLASS_Y, 0.0)
		]),
		AXLE_RADIUS, 8, white, false
	)
	var arm_angle := deg_to_rad(28.0)
	var arm_dir := Vector3(0.0, -cos(arm_angle), sin(arm_angle))
	var arm_start := Vector3(axle_end, WINDLASS_Y, 0.0)
	var arm_end := arm_start + arm_dir * 0.30
	var arm_basis := Basis(arm_dir, Vector3.RIGHT, arm_dir.cross(Vector3.RIGHT))
	_add_board(
		surface,
		Transform3D(arm_basis, (arm_start + arm_end) * 0.5),
		Vector3(0.34, 0.03, 0.04),
		white,
		white
	)
	_add_tube(
		surface,
		PackedVector3Array([arm_end, arm_end + Vector3(0.17, 0.0, 0.0)]),
		0.012, 8, white, false
	)
	# Square bearing plates where the axle passes through the posts.
	for side: float in [-1.0, 1.0]:
		_add_board(
			surface,
			Transform3D(Basis.IDENTITY, Vector3(side * (POST_X + POST_SIZE * 0.5 + 0.004), WINDLASS_Y, 0.0)),
			Vector3(0.008, 0.09, 0.09),
			white,
			white
		)
	return surface.commit()


static func _build_grip_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var arm_angle := deg_to_rad(28.0)
	var arm_end := (
		Vector3(POST_X + POST_SIZE * 0.5 + 0.06, WINDLASS_Y, 0.0)
		+ Vector3(0.0, -cos(arm_angle), sin(arm_angle)) * 0.30
	)
	_add_tube(
		surface,
		PackedVector3Array([arm_end + Vector3(0.03, 0.0, 0.0), arm_end + Vector3(0.155, 0.0, 0.0)]),
		0.024, 10, Color(0.62, 0.55, 0.47), true
	)
	return surface.commit()


## Hemp rope: a tight coil on the drum, then a slack run down to the bucket
## bail. Vertex tone spirals along the tube to suggest twisted strands.
static func _build_rope_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var coil := PackedVector3Array()
	var turns := int(COIL_HALF_WIDTH * 2.0 / (ROPE_RADIUS * 2.2))
	var samples := turns * 14
	var coil_radius := ROLLER_RADIUS + ROPE_RADIUS * 0.9
	var start_angle := 0.0
	var end_angle := TAU * float(turns) + PI * 1.3
	for sample in samples + 1:
		var t := float(sample) / float(samples)
		var angle := lerpf(start_angle, end_angle, t)
		coil.append(
			Vector3(
				lerpf(-COIL_HALF_WIDTH, COIL_HALF_WIDTH, t),
				WINDLASS_Y + cos(angle) * coil_radius,
				sin(angle) * coil_radius
			)
		)
	# Slack run: leaves the drum where the coil ends and sags to the bail.
	var leave := coil[coil.size() - 1]
	var bail := _bail_apex()
	var control := (leave + bail) * 0.5 + Vector3(0.0, -0.16, 0.0)
	for sample in range(1, 17):
		var t := float(sample) / 16.0
		var point := leave.lerp(control, t).lerp(control.lerp(bail, t), t)
		coil.append(point)
	_add_tube(surface, coil, ROPE_RADIUS, 6, Color.WHITE, true)
	return surface.commit()


static func _bucket_base() -> Vector3:
	var angle := atan2(BUCKET_SPOT.x, BUCKET_SPOT.y)
	return Vector3(BUCKET_SPOT.x, _curb_top_at(angle) - 0.004, BUCKET_SPOT.y)


static func _bail_apex() -> Vector3:
	return _bucket_base() + Vector3(0.0, BUCKET_HEIGHT + BUCKET_TOP_RADIUS + 0.006, 0.0)


## Tinned sheet-iron bucket: tapered wall, two pressed stiffening ribs, a
## rolled rim bead, thin wall with a visible inside and floor.
static func _build_bucket_mesh() -> ArrayMesh:
	var base := _bucket_base()
	var h := BUCKET_HEIGHT
	var rb := BUCKET_BOTTOM_RADIUS
	var rt := BUCKET_TOP_RADIUS
	var profile := PackedVector2Array(
		[Vector2(0.0, 0.0), Vector2(rb - 0.006, 0.0), Vector2(rb, 0.008)]
	)
	for rib_y: float in [0.3, 0.62]:
		for offset: float in [-0.018, 0.0, 0.018]:
			var y := h * rib_y + offset
			var r := lerpf(rb, rt, y / h) + (0.004 if offset == 0.0 else 0.0)
			profile.append(Vector2(r, y))
	profile.append(Vector2(rt, h - 0.006))
	for step in 7:
		var angle := -PI * 0.5 + PI * float(step) / 6.0
		profile.append(Vector2(rt + 0.004 + cos(angle) * 0.006, h - 0.006 + sin(angle) * 0.006 + 0.006))
	profile.append(Vector2(rt - 0.004, h - 0.004))
	profile.append(Vector2(rb - 0.004, 0.006))
	profile.append(Vector2(0.0, 0.006))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 20
	for index in profile.size() - 1:
		var p0 := profile[index]
		var p1 := profile[index + 1]
		var direction := (p1 - p0).normalized()
		# Outward normal of the profile edge; the inner wall faces the axis.
		var normal_2d := Vector2(direction.y, -direction.x)
		for segment in segments:
			var a0 := TAU * float(segment) / float(segments)
			var a1 := TAU * float(segment + 1) / float(segments)
			var quad: Array[Vector3] = [
				base + _polar(a0, p0.y, p0.x), base + _polar(a1, p0.y, p0.x),
				base + _polar(a1, p1.y, p1.x), base + _polar(a0, p1.y, p1.x),
			]
			var angles := [a0, a1, a1, a0]
			var heights := [p0.y, p0.y, p1.y, p1.y]
			var normals := []
			var uvs := []
			var colors := []
			var inside := index >= profile.size() - 4
			for corner in 4:
				var angle: float = angles[corner]
				normals.append(
					(Vector3(sin(angle), 0.0, cos(angle)) * normal_2d.x + Vector3.UP * normal_2d.y)
					.normalized()
				)
				uvs.append(Vector2(angle / TAU, float(heights[corner]) / h))
				# Grime and dull oxidation toward the base and inside.
				var grime := (0.55 + 0.45 * clampf(float(heights[corner]) / h, 0.0, 1.0)) * (
					0.55 if inside else 1.0
				)
				colors.append(Color(grime, grime, grime))
			_emit_quad(surface, quad, normals, uvs, colors)
	return surface.commit()


## Wire bail standing up over the bucket, hooked through two riveted ears.
static func _build_bail_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := _bucket_base()
	var rim_y := base.y + BUCKET_HEIGHT - 0.03
	var radius := BUCKET_TOP_RADIUS + 0.006
	# The bail plane faces the drum so the rope pulls along it.
	var across := Vector3(1.0, 0.0, 0.0)
	var arc := PackedVector3Array()
	for step in 17:
		var angle := PI * float(step) / 16.0
		arc.append(
			Vector3(base.x, rim_y, base.z)
			+ across * cos(angle) * radius
			+ Vector3.UP * sin(angle) * (radius + 0.03)
		)
	_add_tube(surface, arc, 0.004, 6, Color(0.7, 0.7, 0.68), false)
	for side: float in [-1.0, 1.0]:
		_add_board(
			surface,
			Transform3D(
				Basis(Vector3.UP, across * side, Vector3.UP.cross(across * side)),
				Vector3(base.x, rim_y - 0.01, base.z) + across * side * (BUCKET_TOP_RADIUS - 0.004)
			),
			Vector3(0.05, 0.004, 0.03),
			Color(0.8, 0.8, 0.78),
			Color(0.8, 0.8, 0.78)
		)
	return surface.commit()


## Swept tube along a polyline. twisted modulates vertex tone in a helix so
## rope reads as laid strands; caps closes both ends.
static func _add_tube(
	surface: SurfaceTool,
	points: PackedVector3Array,
	radius: float,
	sides: int,
	color: Color,
	twisted: bool
) -> void:
	var rings: Array = []
	var reference := Vector3.UP
	var travelled := 0.0
	for index in points.size():
		var tangent: Vector3
		if index == 0:
			tangent = (points[1] - points[0]).normalized()
		elif index == points.size() - 1:
			tangent = (points[index] - points[index - 1]).normalized()
		else:
			tangent = (points[index + 1] - points[index - 1]).normalized()
		if index > 0:
			travelled += points[index].distance_to(points[index - 1])
		if absf(tangent.dot(reference)) > 0.95:
			reference = Vector3.RIGHT if absf(tangent.dot(Vector3.RIGHT)) < 0.9 else Vector3.BACK
		var side_axis := tangent.cross(reference).normalized()
		var up_axis := side_axis.cross(tangent).normalized()
		reference = up_axis
		var ring: Array = []
		for side in sides:
			var angle := TAU * float(side) / float(sides)
			var normal := side_axis * cos(angle) + up_axis * sin(angle)
			var tone := 1.0
			if twisted:
				tone = 0.78 + 0.22 * (0.5 + 0.5 * sin(angle * 3.0 + travelled * 180.0))
			ring.append([points[index] + normal * radius, normal, tone, travelled])
		rings.append(ring)
	for index in rings.size() - 1:
		for side in sides:
			var next := (side + 1) % sides
			var quad: Array = [
				rings[index][side], rings[index + 1][side],
				rings[index + 1][next], rings[index][next],
			]
			var quad_points := []
			var normals := []
			var uvs := []
			var colors := []
			for vertex: Array in quad:
				quad_points.append(vertex[0])
				normals.append(vertex[1])
				var tone: float = vertex[2]
				colors.append(Color(color.r * tone, color.g * tone, color.b * tone))
				uvs.append(Vector2(float(vertex[3]) * 4.0, float(side) / float(sides)))
			_emit_quad(surface, quad_points, normals, uvs, colors)


static func _emit_quad(
	surface: SurfaceTool, points: Array, normals: Array, uvs: Array, colors: Array
) -> void:
	_emit_tri(surface, points, normals, uvs, colors, [0, 1, 2])
	_emit_tri(surface, points, normals, uvs, colors, [0, 2, 3])


## Emits one triangle wound to face along its vertex normals. Godot treats
## clockwise triangles as front faces, and double-sided materials flip the
## normal of back faces, so a wrongly wound triangle would light inverted.
static func _emit_tri(
	surface: SurfaceTool, points: Array, normals: Array, uvs: Array, colors: Array, ids: Array
) -> void:
	var a: Vector3 = points[ids[0]]
	var b: Vector3 = points[ids[1]]
	var c: Vector3 = points[ids[2]]
	var facing: Vector3 = normals[ids[0]] + normals[ids[1]] + normals[ids[2]]
	var order := ids
	if (b - a).cross(c - a).dot(facing) > 0.0:
		order = [ids[0], ids[2], ids[1]]
	for index: int in order:
		surface.set_color(colors[index])
		surface.set_normal(normals[index])
		surface.set_uv(uvs[index])
		surface.add_vertex(points[index])

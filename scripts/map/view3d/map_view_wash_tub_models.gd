class_name MapViewWashTubModels
extends RefCounted

## Hand-built coopered laundry tub for the 3D map view (task R-1190).
##
## WHY: the old yard tub was a smooth cylinder on four thin box legs with a
## bright water disc flush with the rim. From the gameplay camera it read as a
## giant bucket or a baptismal font standing on the forum. This version models
## the ordinary 14th-century Hanseatic washing tub (Ger. Waschzuber, Est. pesupali):
## - tapered coopered body of separate staves with dark seams and a real wall
##   thickness, so looking in shows wet wood rather than a disc;
## - two opposite taller "ear" staves pierced for a carrying pole;
## - split withy (hazel/willow) hoops; iron hoops were rarer and costlier;
## - water well below the rim, dull and grey-green;
## - two plank sleepers keeping the bottom off wet ground, and a washing bat
##   (beetle) leaning on the tub.
## Historical confidence: medium-high (archaeological stave vessels from Hanseatic
## towns and Novgorod; exact tub size is a plausible composite).
## The gameplay footprint stays owned by the map definition; only visual nodes
## change. All geometry is deterministic (hash-seeded) and cached.

const MeshMath := preload("res://scripts/map/view3d/map_view_mesh_builder_math.gd")

const STAVE_COUNT := 16
## Ear staves sit on the local X axis so a pole passes along X.
const EAR_STAVES: Array[int] = [0, 8]
const BODY_BOTTOM := 0.07
const BODY_TOP := 0.50
const RADIUS_BOTTOM := 0.35
const RADIUS_TOP := 0.41
const WALL := 0.024
const SEAM_FRACTION := 0.05
const SEAM_RECESS := 0.005
const EAR_RISE := 0.15
const EAR_HOLE_BOTTOM := 0.03
const EAR_HOLE_TOP := 0.105
const EAR_JAMB_FRACTION := 0.27

## Bottom head sits in the croze a little above the chime.
const HEAD_Y := 0.10
const WATER_Y := 0.39

const HOOPS: Array[Vector2] = [Vector2(0.11, 0.032), Vector2(0.27, 0.030), Vector2(0.445, 0.034)]
const HOOP_PROUD := 0.011
const HOOP_SEGMENTS := 40

const SLEEPER_SIZE := Vector3(0.86, 0.07, 0.11)
const SLEEPER_Z := 0.21

## Washing bat: blade rests on the ground, handle against the rim (front-right).
const BAT_ANGLE := -0.85
const BAT_FOOT_RADIUS := 0.56
const BAT_REST_RADIUS := 0.435
const BAT_REST_Y := 0.50
const BAT_BLADE := Vector3(0.11, 0.30, 0.022)
const BAT_HANDLE_RADIUS := 0.017
const BAT_HANDLE_LENGTH := 0.24

static var _mesh_cache: Dictionary = {}
static var _material_cache: Dictionary = {}


static func add_model(parent: Node3D) -> Node3D:
	var model := Node3D.new()
	model.name = "WashTub"
	model.set_meta(&"production_wash_tub_model", true)
	parent.add_child(model)

	_add_mesh(model, "Staves", _cached("staves", _build_stave_mesh), _wood_material(&"stave"))
	_add_mesh(model, "BottomHead", _cached("head", _build_head_mesh), _wood_material(&"stave"))
	var water := _add_mesh(model, "Water", _cached("water", _build_water_mesh), _water_material())
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_mesh(model, "Hoops", _cached("hoops", _build_hoop_mesh), _withy_material())
	_add_mesh(
		model, "Sleepers", _cached("sleepers", _build_sleeper_mesh), _wood_material(&"sleeper")
	)
	_add_bat(model)
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


## Spruce/pine staves darkened by constant wetting; grain runs along V (up).
static func _wood_material(kind: StringName) -> StandardMaterial3D:
	if not _material_cache.has(kind):
		var noise_seed := 5 if kind == &"stave" else 6
		var material := (
			MapViewMaterials.hewn_timber(false, noise_seed).duplicate() as StandardMaterial3D
		)
		material.albedo_color = Color8(132, 114, 92) if kind == &"stave" else Color8(112, 104, 94)
		material.vertex_color_use_as_albedo = true
		material.uv1_scale = Vector3.ONE
		_material_cache[kind] = material
	return _material_cache[kind]


## Split withy bands: grey-brown bark side out, fully matte.
static func _withy_material() -> StandardMaterial3D:
	if not _material_cache.has(&"withy"):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color8(88, 78, 64)
		material.roughness = 1.0
		material.vertex_color_use_as_albedo = true
		_material_cache[&"withy"] = material
	return _material_cache[&"withy"]


## Dull grey-green wash water; low roughness gives a soft sky sheen without
## turning into the bright disc that made the old tub read as a font.
static func _water_material() -> StandardMaterial3D:
	if not _material_cache.has(&"water"):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color8(70, 78, 70)
		material.roughness = 0.18
		material.metallic_specular = 0.6
		_material_cache[&"water"] = material
	return _material_cache[&"water"]


# --- Body --------------------------------------------------------------------


static func _radius_at(y: float) -> float:
	var t := (y - BODY_BOTTOM) / (BODY_TOP - BODY_BOTTOM)
	return lerpf(RADIUS_BOTTOM, RADIUS_TOP, t)


## Outward cone normal; the body widens upward so the normal tips down slightly.
static func _cone_normal(angle: float, outward: bool) -> Vector3:
	var slope := (RADIUS_TOP - RADIUS_BOTTOM) / (BODY_TOP - BODY_BOTTOM)
	var normal := Vector3(cos(angle), -slope, sin(angle)).normalized()
	return normal if outward else -normal


static func _point(angle: float, y: float, radius: float) -> Vector3:
	return Vector3(cos(angle) * radius, y, sin(angle) * radius)


static func _stave_color(index: int, shade: float = 1.0) -> Color:
	var tone := (0.82 + MeshMath.hash01(index, 23, 911) * 0.22) * shade
	return Color(tone, tone * 0.98, tone * 0.95)


static func _build_stave_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := TAU / float(STAVE_COUNT)
	var seam := step * SEAM_FRACTION
	for index in STAVE_COUNT:
		var a0 := float(index) * step - step * 0.5
		var a1 := a0 + step
		var color := _stave_color(index)
		var seam_color := _stave_color(index, 0.5)
		var top := BODY_TOP + (EAR_RISE if index in EAR_STAVES else 0.0)
		var face0 := a0 + seam * 0.5
		var face1 := a1 - seam * 0.5
		# Outer stave face and the recessed dark seam to the next stave.
		_cone_patch(surface, face0, face1, BODY_BOTTOM, BODY_TOP, 0.0, true, color)
		_cone_patch(
			surface, face1, face1 + seam, BODY_BOTTOM, BODY_TOP, SEAM_RECESS, true, seam_color
		)
		for edge_angle: float in [face1, face1 + seam]:
			_radial_side(surface, edge_angle, BODY_BOTTOM, BODY_TOP, 0.0, SEAM_RECESS, seam_color)
		# Inner wall shows wet wood above the water instead of a flat cap.
		_cone_patch(surface, a0, a1, HEAD_Y, BODY_TOP, WALL, false, _stave_color(index, 0.78))
		# Chime: underside ring of the stave ends.
		_ring_patch(surface, a0, a1, BODY_BOTTOM, WALL, false, color)
		if index in EAR_STAVES:
			_add_ear(surface, a0, a1, color)
		else:
			_ring_patch(surface, a0, a1, top, WALL, true, _stave_color(index, 1.08))
	surface.generate_tangents()
	return surface.commit()


## Ear stave above the rim: two jambs and a bridge leave a hole for the pole.
static func _add_ear(surface: SurfaceTool, a0: float, a1: float, color: Color) -> void:
	var jamb := (a1 - a0) * EAR_JAMB_FRACTION
	var hole_bottom := BODY_TOP + EAR_HOLE_BOTTOM
	var hole_top := BODY_TOP + EAR_HOLE_TOP
	var ear_top := BODY_TOP + EAR_RISE
	var spans: Array[Vector4] = [
		# x/y = angle span, z/w = height span
		Vector4(a0, a1, BODY_TOP, hole_bottom),
		Vector4(a0, a0 + jamb, hole_bottom, hole_top),
		Vector4(a1 - jamb, a1, hole_bottom, hole_top),
		Vector4(a0, a1, hole_top, ear_top),
	]
	for span in spans:
		_cone_patch(surface, span.x, span.y, span.z, span.w, 0.0, true, color)
		_cone_patch(surface, span.x, span.y, span.z, span.w, WALL, false, color)
	# Stave side edges above the rim are open to view.
	for edge_angle: float in [a0, a1]:
		_radial_side(surface, edge_angle, BODY_TOP, ear_top, 0.0, WALL, color)
	# Hole jambs, sill, and lintel.
	_radial_side(surface, a0 + jamb, hole_bottom, hole_top, 0.0, WALL, color)
	_radial_side(surface, a1 - jamb, hole_bottom, hole_top, 0.0, WALL, color)
	_ring_patch(surface, a0 + jamb, a1 - jamb, hole_bottom, WALL, true, color)
	_ring_patch(surface, a0 + jamb, a1 - jamb, hole_top, WALL, false, color)
	_ring_patch(surface, a0, a1, ear_top, WALL, true, _stave_color(0, 1.08))


## Quad on the tapered body surface. `inset` moves the patch inward from the
## outer skin; `outward` selects which side faces the viewer.
static func _cone_patch(
	surface: SurfaceTool,
	a0: float,
	a1: float,
	y0: float,
	y1: float,
	inset: float,
	outward: bool,
	color: Color
) -> void:
	var points := [
		_point(a0, y0, _radius_at(y0) - inset),
		_point(a1, y0, _radius_at(y0) - inset),
		_point(a1, y1, _radius_at(y1) - inset),
		_point(a0, y1, _radius_at(y1) - inset),
	]
	var normals := [
		_cone_normal(a0, outward),
		_cone_normal(a1, outward),
		_cone_normal(a1, outward),
		_cone_normal(a0, outward),
	]
	var u0 := a0 * RADIUS_TOP * 3.0
	var u1 := a1 * RADIUS_TOP * 3.0
	var uvs := [
		Vector2(u0, y0 * 2.0), Vector2(u1, y0 * 2.0), Vector2(u1, y1 * 2.0), Vector2(u0, y1 * 2.0)
	]
	_emit_quad(surface, points, normals, uvs, [color, color, color, color])


## Horizontal annulus slice across the wall thickness at height `y`.
static func _ring_patch(
	surface: SurfaceTool, a0: float, a1: float, y: float, wall: float, up: bool, color: Color
) -> void:
	var outer := _radius_at(y)
	var inner := outer - wall
	var points := [
		_point(a0, y, outer), _point(a1, y, outer), _point(a1, y, inner), _point(a0, y, inner)
	]
	var normal := Vector3.UP if up else Vector3.DOWN
	var uvs := [Vector2(a0, 0.0), Vector2(a1, 0.0), Vector2(a1, 0.05), Vector2(a0, 0.05)]
	_emit_quad(surface, points, [normal, normal, normal, normal], uvs, [color, color, color, color])


## Radial face at `angle` spanning the wall between two insets (0 = outer skin).
## The face normal is chosen by the emitter, so either side may be visible.
static func _radial_side(
	surface: SurfaceTool,
	angle: float,
	y0: float,
	y1: float,
	inset_a: float,
	inset_b: float,
	color: Color
) -> void:
	var points := [
		_point(angle, y0, _radius_at(y0) - inset_a),
		_point(angle, y0, _radius_at(y0) - inset_b),
		_point(angle, y1, _radius_at(y1) - inset_b),
		_point(angle, y1, _radius_at(y1) - inset_a),
	]
	# Seam steps face the gap; ear edges face away from the stave centre. Both
	# cases are covered by emitting the face double-sided.
	var tangent := Vector3(-sin(angle), 0.0, cos(angle))
	var uvs := [
		Vector2(0.0, y0 * 2.0),
		Vector2(0.05, y0 * 2.0),
		Vector2(0.05, y1 * 2.0),
		Vector2(0.0, y1 * 2.0)
	]
	var colors := [color, color, color, color]
	_emit_quad(surface, points, [tangent, tangent, tangent, tangent], uvs, colors)
	_emit_quad(surface, points, [-tangent, -tangent, -tangent, -tangent], uvs, colors)


## Bottom head: boards running along X, visible through the water only at the edge.
static func _build_head_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radius := _radius_at(HEAD_Y) - WALL
	var segments := 32
	for index in segments:
		var a0 := TAU * float(index) / float(segments)
		var a1 := TAU * float(index + 1) / float(segments)
		var points := [
			Vector3(0.0, HEAD_Y, 0.0), _point(a1, HEAD_Y, radius), _point(a0, HEAD_Y, radius)
		]
		var color := _stave_color(index % 5, 0.62)
		var uvs := [
			Vector2(0.5, 0.5),
			Vector2(points[1].x, points[1].z) * 2.0,
			Vector2(points[2].x, points[2].z) * 2.0
		]
		_emit_tri(
			surface,
			points,
			[Vector3.UP, Vector3.UP, Vector3.UP],
			uvs,
			[color, color, color],
			[0, 1, 2]
		)
	return surface.commit()


static func _build_water_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radius := _radius_at(WATER_Y) - WALL - 0.002
	var segments := 32
	for index in segments:
		var a0 := TAU * float(index) / float(segments)
		var a1 := TAU * float(index + 1) / float(segments)
		var points := [
			Vector3(0.0, WATER_Y, 0.0), _point(a1, WATER_Y, radius), _point(a0, WATER_Y, radius)
		]
		_emit_tri(
			surface,
			points,
			[Vector3.UP, Vector3.UP, Vector3.UP],
			[Vector2.ZERO, Vector2.ZERO, Vector2.ZERO],
			[Color.WHITE, Color.WHITE, Color.WHITE],
			[0, 1, 2]
		)
	return surface.commit()


# --- Hoops and stand ----------------------------------------------------------


## Flat withy bands proud of the staves; each band shows its outer face and
## both edges, the inner face is hidden against the wood.
static func _build_hoop_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for hoop_index in HOOPS.size():
		var hoop: Vector2 = HOOPS[hoop_index]
		var y0 := hoop.x - hoop.y * 0.5
		var y1 := hoop.x + hoop.y * 0.5
		for index in HOOP_SEGMENTS:
			var a0 := TAU * float(index) / float(HOOP_SEGMENTS)
			var a1 := TAU * float(index + 1) / float(HOOP_SEGMENTS)
			# Uneven split rods: small deterministic thickness and tone wobble.
			var wobble := MeshMath.hash01(index, hoop_index, 4471) * 0.004
			var tone := 0.80 + MeshMath.hash01(index, hoop_index, 7213) * 0.26
			var color := Color(tone, tone, tone)
			var proud := HOOP_PROUD + wobble
			var o00 := _point(a0, y0, _radius_at(y0) + proud)
			var o10 := _point(a1, y0, _radius_at(y0) + proud)
			var o11 := _point(a1, y1, _radius_at(y1) + proud)
			var o01 := _point(a0, y1, _radius_at(y1) + proud)
			var colors := [color, color, color, color]
			var uvs := [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
			_emit_quad(
				surface,
				[o00, o10, o11, o01],
				[
					_cone_normal(a0, true),
					_cone_normal(a1, true),
					_cone_normal(a1, true),
					_cone_normal(a0, true)
				],
				uvs,
				colors
			)
			for edge in [[y1, Vector3.UP], [y0, Vector3.DOWN]]:
				var y: float = edge[0]
				var normal: Vector3 = edge[1]
				_emit_quad(
					surface,
					[
						_point(a0, y, _radius_at(y) - 0.001),
						_point(a1, y, _radius_at(y) - 0.001),
						_point(a1, y, _radius_at(y) + proud),
						_point(a0, y, _radius_at(y) + proud),
					],
					[normal, normal, normal, normal],
					uvs,
					colors
				)
	return surface.commit()


static func _build_sleeper_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		var center := Vector3(0.0, SLEEPER_SIZE.y * 0.5, SLEEPER_Z * side)
		var tone := 0.9 if side < 0.0 else 1.0
		_add_box(surface, center, SLEEPER_SIZE, Color(tone, tone, tone))
	surface.generate_tangents()
	return surface.commit()


static func _add_box(surface: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var h := size * 0.5
	var faces := [
		[
			Vector3.UP,
			Vector3(-h.x, h.y, -h.z),
			Vector3(h.x, h.y, -h.z),
			Vector3(h.x, h.y, h.z),
			Vector3(-h.x, h.y, h.z)
		],
		[
			Vector3.DOWN,
			Vector3(-h.x, -h.y, -h.z),
			Vector3(h.x, -h.y, -h.z),
			Vector3(h.x, -h.y, h.z),
			Vector3(-h.x, -h.y, h.z)
		],
		[
			Vector3.RIGHT,
			Vector3(h.x, -h.y, -h.z),
			Vector3(h.x, h.y, -h.z),
			Vector3(h.x, h.y, h.z),
			Vector3(h.x, -h.y, h.z)
		],
		[
			Vector3.LEFT,
			Vector3(-h.x, -h.y, -h.z),
			Vector3(-h.x, h.y, -h.z),
			Vector3(-h.x, h.y, h.z),
			Vector3(-h.x, -h.y, h.z)
		],
		[
			Vector3.BACK,
			Vector3(-h.x, -h.y, h.z),
			Vector3(h.x, -h.y, h.z),
			Vector3(h.x, h.y, h.z),
			Vector3(-h.x, h.y, h.z)
		],
		[
			Vector3.FORWARD,
			Vector3(-h.x, -h.y, -h.z),
			Vector3(h.x, -h.y, -h.z),
			Vector3(h.x, h.y, -h.z),
			Vector3(-h.x, h.y, -h.z)
		],
	]
	for face in faces:
		var normal: Vector3 = face[0]
		var points := [center + face[1], center + face[2], center + face[3], center + face[4]]
		# Grain along the long X axis for top/side faces.
		var uvs := [
			Vector2(points[0].x * 2.0, points[0].y + points[0].z),
			Vector2(points[1].x * 2.0, points[1].y + points[1].z),
			Vector2(points[2].x * 2.0, points[2].y + points[2].z),
			Vector2(points[3].x * 2.0, points[3].y + points[3].z),
		]
		_emit_quad(
			surface, points, [normal, normal, normal, normal], uvs, [color, color, color, color]
		)


## Washing bat (beetle) used to beat linen: flat blade down, round handle up.
static func _add_bat(model: Node3D) -> void:
	var direction := Vector3(cos(BAT_ANGLE), 0.0, sin(BAT_ANGLE))
	var foot := direction * BAT_FOOT_RADIUS
	var rest := direction * BAT_REST_RADIUS + Vector3(0.0, BAT_REST_Y, 0.0)
	var axis := (rest - foot).normalized()
	var side := Vector3.UP.cross(direction).normalized()
	var face := side.cross(axis).normalized()
	var bat := Node3D.new()
	bat.name = "WashingBat"
	bat.transform = Transform3D(Basis(side, axis, face), foot)
	model.add_child(bat)

	var blade := _add_mesh(
		bat, "Blade", _cached("bat_blade", _build_bat_blade_mesh), _wood_material(&"sleeper")
	)
	blade.position = Vector3(0.0, BAT_BLADE.y * 0.5, 0.0)
	var handle := _add_mesh(
		bat, "Handle", _cached("bat_handle", _build_bat_handle_mesh), _wood_material(&"sleeper")
	)
	handle.position = Vector3(0.0, BAT_BLADE.y + BAT_HANDLE_LENGTH * 0.5, 0.0)


static func _build_bat_blade_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(surface, Vector3.ZERO, BAT_BLADE, Color(0.95, 0.93, 0.9))
	surface.generate_tangents()
	return surface.commit()


static func _build_bat_handle_mesh() -> ArrayMesh:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = BAT_HANDLE_RADIUS * 0.85
	cylinder.bottom_radius = BAT_HANDLE_RADIUS
	cylinder.height = BAT_HANDLE_LENGTH
	cylinder.radial_segments = 10
	cylinder.rings = 1
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, cylinder.get_mesh_arrays())
	return mesh


# --- Emission -----------------------------------------------------------------


static func _emit_quad(
	surface: SurfaceTool, points: Array, normals: Array, uvs: Array, colors: Array
) -> void:
	_emit_tri(surface, points, normals, uvs, colors, [0, 1, 2])
	_emit_tri(surface, points, normals, uvs, colors, [0, 2, 3])


## Emits one triangle wound to face along its vertex normals (Godot front faces
## are clockwise), matching MapViewWellModels so culling stays correct.
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

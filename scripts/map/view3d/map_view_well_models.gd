class_name MapViewWellModels
extends RefCounted

## Hand-built medieval draw-well for the 3D map view.
##
## WHY: the previous primitive stack (solid capped cylinder, two sticks, and a
## flat beam) read as a small table from the dimetric camera. This model rebuilds
## the prop as the Rataskaev-type well documented for 1340s Reval: an open
## coursed-stone shaft with visible water below the curb, a timber windlass with
## crank and rope-hung bucket, and a gabled plank roof on two posts. The gameplay
## footprint stays owned by the map definition; only the visual nodes change.

const MeshMath := preload("res://scripts/map/view3d/map_view_mesh_builder_math.gd")

const SHAFT_OUTER_BOTTOM := 0.57
const SHAFT_OUTER_TOP := 0.54
const SHAFT_INNER := 0.44
const SHAFT_HEIGHT := 0.62
const CURB_OUTER := 0.62
const CURB_HEIGHT := 0.08
const CURB_TOP := SHAFT_HEIGHT + CURB_HEIGHT
const RING_SEGMENTS := 12

const POST_OFFSET := 0.72
const POST_HEIGHT := 1.62
const WINDLASS_Y := 1.18
const ROOF_BASE := Vector2(1.9, 1.3)
const ROOF_PITCH := 0.75

## Dark inner shaft tone; the water disc sits well below the curb so the opening
## reads as depth instead of a filled stone tub from the top-down camera.
const SHAFT_INTERIOR_COLOR := Color(0.30, 0.28, 0.26)

static var _mesh_cache: Dictionary = {}


static func add_model(parent: Node3D) -> Node3D:
	var model := Node3D.new()
	model.name = "WellModel"
	model.set_meta(&"production_well_model", true)
	parent.add_child(model)

	_add_stone_ring(model, "Shaft", SHAFT_OUTER_BOTTOM, SHAFT_OUTER_TOP, SHAFT_INNER, 0.0, SHAFT_HEIGHT, 17)
	_add_stone_ring(model, "Curb", CURB_OUTER, CURB_OUTER, SHAFT_INNER, SHAFT_HEIGHT, CURB_TOP, 41)
	MapViewMeshBuilderPrimitives.cylinder(model, "Water", SHAFT_INNER - 0.03, 0.04, Vector3(0.0, 0.30, 0.0), &"water_highlight")

	for post_x in [-POST_OFFSET, POST_OFFSET]:
		var post_name := "PostLeft" if post_x < 0.0 else "PostRight"
		MapViewMeshBuilderPrimitives.box(model, post_name, Vector3(0.12, POST_HEIGHT, 0.12), Vector3(post_x, POST_HEIGHT * 0.5, 0.0), &"timber")

	_add_windlass(model)
	_add_hanging_bucket(model)

	MapViewMeshBuilderPrimitives.box(model, "RidgeBeam", Vector3(1.7, 0.08, 0.08), Vector3(0.0, POST_HEIGHT - 0.04, 0.0), &"timber")
	var roof := MeshInstance3D.new()
	roof.name = "Roof"
	roof.mesh = MapViewMeshBuilderPrimitives.gabled_roof_mesh(ROOF_BASE, true, 0.12, true, ROOF_PITCH)
	roof.position = Vector3(0.0, POST_HEIGHT, 0.0)
	roof.material_override = MapViewMeshBuilderPrimitives.role_material(&"roof")
	model.add_child(roof)
	return model


## Coursed annular masonry: tapered outer wall, dark inner wall, and a flat top
## bed. Unlike a capped CylinderMesh the opening stays hollow, which is what
## sells the well from the overhead camera.
static func _add_stone_ring(
	parent: Node3D,
	node_name: String,
	outer_bottom: float,
	outer_top: float,
	inner_radius: float,
	y0: float,
	y1: float,
	seed_salt: int
) -> void:
	var cache_key := "well_ring:%.3f:%.3f:%.3f:%.3f:%.3f:%d" % [outer_bottom, outer_top, inner_radius, y0, y1, seed_salt]
	if not _mesh_cache.has(cache_key):
		_mesh_cache[cache_key] = _build_ring_mesh(outer_bottom, outer_top, inner_radius, y0, y1, seed_salt)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = _mesh_cache[cache_key]
	instance.material_override = MapViewMeshBuilderPrimitives.role_material(&"stone")
	parent.add_child(instance)


static func _build_ring_mesh(
	outer_bottom: float,
	outer_top: float,
	inner_radius: float,
	y0: float,
	y1: float,
	seed_salt: int
) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := TAU / float(RING_SEGMENTS)
	var slope := (outer_top - outer_bottom) / (y1 - y0)
	for segment in RING_SEGMENTS:
		var a0 := float(segment) * step
		var a1 := a0 + step
		var mid := (a0 + a1) * 0.5
		var radial := Vector3(sin(mid), 0.0, cos(mid))
		# Deterministic per-course tone shifts keep the masonry coursed instead of
		# a smooth concrete pipe; same hash inputs, same mesh on every build.
		var tone := 0.80 + MeshMath.hash01(segment, seed_salt, 911) * 0.26
		var outer_normal := (radial - Vector3.UP * slope).normalized()
		_ring_quad(
			surface,
			[
				_ring_point(a0, y0, outer_bottom),
				_ring_point(a1, y0, outer_bottom),
				_ring_point(a1, y1, outer_top),
				_ring_point(a0, y1, outer_top),
			],
			[Vector2(a0, y0), Vector2(a1, y0), Vector2(a1, y1), Vector2(a0, y1)],
			outer_normal,
			Color(tone, tone, tone)
		)
		_ring_quad(
			surface,
			[
				_ring_point(a1, y0, inner_radius),
				_ring_point(a0, y0, inner_radius),
				_ring_point(a0, y1, inner_radius),
				_ring_point(a1, y1, inner_radius),
			],
			[Vector2(a1, y0), Vector2(a0, y0), Vector2(a0, y1), Vector2(a1, y1)],
			-radial,
			SHAFT_INTERIOR_COLOR
		)
		_ring_quad(
			surface,
			[
				_ring_point(a0, y1, outer_top),
				_ring_point(a1, y1, outer_top),
				_ring_point(a1, y1, inner_radius),
				_ring_point(a0, y1, inner_radius),
			],
			[
				Vector2(sin(a0) * outer_top, cos(a0) * outer_top),
				Vector2(sin(a1) * outer_top, cos(a1) * outer_top),
				Vector2(sin(a1) * inner_radius, cos(a1) * inner_radius),
				Vector2(sin(a0) * inner_radius, cos(a0) * inner_radius),
			],
			Vector3.UP,
			Color(tone, tone, tone).lightened(0.06)
		)
	return surface.commit()


static func _ring_quad(surface: SurfaceTool, vertices: Array, uvs: Array, normal: Vector3, color: Color) -> void:
	for index in [0, 1, 2, 0, 2, 3]:
		surface.set_color(color)
		surface.set_normal(normal)
		surface.set_uv(uvs[index])
		surface.add_vertex(vertices[index])


static func _ring_point(angle: float, y: float, radius: float) -> Vector3:
	return Vector3(sin(angle) * radius, y, cos(angle) * radius)


static func _add_windlass(model: Node3D) -> void:
	var span := POST_OFFSET * 2.0 + 0.18
	var roller := MeshInstance3D.new()
	roller.name = "Windlass"
	var roller_mesh := CylinderMesh.new()
	roller_mesh.top_radius = 0.085
	roller_mesh.bottom_radius = 0.085
	roller_mesh.height = span
	roller_mesh.radial_segments = 10
	roller.mesh = roller_mesh
	roller.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	roller.position = Vector3(0.0, WINDLASS_Y, 0.0)
	roller.material_override = MapViewMeshBuilderPrimitives.role_material(&"wood")
	model.add_child(roller)

	# Wrapped rope bulge on the roller middle, hemp-toned like cordage.
	var wrap := MeshInstance3D.new()
	wrap.name = "RopeWrap"
	var wrap_mesh := CylinderMesh.new()
	wrap_mesh.top_radius = 0.105
	wrap_mesh.bottom_radius = 0.105
	wrap_mesh.height = 0.20
	wrap_mesh.radial_segments = 10
	wrap.mesh = wrap_mesh
	wrap.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	wrap.position = Vector3(0.0, WINDLASS_Y, 0.0)
	wrap.material_override = MapViewMeshBuilderPrimitives.role_material(&"hay")
	model.add_child(wrap)

	MapViewMeshBuilderPrimitives.box(model, "CrankArm", Vector3(0.05, 0.26, 0.05), Vector3(POST_OFFSET + 0.12, WINDLASS_Y - 0.10, 0.0), &"wood")
	MapViewMeshBuilderPrimitives.box(model, "CrankHandle", Vector3(0.16, 0.05, 0.05), Vector3(POST_OFFSET + 0.20, WINDLASS_Y - 0.22, 0.0), &"metal")


static func _add_hanging_bucket(model: Node3D) -> void:
	var rope_bottom := 0.78
	var rope_top := WINDLASS_Y - 0.09
	MapViewMeshBuilderPrimitives.cylinder(model, "Rope", 0.018, rope_top - rope_bottom, Vector3(0.0, (rope_top + rope_bottom) * 0.5, 0.0), &"hay")

	var bucket := MeshInstance3D.new()
	bucket.name = "Bucket"
	var bucket_mesh := CylinderMesh.new()
	bucket_mesh.top_radius = 0.13
	bucket_mesh.bottom_radius = 0.10
	bucket_mesh.height = 0.17
	bucket_mesh.radial_segments = 8
	bucket.mesh = bucket_mesh
	bucket.position = Vector3(0.0, rope_bottom - 0.09, 0.0)
	bucket.material_override = MapViewMeshBuilderPrimitives.role_material(&"wood")
	model.add_child(bucket)

	var handle := MeshInstance3D.new()
	handle.name = "BucketHandle"
	var handle_mesh := TorusMesh.new()
	handle_mesh.inner_radius = 0.095
	handle_mesh.outer_radius = 0.11
	handle_mesh.rings = 8
	handle_mesh.ring_segments = 12
	handle.mesh = handle_mesh
	handle.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	handle.position = Vector3(0.0, rope_bottom + 0.02, 0.0)
	handle.material_override = MapViewMeshBuilderPrimitives.role_material(&"metal")
	model.add_child(handle)

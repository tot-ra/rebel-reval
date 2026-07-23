class_name MapViewMeshBuilderPrimitives
extends RefCounted

## Low-level mesh primitives shared by 3D map view builders.
const BarrelMeshes := preload("res://scripts/map/view3d/map_view_barrel_meshes.gd")
const FoliageMeshes := preload("res://scripts/map/view3d/map_view_foliage_meshes.gd")
const TreeMeshes := preload("res://scripts/map/view3d/map_view_tree_meshes.gd")
const AncientOakMeshes := preload("res://scripts/map/view3d/map_view_ancient_oak_meshes.gd")
const MeshMath := preload("res://scripts/map/view3d/map_view_mesh_builder_math.gd")

## Procedural primitives are immutable after construction. Reusing their Mesh
## resources avoids rebuilding identical roofs and foliage for every streamed
## chunk and adjoining-district preview.

static var _mesh_cache: Dictionary = {}

static func hash01(x: int, y: int, noise_seed: int) -> float:
	return MeshMath.hash01(x, y, noise_seed)


static func multi_mesh(
	name: String,
	mesh: Mesh,
	transforms: Array[Transform3D],
	colors: Array[Color],
	material: Material,
	mesh_lift: Vector3
) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = name
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for index in transforms.size():
		var transform := transforms[index]
		transform.origin += mesh_lift * transform.basis.get_scale().y
		multi.set_instance_transform(index, transform)
		multi.set_instance_color(index, colors[index])
	instance.multimesh = multi
	instance.material_override = material
	return instance




static func building_cell_rects(definition: MapDefinition) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var scale := MapViewBridge.world_scale(definition.cell_size)
	for building in definition.buildings:
		var footprint: Rect2 = building["footprint"]
		rects.append(Rect2(footprint.position * scale, footprint.size * scale))
	return rects




static func cell_blocked(cell: Vector2i, rects: Array[Rect2]) -> bool:
	var center := Vector2(cell) + Vector2(0.5, 0.5)
	for rect in rects:
		if rect.grow(0.5).has_point(center):
			return true
	return false


static func unit_roof_prism() -> ArrayMesh:
	const CACHE_KEY := &"unit_roof_prism"
	if _mesh_cache.has(CACHE_KEY):
		return _mesh_cache[CACHE_KEY]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(-0.5, 0.0, -0.5)
	var b := Vector3(0.5, 0.0, -0.5)
	var c := Vector3(0.5, 0.0, 0.5)
	var d := Vector3(-0.5, 0.0, 0.5)
	var r0 := Vector3(-0.5, 1.0, 0.0)
	var r1 := Vector3(0.5, 1.0, 0.0)
	MapViewMeshBuilderPrimitives.add_roof_quad(surface, a, b, r1, r0, Vector3(0.0, 0.5, -1.0).normalized())
	MapViewMeshBuilderPrimitives.add_roof_quad(surface, r0, r1, c, d, Vector3(0.0, 0.5, 1.0).normalized())
	MapViewMeshBuilderPrimitives.add_roof_triangle(surface, a, r0, d, Vector3.LEFT)
	MapViewMeshBuilderPrimitives.add_roof_triangle(surface, b, c, r1, Vector3.RIGHT)
	var mesh := surface.commit()
	_mesh_cache[CACHE_KEY] = mesh
	return mesh




static func placed(spot: Vector2, scale: float, lift: Vector3, yaw: float) -> Transform3D:
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
	return Transform3D(basis, Vector3(spot.x, 0.0, spot.y) + lift)


## Compatibility facade for callers that still consume foliage through the
## shared primitives API. Implementations live in MapViewFoliageMeshes.
static func spruce_canopy_mesh() -> ArrayMesh:
	return FoliageMeshes.spruce_canopy_mesh()


static func leaf_canopy_mesh() -> ArrayMesh:
	return FoliageMeshes.leaf_canopy_mesh()


static func pine_canopy_mesh() -> ArrayMesh:
	return FoliageMeshes.pine_canopy_mesh()


static func column_canopy_mesh() -> ArrayMesh:
	return FoliageMeshes.column_canopy_mesh()


static func canopy_mesh_for(silhouette: StringName) -> ArrayMesh:
	return FoliageMeshes.canopy_mesh_for(silhouette)


static func tree_wood_mesh(species: StringName) -> ArrayMesh:
	return TreeMeshes.wood_mesh(species)


static func tree_canopy_mesh(species: StringName) -> ArrayMesh:
	return TreeMeshes.canopy_mesh(species)


static func tree_fruit_mesh(species: StringName) -> ArrayMesh:
	return TreeMeshes.fruit_mesh(species)


static func tree_geometry_stats(species: StringName) -> Dictionary:
	return TreeMeshes.geometry_stats(species)


static func ancient_oak_wood_mesh() -> ArrayMesh:
	return AncientOakMeshes.wood_mesh()


static func ancient_oak_canopy_mesh() -> ArrayMesh:
	return AncientOakMeshes.canopy_mesh()


static func ancient_oak_moss_mesh() -> ArrayMesh:
	return AncientOakMeshes.moss_mesh()


static func ancient_oak_geometry_stats() -> Dictionary:
	return AncientOakMeshes.geometry_stats()


static func add_chimney_stack(parent: Node3D, node_name: String, outer_size: float, height: float, position: Vector3) -> Node3D:
	var chimney := Node3D.new()
	chimney.name = node_name
	chimney.position = position
	parent.add_child(chimney)

	var wall := MapViewMeshBuilderConfig.CHIMNEY_WALL_THICKNESS
	var inner := outer_size - wall * 2.0
	var center_y := height * 0.5
	var half_outer := outer_size * 0.5
	var stone := MapViewMaterials.role(&"stone")

	for side in [
		{"name": "WallN", "size": Vector3(outer_size, height, wall), "pos": Vector3(0.0, center_y, half_outer - wall * 0.5)},
		{"name": "WallS", "size": Vector3(outer_size, height, wall), "pos": Vector3(0.0, center_y, -(half_outer - wall * 0.5))},
		{"name": "WallE", "size": Vector3(wall, height, inner), "pos": Vector3(half_outer - wall * 0.5, center_y, 0.0)},
		{"name": "WallW", "size": Vector3(wall, height, inner), "pos": Vector3(-(half_outer - wall * 0.5), center_y, 0.0)},
	]:
		var segment := MeshInstance3D.new()
		segment.name = side["name"]
		var segment_mesh := BoxMesh.new()
		segment_mesh.size = side["size"]
		segment.mesh = segment_mesh
		segment.position = side["pos"]
		segment.material_override = stone
		chimney.add_child(segment)

	var flue_height := height - MapViewMeshBuilderConfig.CHIMNEY_FLUE_LIP
	var flue := MeshInstance3D.new()
	flue.name = "Flue"
	var flue_mesh := BoxMesh.new()
	flue_mesh.size = Vector3(inner, flue_height, inner)
	flue.mesh = flue_mesh
	flue.position = Vector3(0.0, flue_height * 0.5, 0.0)
	# Deep void - the flue interior must stay darker than glazed windows.
	flue.material_override = MapViewMaterials.role(&"ink")
	chimney.add_child(flue)
	return chimney


## Every house earns a stone chimney near one ridge end. Smoke is optional and
## schedule-driven per building id: tint, wind bias, and day/night emission all
## vary deterministically.


static func gabled_roof_mesh(
	base: Vector2,
	ridge_along_x: bool = true,
	overhang: float = -1.0,
	close_gables: bool = true,
	pitch: float = -1.0
) -> ArrayMesh:
	if overhang < 0.0:
		overhang = MapViewMeshBuilderConfig.ROOF_OVERHANG
	if pitch < 0.0:
		pitch = MapViewMeshBuilderConfig.ROOF_PITCH
	var cache_key := "gabled_roof:%s:%s:%.3f:%s:%.3f" % [base, ridge_along_x, overhang, close_gables, pitch]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]
	var half_w := base.x * 0.5 + overhang
	var half_d := base.y * 0.5 + overhang
	var narrow := half_d if ridge_along_x else half_w
	var rise := narrow * pitch
	var slope_length := sqrt(narrow * narrow + rise * rise)
	var ridge_half := half_w if ridge_along_x else half_d

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	if ridge_along_x:
		var a := Vector3(-half_w, 0.0, -half_d)
		var b := Vector3(half_w, 0.0, -half_d)
		var c := Vector3(half_w, 0.0, half_d)
		var d := Vector3(-half_w, 0.0, half_d)
		var r0 := Vector3(-half_w, rise, 0.0)
		var r1 := Vector3(half_w, rise, 0.0)
		var north := Vector3(0.0, half_d, -rise).normalized()
		var south := Vector3(0.0, half_d, rise).normalized()
		# U follows the ridge; V always runs from ridge (0) down to eave
		# (slope_length). Reed/shingle patterns therefore follow water runoff rather
		# than the arbitrary world-Y projection used by the former mapping.
		MapViewMeshBuilderPrimitives.add_roof_quad_uv(
			surface, a, b, r1, r0, north,
			Vector2(-ridge_half, slope_length), Vector2(ridge_half, slope_length),
			Vector2(ridge_half, 0.0), Vector2(-ridge_half, 0.0)
		)
		MapViewMeshBuilderPrimitives.add_roof_quad_uv(
			surface, r0, r1, c, d, south,
			Vector2(-ridge_half, 0.0), Vector2(ridge_half, 0.0),
			Vector2(ridge_half, slope_length), Vector2(-ridge_half, slope_length)
		)
		if close_gables:
			MapViewMeshBuilderPrimitives.add_roof_triangle(surface, a, r0, d, Vector3.LEFT)
			MapViewMeshBuilderPrimitives.add_roof_triangle(surface, b, c, r1, Vector3.RIGHT)
	else:
		var a := Vector3(-half_w, 0.0, -half_d)
		var b := Vector3(half_w, 0.0, -half_d)
		var c := Vector3(half_w, 0.0, half_d)
		var d := Vector3(-half_w, 0.0, half_d)
		var r0 := Vector3(0.0, rise, -half_d)
		var r1 := Vector3(0.0, rise, half_d)
		var west := Vector3(-rise, half_w, 0.0).normalized()
		var east := Vector3(rise, half_w, 0.0).normalized()
		MapViewMeshBuilderPrimitives.add_roof_quad_uv(
			surface, a, r0, r1, d, west,
			Vector2(-ridge_half, slope_length), Vector2(-ridge_half, 0.0),
			Vector2(ridge_half, 0.0), Vector2(ridge_half, slope_length)
		)
		MapViewMeshBuilderPrimitives.add_roof_quad_uv(
			surface, r0, b, c, r1, east,
			Vector2(-ridge_half, 0.0), Vector2(-ridge_half, slope_length),
			Vector2(ridge_half, slope_length), Vector2(ridge_half, 0.0)
		)
		if close_gables:
			MapViewMeshBuilderPrimitives.add_roof_triangle(surface, a, b, r0, Vector3.FORWARD)
			MapViewMeshBuilderPrimitives.add_roof_triangle(surface, d, r1, c, Vector3.BACK)
	var mesh := surface.commit()
	_mesh_cache[cache_key] = mesh
	return mesh


static func add_roof_quad_uv(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	normal: Vector3,
	uv_a: Vector2,
	uv_b: Vector2,
	uv_c: Vector2,
	uv_d: Vector2
) -> void:
	var vertices := [a, b, c, a, c, d]
	var uvs := [uv_a, uv_b, uv_c, uv_a, uv_c, uv_d]
	for index in vertices.size():
		surface.set_normal(normal)
		surface.set_uv(uvs[index])
		surface.add_vertex(vertices[index])




static func add_roof_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	for vertex in [a, b, c, a, c, d]:
		surface.set_normal(normal)
		surface.set_uv(Vector2(vertex.x + vertex.z, vertex.y))
		surface.add_vertex(vertex)




static func add_roof_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	for vertex in [a, b, c]:
		surface.set_normal(normal)
		surface.set_uv(Vector2(vertex.x + vertex.z, vertex.y))
		surface.add_vertex(vertex)


## Filled round-headed opening used by civic arcades and portals. The mesh has
## two faces because facade relief can be seen from either side in editor orbit.
static func arched_panel_mesh(
	width: float,
	height: float,
	depth: float = 0.06,
	segments: int = 12
) -> ArrayMesh:
	var safe_width := maxf(width, 0.2)
	var safe_height := maxf(height, safe_width * 0.55)
	var safe_segments := maxi(segments, 4)
	var cache_key := "arched_panel:%.3f:%.3f:%.3f:%d" % [safe_width, safe_height, depth, safe_segments]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]

	var radius := minf(safe_width * 0.5, safe_height * 0.58)
	var spring_y := safe_height - radius
	var points: Array[Vector2] = [Vector2(-safe_width * 0.5, 0.0), Vector2(safe_width * 0.5, 0.0)]
	for index in safe_segments + 1:
		var angle := PI * float(index) / float(safe_segments)
		points.append(Vector2(cos(angle) * radius, spring_y + sin(angle) * radius))

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector2(0.0, safe_height * 0.42)
	for index in points.size():
		var next := (index + 1) % points.size()
		_add_flat_triangle(surface, center, points[next], points[index], -depth * 0.5, Vector3.FORWARD)
		_add_flat_triangle(surface, center, points[index], points[next], depth * 0.5, Vector3.BACK)
	var mesh := surface.commit()
	_mesh_cache[cache_key] = mesh
	return mesh


## Semicircular masonry band. Straight jambs are authored separately so one
## band can top a window-sized arcade bay or a wider functional door portal.
static func arch_band_mesh(
	outer_radius: float,
	thickness: float,
	depth: float = 0.12,
	segments: int = 12
) -> ArrayMesh:
	var safe_outer := maxf(outer_radius, 0.2)
	var safe_thickness := clampf(thickness, 0.05, safe_outer * 0.72)
	var safe_segments := maxi(segments, 4)
	var cache_key := "arch_band:%.3f:%.3f:%.3f:%d" % [safe_outer, safe_thickness, depth, safe_segments]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]

	var inner_radius := safe_outer - safe_thickness
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in safe_segments:
		var angle_a := PI * float(index) / float(safe_segments)
		var angle_b := PI * float(index + 1) / float(safe_segments)
		var outer_a := Vector2(cos(angle_a), sin(angle_a)) * safe_outer
		var outer_b := Vector2(cos(angle_b), sin(angle_b)) * safe_outer
		var inner_a := Vector2(cos(angle_a), sin(angle_a)) * inner_radius
		var inner_b := Vector2(cos(angle_b), sin(angle_b)) * inner_radius
		_add_flat_quad(surface, outer_a, inner_a, inner_b, outer_b, -depth * 0.5, Vector3.FORWARD)
		_add_flat_quad(surface, outer_b, inner_b, inner_a, outer_a, depth * 0.5, Vector3.BACK)
	var mesh := surface.commit()
	_mesh_cache[cache_key] = mesh
	return mesh


static func _add_flat_triangle(
	surface: SurfaceTool,
	a: Vector2,
	b: Vector2,
	c: Vector2,
	z: float,
	normal: Vector3
) -> void:
	for point in [a, b, c]:
		surface.set_normal(normal)
		surface.set_uv(point)
		surface.add_vertex(Vector3(point.x, point.y, z))


static func _add_flat_quad(
	surface: SurfaceTool,
	a: Vector2,
	b: Vector2,
	c: Vector2,
	d: Vector2,
	z: float,
	normal: Vector3
) -> void:
	_add_flat_triangle(surface, a, b, c, z, normal)
	_add_flat_triangle(surface, a, c, d, z, normal)


static func box(parent: Node3D, name: String, size: Vector3, position: Vector3, role: StringName) -> void:
	var instance := MeshInstance3D.new()
	instance.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = MapViewMeshBuilderPrimitives.role_material(role)
	parent.add_child(instance)


## Compatibility facade for prop builders. Barrel-specific geometry and cache
## ownership live in MapViewBarrelMeshes.
static func barrel_stave_mesh(radius: float, height: float) -> ArrayMesh:
	return BarrelMeshes.barrel_stave_mesh(radius, height)


static func barrel_head_mesh(radius: float, thickness: float) -> CylinderMesh:
	return BarrelMeshes.barrel_head_mesh(radius, thickness)


static func barrel_hoop_mesh(radius: float) -> TorusMesh:
	return BarrelMeshes.barrel_hoop_mesh(radius)


static func cylinder(
	parent: Node3D,
	name: String,
	radius: float,
	height: float,
	position: Vector3,
	role: StringName,
	side_axis: bool = false
) -> void:
	var instance := MeshInstance3D.new()
	instance.name = name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	instance.mesh = mesh
	instance.position = position
	if side_axis:
		instance.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	instance.material_override = MapViewMeshBuilderPrimitives.role_material(role)
	parent.add_child(instance)




static func sphere(
	parent: Node3D,
	name: String,
	radius: float,
	position: Vector3,
	role: StringName,
	scale: Vector3 = Vector3.ONE
) -> void:
	var instance := MeshInstance3D.new()
	instance.name = name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	instance.mesh = mesh
	instance.position = position
	instance.scale = scale
	instance.material_override = MapViewMeshBuilderPrimitives.role_material(role)
	parent.add_child(instance)




static func role_material(role: StringName) -> StandardMaterial3D:
	match role:
		&"roof":
			return MapViewMaterials.roof(MapVisualStyle.role_color(&"roof", MapVisualStyle.TARGET_CLEAN_PAINTED, MapVisualStyle.TIME_DAY))
		_:
			return MapViewMaterials.role(role)


static func grass_tuft_mesh() -> ArrayMesh:
	return FoliageMeshes.grass_tuft_mesh()


static func reed_stem_mesh() -> ArrayMesh:
	return FoliageMeshes.reed_stem_mesh()


static func cattail_cluster_mesh() -> ArrayMesh:
	return FoliageMeshes.cattail_cluster_mesh()


static func clover_patch_mesh() -> ArrayMesh:
	return FoliageMeshes.clover_patch_mesh()

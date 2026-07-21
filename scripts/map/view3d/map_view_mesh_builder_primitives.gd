class_name MapViewMeshBuilderPrimitives
extends RefCounted

## Low-level mesh primitives shared by 3D map view builders.
## Procedural primitives are immutable after construction. Reusing their Mesh
## resources avoids rebuilding identical roofs and foliage for every streamed
## chunk and adjoining-district preview.

static var _mesh_cache: Dictionary = {}

static func hash01(x: int, y: int, noise_seed: int) -> float:
	var hashed := ((x * 374761393) + (y * 668265263) + noise_seed * 69069) & 0x7fffffff
	hashed = (hashed ^ (hashed >> 13)) * 1274126177 & 0x7fffffff
	return float(hashed % 100000) / 99999.0


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


## Three stacked, slightly offset cone tiers with a small top spike: a spruce
## silhouette with layered skirts instead of a single flat cone. Local y spans
## 0 (skirt) to about 2.9 (tip).


static func spruce_canopy_mesh() -> ArrayMesh:
	const CACHE_KEY := &"spruce_canopy"
	if _mesh_cache.has(CACHE_KEY):
		return _mesh_cache[CACHE_KEY]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tiers := [
		[0.95, 0.0, 1.2],
		[0.74, 0.7, 1.1],
		[0.52, 1.4, 1.0],
		[0.28, 2.1, 0.8],
	]
	for tier_index in tiers.size():
		var tier: Array = tiers[tier_index]
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = tier[0]
		cone.height = tier[2]
		cone.radial_segments = 9
		cone.rings = 1
		var offset := Vector3(
			(MapViewMeshBuilderPrimitives.hash01(tier_index, 1, 97) - 0.5) * 0.12,
			float(tier[1]) + float(tier[2]) * 0.5,
			(MapViewMeshBuilderPrimitives.hash01(tier_index, 5, 131) - 0.5) * 0.12
		)
		surface.append_from(cone, 0, Transform3D(Basis.IDENTITY, offset))
	var mesh := surface.commit()
	_mesh_cache[CACHE_KEY] = mesh
	return mesh


## Broadleaf canopy: several overlapping lobes merged into one lumpy crown
## centered near the local origin, replacing the single smooth sphere.


static func leaf_canopy_mesh() -> ArrayMesh:
	const CACHE_KEY := &"leaf_canopy"
	if _mesh_cache.has(CACHE_KEY):
		return _mesh_cache[CACHE_KEY]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lobes := [
		[Vector3(0.0, 0.1, 0.0), 0.72],
		[Vector3(0.42, -0.08, 0.14), 0.5],
		[Vector3(-0.38, -0.02, 0.3), 0.54],
		[Vector3(0.08, 0.42, -0.3), 0.5],
		[Vector3(-0.12, 0.34, 0.34), 0.46],
		[Vector3(0.16, -0.18, -0.4), 0.48],
	]
	for lobe: Array in lobes:
		var sphere := SphereMesh.new()
		sphere.radius = lobe[1]
		sphere.height = float(lobe[1]) * 1.8
		sphere.radial_segments = 10
		sphere.rings = 6
		surface.append_from(sphere, 0, Transform3D(Basis.IDENTITY, lobe[0]))
	var mesh := surface.commit()
	_mesh_cache[CACHE_KEY] = mesh
	return mesh




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


static func gabled_roof_mesh(base: Vector2, ridge_along_x: bool = true) -> ArrayMesh:
	var cache_key := "gabled_roof:%s:%s" % [base, ridge_along_x]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]
	var half_w := base.x * 0.5 + MapViewMeshBuilderConfig.ROOF_OVERHANG
	var half_d := base.y * 0.5 + MapViewMeshBuilderConfig.ROOF_OVERHANG
	var narrow := half_d if ridge_along_x else half_w
	var rise := narrow * MapViewMeshBuilderConfig.ROOF_PITCH

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
		MapViewMeshBuilderPrimitives.add_roof_quad(surface, a, b, r1, r0, north)
		MapViewMeshBuilderPrimitives.add_roof_quad(surface, r0, r1, c, d, south)
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
		MapViewMeshBuilderPrimitives.add_roof_quad(surface, a, r0, r1, d, west)
		MapViewMeshBuilderPrimitives.add_roof_quad(surface, r0, b, c, r1, east)
		MapViewMeshBuilderPrimitives.add_roof_triangle(surface, a, b, r0, Vector3.FORWARD)
		MapViewMeshBuilderPrimitives.add_roof_triangle(surface, d, r1, c, Vector3.BACK)
	var mesh := surface.commit()
	_mesh_cache[cache_key] = mesh
	return mesh




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




static func box(parent: Node3D, name: String, size: Vector3, position: Vector3, role: StringName) -> void:
	var instance := MeshInstance3D.new()
	instance.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = MapViewMeshBuilderPrimitives.role_material(role)
	parent.add_child(instance)



## Coopered barrel body with a convex bilge and recessed seams between vertical
## staves. It intentionally has no caps: separate inset heads leave a visible lip.
static func barrel_stave_mesh(radius: float, height: float) -> ArrayMesh:
	var cache_key := "barrel_staves:%.4f:%.4f" % [radius, height]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]

	const STAVE_COUNT := 14
	const SEAM_FRACTION := 0.065
	const SEAM_RECESS := 0.965
	var profile: Array[Vector2] = [
		Vector2(0.0, 0.82),
		Vector2(0.08, 0.86),
		Vector2(0.23, 0.95),
		Vector2(0.42, 1.0),
		Vector2(0.58, 1.0),
		Vector2(0.77, 0.95),
		Vector2(0.92, 0.86),
		Vector2(1.0, 0.82),
	]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stave_step := TAU / float(STAVE_COUNT)
	var seam_width := stave_step * SEAM_FRACTION
	for stave_index in STAVE_COUNT:
		var sector_start := float(stave_index) * stave_step
		var face_start := sector_start + seam_width * 0.5
		var face_end := sector_start + stave_step - seam_width * 0.5
		var seam_start := face_end
		var seam_end := sector_start + stave_step + seam_width * 0.5
		# Gentle deterministic tone changes keep individual staves legible without
		# introducing per-instance resources or noisy randomized geometry.
		var tone := 0.86 + hash01(stave_index, 19, 617) * 0.18
		var stave_color := Color(tone, tone, tone)
		for profile_index in profile.size() - 1:
			var lower := profile[profile_index]
			var upper := profile[profile_index + 1]
			_barrel_profile_quad(
				surface,
				face_start,
				face_end,
				lower,
				upper,
				radius,
				height,
				1.0,
				stave_color
			)
			_barrel_profile_quad(
				surface,
				seam_start,
				seam_end,
				lower,
				upper,
				radius,
				height,
				SEAM_RECESS,
				Color(0.38, 0.34, 0.30)
			)
			_barrel_seam_bevel(
				surface,
				seam_start,
				lower,
				upper,
				radius,
				height,
				false
			)
			_barrel_seam_bevel(
				surface,
				seam_end,
				lower,
				upper,
				radius,
				height,
				true
			)
	var mesh := surface.commit()
	_mesh_cache[cache_key] = mesh
	return mesh


static func barrel_head_mesh(radius: float, thickness: float) -> CylinderMesh:
	var cache_key := "barrel_head:%.4f:%.4f" % [radius, thickness]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = thickness
	mesh.radial_segments = 14
	mesh.rings = 1
	_mesh_cache[cache_key] = mesh
	return mesh


static func barrel_hoop_mesh(radius: float) -> TorusMesh:
	var cache_key := "barrel_hoop:%.4f" % radius
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.003
	mesh.outer_radius = radius + 0.015
	mesh.rings = 14
	mesh.ring_segments = 4
	_mesh_cache[cache_key] = mesh
	return mesh


static func _barrel_profile_quad(
	surface: SurfaceTool,
	angle_start: float,
	angle_end: float,
	lower: Vector2,
	upper: Vector2,
	radius: float,
	height: float,
	radial_scale: float,
	color: Color
) -> void:
	var lower_radius := radius * lower.y * radial_scale
	var upper_radius := radius * upper.y * radial_scale
	var vertices := [
		_barrel_point(angle_start, lower.x * height, lower_radius),
		_barrel_point(angle_end, lower.x * height, lower_radius),
		_barrel_point(angle_end, upper.x * height, upper_radius),
		_barrel_point(angle_start, upper.x * height, upper_radius),
	]
	var mid_angle := (angle_start + angle_end) * 0.5
	var radial := Vector3(sin(mid_angle), 0.0, cos(mid_angle))
	var slope := (upper_radius - lower_radius) / ((upper.x - lower.x) * height)
	var normal := (radial - Vector3.UP * slope).normalized()
	# Rotating the plank pattern makes its grain and board boundaries run along
	# the vertical staves instead of wrapping around the vessel like masonry.
	var circumference_scale := 14.0 / TAU
	var uvs := [
		Vector2(lower.x * 1.6, angle_start * circumference_scale),
		Vector2(lower.x * 1.6, angle_end * circumference_scale),
		Vector2(upper.x * 1.6, angle_end * circumference_scale),
		Vector2(upper.x * 1.6, angle_start * circumference_scale),
	]
	_barrel_quad(surface, vertices, uvs, normal, color)


static func _barrel_seam_bevel(
	surface: SurfaceTool,
	angle: float,
	lower: Vector2,
	upper: Vector2,
	radius: float,
	height: float,
	reverse: bool
) -> void:
	var outer_lower := _barrel_point(angle, lower.x * height, radius * lower.y)
	var outer_upper := _barrel_point(angle, upper.x * height, radius * upper.y)
	var inner_lower := _barrel_point(angle, lower.x * height, radius * lower.y * 0.965)
	var inner_upper := _barrel_point(angle, upper.x * height, radius * upper.y * 0.965)
	var vertices := [outer_lower, inner_lower, inner_upper, outer_upper]
	if reverse:
		vertices = [inner_lower, outer_lower, outer_upper, inner_upper]
	var tangent := Vector3(cos(angle), 0.0, -sin(angle)) * (-1.0 if reverse else 1.0)
	_barrel_quad(
		surface,
		vertices,
		[Vector2.ZERO, Vector2.ONE, Vector2.ONE, Vector2.ZERO],
		tangent,
		Color(0.58, 0.52, 0.46)
	)


static func _barrel_quad(
	surface: SurfaceTool,
	vertices: Array,
	uvs: Array,
	normal: Vector3,
	color: Color
) -> void:
	for index in [0, 1, 2, 0, 2, 3]:
		surface.set_color(color)
		surface.set_normal(normal)
		surface.set_uv(uvs[index])
		surface.add_vertex(vertices[index])


static func _barrel_point(angle: float, y: float, radius: float) -> Vector3:
	return Vector3(sin(angle) * radius, y, cos(angle) * radius)



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
	const CACHE_KEY := &"grass_tuft"
	if _mesh_cache.has(CACHE_KEY):
		return _mesh_cache[CACHE_KEY]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blade_count := 7
	for blade in blade_count:
		var yaw := TAU * float(blade) / float(blade_count) + MapViewMeshBuilderPrimitives.hash01(blade, 3, 17) * 0.9
		var lean := 0.10 + MapViewMeshBuilderPrimitives.hash01(blade, 7, 29) * 0.22
		var blade_height := 0.26 + MapViewMeshBuilderPrimitives.hash01(blade, 11, 41) * 0.24
		var half_width := 0.020 + MapViewMeshBuilderPrimitives.hash01(blade, 13, 53) * 0.012
		var direction := Vector3(sin(yaw), 0.0, cos(yaw))
		var side := Vector3(cos(yaw), 0.0, -sin(yaw))
		var root_center := direction * 0.03
		var tip := root_center + direction * lean + Vector3(0.0, blade_height, 0.0)
		var mid := root_center + direction * lean * 0.45 + Vector3(0.0, blade_height * 0.55, 0.0)
		var normal := Vector3.UP.cross(side).normalized() + Vector3(0.0, 0.4, 0.0)
		normal = normal.normalized()
		var quad := [
			[root_center - side * half_width, Vector2(0.0, 0.0)],
			[root_center + side * half_width, Vector2(1.0, 0.0)],
			[mid + side * half_width * 0.55, Vector2(1.0, 0.55)],
			[mid - side * half_width * 0.55, Vector2(0.0, 0.55)],
		]
		for index in [0, 1, 2, 0, 2, 3]:
			surface.set_normal(normal)
			surface.set_uv(quad[index][1])
			surface.add_vertex(quad[index][0])
		var tip_triangle := [
			[mid - side * half_width * 0.55, Vector2(0.0, 0.55)],
			[mid + side * half_width * 0.55, Vector2(1.0, 0.55)],
			[tip, Vector2(0.5, 1.0)],
		]
		for point in tip_triangle:
			surface.set_normal(normal)
			surface.set_uv(point[1])
			surface.add_vertex(point[0])
	var mesh := surface.commit()
	_mesh_cache[CACHE_KEY] = mesh
	return mesh


static func reed_stem_mesh() -> ArrayMesh:
	const CACHE_KEY := &"reed_stem"
	if _mesh_cache.has(CACHE_KEY):
		return _mesh_cache[CACHE_KEY]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side_sign in [-1.0, 1.0]:
		var half_width := 0.018
		var quad := [
			[Vector3(-half_width * side_sign, 0.0, 0.0), Vector2(0.0, 0.0)],
			[Vector3(half_width * side_sign, 0.0, 0.0), Vector2(1.0, 0.0)],
			[Vector3(half_width * side_sign * 0.6, 0.95, 0.0), Vector2(1.0, 1.0)],
			[Vector3(-half_width * side_sign * 0.6, 0.95, 0.0), Vector2(0.0, 1.0)],
		]
		for index in [0, 1, 2, 0, 2, 3]:
			surface.set_normal(Vector3(0.0, 0.0, 1.0))
			surface.set_uv(quad[index][1])
			surface.add_vertex(quad[index][0])
	var mesh := surface.commit()
	_mesh_cache[CACHE_KEY] = mesh
	return mesh


## A riverbank cattail cluster distinct from the simple authored reed stem:
## crossed narrow leaves surround several tall stalks with dark seed heads.
## Vertex colors keep the seed heads brown while the instance tint varies the
## green foliage. UV.y still runs root-to-tip for the shared wind shader.
static func cattail_cluster_mesh() -> ArrayMesh:
	const CACHE_KEY := &"cattail_cluster"
	if _mesh_cache.has(CACHE_KEY):
		return _mesh_cache[CACHE_KEY]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stalks := [
		[Vector2(-0.12, 0.02), 0.92],
		[Vector2(0.04, -0.08), 1.08],
		[Vector2(0.15, 0.08), 0.84],
	]
	for stalk_index in stalks.size():
		var stalk: Array = stalks[stalk_index]
		var stalk_position: Vector2 = stalk[0]
		var base := Vector3(stalk_position.x, 0.0, stalk_position.y)
		var height: float = stalk[1]
		for yaw in [0.0, PI * 0.5]:
			var side := Vector3(cos(yaw), 0.0, sin(yaw)) * 0.018
			var stem_top := base + Vector3(0.0, height - 0.16, 0.0)
			var stem := [
				[base - side, Vector2(0.0, 0.0)],
				[base + side, Vector2(1.0, 0.0)],
				[stem_top + side, Vector2(1.0, 0.82)],
				[stem_top - side, Vector2(0.0, 0.82)],
			]
			for index in [0, 1, 2, 0, 2, 3]:
				surface.set_color(Color.WHITE)
				surface.set_normal(Vector3(cos(yaw), 0.15, sin(yaw)).normalized())
				surface.set_uv(stem[index][1])
				surface.add_vertex(stem[index][0])
			var head_bottom := base + Vector3(0.0, height - 0.18, 0.0)
			var head_top := base + Vector3(0.0, height, 0.0)
			var head_side := side * 2.25
			var head := [
				[head_bottom - head_side, Vector2(0.0, 0.82)],
				[head_bottom + head_side, Vector2(1.0, 0.82)],
				[head_top + head_side * 0.72, Vector2(1.0, 1.0)],
				[head_top - head_side * 0.72, Vector2(0.0, 1.0)],
			]
			for index in [0, 1, 2, 0, 2, 3]:
				# HDR vertex tint counterbalances the green blade base color and
				# yields a readable dark-brown seed head after instance tinting.
				surface.set_color(Color(2.25, 0.72, 0.28))
				surface.set_normal(Vector3(cos(yaw), 0.0, sin(yaw)))
				surface.set_uv(head[index][1])
				surface.add_vertex(head[index][0])
	for leaf_index in 7:
		var yaw := TAU * float(leaf_index) / 7.0 + hash01(leaf_index, 5, 301) * 0.45
		var direction := Vector3(sin(yaw), 0.0, cos(yaw))
		var side := Vector3(cos(yaw), 0.0, -sin(yaw))
		var leaf_height := 0.48 + hash01(leaf_index, 7, 307) * 0.32
		var lean := 0.18 + hash01(leaf_index, 11, 311) * 0.18
		var half_width := 0.022 + hash01(leaf_index, 13, 313) * 0.012
		var root := direction * 0.035
		var middle := root + direction * lean * 0.42 + Vector3.UP * leaf_height * 0.58
		var tip := root + direction * lean + Vector3.UP * leaf_height
		var leaf := [
			[root - side * half_width, Vector2(0.0, 0.0)],
			[root + side * half_width, Vector2(1.0, 0.0)],
			[middle + side * half_width * 0.55, Vector2(1.0, 0.58)],
			[middle - side * half_width * 0.55, Vector2(0.0, 0.58)],
		]
		for index in [0, 1, 2, 0, 2, 3]:
			surface.set_color(Color(0.82, 1.0, 0.66))
			surface.set_normal((direction + Vector3.UP * 0.2).normalized())
			surface.set_uv(leaf[index][1])
			surface.add_vertex(leaf[index][0])
		for point in [leaf[3], leaf[2], [tip, Vector2(0.5, 1.0)]]:
			surface.set_color(Color(0.82, 1.0, 0.66))
			surface.set_normal((direction + Vector3.UP * 0.2).normalized())
			surface.set_uv(point[1])
			surface.add_vertex(point[0])
	var mesh := surface.commit()
	_mesh_cache[CACHE_KEY] = mesh
	return mesh


static func clover_patch_mesh() -> ArrayMesh:
	const CACHE_KEY := &"clover_patch"
	if _mesh_cache.has(CACHE_KEY):
		return _mesh_cache[CACHE_KEY]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for leaf in 3:
		var yaw := TAU * float(leaf) / 3.0
		var direction := Vector3(cos(yaw), 0.0, sin(yaw))
		var side := Vector3(-sin(yaw), 0.0, cos(yaw))
		var center := direction * 0.08
		var tip := center + direction * 0.16 + Vector3(0.0, 0.02, 0.0)
		var quad := [
			[center - side * 0.05, Vector2(0.0, 0.0)],
			[center + side * 0.05, Vector2(1.0, 0.0)],
			[tip + side * 0.03, Vector2(1.0, 1.0)],
			[tip - side * 0.03, Vector2(0.0, 1.0)],
		]
		for index in [0, 1, 2, 0, 2, 3]:
			surface.set_normal(Vector3.UP)
			surface.set_uv(quad[index][1])
			surface.add_vertex(quad[index][0])
	var mesh := surface.commit()
	_mesh_cache[CACHE_KEY] = mesh
	return mesh


## Landscape ring outside the playable rectangle. Each authored side may
## continue town silhouettes, open water, or an explicit woodland apron with a
## treeline. Unlisted sides render nothing so maps define their own horizon.

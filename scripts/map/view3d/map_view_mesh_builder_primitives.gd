class_name MapViewMeshBuilderPrimitives
extends RefCounted

## Low-level mesh primitives shared by 3D map view builders.

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
	return surface.commit()




static func placed(spot: Vector2, scale: float, lift: Vector3, yaw: float) -> Transform3D:
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
	return Transform3D(basis, Vector3(spot.x, 0.0, spot.y) + lift)


## Three stacked, slightly offset cone tiers with a small top spike: a spruce
## silhouette with layered skirts instead of a single flat cone. Local y spans
## 0 (skirt) to about 2.9 (tip).


static func spruce_canopy_mesh() -> ArrayMesh:
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
	return surface.commit()


## Broadleaf canopy: several overlapping lobes merged into one lumpy crown
## centered near the local origin, replacing the single smooth sphere.


static func leaf_canopy_mesh() -> ArrayMesh:
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
	return surface.commit()




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
	return surface.commit()




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
	return surface.commit()


static func reed_stem_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		var half_width := 0.018
		var quad := [
			[Vector3(-half_width * side, 0.0, 0.0), Vector2(0.0, 0.0)],
			[Vector3(half_width * side, 0.0, 0.0), Vector2(1.0, 0.0)],
			[Vector3(half_width * side * 0.6, 0.95, 0.0), Vector2(1.0, 1.0)],
			[Vector3(-half_width * side * 0.6, 0.95, 0.0), Vector2(0.0, 1.0)],
		]
		for index in [0, 1, 2, 0, 2, 3]:
			surface.set_normal(Vector3(0.0, 0.0, 1.0))
			surface.set_uv(quad[index][1])
			surface.add_vertex(quad[index][0])
	return surface.commit()


static func clover_patch_mesh() -> ArrayMesh:
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
	return surface.commit()


## Landscape ring outside the playable rectangle. Each authored side may
## continue town silhouettes, open water, or an explicit woodland apron with a
## treeline. Unlisted sides render nothing so maps define their own horizon.

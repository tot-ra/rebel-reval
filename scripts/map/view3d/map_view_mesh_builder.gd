class_name MapViewMeshBuilder
extends RefCounted

## Converts immutable MapDefinition data into 3D view geometry (P0-052).
## View only: no collision shapes, physics bodies, or navigation are generated
## here - the logic plane keeps owning all gameplay geometry. All sizes are in
## world units where one logic cell equals one unit (MapViewBridge).

const WATER_RECESS := 0.08
const ROOF_PITCH := 0.9
const ROOF_OVERHANG := 0.15
const CAP_HEIGHT := 0.12
const CAP_OVERHANG := 0.05

## Fallback wall heights in logic pixels when a building omits wall_height,
## matching the observed defaults in the shipped definitions.
const DEFAULT_WALL_HEIGHT_PX := {
	MapTypes.BUILDING_KIND_HOUSE: 64.0,
	MapTypes.BUILDING_KIND_WALL: 48.0,
	MapTypes.BUILDING_KIND_INTERIOR_WALL: 56.0,
	MapTypes.BUILDING_KIND_INTERIOR_BLOCK: 48.0,
}

const DEFAULT_WALL_COLOR := Color(0.46, 0.44, 0.40)
const DEFAULT_ROOF_COLOR := Color(0.24, 0.20, 0.16)


## One MeshInstance3D per used terrain: every cell of that terrain becomes a
## textured ground quad. Water-family cells sit slightly recessed so shorelines
## read in the dimetric view without touching walkability.
static func build_terrain(definition: MapDefinition, grid: MapTerrainGrid) -> Node3D:
	var root := Node3D.new()
	root.name = "Terrain"
	for terrain_id in grid.used_terrain_ids():
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var height := -WATER_RECESS if MapViewMaterials.WATER_TERRAINS.has(terrain_id) else 0.0
		for y in grid.size_cells.y:
			for x in grid.size_cells.x:
				if grid.get_terrain(Vector2i(x, y)) != terrain_id:
					continue
				_add_ground_quad(surface, x, y, height)
		var instance := MeshInstance3D.new()
		instance.name = "Terrain_%s" % String(terrain_id)
		instance.mesh = surface.commit()
		instance.material_override = MapViewMaterials.terrain(terrain_id, definition.seed)
		root.add_child(instance)
	return root


## Building footprint plus per-kind height rules become a wall prism; houses
## get a gabled roof, walls and interior masses get a flat stone cap.
static func build_building(building: Dictionary, cell_size: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Building_%s" % String(building["id"])
	var scale := MapViewBridge.world_scale(cell_size)
	var footprint: Rect2 = building["footprint"]
	var size := footprint.size * scale
	var kind: StringName = building.get("kind", MapTypes.BUILDING_KIND_HOUSE)
	var height_px := float(building.get("wall_height", DEFAULT_WALL_HEIGHT_PX.get(kind, 64.0)))
	var height := height_px * scale
	var center := footprint.get_center() * scale
	root.position = Vector3(center.x, 0.0, center.y)

	var walls := MeshInstance3D.new()
	walls.name = "Walls"
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(size.x, height, size.y)
	walls.mesh = wall_mesh
	walls.position = Vector3(0.0, height * 0.5, 0.0)
	walls.material_override = MapViewMaterials.wall(building.get("wall_color", DEFAULT_WALL_COLOR))
	root.add_child(walls)

	if kind == MapTypes.BUILDING_KIND_HOUSE:
		var roof := MeshInstance3D.new()
		roof.name = "Roof"
		roof.mesh = _gabled_roof_mesh(size)
		roof.position = Vector3(0.0, height, 0.0)
		roof.material_override = MapViewMaterials.roof(building.get("roof_color", DEFAULT_ROOF_COLOR))
		root.add_child(roof)
	else:
		var cap := MeshInstance3D.new()
		cap.name = "Cap"
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(size.x + CAP_OVERHANG * 2.0, CAP_HEIGHT, size.y + CAP_OVERHANG * 2.0)
		cap.mesh = cap_mesh
		cap.position = Vector3(0.0, height + CAP_HEIGHT * 0.5, 0.0)
		cap.material_override = MapViewMaterials.wall(
			Color(building.get("wall_color", DEFAULT_WALL_COLOR)).lightened(0.12)
		)
		root.add_child(cap)
	return root


## Parametric primitive assembly per prop kind, anchored at the shared
## definition position so the logic plane and the view agree on placement.
static func build_prop(prop: Dictionary, cell_size: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Prop_%s" % String(prop["id"])
	root.position = MapViewBridge.logic_to_world(prop["position"], cell_size)

	match prop["kind"] as StringName:
		MapTypes.PROP_KIND_ANVIL:
			_box(root, "Base", Vector3(0.9, 0.22, 0.5), Vector3(0.0, 0.11, 0.0), &"wood")
			_box(root, "Body", Vector3(0.65, 0.3, 0.32), Vector3(0.0, 0.37, 0.0), &"metal")
			_box(root, "Face", Vector3(1.05, 0.14, 0.34), Vector3(0.0, 0.59, 0.0), &"metal")
		MapTypes.PROP_KIND_HAY_STACK:
			_sphere(root, "Mound", 0.85, Vector3(0.0, 0.42, 0.0), &"hay", Vector3(1.0, 0.62, 1.0))
			_sphere(root, "Crown", 0.5, Vector3(0.1, 0.78, -0.05), &"hay", Vector3(1.0, 0.6, 1.0))
		MapTypes.PROP_KIND_CART:
			_box(root, "Bed", Vector3(1.6, 0.16, 0.9), Vector3(0.0, 0.6, 0.0), &"wood")
			_cylinder(root, "WheelLeft", 0.34, 0.1, Vector3(-0.45, 0.34, 0.5), &"wood", true)
			_cylinder(root, "WheelRight", 0.34, 0.1, Vector3(-0.45, 0.34, -0.5), &"wood", true)
			_box(root, "Handle", Vector3(0.9, 0.08, 0.5), Vector3(1.1, 0.62, 0.0), &"wood")
		MapTypes.PROP_KIND_WELL:
			_cylinder(root, "Ring", 0.55, 0.5, Vector3(0.0, 0.25, 0.0), &"stone")
			_cylinder(root, "Water", 0.42, 0.06, Vector3(0.0, 0.49, 0.0), &"water_highlight")
			_box(root, "PostLeft", Vector3(0.1, 1.0, 0.1), Vector3(-0.5, 0.75, 0.0), &"wood")
			_box(root, "PostRight", Vector3(0.1, 1.0, 0.1), Vector3(0.5, 0.75, 0.0), &"wood")
			_box(root, "RoofBeam", Vector3(1.3, 0.1, 0.5), Vector3(0.0, 1.3, 0.0), &"roof")
		MapTypes.PROP_KIND_BARRELS:
			_cylinder(root, "BarrelA", 0.28, 0.62, Vector3(-0.24, 0.31, 0.05), &"wood")
			_cylinder(root, "BarrelB", 0.28, 0.62, Vector3(0.3, 0.31, -0.14), &"wood")
		MapTypes.PROP_KIND_FURNACE:
			_box(root, "Mass", Vector3(1.0, 1.1, 0.9), Vector3(0.0, 0.55, 0.0), &"stone")
			_box(root, "Mouth", Vector3(0.42, 0.36, 0.08), Vector3(0.0, 0.35, 0.48), &"ember")
			_box(root, "Chimney", Vector3(0.26, 0.6, 0.26), Vector3(0.2, 1.4, -0.15), &"stone")
		MapTypes.PROP_KIND_LEDGER:
			_box(root, "Stand", Vector3(0.16, 0.9, 0.16), Vector3(0.0, 0.45, 0.0), &"wood")
			_box(root, "Book", Vector3(0.52, 0.08, 0.42), Vector3(0.0, 0.95, 0.0), &"plaster")
		MapTypes.PROP_KIND_BED:
			_box(root, "Frame", Vector3(1.4, 0.34, 0.8), Vector3(0.0, 0.17, 0.0), &"wood")
			_box(root, "Mattress", Vector3(1.3, 0.14, 0.7), Vector3(0.0, 0.41, 0.0), &"plaster")
			_box(root, "Pillow", Vector3(0.3, 0.12, 0.5), Vector3(-0.48, 0.52, 0.0), &"hay")
		MapTypes.PROP_KIND_CHEST:
			_box(root, "Box", Vector3(0.7, 0.42, 0.46), Vector3(0.0, 0.21, 0.0), &"wood")
			_box(root, "Lid", Vector3(0.72, 0.14, 0.48), Vector3(0.0, 0.49, 0.0), &"timber")
		MapTypes.PROP_KIND_TABLE:
			_box(root, "Top", Vector3(1.1, 0.08, 0.7), Vector3(0.0, 0.56, 0.0), &"wood")
			_box(root, "LegsLeft", Vector3(0.1, 0.52, 0.6), Vector3(-0.45, 0.26, 0.0), &"timber")
			_box(root, "LegsRight", Vector3(0.1, 0.52, 0.6), Vector3(0.45, 0.26, 0.0), &"timber")
		MapTypes.PROP_KIND_SHELF:
			_box(root, "Frame", Vector3(0.9, 1.4, 0.3), Vector3(0.0, 0.7, 0.0), &"timber")
			for level in 3:
				_box(root, "Board%d" % level, Vector3(0.82, 0.06, 0.26), Vector3(0.0, 0.35 + 0.4 * level, 0.0), &"wood")
		MapTypes.PROP_KIND_QUENCH:
			_cylinder(root, "Bucket", 0.3, 0.46, Vector3(0.0, 0.23, 0.0), &"wood")
			_cylinder(root, "Water", 0.24, 0.05, Vector3(0.0, 0.44, 0.0), &"water_highlight")
		MapTypes.PROP_KIND_STAIRS:
			for step in 3:
				_box(
					root,
					"Step%d" % step,
					Vector3(1.0, 0.2, 0.4),
					Vector3(0.0, 0.1 + 0.2 * step, -0.35 * step),
					&"stone"
				)
		MapTypes.PROP_KIND_STALL:
			_box(root, "Counter", Vector3(1.4, 0.8, 0.6), Vector3(0.0, 0.4, 0.0), &"wood")
			_box(root, "PostLeft", Vector3(0.08, 1.5, 0.08), Vector3(-0.65, 0.75, -0.4), &"timber")
			_box(root, "PostRight", Vector3(0.08, 1.5, 0.08), Vector3(0.65, 0.75, -0.4), &"timber")
			_box(root, "Canopy", Vector3(1.6, 0.08, 1.1), Vector3(0.0, 1.55, -0.1), &"hay")
		MapTypes.PROP_KIND_HEARTH:
			_box(root, "Base", Vector3(1.0, 0.4, 1.0), Vector3(0.0, 0.2, 0.0), &"stone")
			_box(root, "Fire", Vector3(0.5, 0.22, 0.5), Vector3(0.0, 0.5, 0.0), &"ember")
		_:
			_box(root, "Marker", Vector3(0.5, 0.5, 0.5), Vector3(0.0, 0.25, 0.0), &"ink")
	return root


static func _add_ground_quad(surface: SurfaceTool, x: int, y: int, height: float) -> void:
	var x0 := float(x)
	var x1 := float(x + 1)
	var z0 := float(y)
	var z1 := float(y + 1)
	var corners := [
		Vector3(x0, height, z0),
		Vector3(x1, height, z0),
		Vector3(x1, height, z1),
		Vector3(x0, height, z1),
	]
	var uvs := [
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0),
	]
	for index in [0, 1, 2, 0, 2, 3]:
		surface.set_normal(Vector3.UP)
		surface.set_uv(uvs[index])
		surface.add_vertex(corners[index])


## Gabled roof over a rectangular footprint: ridge along the longer axis,
## rise proportional to the narrow span, small eave overhang.
static func _gabled_roof_mesh(base: Vector2) -> ArrayMesh:
	var half_w := base.x * 0.5 + ROOF_OVERHANG
	var half_d := base.y * 0.5 + ROOF_OVERHANG
	var ridge_along_x := base.x >= base.y
	var narrow := minf(half_w, half_d)
	var rise := narrow * ROOF_PITCH

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
		_add_roof_quad(surface, a, b, r1, r0, north)
		_add_roof_quad(surface, r0, r1, c, d, south)
		_add_roof_triangle(surface, a, r0, d, Vector3.LEFT)
		_add_roof_triangle(surface, b, c, r1, Vector3.RIGHT)
	else:
		var a := Vector3(-half_w, 0.0, -half_d)
		var b := Vector3(half_w, 0.0, -half_d)
		var c := Vector3(half_w, 0.0, half_d)
		var d := Vector3(-half_w, 0.0, half_d)
		var r0 := Vector3(0.0, rise, -half_d)
		var r1 := Vector3(0.0, rise, half_d)
		var west := Vector3(-rise, half_w, 0.0).normalized()
		var east := Vector3(rise, half_w, 0.0).normalized()
		_add_roof_quad(surface, a, r0, r1, d, west)
		_add_roof_quad(surface, r0, b, c, r1, east)
		_add_roof_triangle(surface, a, b, r0, Vector3.FORWARD)
		_add_roof_triangle(surface, d, r1, c, Vector3.BACK)
	return surface.commit()


static func _add_roof_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	for vertex in [a, b, c, a, c, d]:
		surface.set_normal(normal)
		surface.set_uv(Vector2(vertex.x + vertex.z, vertex.y))
		surface.add_vertex(vertex)


static func _add_roof_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	for vertex in [a, b, c]:
		surface.set_normal(normal)
		surface.set_uv(Vector2(vertex.x + vertex.z, vertex.y))
		surface.add_vertex(vertex)


static func _box(parent: Node3D, name: String, size: Vector3, position: Vector3, role: StringName) -> void:
	var instance := MeshInstance3D.new()
	instance.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _role_material(role)
	parent.add_child(instance)


static func _cylinder(
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
	instance.material_override = _role_material(role)
	parent.add_child(instance)


static func _sphere(
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
	instance.material_override = _role_material(role)
	parent.add_child(instance)


static func _role_material(role: StringName) -> StandardMaterial3D:
	match role:
		&"roof":
			return MapViewMaterials.roof(MapVisualStyle.role_color(&"roof", MapVisualStyle.TARGET_CLEAN_PAINTED, MapVisualStyle.TIME_DAY))
		_:
			return MapViewMaterials.role(role)

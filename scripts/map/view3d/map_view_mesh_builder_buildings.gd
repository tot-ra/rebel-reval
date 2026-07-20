class_name MapViewMeshBuilderBuildings
extends RefCounted

## Building wall, roof, and facade mesh generation.
## Implementation is split across focused modules; this class keeps the public
## API stable for callers and tests.


static func build_building(building: Dictionary, cell_size: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Building_%s" % String(building["id"])
	var scale := MapViewBridge.world_scale(cell_size)
	var footprint: Rect2 = building["footprint"]
	var size := footprint.size * scale
	var kind: StringName = building.get("kind", MapTypes.BUILDING_KIND_HOUSE)
	var authored_height_px := float(building.get("wall_height", MapViewMeshBuilderConfig.DEFAULT_WALL_HEIGHT_PX.get(kind, 64.0)))
	var render_height_px := MapTypes.resolved_wall_height_px(building)
	var height := render_height_px * scale
	var center := footprint.get_center() * scale
	root.position = Vector3(center.x, 0.0, center.y)

	var wall_color := Color(building.get("wall_color", MapViewMeshBuilderConfig.DEFAULT_WALL_COLOR))
	var fortification := kind == MapTypes.BUILDING_KIND_WALL and authored_height_px >= MapViewMeshBuilderConfig.BATTLEMENT_MIN_HEIGHT_PX
	var footprint_aspect := minf(size.x, size.y) / maxf(size.x, size.y)
	var tower := fortification and (
		bool(building.get("tower", false))
		or (
			size.x <= MapViewMeshBuilderConfig.TOWER_MAX_FOOTPRINT
			and size.y <= MapViewMeshBuilderConfig.TOWER_MAX_FOOTPRINT
			and footprint_aspect >= MapViewMeshBuilderConfig.TOWER_MIN_ASPECT
		)
	)

	var walls := MeshInstance3D.new()
	walls.name = "Walls"
	if tower:
		var drum := CylinderMesh.new()
		drum.top_radius = minf(size.x, size.y) * MapViewMeshBuilderConfig.TOWER_RADIUS_FACTOR
		drum.bottom_radius = drum.top_radius * 1.06
		drum.height = height
		drum.radial_segments = 18
		walls.mesh = drum
		walls.material_override = MapViewMaterials.wall_surface_for_size(
			&"limestone",
			wall_color.lightened(0.08),
			Vector3(TAU * drum.top_radius, height, TAU * drum.top_radius)
		)
	else:
		var wall_mesh := BoxMesh.new()
		var mesh_size := Vector3(size.x, height, size.y)
		if fortification:
			mesh_size = MapViewMeshBuilderBuildingFortification.sealed_wall_size(mesh_size)
		wall_mesh.size = mesh_size
		walls.mesh = wall_mesh
		if kind == MapTypes.BUILDING_KIND_HOUSE:
			walls.material_override = MapViewMeshBuilderBuildingHouses.house_wall_material(building, wall_color, wall_mesh.size)
		elif kind == MapTypes.BUILDING_KIND_WALL:
			walls.material_override = MapViewMaterials.wall_surface_triplanar(&"limestone", wall_color)
		elif kind == MapTypes.BUILDING_KIND_INTERIOR_WALL:
			walls.material_override = MapViewMeshBuilderBuildingInteriorWalls.interior_wall_material(building, wall_color)
		else:
			walls.material_override = MapViewMaterials.wall_for_size(wall_color, wall_mesh.size)
	walls.position = Vector3(0.0, height * 0.5, 0.0)
	root.add_child(walls)

	if kind == MapTypes.BUILDING_KIND_HOUSE:
		var along_ridge_x := MapViewMeshBuilderBuildingFacade.ridge_along_x(building, size)
		var roof := MeshInstance3D.new()
		roof.name = "Roof"
		roof.mesh = MapViewMeshBuilderPrimitives.gabled_roof_mesh(size, along_ridge_x)
		roof.position = Vector3(0.0, height, 0.0)
		roof.material_override = MapViewMeshBuilderBuildingHouses.house_roof_material(building)
		root.add_child(roof)
		MapViewMeshBuilderBuildingHouses.add_chimney(root, building, size, height, along_ridge_x)
		MapViewMeshBuilderBuildingHouses.add_house_structure(root, building, size, height)
		MapViewMeshBuilderBuildingFacade.add_house_facade(root, building, size, height)
		MapViewMeshBuilderBuildingHouses.add_historic_building_details(root, building, size, height, along_ridge_x)
		MapViewMeshBuilderBuildingHouses.add_window_lights(root, building["id"])
	elif kind == MapTypes.BUILDING_KIND_INTERIOR_WALL:
		MapViewMeshBuilderBuildingInteriorWalls.add_interior_wall_structure(root, building, size, height)
	elif tower:
		var radius := minf(size.x, size.y) * MapViewMeshBuilderConfig.TOWER_RADIUS_FACTOR
		var cap := MeshInstance3D.new()
		cap.name = "Cap"
		var ring := CylinderMesh.new()
		ring.top_radius = radius + 0.22
		ring.bottom_radius = radius + 0.22
		ring.height = MapViewMeshBuilderConfig.CAP_HEIGHT * 2.0
		ring.radial_segments = 18
		cap.mesh = ring
		cap.position = Vector3(0.0, height + MapViewMeshBuilderConfig.CAP_HEIGHT, 0.0)
		cap.material_override = MapViewMaterials.wall_surface_for_size(
			&"limestone",
			wall_color.lightened(0.16),
			Vector3(TAU * ring.top_radius, ring.height, TAU * ring.top_radius)
		)
		root.add_child(cap)
		MapViewMeshBuilderBuildingFortification.add_tower_roof(root, radius, height)
		if authored_height_px >= MapViewMeshBuilderConfig.TOWER_MIN_HEIGHT_PX:
			MapViewMeshBuilderBuildingFortification.add_tower_slits(root, radius, height)
	elif kind != MapTypes.BUILDING_KIND_INTERIOR_WALL:
		var cap := MeshInstance3D.new()
		cap.name = "Cap"
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(size.x + MapViewMeshBuilderConfig.CAP_OVERHANG * 2.0, MapViewMeshBuilderConfig.CAP_HEIGHT, size.y + MapViewMeshBuilderConfig.CAP_OVERHANG * 2.0)
		cap.mesh = cap_mesh
		cap.position = Vector3(0.0, height + MapViewMeshBuilderConfig.CAP_HEIGHT * 0.5, 0.0)
		if fortification:
			cap.material_override = MapViewMaterials.wall_surface_for_size(
				&"plank",
				wall_color.lerp(MapViewMeshBuilderConfig.WALL_WALK_TIMBER_TONE, 0.72),
				cap_mesh.size
			)
		else:
			cap.material_override = MapViewMaterials.wall_surface_for_size(
				&"limestone" if kind == MapTypes.BUILDING_KIND_WALL else &"plaster",
				wall_color.lightened(0.12),
				cap_mesh.size
			)
		root.add_child(cap)
		if fortification:
			MapViewMeshBuilderBuildingFortification.add_battlements(root, building, size, height)
			MapViewMeshBuilderBuildingFortification.add_wall_walk_roof(root, size, height)
	return root


static func facade_box(
	root: Node3D,
	name: String,
	box_size: Vector3,
	along: float,
	center_y: float,
	side: StringName,
	face_offset: float,
	role: StringName
) -> void:
	MapViewMeshBuilderBuildingFacade.facade_box(root, name, box_size, along, center_y, side, face_offset, role)


static func add_battlements(root: Node3D, building: Dictionary, size: Vector2, height: float) -> void:
	MapViewMeshBuilderBuildingFortification.add_battlements(root, building, size, height)


static func sealed_wall_size(size: Vector3) -> Vector3:
	return MapViewMeshBuilderBuildingFortification.sealed_wall_size(size)

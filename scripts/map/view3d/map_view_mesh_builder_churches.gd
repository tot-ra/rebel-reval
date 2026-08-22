class_name MapViewMeshBuilderChurches
extends RefCounted

## Dedicated view-only forms for exceptional churches.
##
## WHY: St. Catherine's is a large stone church in the Lower Town source, not a
## house with a decorative roof. Keeping this pass separate prevents the ordinary
## house kit from adding a domestic chimney or collapsing the bell tower into the
## generic landmark roof while preserving the authored building ID and footprint.

const ST_CATHERINES_ID := &"st_catherines_church"
const NAVE_ROOF_PITCH := 0.72
const BUTTRESS_COUNT := 4
const LANCET_COUNT := 5


static func is_st_catherines_church(building: Dictionary) -> bool:
	return StringName(String(building.get("id", ""))) == ST_CATHERINES_ID


static func build_st_catherines_church(building: Dictionary, cell_size: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Building_%s" % String(building["id"])
	root.set_meta(&"renderer_boundary", &"exceptional")
	root.set_meta(&"exceptional_category", &"church")
	root.set_meta(&"church_renderer", ST_CATHERINES_ID)

	var scale := MapViewBridge.world_scale(cell_size)
	var footprint: Rect2 = building["footprint"]
	var size := footprint.size * scale
	var height := MapTypes.resolved_wall_height_px(building) * scale
	var center := footprint.get_center() * scale
	root.position = Vector3(center.x, 0.0, center.y)

	var wall_color := Color(building.get("wall_color", MapViewMeshBuilderConfig.DEFAULT_WALL_COLOR))
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(size.x, height, size.y)
	var walls := MeshInstance3D.new()
	walls.name = "Walls"
	walls.mesh = wall_mesh
	walls.position = Vector3(0.0, height * 0.5, 0.0)
	walls.material_override = MapViewMaterials.wall_surface_for_building(
		ST_CATHERINES_ID, &"limestone", wall_color, wall_mesh.size
	)
	root.add_child(walls)

	var nave_roof := MeshInstance3D.new()
	nave_roof.name = "ChurchNaveRoof"
	nave_roof.mesh = MapViewMeshBuilderPrimitives.gabled_roof_mesh(
		size, true, 0.22, true, NAVE_ROOF_PITCH
	)
	nave_roof.position = Vector3(0.0, height, 0.0)
	var roof_color := Color(building.get("roof_color", MapViewMeshBuilderConfig.DEFAULT_ROOF_COLOR))
	nave_roof.material_override = MapViewMaterials.roof_surface_for_building(
		ST_CATHERINES_ID, &"tile", roof_color
	)
	root.add_child(nave_roof)

	_add_lancet_windows(root, size, height)
	_add_buttresses(root, size, height)
	_add_west_bell_tower(root, size, height)
	_add_east_gable_cross(root, size, height)
	var lights: BuildingWindowLights3D = MapViewMeshBuilderConfig.WINDOW_LIGHTS_SCRIPT.new()
	root.add_child(lights)
	lights.configure(ST_CATHERINES_ID)
	return root


static func _add_lancet_windows(root: Node3D, size: Vector2, height: float) -> void:
	var run := size.x
	var face_z := size.y * 0.5 + 0.055
	var window_height := minf(1.65, height * 0.34)
	var window_y := height * 0.52
	for index in LANCET_COUNT:
		var along := (float(index + 1) / float(LANCET_COUNT + 1) - 0.5) * run
		for side: float in [-1.0, 1.0]:
			var suffix := "N" if side < 0.0 else "S"
			MapViewMeshBuilderPrimitives.box(
				root,
				"LancetWindow_%s_%02d" % [suffix, index],
				Vector3(0.34, window_height, 0.08),
				Vector3(along, window_y, side * face_z),
				&"window"
			)
			# Narrow limestone jambs make the openings read as masonry cuts rather
			# than painted marks when the church is viewed from above.
			for jamb_side: float in [-1.0, 1.0]:
				MapViewMeshBuilderPrimitives.box(
					root,
					"LancetJamb_%s_%02d_%s" % [suffix, index, "L" if jamb_side < 0.0 else "R"],
					Vector3(0.08, window_height + 0.12, 0.12),
					Vector3(along + jamb_side * 0.21, window_y, side * (face_z + 0.015)),
					&"stone"
				)


static func _add_buttresses(root: Node3D, size: Vector2, height: float) -> void:
	var span := size.x - 2.2
	for index in BUTTRESS_COUNT:
		var along := lerpf(-span * 0.5, span * 0.5, float(index) / float(BUTTRESS_COUNT - 1))
		for side: float in [-1.0, 1.0]:
			MapViewMeshBuilderPrimitives.box(
				root,
				"Buttress_%s_%02d" % ["N" if side < 0.0 else "S", index],
				Vector3(0.38, height * 0.7, 0.48),
				Vector3(along, height * 0.35, side * (size.y * 0.5 + 0.17)),
				&"stone"
			)


static func _add_west_bell_tower(root: Node3D, size: Vector2, height: float) -> void:
	var tower := Node3D.new()
	tower.name = "WestBellTower"
	root.add_child(tower)
	var tower_width := minf(3.0, size.y * 0.46)
	var tower_depth := minf(3.2, size.y * 0.72)
	var tower_base_height := height * 0.72
	var tower_x := -size.x * 0.5 + tower_width * 0.47
	MapViewMeshBuilderPrimitives.box(
		tower,
		"TowerMasonry",
		Vector3(tower_width, tower_base_height, tower_depth),
		Vector3(tower_x, tower_base_height * 0.5, 0.0),
		&"stone"
	)

	var chamber_y := tower_base_height + 0.62
	for side: float in [-1.0, 1.0]:
		MapViewMeshBuilderPrimitives.box(
			tower,
			"BellOpening_%s" % ("N" if side < 0.0 else "S"),
			Vector3(tower_width, 0.14, 0.16),
			Vector3(tower_x, chamber_y, side * tower_depth * 0.43),
			&"stone"
		)
	MapViewMeshBuilderPrimitives.box(
		tower,
		"BellBeam",
		Vector3(tower_width * 0.72, 0.16, 0.16),
		Vector3(tower_x, chamber_y, 0.0),
		&"timber"
	)

	var bell := MeshInstance3D.new()
	bell.name = "Bell"
	var bell_mesh := CylinderMesh.new()
	bell_mesh.top_radius = 0.1
	bell_mesh.bottom_radius = 0.18
	bell_mesh.height = 0.34
	bell_mesh.radial_segments = 12
	bell.mesh = bell_mesh
	bell.position = Vector3(tower_x, chamber_y - 0.2, 0.0)
	bell.material_override = MapViewMaterials.role(&"metal")
	tower.add_child(bell)

	var cap := MeshInstance3D.new()
	cap.name = "BellTowerRoof"
	cap.mesh = MapViewMeshBuilderPrimitives.gabled_roof_mesh(
		Vector2(tower_width + 0.24, tower_depth + 0.24), true, 0.08, true, 0.95
	)
	cap.position = Vector3(tower_x, chamber_y + 0.14, 0.0)
	cap.material_override = MapViewMaterials.roof_surface_for_building(
		ST_CATHERINES_ID, &"tile", Color(0.27, 0.17, 0.12)
	)
	tower.add_child(cap)


static func _add_east_gable_cross(root: Node3D, size: Vector2, height: float) -> void:
	var narrow_half := size.y * 0.5 + 0.22
	var apex := height + narrow_half * NAVE_ROOF_PITCH
	var east_x := size.x * 0.5 - 0.18
	MapViewMeshBuilderPrimitives.box(
		root,
		"EastGableCrossStem",
		Vector3(0.12, 0.9, 0.12),
		Vector3(east_x, apex + 0.45, 0.0),
		&"stone"
	)
	MapViewMeshBuilderPrimitives.box(
		root,
		"EastGableCrossArm",
		Vector3(0.12, 0.12, 0.52),
		Vector3(east_x, apex + 0.65, 0.0),
		&"stone"
	)

class_name MapViewMeshBuilderBuildingHouses
extends RefCounted

## Stable facade for house style, structure, roof, chimney, and civic-detail builders.

const _Styles := preload("res://scripts/map/view3d/map_view_mesh_builder_house_styles.gd")
const _RoofDressing := preload("res://scripts/map/view3d/map_view_mesh_builder_house_roof_dressing.gd")
const _Structure := preload("res://scripts/map/view3d/map_view_mesh_builder_house_structure.gd")


static func house_style(building: Dictionary) -> StringName:
	return _Styles.house_style(building)


static func house_wall_material(
	building: Dictionary,
	wall_color: Color,
	size: Vector3
) -> StandardMaterial3D:
	return _Styles.house_wall_material(building, wall_color, size)


static func roof_style(building: Dictionary) -> StringName:
	return _Styles.roof_style(building)


static func house_roof_material(building: Dictionary) -> StandardMaterial3D:
	return _Styles.house_roof_material(building)


static func add_house_structure(
	root: Node3D,
	building: Dictionary,
	size: Vector2,
	height: float,
	along_ridge_x: bool
) -> void:
	_Structure.add_house_structure(root, building, size, height, along_ridge_x)


static func add_roof_trim(
	root: Node3D,
	building: Dictionary,
	size: Vector2,
	height: float,
	along_ridge_x: bool
) -> void:
	_RoofDressing.add_roof_trim(root, building, size, height, along_ridge_x)


static func add_historic_building_details(
	root: Node3D,
	building: Dictionary,
	size: Vector2,
	height: float,
	along_ridge_x: bool
) -> void:
	match StringName(building.get("primitive", &"")):
		&"town_hall_1343":
			_add_early_town_hall_details(root, size, height)
		&"holy_spirit_chapel_1343":
			_add_holy_spirit_chapel_details(root, size, height)
		&"stepped_gable_merchant":
			_add_stepped_merchant_gable(root, size, height, along_ridge_x)


static func _add_early_town_hall_details(root: Node3D, size: Vector2, height: float) -> void:
	var facade_z := -size.y * 0.5 - 0.13
	var rear_z := size.y * 0.5 + 0.11
	var bay_count := clampi(int(size.x / 1.95), 5, 9)
	var bay_width := minf(1.35, size.x / float(bay_count) * 0.62)
	for index in bay_count:
		var x := (float(index + 1) / float(bay_count + 1) - 0.5) * size.x
		var arch_height := minf(1.45, height * 0.40)
		MapViewMeshBuilderPrimitives.box(
			root,
			"ArcadePier%02d" % index,
			Vector3(0.20, arch_height, 0.26),
			Vector3(x - bay_width * 0.5, arch_height * 0.5, facade_z),
			&"stone"
		)
		MapViewMeshBuilderPrimitives.box(
			root,
			"ArcadeLintel%02d" % index,
			Vector3(bay_width, 0.18, 0.26),
			Vector3(x, arch_height, facade_z),
			&"stone"
		)
		MapViewMeshBuilderPrimitives.box(
			root,
			"ArcadeShadow%02d" % index,
			Vector3(maxf(0.24, bay_width - 0.26), maxf(0.45, arch_height - 0.28), 0.04),
			Vector3(x, maxf(0.45, arch_height - 0.28) * 0.5, facade_z - 0.05),
			&"window"
		)
	MapViewMeshBuilderPrimitives.box(
		root,
		"CouncilDoorSurround",
		Vector3(1.18, minf(2.05, height * 0.56), 0.14),
		Vector3(size.x * 0.28, minf(2.05, height * 0.56) * 0.5, facade_z - 0.09),
		&"stone"
	)
	for side_x in [-size.x * 0.5 + 0.55, size.x * 0.5 - 0.55]:
		MapViewMeshBuilderPrimitives.box(
			root,
			"TownHallCornerButtress%.0f" % side_x,
			Vector3(0.34, height * 0.92, 0.34),
			Vector3(side_x, height * 0.46, facade_z + 0.05),
			&"stone"
		)
	var step_count := 5
	for index in step_count:
		var step_width := size.y * (0.55 - float(index) * 0.075)
		var step_height := height + 0.18 + float(index) * 0.24
		for x_side in [-1.0, 1.0]:
			MapViewMeshBuilderPrimitives.box(
				root,
				"TownHallGableStep%02d_%s" % [index, "E" if x_side > 0.0 else "W"],
				Vector3(0.24, 0.22, maxf(0.32, step_width)),
				Vector3(x_side * (size.x * 0.5 + 0.05), step_height, 0.0),
				&"stone"
			)
	var dais_height := minf(0.24, height * 0.08)
	MapViewMeshBuilderPrimitives.box(
		root,
		"TownHallMarketStoop",
		Vector3(size.x * 0.72, dais_height, 0.78),
		Vector3(0.0, dais_height * 0.5, facade_z - 0.42),
		&"stone"
	)
	var rear_window_count := clampi(int(size.x / 3.2), 3, 6)
	for index in rear_window_count:
		var x := (float(index + 1) / float(rear_window_count + 1) - 0.5) * size.x
		MapViewMeshBuilderPrimitives.box(
			root,
			"TownHallRearLancet%02d" % index,
			Vector3(0.36, minf(1.25, height * 0.34), 0.05),
			Vector3(x, height * 0.55, rear_z),
			&"window"
		)


static func _add_holy_spirit_chapel_details(root: Node3D, size: Vector2, height: float) -> void:
	var facade_z := size.y * 0.5 + 0.13
	var window_count := clampi(int(size.x / 2.7), 3, 6)
	for index in window_count:
		var x := (float(index + 1) / float(window_count + 1) - 0.5) * size.x
		var opening_height := minf(1.75, height * 0.42)
		MapViewMeshBuilderPrimitives.box(
			root,
			"Lancet%02d" % index,
			Vector3(0.42, opening_height, 0.06),
			Vector3(x, height * 0.52, facade_z),
			&"window"
		)
		MapViewMeshBuilderPrimitives.box(
			root,
			"LancetMullion%02d" % index,
			Vector3(0.055, opening_height, 0.09),
			Vector3(x, height * 0.52, facade_z + 0.04),
			&"stone"
		)
	var cote_x := -size.x * 0.24
	var cote_base := height + 0.2
	MapViewMeshBuilderPrimitives.box(root, "SanctusCote", Vector3(0.72, 1.1, 0.72), Vector3(cote_x, cote_base + 0.55, 0.0), &"stone")
	var cote_roof := MeshInstance3D.new()
	cote_roof.name = "SanctusCoteRoof"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.62
	cone.height = 1.15
	cone.radial_segments = 4
	cote_roof.mesh = cone
	cote_roof.position = Vector3(cote_x, cote_base + 1.1 + cone.height * 0.5, 0.0)
	cote_roof.rotation.y = PI * 0.25
	cote_roof.material_override = MapViewMaterials.roof(Color8(82, 47, 38))
	root.add_child(cote_roof)


static func _add_stepped_merchant_gable(
	root: Node3D,
	size: Vector2,
	height: float,
	along_ridge_x: bool
) -> void:
	var front_side := &"south"
	var facade_width := size.x
	var face_offset := size.y * 0.5
	if along_ridge_x:
		front_side = &"east"
		facade_width = size.y
		face_offset = size.x * 0.5
	var step_widths := [0.78, 0.54, 0.30]
	for index in step_widths.size():
		var step_width := facade_width * float(step_widths[index])
		var step_height := 0.32 + float(index) * 0.18
		MapViewMeshBuilderBuildingFacade.facade_box(
			root,
			"GableStep%02d" % index,
			Vector3(step_width, step_height, 0.32),
			0.0,
			height + 0.18 + float(index) * 0.34,
			front_side,
			face_offset,
			&"stone"
		)
	MapViewMeshBuilderBuildingFacade.facade_box(root, "GablePinnacle", Vector3(0.22, 0.78, 0.28), 0.0, height + 1.42, front_side, face_offset, &"stone")


static func add_chimney(root: Node3D, building: Dictionary, size: Vector2, wall_height: float, ridge_along_x: bool) -> void:
	var building_id: StringName = building["id"]
	var seed := String(building_id).hash()
	var chimney_size := MapViewMeshBuilderConfig.CHIMNEY_SIZE
	var chimney_half := chimney_size * 0.5
	var half_span := (size.y if ridge_along_x else size.x) * 0.5 + MapViewMeshBuilderConfig.ROOF_OVERHANG
	var rise := half_span * MapViewMeshBuilderConfig.ROOF_PITCH
	# Near one ridge end, fully on one slope face so the shaft pierces tiles
	# instead of balancing on the peak like a cube.
	var along := ((size.x if ridge_along_x else size.y) * 0.5 - chimney_size) * 0.62
	if seed % 2 == 0:
		along = -along
	var slope_side := 1.0 if (seed >> 1) % 2 == 0 else -1.0
	var across := slope_side * (chimney_half + MapViewMeshBuilderConfig.CHIMNEY_RIDGE_CLEARANCE)
	var offset := Vector3(along, 0.0, across) if ridge_along_x else Vector3(across, 0.0, along)
	# Embed from the downhill roof edge under the footprint so the whole stack
	# volume intersects the roof plane.
	var across_edge := minf(absf(across) + chimney_half, half_span)
	var roof_y_edge := wall_height + rise * (1.0 - across_edge / half_span)
	var stack_bottom := roof_y_edge - MapViewMeshBuilderConfig.CHIMNEY_STACK_EMBED
	var stack_height := MapViewMeshBuilderConfig.CHIMNEY_STACK_HEIGHT
	var stack_center_y := stack_bottom + stack_height * 0.5
	var top := stack_bottom + stack_height
	MapViewMeshBuilderPrimitives.add_chimney_stack(
		root,
		"Chimney",
		chimney_size,
		stack_height,
		offset + Vector3(0.0, stack_center_y, 0.0)
	)

	if ChimneySmoke3D.schedule_for(seed) == ChimneySmoke3D.Schedule.NEVER:
		return
	var smoke: ChimneySmoke3D = MapViewMeshBuilderConfig.CHIMNEY_SMOKE_SCRIPT.new()
	smoke.position = offset + Vector3(0.0, top + 0.1, 0.0)
	smoke.configure(building_id)
	root.add_child(smoke)


static func add_window_lights(root: Node3D, building_id: StringName) -> void:
	var lights: BuildingWindowLights3D = MapViewMeshBuilderConfig.WINDOW_LIGHTS_SCRIPT.new()
	root.add_child(lights)
	lights.configure(building_id)

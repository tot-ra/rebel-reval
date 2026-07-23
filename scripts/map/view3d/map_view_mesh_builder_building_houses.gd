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
	var bay_count := clampi(int(size.x / 2.65), 5, 9)
	if bay_count % 2 == 0:
		bay_count -= 1
	var bay_spacing := size.x / float(bay_count + 1)
	var opening_width := minf(1.82, bay_spacing * 0.72)
	var arch_height := minf(2.25, height * 0.54)
	var voussoir := minf(0.18, opening_width * 0.12)
	var center_index := floori(float(bay_count) * 0.5)

	# WHY: the later Town Hall arcade is used as a restrained visual motif, not as
	# evidence that the complete post-1404 facade already existed. Rounded bays,
	# pale local limestone, and the tile color provide recognition while the mass
	# stays a single-storey 1343 hall without the later upper floor or tower.
	for index in bay_count:
		var x := (float(index + 1) / float(bay_count + 1) - 0.5) * size.x
		var is_portal := index == center_index
		var bay_width := opening_width * (1.10 if is_portal else 1.0)
		var bay_radius := bay_width * 0.5
		var bay_spring := arch_height - bay_radius
		if not is_portal:
			_add_arch_panel(
				root,
				"ArcadeShadow%02d" % index,
				bay_width - voussoir * 1.5,
				arch_height - voussoir * 0.75,
				facade_z - 0.055,
				&"ink"
			)
		var left_jamb_name := "TownHallPortalJambL" if is_portal else "ArcadePier%02d" % index
		var right_jamb_name := "TownHallPortalJambR" if is_portal else "ArcadePier%02dRight" % index
		for side in [-1.0, 1.0]:
			MapViewMeshBuilderPrimitives.box(
				root,
				left_jamb_name if side < 0.0 else right_jamb_name,
				Vector3(voussoir, bay_spring, 0.28),
				Vector3(x + side * (bay_radius - voussoir * 0.5), bay_spring * 0.5, facade_z),
				&"stone"
			)
		_add_arch_band(
			root,
			"TownHallPortalArch" if is_portal else "ArcadeArch%02d" % index,
			bay_radius,
			voussoir,
			Vector3(x, bay_spring, facade_z),
			&"stone"
		)

	# A shallow string course and narrow lights break up the previous blank wall
	# without implying a second storey. The central light marks the council axis.
	MapViewMeshBuilderPrimitives.box(
		root,
		"TownHallStringCourse",
		Vector3(size.x * 0.94, 0.12, 0.20),
		Vector3(0.0, arch_height + 0.22, facade_z + 0.03),
		&"stone"
	)
	var upper_light_count := clampi((bay_count + 1) / 2, 3, 5)
	for index in upper_light_count:
		var x := (float(index + 1) / float(upper_light_count + 1) - 0.5) * size.x * 0.64
		_add_arch_panel(
			root,
			"TownHallClerestory%02d" % index,
			0.42,
			minf(1.05, height * 0.24),
			facade_z - 0.045,
			&"window"
		)
		(root.get_node("TownHallClerestory%02d" % index) as Node3D).position.x = x
		(root.get_node("TownHallClerestory%02d" % index) as Node3D).position.y = arch_height + 0.42

	for side_x in [-size.x * 0.5 + 0.55, size.x * 0.5 - 0.55]:
		MapViewMeshBuilderPrimitives.box(
			root,
			"TownHallCornerButtress%.0f" % side_x,
			Vector3(0.34, height * 0.92, 0.34),
			Vector3(side_x, height * 0.46, facade_z + 0.05),
			&"stone"
		)
	var step_count := 4
	for index in step_count:
		var step_width := size.y * (0.52 - float(index) * 0.085)
		var step_height := height + 0.18 + float(index) * 0.22
		for x_side in [-1.0, 1.0]:
			MapViewMeshBuilderPrimitives.box(
				root,
				"TownHallGableStep%02d_%s" % [index, "E" if x_side > 0.0 else "W"],
				Vector3(0.24, 0.20, maxf(0.32, step_width)),
				Vector3(x_side * (size.x * 0.5 + 0.05), step_height, 0.0),
				&"stone"
			)
	var dais_height := minf(0.24, height * 0.08)
	MapViewMeshBuilderPrimitives.box(
		root,
		"TownHallMarketStoop",
		Vector3(size.x * 0.76, dais_height, 0.82),
		Vector3(0.0, dais_height * 0.5, facade_z - 0.44),
		&"stone"
	)
	var rear_window_count := clampi(int(size.x / 3.2), 3, 6)
	for index in rear_window_count:
		var x := (float(index + 1) / float(rear_window_count + 1) - 0.5) * size.x
		_add_arch_panel(
			root,
			"TownHallRearLancet%02d" % index,
			0.36,
			minf(1.25, height * 0.34),
			rear_z,
			&"window"
		)
		(root.get_node("TownHallRearLancet%02d" % index) as Node3D).position.x = x
		(root.get_node("TownHallRearLancet%02d" % index) as Node3D).position.y = height * 0.38


static func _add_arch_panel(
	root: Node3D,
	node_name: String,
	width: float,
	height: float,
	z: float,
	role: StringName
) -> void:
	var panel := MeshInstance3D.new()
	panel.name = node_name
	panel.mesh = MapViewMeshBuilderPrimitives.arched_panel_mesh(width, height)
	panel.position.z = z
	panel.material_override = MapViewMeshBuilderPrimitives.role_material(role)
	root.add_child(panel)


static func _add_arch_band(
	root: Node3D,
	node_name: String,
	radius: float,
	thickness: float,
	position: Vector3,
	role: StringName
) -> void:
	var band := MeshInstance3D.new()
	band.name = node_name
	band.mesh = MapViewMeshBuilderPrimitives.arch_band_mesh(radius, thickness)
	band.position = position
	band.material_override = MapViewMeshBuilderPrimitives.role_material(role)
	root.add_child(band)


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

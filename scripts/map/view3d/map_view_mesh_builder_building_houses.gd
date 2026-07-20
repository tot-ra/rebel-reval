class_name MapViewMeshBuilderBuildingHouses
extends RefCounted

## House materials, structural dressing, chimneys, and historic civic silhouettes.


static func house_style(building: Dictionary) -> StringName:
	match StringName(building.get("wall_material", &"")):
		&"plaster", &"timber":
			return MapViewMeshBuilderConfig.HOUSE_STYLE_TIMBER
		&"brick":
			return MapViewMeshBuilderConfig.HOUSE_STYLE_BRICK
		&"plank":
			return MapViewMeshBuilderConfig.HOUSE_STYLE_PLANK
		&"log":
			return MapViewMeshBuilderConfig.HOUSE_STYLE_LOG
		&"limestone", &"stone":
			return MapViewMeshBuilderConfig.HOUSE_STYLE_STONE
	var roll := absi(String(building["id"]).hash()) % 10
	if roll < 4:
		return MapViewMeshBuilderConfig.HOUSE_STYLE_LOG
	if roll < 6:
		return MapViewMeshBuilderConfig.HOUSE_STYLE_TIMBER
	if roll < 8:
		return MapViewMeshBuilderConfig.HOUSE_STYLE_PLANK
	if roll < 9:
		return MapViewMeshBuilderConfig.HOUSE_STYLE_STONE
	return MapViewMeshBuilderConfig.HOUSE_STYLE_BRICK


static func house_wall_material(building: Dictionary, wall_color: Color, size: Vector3) -> StandardMaterial3D:
	match house_style(building):
		MapViewMeshBuilderConfig.HOUSE_STYLE_TIMBER:
			return MapViewMaterials.wall_surface_for_size(&"plaster", wall_color.lerp(MapViewMeshBuilderConfig.PLASTER_TONE, 0.55), size)
		MapViewMeshBuilderConfig.HOUSE_STYLE_BRICK:
			return MapViewMaterials.wall_surface_for_size(&"brick", wall_color.lerp(MapViewMeshBuilderConfig.BRICK_TONE, 0.6), size)
		MapViewMeshBuilderConfig.HOUSE_STYLE_LOG:
			return MapViewMaterials.wall_surface_for_size(&"log", wall_color.lerp(MapViewMeshBuilderConfig.LOG_TONE, 0.45), size)
		MapViewMeshBuilderConfig.HOUSE_STYLE_STONE:
			return MapViewMaterials.wall_surface_for_size(&"limestone", wall_color.lerp(MapViewMeshBuilderConfig.LIMESTONE_TONE, 0.5), size)
		_:
			return MapViewMaterials.wall_surface_for_size(&"plank", wall_color, size)


static func roof_style(building: Dictionary) -> StringName:
	match StringName(building.get("roof_material", &"")):
		&"tile":
			return MapViewMeshBuilderConfig.ROOF_STYLE_TILE
		&"shingle":
			return MapViewMeshBuilderConfig.ROOF_STYLE_SHINGLE
		&"thatch", &"straw":
			return MapViewMeshBuilderConfig.ROOF_STYLE_THATCH
	match house_style(building):
		MapViewMeshBuilderConfig.HOUSE_STYLE_STONE, MapViewMeshBuilderConfig.HOUSE_STYLE_BRICK:
			return MapViewMeshBuilderConfig.ROOF_STYLE_TILE
		MapViewMeshBuilderConfig.HOUSE_STYLE_LOG:
			if absi(String(building["id"]).hash() / 10) % 3 < 2:
				return MapViewMeshBuilderConfig.ROOF_STYLE_THATCH
			return MapViewMeshBuilderConfig.ROOF_STYLE_SHINGLE
		_:
			return MapViewMeshBuilderConfig.ROOF_STYLE_SHINGLE


static func house_roof_material(building: Dictionary) -> StandardMaterial3D:
	var color := Color(building.get("roof_color", MapViewMeshBuilderConfig.DEFAULT_ROOF_COLOR))
	var style := roof_style(building)
	if style == MapViewMeshBuilderConfig.ROOF_STYLE_THATCH and not building.has("roof_material"):
		color = color.lerp(MapViewMeshBuilderConfig.THATCH_TONE, 0.55)
	return MapViewMaterials.roof_surface(style, color)


static func add_house_structure(root: Node3D, building: Dictionary, size: Vector2, height: float) -> void:
	var style := house_style(building)
	MapViewMeshBuilderPrimitives.box(
		root,
		"Plinth",
		Vector3(size.x + 0.12, MapViewMeshBuilderConfig.PLINTH_HEIGHT, size.y + 0.12),
		Vector3(0.0, MapViewMeshBuilderConfig.PLINTH_HEIGHT * 0.5, 0.0),
		&"stone"
	)
	if style == MapViewMeshBuilderConfig.HOUSE_STYLE_BRICK or style == MapViewMeshBuilderConfig.HOUSE_STYLE_STONE:
		return
	var half := size * 0.5
	var beam := MapViewMeshBuilderConfig.FRAME_BEAM_THICKNESS
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		MapViewMeshBuilderPrimitives.box(
			root,
			"CornerPost_%d_%d" % [int(corner.x), int(corner.y)],
			Vector3(beam, height, beam),
			Vector3(corner.x * half.x, height * 0.5, corner.y * half.y),
			&"timber"
		)
	if style != MapViewMeshBuilderConfig.HOUSE_STYLE_TIMBER:
		return
	var beam_heights := [MapViewMeshBuilderConfig.PLINTH_HEIGHT + beam * 0.5, height * 0.55, height - beam * 0.5]
	for beam_y: float in beam_heights:
		MapViewMeshBuilderPrimitives.box(root, "BeamNS%d" % int(beam_y * 100.0), Vector3(size.x + beam, beam, beam), Vector3(0.0, beam_y, half.y), &"timber")
		MapViewMeshBuilderPrimitives.box(root, "BeamNS%dB" % int(beam_y * 100.0), Vector3(size.x + beam, beam, beam), Vector3(0.0, beam_y, -half.y), &"timber")
		MapViewMeshBuilderPrimitives.box(root, "BeamEW%d" % int(beam_y * 100.0), Vector3(beam, beam, size.y + beam), Vector3(half.x, beam_y, 0.0), &"timber")
		MapViewMeshBuilderPrimitives.box(root, "BeamEW%dB" % int(beam_y * 100.0), Vector3(beam, beam, size.y + beam), Vector3(-half.x, beam_y, 0.0), &"timber")
	var brace_length := (height * 0.55 - MapViewMeshBuilderConfig.PLINTH_HEIGHT) * 1.35
	var along_x := size.x >= size.y
	var brace_offset := (size.x if along_x else size.y) * 0.28
	for flip in [-1.0, 1.0]:
		var brace := MeshInstance3D.new()
		brace.name = "Brace%d" % int(flip)
		var brace_mesh := BoxMesh.new()
		brace_mesh.size = Vector3(brace_length, beam * 0.9, beam * 0.6)
		brace.mesh = brace_mesh
		var mid_y := (MapViewMeshBuilderConfig.PLINTH_HEIGHT + height * 0.55) * 0.5
		if along_x:
			brace.position = Vector3(flip * brace_offset, mid_y, half.y)
			brace.rotation.z = flip * 0.7
		else:
			brace.position = Vector3(half.x, mid_y, flip * brace_offset)
			brace.rotation.y = PI * 0.5
			brace.rotation.z = flip * 0.7
		brace.material_override = MapViewMaterials.role(&"timber")
		root.add_child(brace)


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
	var bay_count := clampi(int(size.x / 2.15), 4, 8)
	var bay_width := minf(1.55, size.x / float(bay_count) * 0.68)
	for index in bay_count:
		var x := (float(index + 1) / float(bay_count + 1) - 0.5) * size.x
		MapViewMeshBuilderPrimitives.box(
			root,
			"ArcadePier%02d" % index,
			Vector3(0.22, minf(1.7, height * 0.46), 0.24),
			Vector3(x - bay_width * 0.5, minf(1.7, height * 0.46) * 0.5, facade_z),
			&"stone"
		)
		MapViewMeshBuilderPrimitives.box(
			root,
			"ArcadeLintel%02d" % index,
			Vector3(bay_width, 0.18, 0.24),
			Vector3(x, minf(1.7, height * 0.46), facade_z),
			&"stone"
		)
	MapViewMeshBuilderPrimitives.box(
		root,
		"CouncilDoorSurround",
		Vector3(1.32, minf(2.35, height * 0.62), 0.12),
		Vector3(size.x * 0.30, minf(2.35, height * 0.62) * 0.5, facade_z - 0.08),
		&"stone"
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
	var rise := ((size.y if ridge_along_x else size.x) * 0.5 + MapViewMeshBuilderConfig.ROOF_OVERHANG) * MapViewMeshBuilderConfig.ROOF_PITCH
	var along := ((size.x if ridge_along_x else size.y) * 0.5 - MapViewMeshBuilderConfig.CHIMNEY_SIZE) * 0.62
	if String(building_id).hash() % 2 == 0:
		along = -along
	var offset := Vector3(along, 0.0, 0.0) if ridge_along_x else Vector3(0.0, 0.0, along)
	var ridge_y := wall_height + rise
	var stack_bottom := ridge_y - MapViewMeshBuilderConfig.CHIMNEY_STACK_EMBED
	var stack_center_y := stack_bottom + MapViewMeshBuilderConfig.CHIMNEY_STACK_HEIGHT * 0.5
	var top := stack_bottom + MapViewMeshBuilderConfig.CHIMNEY_STACK_HEIGHT
	MapViewMeshBuilderPrimitives.add_chimney_stack(root, "Chimney", MapViewMeshBuilderConfig.CHIMNEY_SIZE, MapViewMeshBuilderConfig.CHIMNEY_STACK_HEIGHT, offset + Vector3(0.0, stack_center_y, 0.0))

	if ChimneySmoke3D.schedule_for(String(building_id).hash()) == ChimneySmoke3D.Schedule.NEVER:
		return
	var smoke: ChimneySmoke3D = MapViewMeshBuilderConfig.CHIMNEY_SMOKE_SCRIPT.new()
	smoke.position = offset + Vector3(0.0, top + 0.1, 0.0)
	smoke.configure(building_id)
	root.add_child(smoke)


static func add_window_lights(root: Node3D, building_id: StringName) -> void:
	var lights: BuildingWindowLights3D = MapViewMeshBuilderConfig.WINDOW_LIGHTS_SCRIPT.new()
	root.add_child(lights)
	lights.configure(building_id)

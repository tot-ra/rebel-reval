class_name MapViewMeshBuilderBuildingFortification
extends RefCounted

## Fortification towers, battlements, and wall-walk dressing.


static func sealed_wall_size(size: Vector3) -> Vector3:
	if size.x <= size.z:
		return Vector3(size.x + MapViewMeshBuilderConfig.WALL_SEAL_OVERHANG * 2.0, size.y, size.z)
	return Vector3(size.x, size.y, size.z + MapViewMeshBuilderConfig.WALL_SEAL_OVERHANG * 2.0)


static func add_tower_door(
	root: Node3D,
	radius: float,
	height: float,
	side: StringName
) -> void:
	if side not in [&"north", &"south", &"east", &"west"]:
		return
	var door_height := minf(MapViewMeshBuilderConfig.TOWER_DOOR_HEIGHT, height - 0.2)
	var width := MapViewMeshBuilderConfig.TOWER_DOOR_WIDTH
	var frame_width := MapViewMeshBuilderConfig.TOWER_DOOR_FRAME_WIDTH
	var frame_depth := MapViewMeshBuilderConfig.TOWER_DOOR_FRAME_DEPTH
	var panel_depth := MapViewMeshBuilderConfig.DOOR_THICKNESS

	# WHY: explicit door_side is authored toward the city. The renderer must not
	# infer a side from camera/map position because gate and castle towers can sit
	# on internal circuits where map-center heuristics point outside that circuit.
	MapViewMeshBuilderBuildingFacade.facade_box(
		root, "TowerDoor", Vector3(width, door_height, panel_depth),
		0.0, door_height * 0.5, side, radius, &"wood"
	)
	for post_side in [-1.0, 1.0]:
		MapViewMeshBuilderBuildingFacade.facade_box(
			root, "TowerDoorFrame%d" % int(post_side),
			Vector3(frame_width, door_height + frame_width, frame_depth),
			post_side * (width + frame_width) * 0.5,
			(door_height + frame_width) * 0.5,
			side, radius, &"stone"
		)
	MapViewMeshBuilderBuildingFacade.facade_box(
		root, "TowerDoorLintel",
		Vector3(width + frame_width * 2.0, frame_width, frame_depth),
		0.0, door_height + frame_width * 0.5, side, radius, &"stone"
	)
	MapViewMeshBuilderBuildingFacade.facade_box(
		root, "TowerDoorStep",
		Vector3(width + frame_width, 0.1, MapViewMeshBuilderConfig.TOWER_DOOR_STEP_DEPTH),
		0.0, 0.05, side, radius + MapViewMeshBuilderConfig.TOWER_DOOR_STEP_DEPTH * 0.25, &"stone"
	)
	var face_offset := radius + panel_depth * 0.5
	MapViewMeshBuilderBuildingFacade.facade_box(
		root, "TowerDoorStrap0", Vector3(width * 0.88, 0.07, 0.04),
		0.0, door_height * 0.32, side, face_offset, &"metal"
	)
	MapViewMeshBuilderBuildingFacade.facade_box(
		root, "TowerDoorStrap1", Vector3(width * 0.88, 0.07, 0.04),
		0.0, door_height * 0.7, side, face_offset, &"metal"
	)
	MapViewMeshBuilderBuildingFacade.facade_box(
		root, "TowerDoorLatch", Vector3(0.09, 0.14, 0.06),
		width * 0.3, door_height * 0.5, side, face_offset, &"metal"
	)


static func add_tower_roof(root: Node3D, radius: float, height: float) -> void:
	var roof_radius := radius + 0.34
	var roof := MeshInstance3D.new()
	roof.name = "TowerRoof"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = roof_radius
	cone.height = roof_radius * MapViewMeshBuilderConfig.TOWER_ROOF_PITCH
	cone.radial_segments = 18
	roof.mesh = cone
	roof.position = Vector3(0.0, height + MapViewMeshBuilderConfig.CAP_HEIGHT * 2.0 + cone.height * 0.5, 0.0)
	roof.material_override = MapViewMaterials.roof(MapViewMeshBuilderConfig.TOWER_ROOF_COLOR)
	root.add_child(roof)
	var finial := MeshInstance3D.new()
	finial.name = "Finial"
	var knob := SphereMesh.new()
	knob.radius = 0.09
	knob.height = 0.18
	finial.mesh = knob
	var finial_y := height + MapViewMeshBuilderConfig.CAP_HEIGHT * 2.0 + cone.height + 0.06
	finial.position = Vector3(0.0, finial_y, 0.0)
	finial.material_override = MapViewMaterials.role(&"metal")
	root.add_child(finial)
	# WHY: tower pennants make world wind readable on fortified maps that have
	# little grass; the cloth shader shares SkyWeather direction and strength.
	_add_tower_pennant(root, finial_y)


static func _add_tower_pennant(root: Node3D, finial_y: float) -> void:
	var staff := MeshInstance3D.new()
	staff.name = "PennantStaff"
	var staff_mesh := CylinderMesh.new()
	staff_mesh.top_radius = 0.018
	staff_mesh.bottom_radius = 0.022
	staff_mesh.height = 0.72
	staff_mesh.radial_segments = 6
	staff.mesh = staff_mesh
	staff.position = Vector3(0.0, finial_y + 0.36, 0.0)
	staff.material_override = MapViewMaterials.role(&"timber")
	root.add_child(staff)

	var pennant := MeshInstance3D.new()
	pennant.name = "Pennant"
	pennant.mesh = _pennant_mesh()
	pennant.position = Vector3(0.0, finial_y + 0.58, 0.0)
	pennant.material_override = MapViewMaterials.flag_cloth()
	pennant.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pennant)


## Triangular fly with UV.x = 0 at the hoist so the cloth shader keeps the pole
## edge planted while the tip ripples downwind.
static func _pennant_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hoist_top := Vector3(0.0, 0.12, 0.0)
	var hoist_bottom := Vector3(0.0, -0.42, 0.0)
	var fly := Vector3(0.95, -0.12, 0.0)
	for vertex_uv in [
		[hoist_top, Vector2(0.0, 0.0)],
		[hoist_bottom, Vector2(0.0, 1.0)],
		[fly, Vector2(1.0, 0.5)],
	]:
		surface.set_color(Color.WHITE)
		surface.set_uv(vertex_uv[1])
		surface.add_vertex(vertex_uv[0])
	# Back face so the pennant stays readable from either side of the tower.
	for vertex_uv in [
		[hoist_top, Vector2(0.0, 0.0)],
		[fly, Vector2(1.0, 0.5)],
		[hoist_bottom, Vector2(0.0, 1.0)],
	]:
		surface.set_color(Color.WHITE)
		surface.set_uv(vertex_uv[1])
		surface.add_vertex(vertex_uv[0])
	surface.generate_normals()
	return surface.commit()


static func add_tower_slits(root: Node3D, radius: float, height: float) -> void:
	var slit_center_y := height * 0.62
	var index := 0
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var outward := Vector3(sin(angle), 0.0, cos(angle))
		var frame_size := Vector3(
			MapViewMeshBuilderConfig.ARROW_SLIT_SIZE.x + MapViewMeshBuilderConfig.ARROW_SLIT_FRAME_PAD.x * 2.0,
			MapViewMeshBuilderConfig.ARROW_SLIT_SIZE.y + MapViewMeshBuilderConfig.ARROW_SLIT_FRAME_PAD.y * 2.0,
			MapViewMeshBuilderConfig.ARROW_SLIT_FRAME_DEPTH
		)
		var frame := MeshInstance3D.new()
		frame.name = "SlitFrame%d" % index
		var frame_mesh := BoxMesh.new()
		frame_mesh.size = frame_size
		frame.mesh = frame_mesh
		frame.position = outward * (radius + MapViewMeshBuilderConfig.ARROW_SLIT_FRAME_DEPTH * 0.5)
		frame.position.y = slit_center_y
		frame.rotation.y = angle
		frame.material_override = MapViewMaterials.wall_surface_for_size(
			&"brick",
			MapViewMeshBuilderConfig.BRICK_TONE,
			frame_size
		)
		root.add_child(frame)

		var slit := MeshInstance3D.new()
		slit.name = "Slit%d" % index
		var mesh := BoxMesh.new()
		mesh.size = MapViewMeshBuilderConfig.ARROW_SLIT_SIZE
		slit.mesh = mesh
		slit.position = outward * (radius + MapViewMeshBuilderConfig.ARROW_SLIT_FRAME_DEPTH + MapViewMeshBuilderConfig.ARROW_SLIT_SIZE.z * 0.5 - 0.01)
		slit.position.y = slit_center_y
		slit.rotation.y = angle
		slit.material_override = MapViewMaterials.role(&"ink")
		root.add_child(slit)
		index += 1


static func add_wall_walk_roof(root: Node3D, size: Vector2, height: float) -> void:
	var along_x := size.x >= size.y
	var length := (size.x if along_x else size.y) + 0.3
	var span := maxf(
		(size.y if along_x else size.x) + 0.7,
		MapViewMeshBuilderConfig.WALL_WALK_MIN_WIDTH
	)
	var deck_y := height + MapViewMeshBuilderConfig.CAP_HEIGHT
	var clear_height := MapViewMeshBuilderConfig.WALL_WALK_CLEAR_HEIGHT
	var roof := MeshInstance3D.new()
	roof.name = "WalkRoof"
	roof.mesh = MapViewMeshBuilderPrimitives.gabled_roof_mesh(
		Vector2(length, span) if along_x else Vector2(span, length),
		along_x
	)
	roof.position = Vector3(0.0, deck_y + clear_height, 0.0)
	roof.material_override = MapViewMaterials.roof(MapViewMeshBuilderConfig.WALL_ROOF_COLOR)
	root.add_child(roof)

	var post_count := maxi(2, ceili(length / MapViewMeshBuilderConfig.WALL_WALK_POST_SPACING))
	var post_height := clear_height + 0.1
	var side_offset := span * 0.5 - 0.3
	for post_index in post_count + 1:
		var along := (float(post_index) / float(post_count) - 0.5) * (length - 0.4)
		for side in [-1.0, 1.0]:
			var offset: float = side * side_offset
			var post_position := Vector3(along, deck_y + post_height * 0.5, offset)
			if not along_x:
				post_position = Vector3(offset, post_position.y, along)
			MapViewMeshBuilderPrimitives.box(
				root,
				"RoofPost%d_%d" % [post_index, int(side)],
				Vector3.ONE * MapViewMeshBuilderConfig.WALL_WALK_POST_SIZE + Vector3(0.0, post_height - MapViewMeshBuilderConfig.WALL_WALK_POST_SIZE, 0.0),
				post_position,
				&"timber"
			)

	# Continuous rails and eaves beams make the top read as a usable timber
	# gallery rather than a roof balanced on isolated sticks.
	for side in [-1.0, 1.0]:
		var offset: float = side * side_offset
		for rail_y in [
			MapViewMeshBuilderConfig.WALL_WALK_RAIL_HEIGHT * 0.52,
			MapViewMeshBuilderConfig.WALL_WALK_RAIL_HEIGHT,
		]:
			var rail_size := (
				Vector3(length, MapViewMeshBuilderConfig.WALL_WALK_RAIL_SIZE, MapViewMeshBuilderConfig.WALL_WALK_RAIL_SIZE)
				if along_x
				else Vector3(MapViewMeshBuilderConfig.WALL_WALK_RAIL_SIZE, MapViewMeshBuilderConfig.WALL_WALK_RAIL_SIZE, length)
			)
			var rail_position := Vector3(0.0, deck_y + rail_y, offset) if along_x else Vector3(offset, deck_y + rail_y, 0.0)
			MapViewMeshBuilderPrimitives.box(root, "GalleryRail%d_%d" % [int(side), int(rail_y * 100.0)], rail_size, rail_position, &"timber")
		var eaves_size := (
			Vector3(length, MapViewMeshBuilderConfig.WALL_WALK_POST_SIZE, MapViewMeshBuilderConfig.WALL_WALK_POST_SIZE)
			if along_x
			else Vector3(MapViewMeshBuilderConfig.WALL_WALK_POST_SIZE, MapViewMeshBuilderConfig.WALL_WALK_POST_SIZE, length)
		)
		var eaves_position := Vector3(0.0, deck_y + clear_height, offset) if along_x else Vector3(offset, deck_y + clear_height, 0.0)
		MapViewMeshBuilderPrimitives.box(root, "GalleryEaves%d" % int(side), eaves_size, eaves_position, &"timber")

	# Short diagonal brackets visibly transfer the projecting gallery load back
	# into the masonry instead of leaving the deck visually unsupported.
	for end in [-1.0, 1.0]:
		for side in [-1.0, 1.0]:
			var along: float = end * (length * 0.5 - 0.3)
			var offset: float = side * side_offset
			var upper := Vector3(along, deck_y + 0.12, offset)
			var lower := Vector3(along, deck_y - MapViewMeshBuilderConfig.WALL_WALK_BRACKET_DROP, offset * 0.45)
			if not along_x:
				upper = Vector3(offset, upper.y, along)
				lower = Vector3(offset * 0.45, lower.y, along)
			_add_timber_beam(root, "GalleryBracket%d_%d" % [int(end), int(side)], lower, upper, 0.1)


static func add_base_arcades(root: Node3D, building: Dictionary, size: Vector2) -> void:
	var along_x := size.x >= size.y
	var length := size.x if along_x else size.y
	var depth := size.y if along_x else size.x
	var bay_count := maxi(1, floori(length / MapViewMeshBuilderConfig.WALL_BASE_ARCADE_BAY_WIDTH))
	var bay_width := length / float(bay_count)
	var radius := minf(bay_width * 0.38, MapViewMeshBuilderConfig.WALL_BASE_ARCADE_MAX_RADIUS)
	var spring_y := MapViewMeshBuilderConfig.WALL_BASE_ARCADE_SPRING_HEIGHT
	var face_offset := depth * 0.5 + MapViewMeshBuilderConfig.WALL_BASE_ARCADE_DEPTH * 0.5
	var stone_color := Color(building.get("wall_color", MapViewMeshBuilderConfig.DEFAULT_WALL_COLOR)).lightened(0.1)
	var material := MapViewMaterials.wall_surface(&"limestone", stone_color)
	var pier_transforms: Array[Transform3D] = []
	var pier_colors: Array[Color] = []
	var arc_transforms: Array[Transform3D] = []
	var arc_colors: Array[Color] = []
	var segment_count := 7
	var segment_length := PI * radius / float(segment_count) * 1.14

	for side in [-1.0, 1.0]:
		var normal := Vector3(0.0, 0.0, side) if along_x else Vector3(side, 0.0, 0.0)
		for pier_index in bay_count + 1:
			var along := -length * 0.5 + float(pier_index) * bay_width
			var pier_position := Vector3(along, spring_y * 0.5, side * face_offset) if along_x else Vector3(side * face_offset, spring_y * 0.5, along)
			pier_transforms.append(Transform3D(Basis.IDENTITY, pier_position))
			pier_colors.append(Color.WHITE)
		for bay_index in bay_count:
			var center := -length * 0.5 + (float(bay_index) + 0.5) * bay_width
			for segment_index in segment_count:
				var angle := (float(segment_index) + 0.5) / float(segment_count) * PI
				var along := center + cos(angle) * radius
				var position := Vector3(along, spring_y + sin(angle) * radius, side * face_offset) if along_x else Vector3(side * face_offset, spring_y + sin(angle) * radius, along)
				var tangent := ((Vector3.RIGHT if along_x else Vector3.BACK) * -sin(angle) + Vector3.UP * cos(angle)).normalized()
				var radial := normal.cross(tangent).normalized()
				arc_transforms.append(Transform3D(Basis(tangent, radial, normal), position))
				arc_colors.append(Color.WHITE)

	var pier_mesh := BoxMesh.new()
	pier_mesh.size = (
		Vector3(MapViewMeshBuilderConfig.WALL_BASE_ARCADE_STONE_WIDTH, spring_y, MapViewMeshBuilderConfig.WALL_BASE_ARCADE_DEPTH)
		if along_x
		else Vector3(MapViewMeshBuilderConfig.WALL_BASE_ARCADE_DEPTH, spring_y, MapViewMeshBuilderConfig.WALL_BASE_ARCADE_STONE_WIDTH)
	)
	root.add_child(MapViewMeshBuilderPrimitives.multi_mesh("BaseArcadePiers", pier_mesh, pier_transforms, pier_colors, material, Vector3.ZERO))
	var arc_mesh := BoxMesh.new()
	arc_mesh.size = Vector3(segment_length, MapViewMeshBuilderConfig.WALL_BASE_ARCADE_STONE_WIDTH, MapViewMeshBuilderConfig.WALL_BASE_ARCADE_DEPTH)
	root.add_child(MapViewMeshBuilderPrimitives.multi_mesh("BaseArcades", arc_mesh, arc_transforms, arc_colors, material, Vector3.ZERO))


static func _add_timber_beam(root: Node3D, name: String, from: Vector3, to: Vector3, thickness: float) -> void:
	var direction := to - from
	if direction.is_zero_approx():
		return
	var beam := MeshInstance3D.new()
	beam.name = name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(thickness, thickness, direction.length())
	beam.mesh = mesh
	beam.position = (from + to) * 0.5
	var up := Vector3.RIGHT if absf(direction.normalized().dot(Vector3.UP)) > 0.98 else Vector3.UP
	beam.basis = Basis.looking_at(direction.normalized(), up)
	beam.material_override = MapViewMaterials.role(&"timber")
	root.add_child(beam)

static func add_battlements(root: Node3D, building: Dictionary, size: Vector2, height: float) -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var half := size * 0.5
	var tower := size.x <= 3.4 and size.y <= 3.4
	var edges: Array = []
	if tower or size.x >= size.y:
		edges.append([Vector3(-half.x, 0.0, -half.y), Vector3(half.x, 0.0, -half.y)])
		edges.append([Vector3(-half.x, 0.0, half.y), Vector3(half.x, 0.0, half.y)])
	if tower or size.y > size.x:
		edges.append([Vector3(-half.x, 0.0, -half.y), Vector3(-half.x, 0.0, half.y)])
		edges.append([Vector3(half.x, 0.0, -half.y), Vector3(half.x, 0.0, half.y)])
	for edge in edges:
		var from: Vector3 = edge[0]
		var to: Vector3 = edge[1]
		var length := from.distance_to(to)
		var count := maxi(2, int(length / MapViewMeshBuilderConfig.MERLON_SPACING))
		for step in count + 1:
			var origin := from.lerp(to, float(step) / float(count))
			origin.y = height + MapViewMeshBuilderConfig.CAP_HEIGHT + MapViewMeshBuilderConfig.MERLON_SIZE.y * 0.5
			transforms.append(Transform3D(Basis.IDENTITY, origin))
			colors.append(Color.WHITE)
	var merlon_mesh := BoxMesh.new()
	merlon_mesh.size = MapViewMeshBuilderConfig.MERLON_SIZE
	var merlons := MapViewMeshBuilderPrimitives.multi_mesh(
		"Merlons",
		merlon_mesh,
		transforms,
		colors,
		MapViewMaterials.wall_surface(&"limestone", Color(building.get("wall_color", MapViewMeshBuilderConfig.DEFAULT_WALL_COLOR)).lightened(0.12)),
		Vector3.ZERO
	)
	root.add_child(merlons)

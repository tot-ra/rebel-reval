class_name MapViewMeshBuilderBuildingFortification
extends RefCounted

## Fortification towers, battlements, and wall-walk dressing.


static func sealed_wall_size(size: Vector3) -> Vector3:
	if size.x <= size.z:
		return Vector3(size.x + MapViewMeshBuilderConfig.WALL_SEAL_OVERHANG * 2.0, size.y, size.z)
	return Vector3(size.x, size.y, size.z + MapViewMeshBuilderConfig.WALL_SEAL_OVERHANG * 2.0)


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
	finial.position = Vector3(0.0, height + MapViewMeshBuilderConfig.CAP_HEIGHT * 2.0 + cone.height + 0.06, 0.0)
	finial.material_override = MapViewMaterials.role(&"metal")
	root.add_child(finial)


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
	var span := (size.y if along_x else size.x) + 0.7
	var base_y := height + MapViewMeshBuilderConfig.CAP_HEIGHT + MapViewMeshBuilderConfig.WALL_WALK_ROOF_LIFT
	var roof := MeshInstance3D.new()
	roof.name = "WalkRoof"
	roof.mesh = MapViewMeshBuilderPrimitives.gabled_roof_mesh(
		Vector2(length, span) if along_x else Vector2(span, length),
		along_x
	)
	roof.position = Vector3(0.0, base_y, 0.0)
	roof.material_override = MapViewMaterials.roof(MapViewMeshBuilderConfig.WALL_ROOF_COLOR)
	root.add_child(roof)
	var post_count := maxi(2, int(length / 2.2))
	var post_height := MapViewMeshBuilderConfig.WALL_WALK_ROOF_LIFT + 0.1
	for post_index in post_count + 1:
		var along := (float(post_index) / float(post_count) - 0.5) * (length - 0.4)
		for side in [-1.0, 1.0]:
			var offset: float = side * (span * 0.5 - 0.35)
			var position := Vector3(along, height + MapViewMeshBuilderConfig.CAP_HEIGHT + post_height * 0.5, offset)
			if not along_x:
				position = Vector3(offset, position.y, along)
			MapViewMeshBuilderPrimitives.box(
				root,
				"RoofPost%d_%d" % [post_index, int(side)],
				Vector3(0.09, post_height, 0.09),
				position,
				&"timber"
			)


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

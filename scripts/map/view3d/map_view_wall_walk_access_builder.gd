class_name MapViewWallWalkAccessBuilder
extends RefCounted

## Visual geometry for authored wall-walk stairs and platforms. Gameplay
## elevation and collision semantics remain in MapWallWalkAccess.

static func add_to(
	root: Node3D,
	prop: Dictionary,
	cell_size: int,
	definition: MapDefinition
) -> void:
	var target := MapWallWalkAccess.target_height(definition, prop)
	if target <= 0.0:
		return
	var footprint: Rect2 = prop["footprint"]
	var scale := MapViewBridge.world_scale(cell_size)
	var size := footprint.size * scale
	if MapWallWalkAccess.is_platform_prop(prop):
		MapViewMeshBuilderPrimitives.box(
			root, "WallWalkPlatform", Vector3(size.x, 0.14, size.y),
			Vector3(0.0, target, 0.0), &"wood"
		)
		return

	var facing := Vector2(prop.get("facing", Vector2.RIGHT)).normalized()
	var along_x := absf(facing.x) >= absf(facing.y)
	var run := size.x if along_x else size.y
	var step_count := maxi(3, ceili(target / MapViewMeshBuilderConfig.WALL_WALK_ACCESS_STEP_RISE))
	var tread := run * MapViewMeshBuilderConfig.WALL_WALK_ACCESS_CLIMB_FRACTION / float(step_count)
	var width := minf(
		size.y if along_x else size.x,
		MapViewMeshBuilderConfig.WALL_WALK_ACCESS_STAIR_WIDTH
	)
	for step_index in step_count:
		var progress := (float(step_index) + 0.5) / float(step_count)
		var along := -run * 0.5 + progress * run * MapViewMeshBuilderConfig.WALL_WALK_ACCESS_CLIMB_FRACTION
		if (facing.x if along_x else facing.y) < 0.0:
			along = -along
		var center := Vector3(along, target * progress, 0.0) if along_x else Vector3(0.0, target * progress, along)
		var tread_size := Vector3(tread + 0.03, MapViewMeshBuilderConfig.WALL_WALK_ACCESS_TREAD_THICKNESS, width) if along_x else Vector3(width, MapViewMeshBuilderConfig.WALL_WALK_ACCESS_TREAD_THICKNESS, tread + 0.03)
		MapViewMeshBuilderPrimitives.box(root, "WallStairStep%d" % step_index, tread_size, center, &"wood")

	var landing_length := run * (1.0 - MapViewMeshBuilderConfig.WALL_WALK_ACCESS_CLIMB_FRACTION)
	var landing_along := run * 0.5 - landing_length * 0.5
	if (facing.x if along_x else facing.y) < 0.0:
		landing_along = -landing_along
	var landing_size := Vector3(landing_length, 0.14, width) if along_x else Vector3(width, 0.14, landing_length)
	var landing_position := Vector3(landing_along, target, 0.0) if along_x else Vector3(0.0, target, landing_along)
	MapViewMeshBuilderPrimitives.box(root, "WallStairLanding", landing_size, landing_position, &"wood")

	var direction := Vector3(facing.x, 0.0, facing.y)
	var cross := Vector3(-direction.z, 0.0, direction.x)
	var start := -direction * run * 0.5
	var finish := start + direction * run * MapViewMeshBuilderConfig.WALL_WALK_ACCESS_CLIMB_FRACTION + Vector3.UP * target
	for side in [-1.0, 1.0]:
		var offset := cross * width * 0.48
		_add_access_beam(root, "WallStairRail%d" % int(side), start + offset * side + Vector3.UP * 0.55, finish + offset * side + Vector3.UP * MapViewMeshBuilderConfig.WALL_WALK_ACCESS_RAIL_HEIGHT, 0.09)
		for progress in [0.0, 0.25, 0.5, 0.75, 1.0]:
			var foot: Vector3 = start.lerp(finish, progress) + offset * side
			_add_access_beam(root, "WallStairPost%d_%d" % [int(side), int(progress * 100.0)], foot, foot + Vector3.UP * MapViewMeshBuilderConfig.WALL_WALK_ACCESS_RAIL_HEIGHT, 0.08)


static func _add_access_beam(root: Node3D, name: String, from: Vector3, to: Vector3, thickness: float) -> void:
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

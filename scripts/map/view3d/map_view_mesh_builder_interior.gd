class_name MapViewMeshBuilderInterior
extends RefCounted

## Interior shell dressing for enclosed room maps (first-person ceiling closure).
## WHY: exterior house roofs do not apply to interior_wall shells; without a
## shared ceiling the sky dome reads through when the camera looks up.


static func build_interior_shell(definition: MapDefinition) -> Node3D:
	var root := Node3D.new()
	root.name = "InteriorShell"
	if not definition.suppresses_exterior_surroundings():
		return root

	var scale := MapViewBridge.world_scale(definition.cell_size)
	var wall_height := MapViewMeshBuilderLandmarks.interior_shell_wall_height_world(definition)
	var floor_bounds := _interior_floor_bounds_world(definition, scale)
	if floor_bounds.size.x <= 0.5 or floor_bounds.size.y <= 0.5:
		return root

	var ceiling_plane := wall_height + MapViewMeshBuilderConfig.INTERIOR_CEILING_FIRST_PERSON_HEADROOM
	var ceiling_y := ceiling_plane - MapViewMeshBuilderConfig.INTERIOR_CEILING_THICKNESS * 0.5
	var center := Vector3(
		floor_bounds.position.x + floor_bounds.size.x * 0.5,
		ceiling_y,
		floor_bounds.position.y + floor_bounds.size.y * 0.5
	)
	var ceiling_size := Vector3(
		floor_bounds.size.x,
		MapViewMeshBuilderConfig.INTERIOR_CEILING_THICKNESS,
		floor_bounds.size.y
	)

	var ceiling := MeshInstance3D.new()
	ceiling.name = "Ceiling"
	var ceiling_mesh := BoxMesh.new()
	ceiling_mesh.size = ceiling_size
	ceiling.mesh = ceiling_mesh
	ceiling.position = center
	ceiling.material_override = MapViewMaterials.wall_surface_for_size(
		&"plank",
		MapViewMeshBuilderConfig.INTERIOR_CEILING_COLOR,
		ceiling_size
	)
	root.add_child(ceiling)
	_add_exposed_beams(root, floor_bounds, ceiling_plane)
	root.visible = false
	return root


static func _interior_floor_bounds_world(definition: MapDefinition, scale: float) -> Rect2:
	var logic_bounds := definition.camera_bounds
	if logic_bounds.size == Vector2.ZERO:
		logic_bounds = Rect2(Vector2.ZERO, definition.world_size())
	var inset := float(definition.cell_size) * scale
	return Rect2(
		logic_bounds.position * scale + Vector2(inset, inset),
		logic_bounds.size * scale - Vector2(inset * 2.0, inset * 2.0)
	)


## Exposed timber beams hang slightly below the plank ceiling so the room reads
## as carpentry from both the dimetric camera and first-person look-up.


static func _add_exposed_beams(root: Node3D, floor_bounds: Rect2, ceiling_plane: float) -> void:
	var along_x := floor_bounds.size.x >= floor_bounds.size.y
	var primary_span := floor_bounds.size.x if along_x else floor_bounds.size.y
	var secondary_span := floor_bounds.size.y if along_x else floor_bounds.size.x
	var beam_bottom := ceiling_plane - MapViewMeshBuilderConfig.INTERIOR_CEILING_THICKNESS
	var beam_center_y := beam_bottom - MapViewMeshBuilderConfig.INTERIOR_BEAM_DEPTH * 0.5
	var primary_count := maxi(2, int(primary_span / MapViewMeshBuilderConfig.INTERIOR_BEAM_SPACING) + 1)
	var secondary_count := maxi(2, int(secondary_span / (MapViewMeshBuilderConfig.INTERIOR_BEAM_SPACING * 1.35)) + 1)

	for index in primary_count:
		var t := float(index) / float(primary_count - 1) if primary_count > 1 else 0.5
		var along := lerpf(
			floor_bounds.position.y if along_x else floor_bounds.position.x,
			(floor_bounds.position.y if along_x else floor_bounds.position.x)
				+ (floor_bounds.size.y if along_x else floor_bounds.size.x),
			t
		)
		var beam_size := Vector3(
			floor_bounds.size.x if along_x else MapViewMeshBuilderConfig.INTERIOR_BEAM_THICKNESS,
			MapViewMeshBuilderConfig.INTERIOR_BEAM_DEPTH,
			floor_bounds.size.y if not along_x else MapViewMeshBuilderConfig.INTERIOR_BEAM_THICKNESS
		)
		var position := Vector3(
			floor_bounds.position.x + floor_bounds.size.x * 0.5 if along_x else along,
			beam_center_y,
			along if along_x else floor_bounds.position.y + floor_bounds.size.y * 0.5
		)
		MapViewMeshBuilderPrimitives.box(
			root,
			"PrimaryBeam%d" % index,
			beam_size,
			position,
			&"timber"
		)

	for index in range(1, secondary_count - 1):
		var t := float(index) / float(secondary_count - 1)
		var along := lerpf(
			floor_bounds.position.x if along_x else floor_bounds.position.y,
			(floor_bounds.position.x if along_x else floor_bounds.position.y)
				+ (floor_bounds.size.x if along_x else floor_bounds.size.y),
			t
		)
		var beam_size := Vector3(
			MapViewMeshBuilderConfig.INTERIOR_BEAM_THICKNESS,
			MapViewMeshBuilderConfig.INTERIOR_BEAM_DEPTH * 0.82,
			floor_bounds.size.y * 0.92 if along_x else MapViewMeshBuilderConfig.INTERIOR_BEAM_THICKNESS
		)
		if not along_x:
			beam_size = Vector3(floor_bounds.size.x * 0.92, beam_size.y, beam_size.z)
		var position := Vector3(
			along if along_x else floor_bounds.position.x + floor_bounds.size.x * 0.5,
			beam_center_y - 0.02,
			floor_bounds.position.y + floor_bounds.size.y * 0.5 if along_x else along
		)
		MapViewMeshBuilderPrimitives.box(
			root,
			"SecondaryBeam%d" % index,
			beam_size,
			position,
			&"timber"
		)

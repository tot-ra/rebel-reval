class_name MapViewMeshBuilderLandmarks
extends RefCounted

## Landmark arches, interior windows, and transition doors.

static func interior_shell_wall_height_world(definition: MapDefinition) -> float:
	var scale := MapViewBridge.world_scale(definition.cell_size)
	for building in definition.buildings:
		if building.get("kind", &"") == MapTypes.BUILDING_KIND_INTERIOR_WALL:
			return MapTypes.resolved_wall_height_px(building) * scale
	return MapViewMeshBuilderConfig.DEFAULT_WALL_HEIGHT_PX[MapTypes.BUILDING_KIND_INTERIOR_WALL] * scale


## View-only landmark geometry over walkable openings (never collides).


static func build_landmark(
	landmark: Dictionary,
	cell_size: int,
	wall_height_world: float = -1.0
) -> Node3D:
	var root := Node3D.new()
	root.name = "Landmark_%s" % String(landmark["id"])
	var scale := MapViewBridge.world_scale(cell_size)
	var rect: Rect2 = landmark["rect"]
	var size := rect.size * scale
	var center := rect.get_center() * scale
	root.position = Vector3(center.x, 0.0, center.y)
	match landmark.get("kind", &""):
		&"gate_arch":
			_add_gate_arch(root, landmark, size, scale)
		&"interior_window":
			var resolved_wall_height := wall_height_world
			if resolved_wall_height <= 0.0:
				resolved_wall_height = MapViewMeshBuilderConfig.DEFAULT_WALL_HEIGHT_PX[MapTypes.BUILDING_KIND_INTERIOR_WALL] * scale
			_add_interior_window_landmark(root, landmark, size, cell_size, resolved_wall_height)
			var interior_lights = MapViewMeshBuilderConfig.INTERIOR_WINDOW_LIGHTS_SCRIPT.new()
			interior_lights.configure_from(root)
			root.add_child(interior_lights)
	return root


## Gate passages follow the street axis, not the landmark rectangle aspect ratio.
## Boundary arches are often deeper than they are wide even when the road runs
## east-west (or vice versa on the north edge).


static func _gate_passage_along_x(landmark: Dictionary, size: Vector2) -> bool:
	var axis: StringName = landmark.get("passage_axis", &"")
	if axis == &"x":
		return true
	if axis == &"z":
		return false
	return size.x >= size.y


## View-only interior window frame and glazed pane on the inward wall face.


static func _add_interior_window_landmark(
	root: Node3D,
	landmark: Dictionary,
	size: Vector2,
	cell_size: int,
	wall_height_world: float
) -> void:
	var side := _interior_window_side(landmark, cell_size)
	var sill := wall_height_world * MapViewMeshBuilderConfig.INTERIOR_WINDOW_SILL_RATIO
	var max_opening := wall_height_world - sill - MapViewMeshBuilderConfig.INTERIOR_WINDOW_LINTEL
	# The landmark rect's long axis runs along the wall: X on north/south walls,
	# Y on east/west walls. Both spans are horizontal width; the glazed height is
	# always derived from the wall height so tall openings never become
	# door-height glass with sky gaps beside it.
	var span := size.x if side in [&"north", &"south"] else maxf(size.y, 0.35)
	var opening_height := clampf(
		wall_height_world * 0.42,
		MapViewMeshBuilderConfig.INTERIOR_WINDOW_MIN_HEIGHT,
		max_opening
	)
	var frame := MapViewMeshBuilderConfig.HOUSE_WINDOW_FRAME
	var glass_w := maxf(span - frame * 2.0, 0.25)
	var glass_h := maxf(opening_height - frame * 2.0, 0.35)
	var center_y := sill + opening_height * 0.5
	var face_offset := 0.35
	if sill > 0.08:
		MapViewMeshBuilderBuildings.facade_box(
			root,
			"WallBelow0",
			Vector3(span + 0.1, sill, MapViewMeshBuilderConfig.HOUSE_WINDOW_OUTER_DEPTH * 0.65),
			0.0,
			sill * 0.5,
			side,
			face_offset - 0.04,
			&"plaster"
		)
	MapViewMeshBuilderBuildings.facade_box(root, "WindowFrameT0", Vector3(span, frame, MapViewMeshBuilderConfig.HOUSE_WINDOW_OUTER_DEPTH), 0.0, sill + opening_height - frame * 0.5, side, face_offset, &"timber")
	MapViewMeshBuilderBuildings.facade_box(root, "WindowFrameB0", Vector3(span, frame, MapViewMeshBuilderConfig.HOUSE_WINDOW_OUTER_DEPTH), 0.0, sill + frame * 0.5, side, face_offset, &"timber")
	MapViewMeshBuilderBuildings.facade_box(root, "WindowFrameL0", Vector3(frame, opening_height, MapViewMeshBuilderConfig.HOUSE_WINDOW_OUTER_DEPTH), -span * 0.5 + frame * 0.5, center_y, side, face_offset, &"timber")
	MapViewMeshBuilderBuildings.facade_box(root, "WindowFrameR0", Vector3(frame, opening_height, MapViewMeshBuilderConfig.HOUSE_WINDOW_OUTER_DEPTH), span * 0.5 - frame * 0.5, center_y, side, face_offset, &"timber")
	MapViewMeshBuilderBuildings.facade_box(root, "Window0", Vector3(glass_w, glass_h, MapViewMeshBuilderConfig.HOUSE_WINDOW_GLASS_DEPTH), 0.0, center_y, side, face_offset, &"window")
	MapViewMeshBuilderBuildings.facade_box(root, "WindowMullionV0", Vector3(MapViewMeshBuilderConfig.HOUSE_WINDOW_MULLION, glass_h, MapViewMeshBuilderConfig.HOUSE_WINDOW_MULLION_DEPTH), 0.0, center_y, side, face_offset, &"timber")
	MapViewMeshBuilderBuildings.facade_box(root, "WindowLintel0", Vector3(span + 0.12, 0.1, 0.09), 0.0, sill + opening_height + 0.05, side, face_offset, &"timber")
	MapViewMeshBuilderBuildings.facade_box(root, "WindowSill0", Vector3(span + 0.12, 0.08, 0.12), 0.0, sill - 0.04, side, face_offset, &"timber")
	var headroom := wall_height_world - sill - opening_height
	if headroom > 0.08:
		# Wall segments are omitted around openings; fill the void above the lintel.
		MapViewMeshBuilderBuildings.facade_box(
			root,
			"WallAbove0",
			Vector3(span + 0.1, headroom, MapViewMeshBuilderConfig.HOUSE_WINDOW_OUTER_DEPTH * 0.65),
			0.0,
			sill + opening_height + headroom * 0.5,
			side,
			face_offset - 0.04,
			&"plaster"
		)




static func _interior_window_side(landmark: Dictionary, cell_size: int) -> StringName:
	var rect: Rect2 = landmark["rect"]
	var axis: StringName = landmark.get("passage_axis", &"z")
	if axis == &"z":
		if rect.position.y <= float(cell_size):
			return &"north"
		return &"south"
	if rect.position.x <= float(cell_size):
		return &"west"
	return &"east"




static func _add_gate_arch(root: Node3D, landmark: Dictionary, size: Vector2, scale: float) -> void:
	var color := Color(landmark.get("wall_color", MapViewMeshBuilderConfig.DEFAULT_WALL_COLOR))
	var top := MapTypes.resolved_landmark_top_px(landmark) * scale
	var span_height := maxf(top - MapViewMeshBuilderConfig.GATE_ARCH_CLEARANCE, 0.6)
	var passage_along_x := _gate_passage_along_x(landmark, size)

	var bridge := MeshInstance3D.new()
	bridge.name = "Bridge"
	var bridge_mesh := BoxMesh.new()
	bridge_mesh.size = Vector3(size.x, span_height, size.y)
	bridge.mesh = bridge_mesh
	bridge.position = Vector3(0.0, MapViewMeshBuilderConfig.GATE_ARCH_CLEARANCE + span_height * 0.5, 0.0)
	bridge.material_override = MapViewMaterials.wall_surface_triplanar(&"limestone", color)
	root.add_child(bridge)

	var jamb_height := MapViewMeshBuilderConfig.GATE_ARCH_CLEARANCE
	var half := size * 0.5
	if passage_along_x:
		for side_index in 2:
			var side := -1.0 if side_index == 0 else 1.0
			var z := side * (half.y - MapViewMeshBuilderConfig.GATE_JAMB_THICKNESS * 0.5)
			MapViewMeshBuilderPrimitives.box(
				root,
				"Jamb%d" % side_index,
				Vector3(size.x, jamb_height, MapViewMeshBuilderConfig.GATE_JAMB_THICKNESS),
				Vector3(0.0, jamb_height * 0.5, z),
				&"stone"
			)
	else:
		for side_index in 2:
			var side := -1.0 if side_index == 0 else 1.0
			var x := side * (half.x - MapViewMeshBuilderConfig.GATE_JAMB_THICKNESS * 0.5)
			MapViewMeshBuilderPrimitives.box(
				root,
				"Jamb%d" % side_index,
				Vector3(MapViewMeshBuilderConfig.GATE_JAMB_THICKNESS, jamb_height, size.y),
				Vector3(x, jamb_height * 0.5, 0.0),
				&"stone"
			)

	MapViewMeshBuilderPrimitives.box(
		root,
		"Threshold",
		Vector3(size.x + 0.2, 0.1, size.y + 0.2),
		Vector3(0.0, 0.05, 0.0),
		&"stone"
	)

	var door_material: StringName = landmark.get("door_material", &"wood")
	if door_material in [&"wood", &"metal"]:
		_add_gate_doors(root, size, passage_along_x, door_material)

	MapViewMeshBuilderBuildings.add_battlements(root, {"id": landmark["id"], "wall_color": color}, size, top - MapViewMeshBuilderConfig.CAP_HEIGHT)


## Double gate leaves hinged on the jambs and swung open so the passage stays
## walkable while the gate reads as an inhabited threshold.


static func _add_gate_doors(root: Node3D, size: Vector2, passage_along_x: bool, door_material: StringName) -> void:
	var door_height := minf(MapViewMeshBuilderConfig.GATE_DOOR_HEIGHT, MapViewMeshBuilderConfig.GATE_ARCH_CLEARANCE - 0.1)
	var half := size * 0.5
	var role := door_material

	if passage_along_x:
		var leaf_width := maxf((size.x - MapViewMeshBuilderConfig.GATE_JAMB_THICKNESS * 2.4) * 0.5, 0.8)
		for side_index in 2:
			var side := -1.0 if side_index == 0 else 1.0
			var hinge_z := side * (half.y - MapViewMeshBuilderConfig.GATE_JAMB_THICKNESS * 0.5)
			var door := MeshInstance3D.new()
			door.name = "GateDoor%d" % side_index
			var mesh := BoxMesh.new()
			mesh.size = Vector3(leaf_width, door_height, MapViewMeshBuilderConfig.GATE_DOOR_THICKNESS)
			door.mesh = mesh
			door.position = Vector3(0.0, door_height * 0.5, hinge_z + side * leaf_width * 0.5)
			door.rotation.y = side * deg_to_rad(92.0)
			door.material_override = MapViewMeshBuilderPrimitives.role_material(role)
			root.add_child(door)
	else:
		var leaf_width := maxf((size.y - MapViewMeshBuilderConfig.GATE_JAMB_THICKNESS * 2.4) * 0.5, 0.8)
		for side_index in 2:
			var side := -1.0 if side_index == 0 else 1.0
			var hinge_x := side * (half.x - MapViewMeshBuilderConfig.GATE_JAMB_THICKNESS * 0.5)
			var door := MeshInstance3D.new()
			door.name = "GateDoor%d" % side_index
			var mesh := BoxMesh.new()
			mesh.size = Vector3(MapViewMeshBuilderConfig.GATE_DOOR_THICKNESS, door_height, leaf_width)
			door.mesh = mesh
			door.position = Vector3(hinge_x + side * leaf_width * 0.5, door_height * 0.5, 0.0)
			door.rotation.y = side * deg_to_rad(92.0)
			door.material_override = MapViewMeshBuilderPrimitives.role_material(role)
			root.add_child(door)




static func transition_uses_landmark_visual(definition: MapDefinition, transition: Dictionary) -> bool:
	var landmark_id := StringName(String(transition.get("view_landmark_id", "")))
	if not String(landmark_id).is_empty():
		for landmark in definition.view_landmarks:
			if landmark.get("id") == landmark_id:
				return true
		return true
	var rect: Rect2 = transition["rect"]
	for landmark in definition.view_landmarks:
		if landmark.get("kind", &"") != &"gate_arch":
			continue
		var landmark_rect: Rect2 = landmark["rect"]
		if landmark_rect == rect or landmark_rect.encloses(rect):
			return true
	return false


## Functional transitions get a view-only framed door at the edge of their
## trigger rectangle. The trigger can stay generously sized for navigation;
## the visible door remains at the frozen character scale.


static func build_transition_door(
	transition: Dictionary,
	cell_size: int,
	wall_height_world: float = -1.0
) -> Node3D:
	var root := Node3D.new()
	root.name = "Door_%s" % String(transition["id"])
	root.set_meta("transition_id", transition["id"])

	var scale := MapViewBridge.world_scale(cell_size)
	var rect: Rect2 = transition["rect"]
	var horizontal_wall := rect.size.x >= rect.size.y
	var center := rect.get_center() * scale
	if horizontal_wall:
		# Transition rectangles begin at the wall boundary and extend into the
		# walkable approach, so use the leading edge rather than the center.
		center.y = rect.position.y * scale
	else:
		center.x = rect.position.x * scale
	root.position = Vector3(center.x, 0.0, center.y)
	if not horizontal_wall:
		root.rotation.y = PI * 0.5

	var resolved_wall_height := wall_height_world
	if resolved_wall_height <= 0.0:
		resolved_wall_height = MapViewMeshBuilderConfig.DEFAULT_WALL_HEIGHT_PX[MapTypes.BUILDING_KIND_INTERIOR_WALL] * scale
	var opening_width := (rect.size.x if horizontal_wall else rect.size.y) * scale
	_add_transition_opening_infill(root, opening_width, resolved_wall_height)

	MapViewMeshBuilderPrimitives.box(
		root,
		"Panel",
		Vector3(MapViewMeshBuilderConfig.DOOR_WIDTH, MapViewMeshBuilderConfig.DOOR_HEIGHT, MapViewMeshBuilderConfig.DOOR_THICKNESS),
		Vector3(0.0, MapViewMeshBuilderConfig.DOOR_HEIGHT * 0.5, 0.0),
		&"wood"
	)
	var frame_height := MapViewMeshBuilderConfig.DOOR_HEIGHT + MapViewMeshBuilderConfig.DOOR_FRAME_THICKNESS
	var frame_x := MapViewMeshBuilderConfig.DOOR_WIDTH * 0.5 + MapViewMeshBuilderConfig.DOOR_FRAME_THICKNESS * 0.5
	MapViewMeshBuilderPrimitives.box(root, "FrameLeft", Vector3(MapViewMeshBuilderConfig.DOOR_FRAME_THICKNESS, frame_height, 0.22), Vector3(-frame_x, frame_height * 0.5, 0.0), &"timber")
	MapViewMeshBuilderPrimitives.box(root, "FrameRight", Vector3(MapViewMeshBuilderConfig.DOOR_FRAME_THICKNESS, frame_height, 0.22), Vector3(frame_x, frame_height * 0.5, 0.0), &"timber")
	MapViewMeshBuilderPrimitives.box(root, "Lintel", Vector3(MapViewMeshBuilderConfig.DOOR_WIDTH + MapViewMeshBuilderConfig.DOOR_FRAME_THICKNESS * 2.0, MapViewMeshBuilderConfig.DOOR_FRAME_THICKNESS, 0.22), Vector3(0.0, frame_height, 0.0), &"timber")
	MapViewMeshBuilderPrimitives.box(root, "Threshold", Vector3(MapViewMeshBuilderConfig.DOOR_WIDTH + 0.18, 0.08, 0.28), Vector3(0.0, 0.04, 0.0), &"stone")
	for plank_index in 3:
		var plank_x := -MapViewMeshBuilderConfig.DOOR_WIDTH * 0.25 + float(plank_index) * MapViewMeshBuilderConfig.DOOR_WIDTH * 0.25
		MapViewMeshBuilderPrimitives.box(root, "Plank%d" % plank_index, Vector3(0.025, MapViewMeshBuilderConfig.DOOR_HEIGHT - 0.12, 0.018), Vector3(plank_x, MapViewMeshBuilderConfig.DOOR_HEIGHT * 0.5, MapViewMeshBuilderConfig.DOOR_THICKNESS * 0.5 + 0.01), &"timber")
	MapViewMeshBuilderPrimitives.sphere(root, "Handle", 0.055, Vector3(MapViewMeshBuilderConfig.DOOR_WIDTH * 0.3, MapViewMeshBuilderConfig.DOOR_HEIGHT * 0.52, MapViewMeshBuilderConfig.DOOR_THICKNESS * 0.5 + 0.06), &"metal")
	return root


## Compiler wall openings leave a full-height void. Fill the leftover width and
## headroom so doors do not float inside oversized gaps.


static func _add_transition_opening_infill(
	root: Node3D,
	opening_width: float,
	wall_height_world: float
) -> void:
	var frame_height := MapViewMeshBuilderConfig.DOOR_HEIGHT + MapViewMeshBuilderConfig.DOOR_FRAME_THICKNESS
	var framed_width := MapViewMeshBuilderConfig.DOOR_WIDTH + MapViewMeshBuilderConfig.DOOR_FRAME_THICKNESS * 2.0
	var side_gap := opening_width - framed_width
	if side_gap > 0.08:
		var jamb_width := side_gap * 0.5
		var jamb_x := framed_width * 0.5 + jamb_width * 0.5
		MapViewMeshBuilderPrimitives.box(
			root,
			"OpeningJambL",
			Vector3(jamb_width, frame_height, MapViewMeshBuilderConfig.DOOR_THICKNESS),
			Vector3(-jamb_x, frame_height * 0.5, 0.0),
			&"stone"
		)
		MapViewMeshBuilderPrimitives.box(
			root,
			"OpeningJambR",
			Vector3(jamb_width, frame_height, MapViewMeshBuilderConfig.DOOR_THICKNESS),
			Vector3(jamb_x, frame_height * 0.5, 0.0),
			&"stone"
		)
	var headroom := wall_height_world - frame_height
	if headroom > 0.08:
		MapViewMeshBuilderPrimitives.box(
			root,
			"OpeningHead",
			Vector3(maxf(opening_width, framed_width), headroom, MapViewMeshBuilderConfig.DOOR_THICKNESS),
			Vector3(0.0, frame_height + headroom * 0.5, 0.0),
			&"stone"
		)


## A low translucent patch makes district exits readable without looking like
## ordinary terrain. Runtime proximity raises its opacity for a gentle focus cue.


static func build_transition_marker(transition: Dictionary, cell_size: int) -> Node3D:
	var root := MapViewMeshBuilderConfig.TRANSITION_MARKER_SCRIPT.new() as Node3D
	root.name = "Marker_%s" % String(transition["id"])
	root.set_meta("transition_id", transition["id"])
	var rect: Rect2 = transition["rect"]
	var scale := MapViewBridge.world_scale(cell_size)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Surface"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(rect.size.x * scale, MapViewMeshBuilderConfig.TRANSITION_MARKER_HEIGHT, rect.size.y * scale)
	mesh_instance.mesh = mesh
	mesh_instance.position.y = MapViewMeshBuilderConfig.TRANSITION_MARKER_HEIGHT * 0.5
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = MapViewMeshBuilderConfig.TRANSITION_MARKER_COLOR
	mesh_instance.material_override = material
	root.position = Vector3(rect.get_center().x * scale, 0.0, rect.get_center().y * scale)
	root.add_child(mesh_instance)
	return root


## Parametric primitive assembly per prop kind, anchored at the shared
## definition position so the logic plane and the view agree on placement.

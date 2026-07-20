class_name MapViewMeshBuilderBuildingFacade
extends RefCounted

## Shared facade placement helpers for houses, interior walls, and landmarks.


static func ridge_along_x(building: Dictionary, size: Vector2) -> bool:
	match building.get("ridge_axis", &""):
		&"x":
			return true
		&"z":
			return false
	return size.x >= size.y


static func opposite_side(side: StringName) -> StringName:
	match side:
		&"north":
			return &"south"
		&"south":
			return &"north"
		&"east":
			return &"west"
	return &"east"


## Places a box flush against the given facade, protruding MapViewMeshBuilderConfig.FACADE_RELIEF so it
## reads in the dimetric light.
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
	var out := face_offset + box_size.z * 0.5 - MapViewMeshBuilderConfig.FACADE_RELIEF + 0.06
	var position := Vector3.ZERO
	var size := box_size
	match side:
		&"south":
			position = Vector3(along, center_y, out)
		&"north":
			position = Vector3(along, center_y, -out)
		&"east":
			position = Vector3(out, center_y, along)
			size = Vector3(box_size.z, box_size.y, box_size.x)
		&"west":
			position = Vector3(-out, center_y, along)
			size = Vector3(box_size.z, box_size.y, box_size.x)
	MapViewMeshBuilderPrimitives.box(root, name, size, position, role)


static func add_house_facade(root: Node3D, building: Dictionary, size: Vector2, height: float) -> void:
	var declared: StringName = building.get("door_side", &"south")
	var side := declared if declared != &"none" else &"south"
	var along_x := side == &"north" or side == &"south"
	var facade_length := size.x if along_x else size.y
	var face_offset := (size.y if along_x else size.x) * 0.5
	var id_hash := String(building["id"]).hash()

	var door_height := minf(MapViewMeshBuilderConfig.HOUSE_DOOR_HEIGHT, height - 0.2)
	var door_along := (float(id_hash % 100) / 99.0 - 0.5) * maxf(facade_length - MapViewMeshBuilderConfig.HOUSE_DOOR_WIDTH - 1.2, 0.0) * 0.5
	if declared != &"none":
		facade_box(root, "Door", Vector3(MapViewMeshBuilderConfig.HOUSE_DOOR_WIDTH, door_height, MapViewMeshBuilderConfig.DOOR_THICKNESS), door_along, door_height * 0.5, side, face_offset, &"wood")
		facade_box(root, "DoorLintel", Vector3(MapViewMeshBuilderConfig.HOUSE_DOOR_WIDTH + 0.24, MapViewMeshBuilderConfig.DOOR_FRAME_THICKNESS, MapViewMeshBuilderConfig.DOOR_THICKNESS + 0.02), door_along, door_height + MapViewMeshBuilderConfig.DOOR_FRAME_THICKNESS * 0.5, side, face_offset, &"timber")
		facade_box(root, "DoorStep", Vector3(MapViewMeshBuilderConfig.HOUSE_DOOR_WIDTH + 0.2, 0.09, 0.34), door_along, 0.045, side, face_offset, &"stone")

	var window_count := clampi(int(facade_length / MapViewMeshBuilderConfig.HOUSE_WINDOW_SPACING), 1, 3)
	var window_sill := minf(MapViewMeshBuilderConfig.HOUSE_WINDOW_SILL, height - MapViewMeshBuilderConfig.HOUSE_WINDOW_SIZE.y - 0.15)
	var index := 0
	var faces: Array[StringName] = [side, opposite_side(side)]
	for face in faces:
		for window in window_count:
			var along := (float(window + 1) / float(window_count + 1) - 0.5) * facade_length
			if face == side and absf(along - door_along) < (MapViewMeshBuilderConfig.HOUSE_DOOR_WIDTH + MapViewMeshBuilderConfig.HOUSE_WINDOW_SIZE.x) * 0.62:
				continue
			add_house_window(root, index, along, window_sill, face, face_offset)
			index += 1


static func add_house_window(
	root: Node3D,
	index: int,
	along: float,
	window_sill: float,
	face: StringName,
	face_offset: float
) -> void:
	var w := MapViewMeshBuilderConfig.HOUSE_WINDOW_SIZE.x
	var h := MapViewMeshBuilderConfig.HOUSE_WINDOW_SIZE.y
	var fw := MapViewMeshBuilderConfig.HOUSE_WINDOW_FRAME
	var cy := window_sill + h * 0.5
	var glass_w := w - fw * 2.0
	var glass_h := h - fw * 2.0

	facade_box(root, "WindowFrameL%d" % index, Vector3(fw, h, MapViewMeshBuilderConfig.HOUSE_WINDOW_OUTER_DEPTH), along - w * 0.5 + fw * 0.5, cy, face, face_offset, &"timber")
	facade_box(root, "WindowFrameR%d" % index, Vector3(fw, h, MapViewMeshBuilderConfig.HOUSE_WINDOW_OUTER_DEPTH), along + w * 0.5 - fw * 0.5, cy, face, face_offset, &"timber")
	facade_box(root, "WindowFrameT%d" % index, Vector3(w, fw, MapViewMeshBuilderConfig.HOUSE_WINDOW_OUTER_DEPTH), along, window_sill + h - fw * 0.5, face, face_offset, &"timber")
	facade_box(root, "WindowFrameB%d" % index, Vector3(w, fw, MapViewMeshBuilderConfig.HOUSE_WINDOW_OUTER_DEPTH), along, window_sill + fw * 0.5, face, face_offset, &"timber")
	facade_box(root, "Window%d" % index, Vector3(glass_w, glass_h, MapViewMeshBuilderConfig.HOUSE_WINDOW_GLASS_DEPTH), along, cy, face, face_offset, &"window")
	facade_box(root, "WindowMullionV%d" % index, Vector3(MapViewMeshBuilderConfig.HOUSE_WINDOW_MULLION, glass_h, MapViewMeshBuilderConfig.HOUSE_WINDOW_MULLION_DEPTH), along, cy, face, face_offset, &"wood")
	facade_box(root, "WindowMullionH%d" % index, Vector3(glass_w, MapViewMeshBuilderConfig.HOUSE_WINDOW_MULLION, MapViewMeshBuilderConfig.HOUSE_WINDOW_MULLION_DEPTH), along, cy, face, face_offset, &"wood")
	facade_box(root, "WindowLintel%d" % index, Vector3(w + 0.18, 0.1, 0.09), along, window_sill + h + 0.05, face, face_offset, &"timber")
	facade_box(root, "WindowSill%d" % index, Vector3(w + 0.18, 0.08, 0.12), along, window_sill - 0.04, face, face_offset, &"timber")

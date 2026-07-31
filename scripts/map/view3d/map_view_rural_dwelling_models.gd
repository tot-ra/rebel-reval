class_name MapViewRuralDwellingModels
extends RefCounted

## Conservative rural facade treatment for Spring 1343.
##
## The named forms are plausible composites from the excavated 8th-15th-century
## smoke-cottage baseline and the museum's type-level barn-dwelling evidence. They
## intentionally avoid copying surviving 18th/19th-century museum facades.

const SMOKE_COTTAGE_PRIMITIVE := &"smoke_cottage_1343"
const BARN_DWELLING_PRIMITIVE := &"barn_dwelling_1343"
const RURAL_BARN_PRIMITIVE := &"rural_barn_1343"

const RURAL_PRIMITIVES: Array[StringName] = [
	SMOKE_COTTAGE_PRIMITIVE,
	BARN_DWELLING_PRIMITIVE,
	RURAL_BARN_PRIMITIVE,
]

const DWELLING_DOOR_WIDTH := 0.88
const DWELLING_DOOR_HEIGHT := 1.78
const WORK_GATE_HEIGHT := 2.32
const WORK_GATE_MAX_WIDTH := 2.7
const WORK_GATE_MIN_WIDTH := 1.75
const BAY_SEAM_WIDTH := 0.12
const BAY_SEAM_DEPTH := 0.08
const VENT_SIZE := Vector2(0.34, 0.25)


static func is_rural_1343(building: Dictionary) -> bool:
	return StringName(building.get("primitive", &"")) in RURAL_PRIMITIVES


static func is_smoke_heated(building: Dictionary) -> bool:
	return StringName(building.get("primitive", &"")) in [
		SMOKE_COTTAGE_PRIMITIVE,
		BARN_DWELLING_PRIMITIVE,
	]


static func add_facade(
	root: Node3D,
	building: Dictionary,
	size: Vector2,
	height: float
) -> void:
	var side: StringName = building.get("door_side", &"south")
	if side == &"none":
		return
	var along_x := side in [&"north", &"south"]
	var facade_length := size.x if along_x else size.y
	var face_offset := (size.y if along_x else size.x) * 0.5
	var primitive := StringName(building.get("primitive", &""))
	var seed := String(building.get("id", &"rural_building")).hash()

	match primitive:
		BARN_DWELLING_PRIMITIVE:
			_add_barn_dwelling_front(root, side, facade_length, face_offset, height, seed)
		RURAL_BARN_PRIMITIVE:
			_add_work_gate(root, "ThreshingGate", 0.0, side, face_offset, height, facade_length, seed)
		_:
			_add_human_door(root, "Door", 0.0, side, face_offset, height, seed)
			_add_smoke_vent(root, side, face_offset, height, facade_length)


static func _facade_box(
	root: Node3D,
	name: String,
	box_size: Vector3,
	along: float,
	center_y: float,
	side: StringName,
	face_offset: float,
	role: StringName
) -> void:
	# Kept local to avoid a Rural -> Facade -> Houses resource cycle while this
	# focused primitive module is preloaded by the shared house-style facade.
	var out := face_offset + box_size.z * 0.5 - MapViewMeshBuilderConfig.FACADE_RELIEF
	var position := Vector3(along, center_y, out)
	var size := box_size
	match side:
		&"north":
			position = Vector3(along, center_y, -out)
		&"east":
			position = Vector3(out, center_y, along)
			size = Vector3(box_size.z, box_size.y, box_size.x)
		&"west":
			position = Vector3(-out, center_y, along)
			size = Vector3(box_size.z, box_size.y, box_size.x)
	MapViewMeshBuilderPrimitives.box(root, name, size, position, role)


static func _add_barn_dwelling_front(
	root: Node3D,
	side: StringName,
	facade_length: float,
	face_offset: float,
	height: float,
	seed: int
) -> void:
	# WHY: the early evidence supports a heated room plus threshing floor, while
	# later chambers must not silently appear. The seam makes that two-part working
	# sequence readable without claiming an excavated facade plan.
	var room_share := 0.38
	var room_center := -facade_length * (1.0 - room_share) * 0.5
	var work_center := facade_length * room_share * 0.5
	_facade_box(
		root,
		"BarnDwellingBaySeam",
		Vector3(BAY_SEAM_WIDTH, maxf(height - 0.32, 0.4), BAY_SEAM_DEPTH),
		facade_length * (room_share - 0.5),
		maxf(height - 0.32, 0.4) * 0.5 + 0.08,
		side,
		face_offset,
		&"timber"
	)
	_add_human_door(root, "DwellingDoor", room_center, side, face_offset, height, seed)
	_add_work_gate(root, "ThreshingGate", work_center, side, face_offset, height, facade_length, seed + 101)
	_add_smoke_vent(root, side, face_offset, height, facade_length, room_center)


static func _add_human_door(
	root: Node3D,
	name_prefix: String,
	along: float,
	side: StringName,
	face_offset: float,
	height: float,
	seed: int
) -> void:
	var door_height := minf(DWELLING_DOOR_HEIGHT, height - 0.18)
	var transform := MapViewDoorBuilder.facade_transform(
		along,
		side,
		face_offset,
		MapViewMeshBuilderConfig.DOOR_THICKNESS
	)
	MapViewDoorBuilder.add_leaf(
		root,
		name_prefix,
		name_prefix,
		DWELLING_DOOR_WIDTH,
		door_height,
		MapViewMeshBuilderConfig.DOOR_THICKNESS,
		transform,
		seed
	)
	MapViewDoorBuilder.add_frame(
		root,
		name_prefix,
		DWELLING_DOOR_WIDTH,
		door_height,
		MapViewMeshBuilderConfig.HOUSE_DOOR_FRAME_WIDTH,
		MapViewMeshBuilderConfig.HOUSE_DOOR_FRAME_DEPTH,
		transform,
		seed,
		false
	)


static func _add_work_gate(
	root: Node3D,
	name_prefix: String,
	along: float,
	side: StringName,
	face_offset: float,
	height: float,
	facade_length: float,
	seed: int
) -> void:
	var gate_width := clampf(facade_length * 0.32, WORK_GATE_MIN_WIDTH, WORK_GATE_MAX_WIDTH)
	var gate_height := minf(WORK_GATE_HEIGHT, height - 0.15)
	var transform := MapViewDoorBuilder.facade_transform(
		along,
		side,
		face_offset,
		MapViewMeshBuilderConfig.DOOR_THICKNESS
	)
	MapViewDoorBuilder.add_leaf(
		root,
		name_prefix,
		name_prefix,
		gate_width,
		gate_height,
		MapViewMeshBuilderConfig.DOOR_THICKNESS,
		transform,
		seed
	)
	MapViewDoorBuilder.add_frame(
		root,
		name_prefix,
		gate_width,
		gate_height,
		MapViewMeshBuilderConfig.HOUSE_DOOR_FRAME_WIDTH * 1.15,
		MapViewMeshBuilderConfig.HOUSE_DOOR_FRAME_DEPTH,
		transform,
		seed,
		false
	)


static func _add_smoke_vent(
	root: Node3D,
	side: StringName,
	face_offset: float,
	height: float,
	facade_length: float,
	along: float = 0.0
) -> void:
	# This is a dark, unglazed smoke/light aperture, not a late glazed window.
	var vent_along := clampf(along, -facade_length * 0.32, facade_length * 0.32)
	_facade_box(
		root,
		"SmokeVent",
		Vector3(VENT_SIZE.x, VENT_SIZE.y, 0.035),
		vent_along,
		minf(height - VENT_SIZE.y, height * 0.67),
		side,
		face_offset,
		&"ink"
	)

class_name DirectionSign3D
extends RefCounted

## Reusable view-only wooden road sign for destinations beyond the town walls.
## The map definition owns placement, label, and the outgoing ground-plane
## direction; this builder only turns those declarative values into 3D geometry.

const MeshBuilderPrimitives := preload(
	"res://scripts/map/view3d/map_view_mesh_builder_primitives.gd"
)

# Halved from the original footprint so signs read as hand-built waymarks, not
# highway signage at the fixed dimetric camera distance.
const POST_HEIGHT := 1.35
const POST_RADIUS := 0.0425
const BOARD_HEIGHT := 0.26
const BOARD_MIN_BODY_LENGTH := 1.0
const BOARD_MAX_BODY_LENGTH := 1.5
const BOARD_TEXT_PADDING := 0.09
const TEXT_OFFSET_X := -0.06
const ARROW_HEAD_LENGTH := 0.325
const ARROW_HEAD_HEIGHT := 0.39
const BOARD_THICKNESS := 0.06
const BOARD_HEIGHT_FROM_GROUND := 1.125
const TEXT_FONT_SIZE := 44
const TEXT_PIXEL_SIZE := 0.00275
const BODY_PLANK_COUNT := 3
const PLANK_GAP := 0.006
const NAIL_HEAD_RADIUS := 0.008
const NAIL_HEAD_THICKNESS := 0.003
# Pale painted letters and an opaque dark outline remain readable against timber
# in both the warm daylight palette and the blue-black night lighting.
const TEXT_COLOR := Color(0.96, 0.86, 0.62)
const TEXT_OUTLINE_COLOR := Color(0.055, 0.035, 0.02)
const TEXT_OUTLINE_SIZE := 6


static func build(sign: Dictionary, cell_size: int) -> Node3D:
	var root := Node3D.new()
	root.name = "DirectionSign_%s" % _node_safe_name(String(sign["text"]))
	root.set_meta("direction_text", sign["text"])
	root.set_meta("outside_direction", sign["direction"])

	var position_2d: Vector2 = sign["position"]
	root.position = MapViewBridge.logic_to_world(position_2d, cell_size)
	var direction: Vector2 = sign["direction"]
	root.rotation.y = atan2(-direction.y, direction.x)

	var text := String(sign["text"])
	var board_length := _board_length_for_text(text)
	var sign_seed := text.hash()
	_add_post(root)
	_add_arrow_board(root, board_length, sign_seed)
	_add_text(root, text, false, board_length)
	_add_text(root, text, true, board_length)
	return root


static func _add_post(root: Node3D) -> void:
	var post := MeshInstance3D.new()
	post.name = "Post"
	var mesh := CylinderMesh.new()
	mesh.top_radius = POST_RADIUS * 0.88
	mesh.bottom_radius = POST_RADIUS
	mesh.height = POST_HEIGHT
	mesh.radial_segments = 8
	post.mesh = mesh
	post.position.y = POST_HEIGHT * 0.5
	post.material_override = MapViewMaterials.role(&"timber")
	root.add_child(post)


static func _add_arrow_board(root: Node3D, board_length: float, sign_seed: int) -> void:
	var metal := MapViewMaterials.role(&"metal")

	var body := Node3D.new()
	body.name = "ArrowBody"
	body.position = Vector3(0.0, BOARD_HEIGHT_FROM_GROUND, 0.0)
	root.add_child(body)
	_add_body_planks(body, board_length, metal, sign_seed)

	var head := Node3D.new()
	head.name = "ArrowHead"
	head.position = Vector3(board_length * 0.5, BOARD_HEIGHT_FROM_GROUND, 0.0)
	root.add_child(head)
	_add_head_planks(head, metal, sign_seed)


static func _add_body_planks(
	parent: Node3D, board_length: float, metal: StandardMaterial3D, sign_seed: int
) -> void:
	var plank_width := (
		(board_length - PLANK_GAP * float(BODY_PLANK_COUNT - 1)) / float(BODY_PLANK_COUNT)
	)
	var x_start := -board_length * 0.5 + plank_width * 0.5
	var half_thickness := BOARD_THICKNESS * 0.5

	for plank_index in BODY_PLANK_COUNT:
		var variation := _variation(sign_seed, plank_index)
		var plank_height := BOARD_HEIGHT * (1.0 + variation * 0.07)
		var plank_depth := BOARD_THICKNESS * (0.9 + absf(variation) * 0.08)
		var plank := MeshInstance3D.new()
		plank.name = "Plank%d" % plank_index
		var mesh := BoxMesh.new()
		mesh.size = Vector3(
			plank_width * (0.97 + absf(variation) * 0.04), plank_height, plank_depth
		)
		plank.mesh = mesh
		var x := x_start + float(plank_index) * (plank_width + PLANK_GAP)
		plank.position = Vector3(x, variation * 0.01, variation * 0.003)
		plank.rotation.z = variation * 0.035
		plank.material_override = MapViewMaterials.role_for_size(&"timber", mesh.size)
		parent.add_child(plank)

		for y_sign in [-1.0, 1.0]:
			for z_sign in [-1.0, 1.0]:
				_add_nail_head(
					parent,
					"NailBody%d_%d_%d" % [plank_index, int(y_sign > 0.0), int(z_sign > 0.0)],
					Vector3(
						x,
						y_sign * plank_height * 0.38,
						z_sign * (half_thickness + NAIL_HEAD_THICKNESS * 0.45)
					),
					z_sign,
					metal
				)


static func _add_head_planks(parent: Node3D, metal: StandardMaterial3D, sign_seed: int) -> void:
	var half_height := ARROW_HEAD_HEIGHT * 0.5
	var head_length := ARROW_HEAD_LENGTH
	var slope_length := sqrt(head_length * head_length + half_height * half_height)
	var slope_angle := atan2(half_height, head_length)

	for side_index in 2:
		var side := 1.0 if side_index == 0 else -1.0
		var variation := _variation(sign_seed, side_index + 11)
		var plank := MeshInstance3D.new()
		plank.name = "HeadPlank%d" % side_index
		var mesh := BoxMesh.new()
		mesh.size = Vector3(
			slope_length * (0.98 + absf(variation) * 0.03),
			BOARD_THICKNESS * (0.88 + absf(variation) * 0.06),
			BOARD_HEIGHT * 0.42
		)
		plank.mesh = mesh
		plank.rotation.z = -side * slope_angle + variation * 0.02
		plank.position = Vector3(
			head_length * 0.5 - slope_length * 0.5 * cos(slope_angle),
			side * half_height * 0.34 + variation * 0.008,
			variation * 0.004
		)
		plank.material_override = MapViewMaterials.role_for_size(&"timber", mesh.size)
		parent.add_child(plank)

		_add_nail_head(
			parent,
			"NailHead%d" % side_index,
			Vector3(
				0.02,
				side * half_height * 0.22,
				side * (BOARD_THICKNESS * 0.5 + NAIL_HEAD_THICKNESS * 0.45)
			),
			side,
			metal
		)


static func _add_nail_head(
	parent: Node3D,
	nail_name: String,
	position: Vector3,
	face_sign: float,
	metal: StandardMaterial3D
) -> void:
	var nail := MeshInstance3D.new()
	nail.name = nail_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = NAIL_HEAD_RADIUS
	mesh.bottom_radius = NAIL_HEAD_RADIUS * 0.82
	mesh.height = NAIL_HEAD_THICKNESS
	mesh.radial_segments = 6
	nail.mesh = mesh
	nail.position = position
	nail.rotation.x = PI * 0.5 if face_sign > 0.0 else -PI * 0.5
	nail.material_override = metal
	parent.add_child(nail)


static func _variation(seed: int, index: int) -> float:
	return MeshBuilderPrimitives.hash01(index, seed & 0xFFFF, seed) * 2.0 - 1.0


static func _add_text(root: Node3D, text: String, back: bool, board_length: float) -> void:
	var label := Label3D.new()
	label.name = "TextBack" if back else "TextFront"
	label.text = text
	label.font_size = TEXT_FONT_SIZE
	label.pixel_size = _text_pixel_size(text, board_length)
	label.modulate = TEXT_COLOR
	label.outline_modulate = TEXT_OUTLINE_COLOR
	label.outline_size = TEXT_OUTLINE_SIZE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector3(
		TEXT_OFFSET_X,
		BOARD_HEIGHT_FROM_GROUND,
		-BOARD_THICKNESS * 0.5 - 0.008 if back else BOARD_THICKNESS * 0.5 + 0.008
	)
	if back:
		label.rotation.y = PI
	root.add_child(label)


## Short destinations should not inherit the footprint required by the longest
## map label. Long text is scaled only enough to fit the capped board width.
static func _board_length_for_text(text: String) -> float:
	return clampf(
		(
			_text_width_pixels(text) * TEXT_PIXEL_SIZE
			+ BOARD_TEXT_PADDING * 2.0
			+ absf(TEXT_OFFSET_X) * 2.0
		),
		BOARD_MIN_BODY_LENGTH,
		BOARD_MAX_BODY_LENGTH
	)


static func _text_pixel_size(text: String, board_length: float) -> float:
	var available_width := board_length - BOARD_TEXT_PADDING * 2.0 - absf(TEXT_OFFSET_X) * 2.0
	return minf(TEXT_PIXEL_SIZE, available_width / _text_width_pixels(text))


static func _text_width_pixels(text: String) -> float:
	return maxf(
		1.0,
		(
			ThemeDB
			. fallback_font
			. get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TEXT_FONT_SIZE)
			. x
		)
	)


static func _node_safe_name(value: String) -> String:
	return value.strip_edges().replace(" ", "_").to_lower()

class_name DirectionSign3D
extends RefCounted

## Reusable view-only wooden road sign for destinations beyond the town walls.
## The map definition owns placement, label, and the outgoing ground-plane
## direction; this builder only turns those declarative values into 3D geometry.

const POST_HEIGHT := 2.7
const POST_RADIUS := 0.085
const BOARD_HEIGHT := 0.52
const BOARD_MIN_BODY_LENGTH := 2.0
const BOARD_MAX_BODY_LENGTH := 3.0
const BOARD_TEXT_PADDING := 0.18
const TEXT_OFFSET_X := -0.12
const ARROW_HEAD_LENGTH := 0.65
const ARROW_HEAD_HEIGHT := 0.78
const BOARD_THICKNESS := 0.12
const BOARD_HEIGHT_FROM_GROUND := 2.25
const TEXT_FONT_SIZE := 56
const TEXT_PIXEL_SIZE := 0.0055
# Pale painted letters and an opaque dark outline remain readable against timber
# in both the warm daylight palette and the blue-black night lighting.
const TEXT_COLOR := Color(0.96, 0.86, 0.62)
const TEXT_OUTLINE_COLOR := Color(0.055, 0.035, 0.02)
const TEXT_OUTLINE_SIZE := 7


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
	_add_post(root)
	_add_arrow_board(root, board_length)
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


static func _add_arrow_board(root: Node3D, board_length: float) -> void:
	var body := MeshInstance3D.new()
	body.name = "ArrowBody"
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(board_length, BOARD_HEIGHT, BOARD_THICKNESS)
	body.mesh = body_mesh
	body.position = Vector3(0.0, BOARD_HEIGHT_FROM_GROUND, 0.0)
	body.material_override = MapViewMaterials.role(&"wood")
	root.add_child(body)

	var head := MeshInstance3D.new()
	head.name = "ArrowHead"
	head.mesh = _arrow_head_mesh()
	head.position = Vector3(board_length * 0.5, BOARD_HEIGHT_FROM_GROUND, 0.0)
	head.material_override = MapViewMaterials.role(&"wood")
	root.add_child(head)


## A shallow triangular prism keeps the silhouette unmistakably arrow-shaped
## from the fixed dimetric camera while retaining visible wooden side faces.
static func _arrow_head_mesh() -> ArrayMesh:
	var half_height := ARROW_HEAD_HEIGHT * 0.5
	var half_depth := BOARD_THICKNESS * 0.5
	var points := [
		Vector3(0.0, -half_height, -half_depth),
		Vector3(0.0, half_height, -half_depth),
		Vector3(ARROW_HEAD_LENGTH, 0.0, -half_depth),
		Vector3(0.0, -half_height, half_depth),
		Vector3(0.0, half_height, half_depth),
		Vector3(ARROW_HEAD_LENGTH, 0.0, half_depth),
	]
	var triangles := PackedInt32Array([
		0, 2, 1,
		3, 4, 5,
		0, 3, 5, 0, 5, 2,
		1, 2, 5, 1, 5, 4,
		0, 1, 4, 0, 4, 3,
	])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in triangles:
		surface.add_vertex(points[index])
	surface.generate_normals()
	return surface.commit()


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
	label.position = Vector3(TEXT_OFFSET_X, BOARD_HEIGHT_FROM_GROUND, -BOARD_THICKNESS * 0.5 - 0.012 if back else BOARD_THICKNESS * 0.5 + 0.012)
	if back:
		label.rotation.y = PI
	root.add_child(label)


## Short destinations should not inherit the footprint required by the longest
## map label. Long text is scaled only enough to fit the capped board width.
static func _board_length_for_text(text: String) -> float:
	return clampf(
		_text_width_pixels(text) * TEXT_PIXEL_SIZE + BOARD_TEXT_PADDING * 2.0 + absf(TEXT_OFFSET_X) * 2.0,
		BOARD_MIN_BODY_LENGTH,
		BOARD_MAX_BODY_LENGTH
	)


static func _text_pixel_size(text: String, board_length: float) -> float:
	var available_width := board_length - BOARD_TEXT_PADDING * 2.0 - absf(TEXT_OFFSET_X) * 2.0
	return minf(TEXT_PIXEL_SIZE, available_width / _text_width_pixels(text))


static func _text_width_pixels(text: String) -> float:
	return maxf(
		1.0,
		ThemeDB.fallback_font.get_string_size(
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			TEXT_FONT_SIZE
		).x
	)


static func _node_safe_name(value: String) -> String:
	return value.strip_edges().replace(" ", "_").to_lower()

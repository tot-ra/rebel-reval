class_name DirectionSign3D
extends RefCounted

## Reusable view-only wooden road sign for destinations beyond the town walls.
## The map definition owns placement, label, and the outgoing ground-plane
## direction; this builder only turns those declarative values into 3D geometry.

const POST_HEIGHT := 3.2
const POST_RADIUS := 0.11
const BOARD_HEIGHT := 0.72
const BOARD_BODY_LENGTH := 3.5
const ARROW_HEAD_LENGTH := 0.9
const ARROW_HEAD_HEIGHT := 1.12
const BOARD_THICKNESS := 0.16
const BOARD_HEIGHT_FROM_GROUND := 2.65
const TEXT_FONT_SIZE := 48
const TEXT_PIXEL_SIZE := 0.007
const TEXT_COLOR := Color(0.15, 0.09, 0.045)
const TEXT_OUTLINE_COLOR := Color(0.76, 0.56, 0.32, 0.5)


static func build(sign: Dictionary, cell_size: int) -> Node3D:
	var root := Node3D.new()
	root.name = "DirectionSign_%s" % _node_safe_name(String(sign["text"]))
	root.set_meta("direction_text", sign["text"])
	root.set_meta("outside_direction", sign["direction"])

	var position_2d: Vector2 = sign["position"]
	root.position = MapViewBridge.logic_to_world(position_2d, cell_size)
	var direction: Vector2 = sign["direction"]
	root.rotation.y = atan2(-direction.y, direction.x)

	_add_post(root)
	_add_arrow_board(root)
	_add_text(root, String(sign["text"]), false)
	_add_text(root, String(sign["text"]), true)
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


static func _add_arrow_board(root: Node3D) -> void:
	var body := MeshInstance3D.new()
	body.name = "ArrowBody"
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(BOARD_BODY_LENGTH, BOARD_HEIGHT, BOARD_THICKNESS)
	body.mesh = body_mesh
	body.position = Vector3(0.0, BOARD_HEIGHT_FROM_GROUND, 0.0)
	body.material_override = MapViewMaterials.role(&"wood")
	root.add_child(body)

	var head := MeshInstance3D.new()
	head.name = "ArrowHead"
	head.mesh = _arrow_head_mesh()
	head.position = Vector3(BOARD_BODY_LENGTH * 0.5, BOARD_HEIGHT_FROM_GROUND, 0.0)
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


static func _add_text(root: Node3D, text: String, back: bool) -> void:
	var label := Label3D.new()
	label.name = "TextBack" if back else "TextFront"
	label.text = text
	label.font_size = TEXT_FONT_SIZE
	label.pixel_size = TEXT_PIXEL_SIZE
	label.modulate = TEXT_COLOR
	label.outline_modulate = TEXT_OUTLINE_COLOR
	label.outline_size = 4
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector3(-0.35, BOARD_HEIGHT_FROM_GROUND, -BOARD_THICKNESS * 0.5 - 0.012 if back else BOARD_THICKNESS * 0.5 + 0.012)
	if back:
		label.rotation.y = PI
	root.add_child(label)


static func _node_safe_name(value: String) -> String:
	return value.strip_edges().replace(" ", "_").to_lower()

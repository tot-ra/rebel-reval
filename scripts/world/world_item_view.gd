class_name WorldItemView
extends Node3D

## Mirrors a world item onto the 3D view with a simple contour highlight.

const HIGHLIGHT_COLOR := Color(0.396, 0.694, 0.769, 0.55)

var _highlight: MeshInstance3D


func configure(item_scene: PackedScene, logic_position: Vector2, cell_size: int) -> void:
	for child in get_children():
		child.queue_free()
	_highlight = null

	if item_scene != null:
		var item_root := item_scene.instantiate() as Node3D
		if item_root != null:
			add_child(item_root)

	MapViewBridge.sync_actor(self, logic_position, cell_size)
	_build_highlight()


func sync_logic_position(logic_position: Vector2, cell_size: int) -> void:
	MapViewBridge.sync_actor(self, logic_position, cell_size)


func set_hovered(value: bool) -> void:
	if _highlight != null:
		_highlight.visible = value


func _build_highlight() -> void:
	_highlight = MeshInstance3D.new()
	_highlight.name = "ContourHighlight"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.42, 0.06, 0.42)
	_highlight.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = HIGHLIGHT_COLOR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_highlight.material_override = material
	_highlight.position = Vector3(0.0, 0.04, 0.0)
	_highlight.visible = false
	add_child(_highlight)

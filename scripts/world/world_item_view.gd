class_name WorldItemView
extends Node3D

## Mirrors a world item onto the 3D view with a persistent yellow pickup outline.

const OUTLINE_COLOR_IDLE := Color(0.95, 0.82, 0.35, 0.9)
const OUTLINE_COLOR_HOVER := Color(1.0, 0.93, 0.5, 1.0)
const FRAME_HALF_SIZE := 0.21
const FRAME_THICKNESS := 0.015
const FRAME_HEIGHT := 0.025
const FRAME_Y := 0.04

var _outline_root: Node3D
var _outline_material: StandardMaterial3D
var _hovered := false


func configure(item_scene: PackedScene, logic_position: Vector2, cell_size: int) -> void:
	for child in get_children():
		child.queue_free()
	_outline_root = null
	_outline_material = null
	_hovered = false

	if item_scene != null:
		var item_root := item_scene.instantiate() as Node3D
		if item_root != null:
			add_child(item_root)

	MapViewBridge.sync_actor(self, logic_position, cell_size)
	_build_outline()


func sync_logic_position(logic_position: Vector2, cell_size: int) -> void:
	MapViewBridge.sync_actor(self, logic_position, cell_size)


func set_hovered(value: bool) -> void:
	if _hovered == value:
		return
	_hovered = value
	_apply_outline_color()


func _build_outline() -> void:
	_outline_root = Node3D.new()
	_outline_root.name = "PickupOutline"
	_outline_material = _make_outline_material(OUTLINE_COLOR_IDLE)

	var half := FRAME_HALF_SIZE
	var thickness := FRAME_THICKNESS
	var inner := half * 2.0 - thickness * 2.0
	_add_frame_edge(Vector3(0.0, FRAME_Y, -half + thickness * 0.5), Vector3(half * 2.0, FRAME_HEIGHT, thickness))
	_add_frame_edge(Vector3(0.0, FRAME_Y, half - thickness * 0.5), Vector3(half * 2.0, FRAME_HEIGHT, thickness))
	_add_frame_edge(Vector3(-half + thickness * 0.5, FRAME_Y, 0.0), Vector3(thickness, FRAME_HEIGHT, inner))
	_add_frame_edge(Vector3(half - thickness * 0.5, FRAME_Y, 0.0), Vector3(thickness, FRAME_HEIGHT, inner))
	add_child(_outline_root)


func _add_frame_edge(position: Vector3, size: Vector3) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _outline_material
	mesh_instance.position = position
	_outline_root.add_child(mesh_instance)


func _make_outline_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _apply_outline_color() -> void:
	if _outline_material == null:
		return
	_outline_material.albedo_color = OUTLINE_COLOR_HOVER if _hovered else OUTLINE_COLOR_IDLE

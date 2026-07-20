class_name CharacterHealthRing3D
extends Node3D

## Overhead horizontal health bar for shared character rigs in the 3D map view.
## Sits just above the 2.0-unit visible-height contract and depletes left-to-right.

const BAR_WIDTH := 0.72
const BAR_HEIGHT := 0.07
const BAR_Y := 2.18

var _background: MeshInstance3D
var _fill: MeshInstance3D
var _fill_material: StandardMaterial3D

var current_health := 100.0
var max_health := 100.0


func _ready() -> void:
	_build_nodes()
	set_health(current_health, max_health)


func set_health(current: float, maximum: float) -> void:
	current_health = maxf(current, 0.0)
	max_health = maxf(maximum, 0.0)
	_update_fill()


func get_health_ratio() -> float:
	if max_health <= 0.0:
		return 0.0
	return clampf(current_health / max_health, 0.0, 1.0)


func _build_nodes() -> void:
	position = Vector3(0.0, BAR_Y, 0.0)

	_background = MeshInstance3D.new()
	_background.name = "Background"
	# Offset baked into mesh vertices so FIXED_Y billboarding keeps left/right correct.
	_background.mesh = _make_bar_mesh(BAR_WIDTH, BAR_HEIGHT, 0.0)
	_background.material_override = _make_bar_material(CharacterHealthRing.COLOR_BACKGROUND)
	add_child(_background)

	_fill = MeshInstance3D.new()
	_fill.name = "Fill"
	_fill_material = _make_bar_material(CharacterHealthRing.COLOR_HEALTHY)
	_fill.material_override = _fill_material
	add_child(_fill)


func _update_fill() -> void:
	if _fill == null or _fill_material == null:
		return
	var ratio := get_health_ratio()
	_fill_material.albedo_color = CharacterHealthRing.color_for_ratio(ratio)
	if ratio <= 0.0:
		_fill.mesh = null
		_fill.visible = false
		return
	_fill.visible = true
	var width := BAR_WIDTH * ratio
	# Keep the fill's left edge locked to the background's left edge.
	var center_x := -0.5 * BAR_WIDTH + 0.5 * width
	_fill.mesh = _make_bar_mesh(width, BAR_HEIGHT, center_x)


func _make_bar_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Fixed-Y billboard keeps the bar upright and readable from the isometric camera.
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.billboard_keep_scale = true
	return material


static func _make_bar_mesh(width: float, height: float, center_x: float) -> ArrayMesh:
	var half_w := width * 0.5
	var half_h := height * 0.5
	var left := center_x - half_w
	var right := center_x + half_w
	var vertices := PackedVector3Array([
		Vector3(left, -half_h, 0.0),
		Vector3(right, -half_h, 0.0),
		Vector3(right, half_h, 0.0),
		Vector3(left, half_h, 0.0),
	])
	var normals := PackedVector3Array([
		Vector3.BACK,
		Vector3.BACK,
		Vector3.BACK,
		Vector3.BACK,
	])
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

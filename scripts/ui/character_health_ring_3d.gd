class_name CharacterHealthRing3D
extends Node3D

## Overhead horizontal health bar for shared character rigs in the 3D map view.
## Sits just above the 2.0-unit visible-height contract and depletes left-to-right.
## Orientation is driven in _process so the bar never inherits skeleton yaw and
## never uses shader billboarding (both caused green/dark flicker).

const BAR_WIDTH := 0.72
const BAR_HEIGHT := 0.07
const BAR_Y := 2.18
## Push fill slightly toward the camera to avoid z-fighting with the background.
const FILL_Z_BIAS := 0.002
## Optional thin stamina strip under the health bar (R-1756); built on first use
## so actors that never report stamina keep the single bar.
const STAMINA_HEIGHT := 0.035
const STAMINA_GAP := 0.02
const COLOR_STAMINA := Color(0.93, 0.78, 0.25, 0.95)

var current_health := 100.0
var max_health := 100.0

var _background: MeshInstance3D
var _fill: MeshInstance3D
var _fill_material: StandardMaterial3D
var _applied_ratio := -1.0
var _stamina_fill: MeshInstance3D
var _stamina_ratio := -1.0

func _ready() -> void:
	_build_nodes()
	set_health(current_health, max_health)


func _process(_delta: float) -> void:
	_face_camera_upright()


func set_health(current: float, maximum: float) -> void:
	var next_current := maxf(current, 0.0)
	var next_maximum := maxf(maximum, 0.0)
	# Runtime syncs every frame; skip when HP is unchanged after first apply.
	if (
		_applied_ratio >= 0.0
		and is_equal_approx(next_current, current_health)
		and is_equal_approx(next_maximum, max_health)
	):
		return
	current_health = next_current
	max_health = next_maximum
	_update_fill()


func set_stamina(current: float, maximum: float) -> void:
	var ratio := clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
	if is_equal_approx(ratio, _stamina_ratio):
		return
	_stamina_ratio = ratio
	if _stamina_fill == null:
		if _background == null:
			return
		var y := -(BAR_HEIGHT + STAMINA_HEIGHT) * 0.5 - STAMINA_GAP
		var back := MeshInstance3D.new()
		back.name = "StaminaBackground"
		back.mesh = _make_bar_mesh(BAR_WIDTH, STAMINA_HEIGHT)
		back.material_override = _make_bar_material(CharacterHealthRing.COLOR_BACKGROUND)
		back.position.y = y
		add_child(back)
		_stamina_fill = MeshInstance3D.new()
		_stamina_fill.name = "StaminaFill"
		_stamina_fill.mesh = _make_bar_mesh(BAR_WIDTH, STAMINA_HEIGHT)
		_stamina_fill.material_override = _make_bar_material(COLOR_STAMINA)
		_stamina_fill.position = Vector3(0.0, y, FILL_Z_BIAS)
		add_child(_stamina_fill)
	_stamina_fill.visible = ratio > 0.0
	_stamina_fill.scale = Vector3(maxf(ratio, 0.001), 1.0, 1.0)
	_stamina_fill.position.x = -0.5 * BAR_WIDTH * (1.0 - ratio)


func get_stamina_ratio() -> float:
	return maxf(_stamina_ratio, 0.0)


func get_health_ratio() -> float:
	if max_health <= 0.0:
		return 0.0
	return clampf(current_health / max_health, 0.0, 1.0)


func _build_nodes() -> void:
	position = Vector3(0.0, BAR_Y, 0.0)

	_background = MeshInstance3D.new()
	_background.name = "Background"
	_background.mesh = _make_bar_mesh(BAR_WIDTH, BAR_HEIGHT)
	_background.material_override = _make_bar_material(CharacterHealthRing.COLOR_BACKGROUND)
	add_child(_background)

	_fill = MeshInstance3D.new()
	_fill.name = "Fill"
	# Full-width mesh; depletion uses scale.x + position.x (no per-frame remesh).
	_fill.mesh = _make_bar_mesh(BAR_WIDTH, BAR_HEIGHT)
	_fill_material = _make_bar_material(CharacterHealthRing.COLOR_HEALTHY)
	_fill.material_override = _fill_material
	_fill.position.z = FILL_Z_BIAS
	add_child(_fill)


func _update_fill() -> void:
	if _fill == null or _fill_material == null:
		return
	var ratio := get_health_ratio()
	_fill_material.albedo_color = CharacterHealthRing.color_for_ratio(ratio)
	if is_equal_approx(ratio, _applied_ratio):
		return
	_applied_ratio = ratio
	if ratio <= 0.0:
		_fill.visible = false
		return
	_fill.visible = true
	# Left edge stays locked to the background; width shrinks via scale.
	_fill.scale = Vector3(ratio, 1.0, 1.0)
	_fill.position.x = -0.5 * BAR_WIDTH * (1.0 - ratio)


func _face_camera_upright() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	# Match camera yaw only so the bar stays upright and independent of the
	# parent SharedCharacterRig facing (skeleton turn).
	global_rotation = Vector3(0.0, camera.global_rotation.y, 0.0)


func _make_bar_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# No billboard: shader FIXED_Y + parent yaw caused green/dark flicker.
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	return material


static func _make_bar_mesh(width: float, height: float) -> ArrayMesh:
	var half_w := width * 0.5
	var half_h := height * 0.5
	var vertices := PackedVector3Array(
		[
			Vector3(-half_w, -half_h, 0.0),
			Vector3(half_w, -half_h, 0.0),
			Vector3(half_w, half_h, 0.0),
			Vector3(-half_w, half_h, 0.0),
		]
	)
	var normals := PackedVector3Array(
		[
			Vector3.BACK,
			Vector3.BACK,
			Vector3.BACK,
			Vector3.BACK,
		]
	)
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

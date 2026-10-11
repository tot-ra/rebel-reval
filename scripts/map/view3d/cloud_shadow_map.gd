extends Node

## Top-down map of the cloud shade over the ground (cloud_shadow_map.gdshader), drawn into a
## small SubViewport every few frames and read by the god-ray pass instead of evaluating the
## cloud deck and every cell at each ray sample. The shade of air at height y is the map read
## at p.xz - light.xz / light.y * y, so the map itself carries no height.

const SHADER := preload("res://scripts/map/view3d/cloud_shadow_map.gdshader")
const SIZE := 768
## World metres covered: the god-ray far march reaches 1600 m each way.
const WINDOW := 3200.0
## Re-render every Nth frame; clouds and the light drift slowly.
const REFRESH_FRAMES := 3

var _viewport: SubViewport
var _material: ShaderMaterial
var _window := Vector3(0.0, 0.0, WINDOW)
var _frame := 0
var _ready_once := false


func _init() -> void:
	name = "CloudShadowMap"
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(SIZE, SIZE)
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	var rect := ColorRect.new()
	rect.size = Vector2(SIZE, SIZE)
	rect.material = _material
	_viewport.add_child(rect)


func texture() -> Texture2D:
	return _viewport.get_texture()


## (corner x, corner z, world size) of the last render the texture holds.
func window() -> Vector3:
	return _window


## Whether a render has been issued yet (the texture is empty before).
func is_ready() -> bool:
	return _ready_once


## Called every frame by the pass; renders when due. `center` is the camera's world XZ.
func update(center: Vector2, light_dir: Vector3, cloud_cells: Variant) -> void:
	_frame += 1
	if _ready_once and _frame % REFRESH_FRAMES != 0:
		return
	var texel := WINDOW / float(SIZE)
	var corner := (center / texel).floor() * texel - Vector2(WINDOW, WINDOW) * 0.5
	_window = Vector3(corner.x, corner.y, WINDOW)
	_material.set_shader_parameter(&"light_dir", light_dir)
	_material.set_shader_parameter(&"window_origin", corner)
	_material.set_shader_parameter(&"window_size", WINDOW)
	_material.set_shader_parameter(&"cloud_cells", cloud_cells)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_ready_once = true

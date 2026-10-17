class_name PlanarReflection3D
extends Node

## R-1861: planar reflection for puddles and calm inland water (docs/SYSTEMS/WEATHER_GROUND.md
## "Reflections"). The Mobile renderer has no screen-space reflections, so pools mirrored
## only the sky radiance. One extra camera renders the scene mirrored about a horizontal
## plane (the ground or water height near the view) into a reduced-size SubViewport; the
## ground and water shaders read it through the `planar_reflection_*` shader globals
## (planar_reflection.gdshaderinc), so houses, trees and people show in the water.
##
## WHY a proper (non-mirrored) camera: Godot cameras cannot carry a reflection matrix.
## A camera at the mirrored position with its pitch negated sees the mirror image
## flipped vertically, so the shaders read the texture at (x, 1 - y).
##
## Surfaces that sample the texture (ground, water) must never draw into it, or the
## viewport would read its own render target. They and the full-screen overlay passes
## (AO, god rays, fog: they are already applied on top of the main view) carry only
## HIDDEN_LAYER, which the reflection camera culls. The ground seen from below is
## back-face culled anyway, so hiding it costs nothing visible.

const GraphicsPresetsScript := preload("res://scripts/settings/graphics_presets.gd")

## Visual layer drawn by the main camera only (bit 18; 19 is the door facades, 20 the
## player light).
const HIDDEN_LAYER := 18
const HIDDEN_LAYER_BIT := 1 << (HIDDEN_LAYER - 1)
const GLOBAL_TEXTURE := &"planar_reflection_tex"
## x = mirror plane height (world y), y = strength 0..1 (0 = off), z = 1 / main exposure,
## w = height fade distance in metres (surfaces this far off the plane get no reflection).
const GLOBAL_PLANE := &"planar_reflection_plane"
const HEIGHT_FADE := 1.6
## Coarser LODs in the mirror: the image is small and broken up by ripples.
const MESH_LOD_THRESHOLD := 6.0

static var _off_texture: ImageTexture

## Returns the mirror plane height for this frame, or NAN to switch the reflection off
## (no puddles or inland water in view, indoors).
var plane_provider: Callable

var _source: Camera3D
var _viewport: SubViewport
var _camera: Camera3D
var _scale := 0.5
var _active := false
var _plane_y := 0.0


## Puts every visual instance under `node` on the main-camera-only layer.
static func hide_in_reflection(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = HIDDEN_LAYER_BIT
	for child in node.get_children():
		hide_in_reflection(child)


## The reflection camera's transform for a source camera transform and plane height:
## position mirrored below the plane, basis mirrored with its Y axis negated so it stays
## a proper rotation (the image comes out flipped vertically).
static func mirror_transform(source: Transform3D, plane_y: float) -> Transform3D:
	var b := source.basis
	var x := Vector3(b.x.x, -b.x.y, b.x.z)
	var y := -Vector3(b.y.x, -b.y.y, b.y.z)
	var z := Vector3(b.z.x, -b.z.y, b.z.z)
	var o := source.origin
	return Transform3D(Basis(x, y, z), Vector3(o.x, 2.0 * plane_y - o.y, o.z))


## Size of the reflection target for a main viewport size and quality scale.
static func target_size(viewport_size: Vector2i, scale: float) -> Vector2i:
	return Vector2i(
		maxi(int(round(viewport_size.x * scale)), 16), maxi(int(round(viewport_size.y * scale)), 16)
	)


## Black 1x1 stand-in bound while no reflection renders, so the shader global never
## points at a freed viewport texture.
static func off_texture() -> ImageTexture:
	if _off_texture == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.0, 0.0, 0.0, 1.0))
		_off_texture = ImageTexture.create_from_image(img)
	return _off_texture


func configure(source: Camera3D) -> void:
	_source = source
	_viewport = SubViewport.new()
	_viewport.name = "PlanarReflectionViewport"
	# Shares the parent viewport's World3D (sky, sun, fog, every mesh).
	_viewport.own_world_3d = false
	_viewport.transparent_bg = false
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_viewport.use_taa = false
	_viewport.positional_shadow_atlas_size = 0
	_viewport.mesh_lod_threshold = MESH_LOD_THRESHOLD
	_viewport.audio_listener_enable_3d = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.name = "ReflectionCamera"
	_camera.cull_mask = 0xFFFFF & ~HIDDEN_LAYER_BIT
	_viewport.add_child(_camera)
	_camera.current = true
	_set_off()
	RenderingServer.frame_pre_draw.connect(_sync)
	_follow_graphics_quality()


func apply_quality(quality: String) -> void:
	_scale = float(GraphicsPresetsScript.row(quality).get("planar_reflection_scale", 0.5))


func is_active() -> bool:
	return _active


func plane_height() -> float:
	return _plane_y


func viewport() -> SubViewport:
	return _viewport


func reflection_camera() -> Camera3D:
	return _camera


## Runs right before the frame is drawn, after every camera controller moved, so the
## mirror never lags the main view by a frame.
func _sync() -> void:
	if _source == null or not is_instance_valid(_source) or not _source.is_inside_tree():
		return
	var plane := NAN
	if _scale > 0.0 and plane_provider.is_valid():
		plane = float(plane_provider.call())
	if is_nan(plane):
		if _active:
			_set_off()
		return
	_plane_y = plane
	var size := target_size(_source.get_viewport().size, _scale)
	if _viewport.size != size:
		_viewport.size = size
	_camera.global_transform = mirror_transform(_source.global_transform, plane)
	_camera.projection = _source.projection
	_camera.fov = _source.fov
	_camera.size = _source.size
	_camera.keep_aspect = _source.keep_aspect
	_camera.near = _source.near
	_camera.far = _source.far
	if not _active:
		_active = true
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		RenderingServer.global_shader_parameter_set(GLOBAL_TEXTURE, _viewport.get_texture())
	var exposure := 1.0
	var env := _source.get_world_3d().environment if _source.get_world_3d() != null else null
	if env != null:
		exposure = maxf(env.tonemap_exposure, 0.01)
	RenderingServer.global_shader_parameter_set(
		GLOBAL_PLANE, Vector4(plane, 1.0, 1.0 / exposure, HEIGHT_FADE)
	)


func _set_off() -> void:
	_active = false
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	RenderingServer.global_shader_parameter_set(GLOBAL_TEXTURE, off_texture())
	RenderingServer.global_shader_parameter_set(GLOBAL_PLANE, Vector4(0.0, 0.0, 1.0, HEIGHT_FADE))


func _follow_graphics_quality() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var settings := tree.root.get_node_or_null("UserSettings") if tree != null else null
	if settings == null or settings.get("graphics") == null:
		return
	apply_quality(String(settings.graphics.quality))
	if not settings.graphics_settings_changed.is_connected(_on_graphics_settings_changed):
		settings.graphics_settings_changed.connect(_on_graphics_settings_changed)


func _on_graphics_settings_changed(settings) -> void:
	apply_quality(String(settings.quality))


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sync):
		RenderingServer.frame_pre_draw.disconnect(_sync)
	_set_off()

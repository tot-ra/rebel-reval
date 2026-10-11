extends Node3D

## R-1748: screen-space ambient occlusion for the Mobile renderer, which has no built-in
## SSAO (Forward+ only). A full-screen overlay (ambient_occlusion_pass.gdshader) rebuilds
## positions and normals from scene depth and darkens alleys, eaves, wall bases and the
## ground under props and people. Sample counts follow GraphicsPresets (low = off).
## See docs/SYSTEMS/POST_PROCESS.md, "Ambient occlusion".

const PASS_SHADER := preload("res://scripts/map/view3d/ambient_occlusion_pass.gdshader")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const GraphicsPresetsScript := preload("res://scripts/settings/graphics_presets.gd")

## Drawn before CloudShadowPass (-100) and every other transparent: on Compatibility the
## water's screen copy empties `hint_depth_texture` for passes drawn after it.
const RENDER_PRIORITY := -101
## Overlay opacity at full occlusion. Lower in full sun because the pass cannot tell sun
## from sky light and would grey sunlit corners; strongest in shade-only light (overcast,
## twilight). Night keeps a little so lamplit streets still ground their props.
const STRENGTH_SUNLIT := 0.55
const STRENGTH_DIFFUSE := 0.7
const STRENGTH_NIGHT := 0.35
const CONTACT_RADIUS := 0.35
const AREA_RADIUS := 2.4

var strength := 0.0
var enabled := true
var _samples := Vector2i.ZERO
var _material: ShaderMaterial
var _overlay: MeshInstance3D


static func should_create(indoor: bool) -> bool:
	return not indoor


## Opacity for this light: night floor, rising with the day, softer in direct sun.
static func strength_for(presentation: SkyWeather.WeatherPresentation) -> float:
	if presentation == null:
		return 0.0
	var day := clampf(presentation.day_blend, 0.0, 1.0)
	var diffuse := clampf(presentation.overcast, 0.0, 1.0)
	var day_strength := lerpf(STRENGTH_SUNLIT, STRENGTH_DIFFUSE, diffuse)
	return lerpf(STRENGTH_NIGHT, day_strength, day)


func configure() -> void:
	name = "AmbientOcclusionPass"
	_material = ShaderMaterial.new()
	_material.shader = PASS_SHADER
	_material.render_priority = RENDER_PRIORITY
	_material.set_shader_parameter(&"contact_radius", CONTACT_RADIUS)
	_material.set_shader_parameter(&"area_radius", AREA_RADIUS)
	_material.set_shader_parameter(&"strength", 0.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	quad.flip_faces = true
	quad.material = _material
	_overlay = MeshInstance3D.new()
	_overlay.name = "AmbientOcclusionOverlay"
	_overlay.mesh = quad
	_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_overlay.ignore_occlusion_culling = true
	_overlay.extra_cull_margin = 16384.0
	_overlay.visible = false
	add_child(_overlay)
	_follow_graphics_quality()


func apply_quality(quality: String) -> void:
	var row := GraphicsPresetsScript.row(quality)
	_samples = Vector2i(int(row["ao_contact_samples"]), int(row["ao_area_samples"]))
	if _material != null:
		_material.set_shader_parameter(&"contact_samples", _samples.x)
		_material.set_shader_parameter(&"area_samples", _samples.y)
	_sync_visible()


func set_enabled(value: bool) -> void:
	enabled = value
	_sync_visible()


func is_active() -> bool:
	return _overlay != null and _overlay.visible


func update(presentation: SkyWeather.WeatherPresentation) -> void:
	strength = strength_for(presentation)
	if _material != null:
		_material.set_shader_parameter(&"strength", strength)
	_sync_visible()


func _sync_visible() -> void:
	if _overlay != null:
		_overlay.visible = enabled and strength > 0.001 and (_samples.x + _samples.y) > 0


func _follow_graphics_quality() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var settings := tree.root.get_node_or_null("UserSettings") if tree != null else null
	if settings == null or settings.get("graphics") == null:
		apply_quality(GraphicsPresetsScript.MID)
		return
	apply_quality(String(settings.graphics.quality))
	if not settings.graphics_settings_changed.is_connected(_on_graphics_settings_changed):
		settings.graphics_settings_changed.connect(_on_graphics_settings_changed)


func _on_graphics_settings_changed(settings) -> void:
	apply_quality(String(settings.quality))

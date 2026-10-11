extends "res://tests/godot/test_case.gd"

const GraphicsSettingsScript := preload("res://scripts/settings/graphics_settings.gd")
const GraphicsPresetsScript := preload("res://scripts/settings/graphics_presets.gd")
const GodRayPassScript := preload("res://scripts/map/view3d/god_ray_pass.gd")
const SkyWeatherQualityScript := preload("res://scripts/map/view3d/sky_weather_quality.gd")

const COSTS: Array[String] = [
	"render_scale", "shadow_atlas_size", "god_ray_view_steps", "god_ray_shadow_steps",
	"god_ray_far_steps", "tree_near_scale", "tree_macro_scale", "sun_shadow_mode",
]


func after_each() -> void:
	GraphicsPresetsScript.apply_to(_tree().root, GraphicsPresetsScript.MID)
	super.after_each()


func test_every_user_quality_has_a_preset_row() -> void:
	for quality in GraphicsSettingsScript.QUALITIES:
		assert_true(GraphicsPresetsScript.PRESETS.has(quality), "row for %s" % quality)


func test_costs_never_decrease_from_low_to_high() -> void:
	var low := GraphicsPresetsScript.row("low")
	var mid := GraphicsPresetsScript.row("mid")
	var high := GraphicsPresetsScript.row("high")
	for key in COSTS:
		assert_true(float(low[key]) <= float(mid[key]), "%s low <= mid" % key)
		assert_true(float(mid[key]) <= float(high[key]), "%s mid <= high" % key)
	assert_eq(float(high["render_scale"]), 1.0, "high renders at native resolution")


func test_sky_tiers_are_real_sky_weather_tiers() -> void:
	for quality in GraphicsSettingsScript.QUALITIES:
		var tier: StringName = GraphicsPresetsScript.row(quality)["sky_tier"]
		assert_true(tier in SkyWeatherQualityScript.QUALITY_TIER_IDS, "%s tier %s" % [quality, tier])
	assert_eq(GraphicsPresetsScript.row("low")["sky_tier"], &"minimum")


func test_unknown_quality_falls_back_to_mid() -> void:
	assert_eq(GraphicsPresetsScript.row("ultra"), GraphicsPresetsScript.row("mid"))


func test_apply_sets_the_window_render_scale() -> void:
	var window := _tree().root
	GraphicsPresetsScript.apply_to(window, "low")
	assert_almost_eq(window.scaling_3d_scale, 0.67, 0.001)
	var upscaler := (
		Viewport.SCALING_3D_MODE_FSR
		if RenderingServer.get_current_rendering_method() == "forward_plus"
		else Viewport.SCALING_3D_MODE_BILINEAR
	)
	assert_eq(window.scaling_3d_mode, upscaler, "FSR only where the renderer has it")
	GraphicsPresetsScript.apply_to(window, "high")
	assert_almost_eq(window.scaling_3d_scale, 1.0, 0.001)
	assert_eq(window.scaling_3d_mode, Viewport.SCALING_3D_MODE_BILINEAR)


func test_god_ray_steps_follow_quality() -> void:
	var pass_node := GodRayPassScript.new()
	_tree().root.add_child(pass_node)
	var camera := Camera3D.new()
	_tree().root.add_child(camera)
	pass_node.configure(camera)
	var material: ShaderMaterial = pass_node._material
	pass_node.apply_quality("low")
	assert_eq(material.get_shader_parameter(&"view_steps"), 6)
	assert_eq(material.get_shader_parameter(&"far_steps"), 4)
	pass_node.apply_quality("high")
	var high := GraphicsPresetsScript.row("high")
	assert_eq(material.get_shader_parameter(&"view_steps"), high["god_ray_view_steps"])
	assert_eq(material.get_shader_parameter(&"shadow_steps"), high["god_ray_shadow_steps"])
	assert_true(pass_node._shade_map != null, "the pass owns a cloud shade map")
	pass_node.queue_free()
	camera.queue_free()


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func test_low_quality_draws_no_macro_crowns_and_one_cascade() -> void:
	var lod := CityTreeLod.new()
	lod.apply_quality("low")
	assert_eq(lod._macro_scale, 0.0, "low has no 500k-triangle macro crowns")
	lod.apply_quality("high")
	assert_eq(lod._macro_scale, GraphicsPresetsScript.row("high")["tree_macro_scale"])
	lod.free()
	var sun := DirectionalLight3D.new()
	GraphicsPresetsScript.apply_to_sun(sun, "low")
	assert_eq(sun.directional_shadow_mode, DirectionalLight3D.SHADOW_ORTHOGONAL)
	GraphicsPresetsScript.apply_to_sun(sun, "high")
	assert_eq(sun.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS)
	sun.free()


func test_quality_rows_set_the_dome_cloud_march() -> void:
	var sky := SkyWeather3D.new()
	GraphicsPresetsScript.apply_to_sky(sky, "mid")
	var mid := GraphicsPresetsScript.row("mid")
	assert_eq(sky._cell_march_override["steps"], mid["sky_cell_steps"])
	assert_eq(sky._cell_march_override["ray"], 0, "sky-beam march off on mid: it doubles the dome cost")
	sky.free()

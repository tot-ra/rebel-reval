extends "res://tests/godot/test_case.gd"

const CloudShadowPassScript := preload("res://scripts/map/view3d/cloud_shadow_pass.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const KalevSmithyDefinition := preload(
	"res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd"
)


func test_pass_is_created_only_for_outdoor_maps() -> void:
	assert_true(
		CloudShadowPassScript.should_create(false, true),
		"outdoor maps with the tier enabled get the pass"
	)
	assert_false(
		CloudShadowPassScript.should_create(true, true),
		"enclosed interiors never get the pass"
	)
	assert_false(
		CloudShadowPassScript.should_create(false, false),
		"a disabled quality tier must not create the pass"
	)
	var outdoor := _tiny_outdoor_definition()
	var outdoor_view := MapView3D.create(outdoor, MapBuilder.build(outdoor))
	assert_true(
		outdoor_view.cloud_shadow_pass() != null,
		"a tiny outdoor map must attach CloudShadowPass"
	)
	outdoor_view.free()
	var smithy: MapDefinition = KalevSmithyDefinition.create()
	var smithy_view := MapView3D.create(smithy, MapBuilder.build(smithy))
	assert_true(
		smithy_view.cloud_shadow_pass() == null,
		"the roofed smithy must not attach CloudShadowPass"
	)
	smithy_view.free()


func test_sun_share_is_zero_at_night_and_overcast() -> void:
	var sky := SkyWeather.new()
	sky.auto_weather = false
	sky.set_weather(SkyWeather.WEATHER_CLEAR)
	sky.advance(SkyWeather.TRANSITION_SECONDS)
	var noon := sky.presentation_snapshot(0.5, 1.0)
	var noon_share := CloudShadowPassScript.sun_share_from_presentation(noon)
	assert_true(
		noon_share > 0.4,
		"clear noon must keep a readable direct-sun share (got %s)" % noon_share
	)
	var night := sky.presentation_snapshot(0.0, 0.0)
	assert_true(
		CloudShadowPassScript.sun_share_from_presentation(night) < 0.05,
		"night day_blend must kill the ground-shadow share"
	)
	sky.set_weather(SkyWeather.WEATHER_OVERCAST)
	sky.advance(SkyWeather.TRANSITION_SECONDS)
	var overcast := sky.presentation_snapshot(0.5, 1.0)
	assert_true(
		CloudShadowPassScript.sun_share_from_presentation(overcast) < 0.05,
		"full overcast must fade patches to ~0"
	)
	sky.free()


func test_capture_tool_documents_r1033_modes() -> void:
	var source := FileAccess.get_file_as_string(
		"res://tools/capture_ws12_cloud_shadows.gd"
	)
	assert_false(source.is_empty(), "R-1033 capture tool must exist")
	for token in [
		"--scenario=partly",
		"--clip",
		"--sky",
		"--bench",
		"0.45",
		"reval_harbor_north",
	]:
		assert_true(
			source.contains(token),
			"capture tool must document %s" % token
		)


func test_cloud_shadow_globals_are_registered() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	for name in [
		"cloud_noise_tex",
		"cloud_shape_tex",
		"cloud_offset_g",
		"cloud_detail_offset_g",
		"cloud_coverage_g",
		"cloud_chaos_g",
		"storm_intensity_g",
		"storm_locality_g",
		"cloud_sun_dir",
		"cloud_shadow_strength",
	]:
		assert_true(
			project.contains("%s={" % name),
			"project.godot must register global %s" % name
		)
	var source := FileAccess.get_file_as_string(
		"res://scripts/map/view3d/sky_weather_3d.gdshader"
	)
	assert_true(
		source.contains("sky_clouds.gdshaderinc"),
		"the sky shader must include the shared cloud field"
	)
	assert_false(
		source.contains("vec2 cloud_uv(vec3 dir, float altitude) {\n\tfloat distance"),
		"private cloud_uv body must live in the include"
	)


func _tiny_outdoor_definition() -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = &"ws12.cloud_shadow.yard"
	definition.size_cells = Vector2i(6, 6)
	definition.cell_size = 32
	definition.base_terrain = MapTypes.TERRAIN_DIRT
	definition.player_spawn = Vector2(16.0, 16.0)
	definition.location = &"test"
	definition.scope = &"prototype"
	definition.palette = &"spring"
	definition.seed = 1212
	definition.fingerprint = "ws12-cloud-shadow-yard"
	return definition

extends "res://tests/godot/test_case.gd"

## WS-04: the water shader's FFT path is fed from the WS-03 bake profile, is
## enabled only for sea terrains once BoatFloat3D can follow it, and maps the
## weather to cascade weights monotonically from calm to storm.

const WaterMaterials := preload("res://scripts/map/view3d/map_view_water_materials.gd")
const MaterialsFacade := preload("res://scripts/map/view3d/map_view_materials.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const RuntimeEnvironment := preload("res://scripts/map/view3d/map_view_runtime_environment.gd")
const MapTypesContract := preload("res://scripts/map/map_types.gd")
const WATER_SHADER_PATH := "res://scripts/map/view3d/map_view_water.gdshader"


func before_each() -> void:
	WaterMaterials.reset()
	WaterMaterials.force_ocean_fft_support = true
	WaterMaterials.set_ocean_fft_quality_tier(SkyWeather.QUALITY_RECOMMENDED)


func after_each() -> void:
	WaterMaterials.force_ocean_fft_support = false
	WaterMaterials.set_ocean_fft_quality_tier(SkyWeather.QUALITY_RECOMMENDED)
	WaterMaterials.reset()


func _sea_material(terrain_id: StringName = MapTypesContract.TERRAIN_DEEP_WATER) -> ShaderMaterial:
	return WaterMaterials.water_surface(terrain_id, MaterialsFacade.WATER_WAVE_BASE)


func test_profile_drives_cascade_uniforms() -> void:
	var profile := WaterMaterials.ocean_fft_profile()
	assert_false(profile.is_empty(), "the WS-03 profile JSON must load")
	var meters_per_unit := float(profile["meters_per_world_unit"])
	assert_almost_eq(meters_per_unit, 0.87, 0.0001, "bake uses 0.87 m per world unit")
	var cascades: PackedVector4Array = _sea_material().get_shader_parameter("fft_cascade")
	assert_eq(cascades.size(), 3, "three cascade uniforms")
	for index in 3:
		var baked: Dictionary = profile["cascades"][index]
		var uniform := cascades[index]
		assert_almost_eq(
			uniform.x, float(baked["patch_m"]) / meters_per_unit, 0.0001,
			"cascade %d patch must be patch_m / 0.87 world units" % index,
		)
		assert_almost_eq(uniform.y, float(baked["period_s"]), 0.0001, "cascade %d loop period" % index)
		assert_almost_eq(uniform.z, float(baked["frames"]), 0.0001, "cascade %d frame count" % index)
	var disp_scale: PackedVector4Array = _sea_material().get_shader_parameter("fft_disp_scale")
	assert_eq(disp_scale.size(), 2, "only C0 and C1 carry displacement")
	assert_almost_eq(
		disp_scale[0].y,
		float(profile["cascades"][0]["channel_scales"]["dy"]),
		0.00001,
		"C0 height decode scale comes from the profile",
	)
	var deriv_scale: PackedVector4Array = _sea_material().get_shader_parameter("fft_deriv_scale")
	assert_eq(deriv_scale.size(), 3, "all three cascades carry derivatives")
	assert_almost_eq(
		deriv_scale[2].w,
		float(profile["cascades"][2]["channel_scales"]["dz_dz"]),
		0.00001,
		"C2 dDz/dz decode scale comes from the profile",
	)


func test_atlases_load_as_texture_layered_with_64_frames() -> void:
	var textures := WaterMaterials.ocean_fft_textures()
	assert_eq(textures.size(), 5, "five baked atlases: C0/C1 disp+deriv and C2 deriv")
	for uniform_name: String in textures:
		var texture: Variant = textures[uniform_name]
		assert_true(texture is TextureLayered, "%s must be typed TextureLayered" % uniform_name)
		assert_eq((texture as TextureLayered).get_layers(), 64, "%s has 64 frames" % uniform_name)
		assert_eq(
			_sea_material().get_shader_parameter(uniform_name),
			texture,
			"%s must be bound on the sea material" % uniform_name,
		)


func test_reference_sea_state_is_the_physical_bake() -> void:
	var reference := WaterMaterials.fft_sea_state(WaterMaterials.OCEAN_FFT_REFERENCE_SEA_STATE, 0.0)
	for weight: float in reference["weights"]:
		assert_almost_eq(weight, 1.0, 0.00001, "reference cascade weights stay 1.0")
	assert_almost_eq(float(reference["amplitude"]), 1.0, 0.00001, "reference amplitude stays 1.0")
	var material := _sea_material()
	assert_almost_eq(
		float(material.get_shader_parameter("ocean_amplitude")), 1.0, 0.00001,
		"a fresh sea material starts at the baked reference amplitude",
	)
	for cascade: Vector4 in material.get_shader_parameter("fft_cascade") as PackedVector4Array:
		assert_almost_eq(cascade.w, 1.0, 0.00001, "a fresh sea material starts at weight 1.0")


func test_sea_terrains_use_fft_and_rivers_do_not() -> void:
	for terrain_id: StringName in WaterMaterials.OCEAN_FFT_TERRAINS:
		assert_true(
			bool(_sea_material(terrain_id).get_shader_parameter("use_fft")),
			"%s uses FFT" % terrain_id,
		)
	assert_false(
		bool(_sea_material(MapTypesContract.TERRAIN_RIVER_WATER).get_shader_parameter("use_fft")),
		"rivers keep the Gerstner current path",
	)
	assert_true(
		float(_sea_material(MapTypesContract.TERRAIN_DEEP_WATER).get_shader_parameter("choppiness"))
			> float(_sea_material(MapTypesContract.TERRAIN_WATER).get_shader_parameter("choppiness")),
		"open sea must peak harder than sheltered harbour water on the FFT path too",
	)
	# The mesh sea is compressed to each terrain's Gerstner height budget, so the
	# recessed bed (0.006 units under the rest surface) is never exposed.
	for terrain_id: StringName in WaterMaterials.OCEAN_FFT_TERRAINS:
		var height := float(MaterialsFacade.WATER_WAVE_BASE[terrain_id]["height"])
		assert_almost_eq(
			float(_sea_material(terrain_id).get_shader_parameter("fft_geometry_scale")),
			height / (WaterMaterials.OCEAN_FFT_REFERENCE_CREST_M / 0.87),
			0.00001,
			"%s geometry scale maps the reference crest onto its height budget" % terrain_id,
		)
	# Without the WS-05 hook the constant decides; before WS-05 it is absent.
	WaterMaterials.force_ocean_fft_support = false
	WaterMaterials.reset()
	var boat_script := load(WaterMaterials.BOAT_FLOAT_SCRIPT_PATH) as Script
	var boat_constants := boat_script.get_script_constant_map()
	assert_eq(
		bool(_sea_material().get_shader_parameter("use_fft")),
		bool(boat_constants.get("FFT_SUPPORTED", false)),
		"production enablement follows BoatFloat3D.FFT_SUPPORTED",
	)


func test_weather_table_is_monotonic_calm_to_storm() -> void:
	var previous: Dictionary = {}
	for step in 21:
		var wind := float(step) / 20.0
		var sea := WaterMaterials.fft_sea_state(wind, wind * 0.5)
		if not previous.is_empty():
			for index in 3:
				assert_true(
					float(sea["weights"][index]) >= float(previous["weights"][index]) - 0.00001,
					"C%d weight must not drop as wind rises (wind %.2f)" % [index, wind],
				)
			for key: String in ["choppiness", "amplitude"]:
				assert_true(
					float(sea[key]) >= float(previous[key]) - 0.00001,
					"%s must not drop as wind rises (wind %.2f)" % [key, wind],
				)
		previous = sea
	var calm := WaterMaterials.fft_sea_state(0.2, 0.0)
	var storm := WaterMaterials.fft_sea_state(0.7, 0.22)
	assert_true(float(storm["amplitude"]) > float(calm["amplitude"]) * 2.0, "storm sea is much taller")
	assert_true(float(storm["choppiness"]) > float(calm["choppiness"]), "storm sea is steeper")


func test_minimum_tier_drops_the_ripple_cascade() -> void:
	WaterMaterials.set_ocean_fft_quality_tier(SkyWeather.QUALITY_MINIMUM)
	WaterMaterials.reset()
	assert_eq(int(_sea_material().get_shader_parameter("fft_cascade_count")), 2, "minimum tier: C0+C1")
	WaterMaterials.set_ocean_fft_quality_tier(SkyWeather.QUALITY_RECOMMENDED)
	WaterMaterials.reset()
	assert_eq(int(_sea_material().get_shader_parameter("fft_cascade_count")), 3, "recommended: C0-C2")
	for tier: StringName in SkyWeather.QUALITY_TIER_IDS:
		assert_true(
			SkyWeather.quality_settings(tier).has("ocean_fft_cascades"),
			"%s tier declares ocean_fft_cascades" % tier,
		)


func test_ocean_clock_wraps_seamlessly_on_every_cascade_period() -> void:
	var wrap := RuntimeEnvironment.OCEAN_TIME_WRAP_SECONDS
	for cascade: Dictionary in WaterMaterials.ocean_fft_profile()["cascades"]:
		var loops := wrap / float(cascade["period_s"])
		assert_almost_eq(
			loops, roundf(loops), 0.0001, "wrap is a whole number of %s loops" % cascade["name"]
		)
	RuntimeEnvironment.set_ocean_time(wrap - 0.5)
	RuntimeEnvironment.advance_ocean_time(1.0)
	assert_almost_eq(
		RuntimeEnvironment.ocean_time(), 0.5, 0.0001, "the clock wraps instead of growing"
	)
	RuntimeEnvironment.advance_ocean_time(-3.0)
	assert_almost_eq(
		RuntimeEnvironment.ocean_time(), 0.5, 0.0001, "negative deltas never rewind the sea"
	)
	RuntimeEnvironment.set_ocean_time(0.0)


func test_shader_keeps_gerstner_fallback_and_fft_sign_conventions() -> void:
	# WS-13 moved the FFT uniforms and sampling into a shared include.
	var source := (
		FileAccess.get_file_as_string(WATER_SHADER_PATH)
		+ FileAccess.get_file_as_string("res://scripts/map/view3d/ocean_fft_common.gdshaderinc")
	)
	assert_true(source.contains("global uniform float ocean_time;"), "one global ocean clock")
	assert_true(source.contains("uniform bool use_fft = false;"), "FFT is opt-in per material")
	assert_true(
		source.contains("_water_field(wave_sample_xz - flow_advection"), "Gerstner fallback stays"
	)
	# Amendments 1 and 2: positive displacement, derivatives decoded as-is.
	assert_true(
		source.contains("_fft_from_wind(d.xz * chop * FFT_HORIZONTAL_GEOMETRY, axis)"),
		"horizontal displacement is added",
	)
	assert_true(
		source.contains("vec2 jacobian = d.zw * chop * ocean_amplitude;"), "no Jacobian sign flip"
	)
	assert_true(source.contains("if (standing > 0.01)"), "standing-wave emulation only where needed")
	var settings := ProjectSettings.get_setting("shader_globals/ocean_time", {}) as Dictionary
	assert_eq(String(settings.get("type", "")), "float", "ocean_time is registered as a shader global")

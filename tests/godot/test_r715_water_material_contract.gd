extends "res://tests/godot/test_case.gd"

const MapTypesContract := preload("res://scripts/map/map_types.gd")
const MaterialsFacade := preload("res://scripts/map/view3d/map_view_materials.gd")
const ShaderSources := preload("res://scripts/map/view3d/map_view_material_shaders.gd")
const WaterMaterials := preload("res://scripts/map/view3d/map_view_water_materials.gd")


func test_all_water_ids_use_one_approved_shader_family() -> void:
	MaterialsFacade.reset()
	assert_eq(
		MaterialsFacade.WATER_TERRAINS,
		MapTypesContract.WATER_TERRAINS,
		"the public facade must cover every stable water terrain ID",
	)
	var source := ShaderSources.WATER_SHADER.code
	var shared_shader: Shader = null
	for terrain_id: StringName in MapTypesContract.WATER_TERRAINS:
		var material := MaterialsFacade.water_surface(terrain_id)
		assert_true(
			material is ShaderMaterial,
			"%s must resolve to a ShaderMaterial" % terrain_id,
		)
		if not material is ShaderMaterial:
			continue
		var water_material := material as ShaderMaterial
		assert_true(
			water_material.shader != null,
			"%s must have a water shader" % terrain_id,
		)
		if water_material.shader == null:
			continue
		if shared_shader == null:
			shared_shader = water_material.shader
		else:
			assert_eq(
				water_material.shader,
				shared_shader,
				"%s must use the shared water shader resource" % terrain_id,
			)
		assert_eq(
			water_material.shader.code,
			source,
			"%s must use the approved water shader source" % terrain_id,
		)


func test_water_profiles_keep_optical_flow_and_tide_roles_distinct() -> void:
	MaterialsFacade.reset()
	var shallow := MaterialsFacade.water_surface(MapTypesContract.TERRAIN_SHALLOW_WATER)
	var deep := MaterialsFacade.water_surface(MapTypesContract.TERRAIN_DEEP_WATER)
	var enclosed := MaterialsFacade.water_surface(MapTypesContract.TERRAIN_WATER)
	var river := MaterialsFacade.water_surface(MapTypesContract.TERRAIN_RIVER_WATER)

	var shallow_optical := float(shallow.get_shader_parameter("optical_depth"))
	var deep_optical := float(deep.get_shader_parameter("optical_depth"))
	var enclosed_optical := float(enclosed.get_shader_parameter("optical_depth"))
	var river_optical := float(river.get_shader_parameter("optical_depth"))
	assert_true(shallow_optical < river_optical, "shallow water needs the shortest optical column")
	assert_true(river_optical < enclosed_optical, "river water needs a distinct optical column")
	assert_true(enclosed_optical < deep_optical, "deep water needs the longest optical column")

	assert_eq(
		river.get_shader_parameter("flow_direction"),
		Vector2(0.0, -1.0),
		"river current must follow the authored Pirita direction",
	)
	assert_true(
		float(river.get_shader_parameter("flow_strength")) > 0.0,
		"river water must expose a non-zero current",
	)
	for still_material: ShaderMaterial in [shallow, deep, enclosed]:
		assert_eq(
			still_material.get_shader_parameter("flow_direction"),
			Vector2.ZERO,
			"coastal and enclosed water must remain still",
		)
		assert_eq(
			float(still_material.get_shader_parameter("flow_strength")),
			0.0,
			"non-river water must not inherit river current",
		)

	assert_true(
		float(shallow.get_shader_parameter("tide_shore_retreat")) > 0.0,
		"shallow coastal water must expose shoreline tide response",
	)
	assert_true(
		float(deep.get_shader_parameter("tide_optical_depth")) > 0.0,
		"deep coastal water must expose optical tide response",
	)
	for river_tide_parameter: String in ["tide_height", "tide_shore_retreat", "tide_optical_depth"]:
		assert_eq(
			float(river.get_shader_parameter(river_tide_parameter)),
			0.0,
			"river water must keep %s outside coastal tide logic" % river_tide_parameter,
		)



func test_water_prioritizes_reflection_and_hides_terrestrial_bed_detail() -> void:
	MaterialsFacade.reset()
	var shallow := MaterialsFacade.water_surface(MapTypesContract.TERRAIN_SHALLOW_WATER)
	var enclosed := MaterialsFacade.water_surface(MapTypesContract.TERRAIN_WATER)
	var deep := MaterialsFacade.water_surface(MapTypesContract.TERRAIN_DEEP_WATER)
	assert_true(
		float(shallow.get_shader_parameter("optical_depth")) >= 0.075,
		"even shallow water needs enough visual column to avoid exposing the grass bed",
	)
	assert_true(
		float(enclosed.get_shader_parameter("optical_depth")) >= 0.24,
		"pond and harbour water must hide the flat grass terrain below its surface",
	)
	assert_true(
		float(deep.get_shader_parameter("optical_depth")) >= 0.38,
		"deep water must retain the strongest visual depth treatment",
	)
	var source := ShaderSources.WATER_SHADER.code
	for safeguard in [
		"bed_vegetation * 0.22",
		"bed_detail_visibility = exp(-water_depth * 9.5) * 0.18",
		"0.34 + fresnel",
	]:
		assert_true(safeguard in source, "water shader must retain %s" % safeguard)

func test_water_shader_declares_reflection_inputs_and_safe_compatibility_fallbacks() -> void:
	var source := ShaderSources.WATER_SHADER.code
	for feature in [
		"hint_screen_texture",
		"hint_depth_texture",
		"optical_depth",
		"foam_intensity",
		"wave_height",
		"flow_direction",
		"flow_strength",
		"tide_level",
		"tide_height",
		"star_map",
		"sun_direction",
		"moon_direction",
		"observer_latitude",
		"sidereal_angle",
		"fresnel",
	]:
		assert_true(feature in source, "water shader must retain %s" % feature)
	assert_true("render_mode blend_mix" in source, "water must use a GL-compatible spatial blend")
	assert_true(
		"refracted_uv = SCREEN_UV" in source,
		"invalid depth samples need a screen-space fallback",
	)
	assert_true(
		"vec2(0.001)" in source,
		"screen UV distortion must be clamped away from texture edges",
	)
	assert_true(
		"max(path_len, terrain_optical_depth)" in source,
		"water needs a safe optical depth floor",
	)
	assert_false(
		"planar_reflection" in source.to_lower(),
		"water must not depend on a planar reflection pass",
	)


func test_ws01_extinction_follows_the_snell_refracted_path_to_the_bed() -> void:
	var source := ShaderSources.WATER_SHADER.code
	assert_true("refract(" in source, "the view ray must be refracted at the surface")
	assert_true("WATER_IOR" in source, "refraction must use the shared water index of refraction")
	assert_true(
		"float path_len = water_column / transmitted_down" in source,
		"the optical path must be the vertical column over the refracted cosine",
	)
	assert_true(
		"exp(-sigma_t * path_m)" in source,
		"Beer-Lambert extinction must be driven by the refracted path length",
	)
	assert_true(
		"RENDERER_COMPATIBILITY" in source and "_view_position(" in source,
		"bed reconstruction must handle the Compatibility and Mobile depth conventions",
	)
	assert_true(
		"_seabed_layers(water_world_position.xz, bed_column)" in source,
		"the layered bed must be classified by vertical depth, not the view ray",
	)
	assert_false(
		"refraction_strength" in source or "geometric_depth" in source,
		"the fixed screen-offset refraction and view-ray depth must be gone",
	)
	assert_false(
		"planar_reflection" in source.to_lower(),
		"water must not depend on a planar reflection pass",
	)


func test_ws02_glints_come_from_a_shadowed_ggx_light_function() -> void:
	var source := ShaderSources.WATER_SHADER.code
	var light_start := source.find("void light()")
	assert_true(light_start > 0, "water owns its light() so glints are shadowed and lit once")
	var light_body := source.substr(light_start)
	for term in [
		"_d_ggx(n_dot_h, a2)",
		"_v_smith_ggx_correlated(n_dot_l, n_dot_v, a2)",
		"_fresnel_dielectric(v_dot_h, WATER_IOR)",
		"min(glint, GLINT_CLAMP)",
		"ATTENUATION",
		"LIGHT_IS_DIRECTIONAL",
	]:
		assert_true(light_body.contains(term), "water light() must use %s" % term)
	# Exact unpolarised Fresnel, not Schlick's pow(1 - c, 5).
	var fresnel_start := source.find("float _fresnel_dielectric(")
	var fresnel_body := source.substr(fresnel_start, source.find("}", fresnel_start) - fresnel_start)
	assert_true(fresnel_body.contains("sqrt(ior * ior - 1.0 + c * c)"), "Fresnel must be exact")
	assert_false(fresnel_body.contains("pow("), "Fresnel must not be Schlick")
	assert_true(source.contains("a2 / (PI * d * d)"), "GGX distribution term is present")
	assert_false(source.contains("pow(sun_alignment, 220.0)"), "hand-made sun glint is removed")
	assert_false(source.contains("pow(moon_alignment, 320.0)"), "hand-made moon glint is removed")
	assert_false(source.contains("film_glint"), "the beach film glint is lit, not painted")
	# Twilight gates survive: the light keeps following the sun past the disk fade.
	for gate in ["sun_reflection_visibility", "low_sun_glitter", "moon_visibility"]:
		assert_true(source.contains(gate), "water glint must stay gated by %s" % gate)
	# Slope-variance roughness keeps glitter wide on rough seas and alias-free far away.
	assert_true(source.contains("dFdx(world_normal)"), "unresolved wave slope widens the lobe")
	assert_true(source.contains("choppiness * wave_chaos"), "sea state widens the glitter path")
	assert_true(source.contains("NORMAL = view_normal;"), "the lit normal stays the calm normal")
	# Stars are not lights, so their reflected sparkle stays in the fragment colour.
	assert_true(source.contains("reflected_stars * night_sparkle"), "star sparkle is retained")


func test_ws07_caustics_are_baked_tiles_projected_onto_the_bed() -> void:
	var source := ShaderSources.WATER_SHADER.code
	var tiles := FileAccess.get_file_as_string("res://scripts/map/view3d/caustics_common.gdshaderinc")
	assert_true(
		source.contains('#include "res://scripts/map/view3d/caustics_common.gdshaderinc"'),
		"water and underwater share the WS-07 tile helpers",
	)
	assert_false(source.contains("_bed_caustics"), "the sine-lattice caustics are removed")
	assert_false(
		source.contains("water_color += highlight_color * caustics"),
		"caustics are bed light, not a colour added on top of the water",
	)
	assert_true(
		tiles.contains("textureGrad(tile, uv_a, gx, gy)"), "caustic tiles sample with textureGrad"
	)
	assert_true(tiles.contains("_caustic_stretch(dFdx(uv_fine), min_len)"), "gradients are stretched")
	assert_true(
		source.contains("refract(-sun, vec3(0.0, 1.0, 0.0), 1.0 / WATER_IOR)"),
		"the net is projected along the refracted sun ray",
	)
	assert_true(tiles.contains("smoothstep(0.6, 3.0, h_m)"), "fine to broad focus follows depth")
	# Applied to the bed before extinction, so the view path dims it on the way up.
	var gain_at := source.find("seabed *= _bed_caustic_gain(")
	assert_true(gain_at > 0, "caustics multiply the seabed")
	assert_true(
		gain_at < source.find("vec3 transmitted = seabed * spectral_transmission"),
		"caustic light lands on the bed before Beer-Lambert extinction",
	)
	assert_true(
		source.contains("* sun_reflection_visibility;"), "cloud cover (no direct sun) removes caustics"
	)
	assert_true(
		source.contains("smoothstep(0.0, 0.7, sun_direction.y)"), "caustics follow the direct-sun share"
	)
	# Sample budget: at most 8 on recommended, 2 on minimum. Lives in the shared include.
	var body_start := tiles.find("vec3 _caustic_tiles_at(")
	var body := tiles.substr(body_start, tiles.find("\n}\n", body_start) - body_start)
	assert_eq(body.count("_caustic_tile("), 4, "two tiles on recommended, one per branch on minimum")
	assert_true(
		body.contains("full_quality ? sun_az * (h_m * 0.004 / caustic_pattern_scale) : vec2(0.0)"),
		"no dispersion on minimum",
	)
	# Scrolls must be whole tiles per ocean-clock wrap.
	for layer: String in ["FINE_A", "FINE_B", "BROAD_A", "BROAD_B"]:
		var at := tiles.find("const float CAUSTIC_%s_TILES_PER_WRAP = " % layer)
		assert_true(at > 0, "%s scroll constant exists" % layer)
		var value := float(tiles.substr(at).get_slice("= ", 1).get_slice(";", 0))
		assert_eq(value, roundf(value), "%s scroll wraps seamlessly" % layer)


func test_ws07_water_materials_bind_caustic_tiles_and_quality_tier() -> void:
	var profile_text := FileAccess.get_file_as_string(
		"res://assets/water/ocean_fft/caustics_profile.json"
	)
	var profile: Dictionary = JSON.parse_string(profile_text)
	var tiles: Array = profile["tiles"]
	assert_eq(float(profile["scale"]), 4.0, "the shader decodes the tiles with scale 4")
	assert_eq(float(tiles[0]["patch_m"]), 4.0, "fine tile patch matches CAUSTIC_FINE_PATCH_M")
	assert_eq(float(tiles[1]["patch_m"]), 16.0, "broad tile patch matches CAUSTIC_BROAD_PATCH_M")
	assert_true(
		absf(float(tiles[0]["min_pair_mean"]) - WaterMaterials.CAUSTIC_MIN_PAIR_MEAN.x) < 0.0005
			and absf(float(tiles[1]["min_pair_mean"]) - WaterMaterials.CAUSTIC_MIN_PAIR_MEAN.y) < 0.0005,
		"the material's min-pair means mirror the baked profile",
	)
	var terrains: Array[StringName] = [
		MapTypesContract.TERRAIN_RIVER_WATER, MapTypesContract.TERRAIN_WATER
	]
	for terrain_id: StringName in terrains:
		MaterialsFacade.reset()
		var material := MaterialsFacade.water_surface(terrain_id)
		assert_true(material.get_shader_parameter("caustics_fine_tex") is Texture2D, "fine tile bound")
		assert_true(material.get_shader_parameter("caustics_broad_tex") is Texture2D, "broad tile bound")
		assert_true(
			bool(material.get_shader_parameter("caustic_full_quality")), "recommended is full quality"
		)
	WaterMaterials.set_ocean_fft_quality_tier(&"minimum")
	MaterialsFacade.reset()
	var minimum := MaterialsFacade.water_surface(MapTypesContract.TERRAIN_WATER)
	assert_false(
		bool(minimum.get_shader_parameter("caustic_full_quality")), "minimum drops to 2 samples"
	)
	WaterMaterials.set_ocean_fft_quality_tier(&"recommended")
	MaterialsFacade.reset()


func test_water_field_is_choppy_gerstner_not_a_sine_sheet() -> void:
	MaterialsFacade.reset()
	var source := ShaderSources.WATER_SHADER.code
	for feature in ["choppiness", "standing_wave_ratio", "VERTEX.x +=", "VERTEX.z +=", "crest_lift"]:
		assert_true(feature in source, "water shader must retain %s" % feature)
	var deep := MaterialsFacade.water_surface(MapTypesContract.TERRAIN_DEEP_WATER)
	var enclosed := MaterialsFacade.water_surface(MapTypesContract.TERRAIN_WATER)
	var river := MaterialsFacade.water_surface(MapTypesContract.TERRAIN_RIVER_WATER)
	assert_true(
		float(deep.get_shader_parameter("choppiness"))
			> float(enclosed.get_shader_parameter("choppiness")),
		"open sea must peak harder than sheltered harbor water",
	)
	assert_true(
		float(enclosed.get_shader_parameter("standing_wave_ratio"))
			> float(deep.get_shader_parameter("standing_wave_ratio")),
		"harbor water must bob more than it travels",
	)
	assert_true(
		float(river.get_shader_parameter("choppiness"))
			< float(deep.get_shader_parameter("choppiness")),
		"river chop must stay below open-sea chop",
	)
	assert_true(
		float(deep.get_shader_parameter("wave_height")) > 0.1,
		"deep water displacement must be large enough to read from the gameplay camera",
	)


func test_water_shader_uses_jacobian_crest_whitecaps_separate_from_shore_breakers() -> void:
	var source := ShaderSources.WATER_SHADER.code
	for feature in [
		"_water_jacobian",
		"jacobian_now",
		"jacobian_trail",
		"breaker_band",
		"edge_foam",
		"flow_strength <= 0.001",
	]:
		assert_true(feature in source, "water shader must retain %s" % feature)
	assert_true(
		"crest_fold *= choppiness" in source,
		"crest whitecaps must scale with choppiness",
	)
	assert_true(
		"crest_fold *= smoothstep(0.14, 0.48, shore_factor)" in source,
		"crest whitecaps must stay off the pinned shoreline seam",
	)


func test_fft_whitecaps_come_from_baked_foam_and_the_foam_tile() -> void:
	# WS-06: the FFT path styles the baked foam; the Jacobian stays on the fallback only.
	var source := ShaderSources.WATER_SHADER.code
	var start := source.find("float whitecap_fresh = 0.0;")
	var end := source.find("// Thin crests transmit more Baltic teal", start)
	assert_true(start > 0 and end > start, "the WS-06 whitecap block exists before the crest glow")
	var whitecap_block := source.substr(start, end - start)
	assert_false(whitecap_block.contains("_water_jacobian("), "FFT whitecaps never call the Jacobian")
	assert_true(
		source.contains("if (!use_fft && flow_strength <= 0.001) {"),
		"the Gerstner Jacobian whitecaps run only on the fallback path",
	)
	assert_true(
		whitecap_block.contains(
			"vec2 whitecap_uv = _fft_to_wind(wave_sample_xz, _fft_wind_axis()) * foam_tile_scale;"
		),
		"the foam tile is sampled at the undisplaced wave_sample_xz so it rides the surface",
	)
	assert_eq(whitecap_block.count("texture(foam_tile"), 2, "at most two extra samples per fragment")
	assert_true(
		whitecap_block.contains("fft_foam = _fft_foam_terms(wave_sample_xz);"),
		"WS-06b resamples baked foam in fragment, not from a vertex varying",
	)
	assert_false(
		source.contains("varying vec3 fft_foam"),
		"GL vertex atlas alpha is not trusted as a foam varying",
	)
	assert_true(
		source.contains("uniform float debug_foam_mask = 0.0;"),
		"capture can write the unlit baked mask for Metal vs Compatibility compare",
	)
	assert_true(
		whitecap_block.contains(
			"whitecap = clamp((foam_mask - (1.0 - foam_texture)) * foam_sharpness, 0.0, 1.0);"
		),
		"coverage threshold follows the Tidewater foam formula",
	)
	assert_true(
		whitecap_block.contains(
			"min(fft_foam.x * storm_foam_coverage * foam_coverage, FOAM_MASK_CAP)"
		),
		"the weighted baked mask scales with weather and coverage",
	)
	assert_true(
		source.contains("sky_reflection_weight *= 1.0 - whitecap_fresh;"),
		"fresh foam suppresses the sky mirror",
	)
	assert_true(
		source.contains("crest_subsurface *= 1.0 - whitecap_fresh;"), "foam dims the crest glow"
	)
	assert_true(source.contains("ROUGHNESS = mix(ROUGHNESS, 0.6, whitecap_fresh);"), "foam is rough")
	assert_false(source.contains("EMISSION = foam"), "foam is lit, never emissive")
	var include := FileAccess.get_file_as_string(
		"res://scripts/map/view3d/ocean_fft_common.gdshaderinc"
	)
	# Amendment 1: foam is linear 0..1 in the disp alpha, read raw (no signed decode).
	assert_true(
		include.contains("foam = vec3(s0.a * c0.w + s1.a * c1.w, max(s0.a, s1.a), s0.a * c0.w);"),
		"the foam mask reads the raw disp alpha of C0 and C1",
	)
	assert_true(
		include.contains("vec3 _fft_foam_terms(vec2 world_xz)"),
		"WS-06b exposes a fragment foam helper that matches the vertex displacement alpha",
	)
	assert_true(
		include.contains("_compat_stored_alpha(") and include.contains("OUTPUT_IS_SRGB"),
		"Compatibility restores stored linear foam after sRGB-decoding 8-bit atlas alpha",
	)
	assert_false(include.contains("_fft_signed(s0, fft_disp_scale[0]).a"), "foam is never decoded")
	assert_true(source.contains("_fft_normal_gust("), "gusts and slicks scale the ripple cascade")
	assert_true(
		source.contains("clamp(detail_normal_strength * sea_gust, 0.0, 1.0)"),
		"gusts and slicks scale the detail normal",
	)


func test_fft_foam_drifts_are_seamless_over_the_ocean_clock_wrap() -> void:
	var source := ShaderSources.WATER_SHADER.code
	var wrap := float(MapViewRuntimeEnvironment.OCEAN_TIME_WRAP_SECONDS)
	assert_true(
		source.contains("const float OCEAN_TIME_WRAP_SECONDS = %.1f;" % wrap),
		"the shader mirrors the runtime ocean clock wrap",
	)
	for constant: String in [
		"FOAM_DRIFT_A_TILES_PER_WRAP = 40.0",
		"FOAM_DRIFT_B_TILES_PER_WRAP = 100.0",
		"GUST_DRIFT_CELLS_PER_WRAP = 64.0",
		"GUST_PERIOD_CELLS = 16.0",
	]:
		assert_true(source.contains(constant), "drift constant %s is a whole period count" % constant)
	assert_eq(fmod(64.0, 16.0), 0.0, "the gust drift is a whole number of noise periods per wrap")


func test_fft_foam_follows_sea_weather() -> void:
	MaterialsFacade.reset()
	var calm := WaterMaterials.fft_sea_state(0.2, 0.0)
	var reference := WaterMaterials.fft_sea_state(0.5, 0.0)
	var storm := WaterMaterials.fft_sea_state(0.85, 0.3)
	assert_almost_eq(float(calm["foam_coverage"]), 0.2, 0.001, "calm seas barely whiten")
	assert_almost_eq(float(storm["foam_coverage"]), 1.8, 0.001, "storms whiten hard")
	assert_true(
		float(calm["foam_coverage"]) < float(reference["foam_coverage"]),
		"coverage rises with the sea state",
	)
	assert_eq(float(calm["streaks"]), 0.0, "no wind streaks on calm water")
	assert_eq(float(storm["streaks"]), 1.0, "storm seas are streaked")
	assert_true(
		ResourceLoader.exists(WaterMaterials.OCEAN_FOAM_TILE_PATH), "the foam tile is imported"
	)


func test_water_shader_boosts_transmission_on_crest_fold_not_troughs() -> void:
	var source := ShaderSources.WATER_SHADER.code
	for feature in [
		"crest_subsurface",
		# WS-04: the glow reads one crest term, Gerstner fold or FFT Jacobian.
		"max(crest_term, 0.0)",
		"crest_term = normal_terms.y;",
		"crest_sss_visibility = twilight_water_light * day_blend",
		"crest_transmit_tint",
	]:
		assert_true(feature in source, "water shader must retain %s" % feature)
	assert_true(
		"crest_subsurface *= choppiness" in source,
		"crest subsurface glow must scale with open-water chop",
	)
	assert_true(
		"crest_subsurface *= choppiness * smoothstep(0.14, 0.48, shore_factor)" in source,
		"crest subsurface must fade near the pinned shoreline seam",
	)


func test_water_shader_reflects_bounded_sky_dome_without_planar_pass() -> void:
	var source := ShaderSources.WATER_SHADER.code
	for feature in [
		"_sky_dome_gradient",
		"day_top_color",
		"day_horizon_color",
		"sunset_factor",
		"sky_reflection_weight",
		"reflected_sky_ray",
		"sun_glint",
	]:
		assert_true(feature in source, "water shader must retain %s" % feature)
	assert_true(
		"clamp(" in source and "0.88" in source,
		"sky reflection must stay bounded away from a full planar replacement",
	)
	assert_false(
		"planar_reflection" in source.to_lower(),
		"water must not depend on a planar reflection pass",
	)


func test_water_shader_shares_fft_include_and_draws_snells_window_from_below() -> void:
	# WS-13: the UnderwaterPass fogs the view under water, so the P0-227 tint on the
	# surface pixels is gone and the back face resolves Snell's window instead.
	var source := ShaderSources.WATER_SHADER.code
	assert_true(
		source.contains('#include "res://scripts/map/view3d/ocean_fft_common.gdshaderinc"'),
		"the water shader and the underwater pass share one FFT sampling include",
	)
	assert_false(source.contains("vec4 _fft_sample("), "FFT sampling lives only in the include")
	for removed in ["camera_submerge", "underwater_fog_density", "underwater_fog_strength"]:
		assert_false(removed in source, "the P0-227 tint (%s) is replaced by the pass" % removed)
	assert_true(
		source.contains("bool seen_from_below = camera_world.y < water_world_position.y;"),
		"the underside branch keys on the camera height, not mesh winding",
	)
	assert_true(
		source.contains("if (seen_from_below && !swash_sheet)"), "the underside has its own branch"
	)
	assert_true(source.contains("_uw_below_color("), "the back face draws Snell's window")
	var include := FileAccess.get_file_as_string(
		"res://scripts/map/view3d/ocean_fft_common.gdshaderinc"
	)
	assert_true(
		include.contains("float k = 1.0 - WATER_IOR * WATER_IOR * (1.0 - cos_in * cos_in);"),
		"the window edge is the critical angle of total internal reflection",
	)
	assert_true(include.contains("refract(ray_up, -surface_up, WATER_IOR)"), "air is refracted in")
	assert_false(include.contains("sampler2D screen"), "screen samplers never enter a function")
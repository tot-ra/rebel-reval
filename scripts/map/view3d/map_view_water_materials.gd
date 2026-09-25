extends RefCounted

## Cached procedural water and puddle materials for the 3D map view.
##
## This owns water-only shader state so MapViewMaterials can remain the stable
## public facade for terrain, building, foliage, and water material consumers.

## Stable water terrain IDs for material and mesh builders. Re-exported on the
## MapViewMaterials facade so rollout inventory tests keep one public entry point.
const WATER_TERRAINS: Array[StringName] = MapTypes.WATER_TERRAINS

const OPTICAL_DEPTH_BY_TERRAIN := {
	MapTypes.TERRAIN_SHALLOW_WATER: 0.075,
	MapTypes.TERRAIN_RIVER_WATER: 0.14,
	MapTypes.TERRAIN_WATER: 0.24,
	MapTypes.TERRAIN_DEEP_WATER: 0.38,
}

## Closed per-terrain wave profile catalog consumed by water_surface() and the
## weather, lighting, tide, and sky-reflection updaters. MapViewMaterials
## re-exports this as WATER_WAVE_BASE so tests and builders keep one facade.
const WATER_WAVE_BASE := {
	MapTypes.TERRAIN_SHALLOW_WATER:
	{
		"height": 0.070,
		"chaos": 0.78,
		"choppiness": 0.85,
		"standing": 0.18,
		"foam": 0.24,
		"breakers": 0.52,
		"absorption": 5.0,
		"tide_height": 0.004,
		"tide_shore_retreat": 0.13,
		"tide_optical_depth": 0.055,
	},
	MapTypes.TERRAIN_DEEP_WATER:
	{
		"height": 0.120,
		"chaos": 1.18,
		"choppiness": 1.05,
		"standing": 0.08,
		"foam": 0.12,
		"breakers": 0.10,
		"absorption": 9.0,
		"tide_height": 0.004,
		"tide_shore_retreat": 0.0,
		"tide_optical_depth": 0.025,
	},
	MapTypes.TERRAIN_WATER:
	{
		"height": 0.080,
		"chaos": 0.96,
		"choppiness": 0.55,
		"standing": 0.42,
		"foam": 0.18,
		"breakers": 0.22,
		"absorption": 7.0,
		"bed_vegetation": 1.0,
		"tide_height": 0.0,
		"tide_shore_retreat": 0.0,
		"tide_optical_depth": 0.0,
	},
	# Fast river water uses tighter, livelier ripples than ponds or open sea and
	# drops the sheltered-water algae layer. Absorption sits higher than the old
	# clear-shallow tuning so the blue water column, not the warm bed, dominates
	# the surface colour - the Pirita should read as a river, not a green shallow.
	MapTypes.TERRAIN_RIVER_WATER:
	{
		"height": 0.045,
		"chaos": 0.72,
		"choppiness": 0.35,
		"standing": 0.05,
		"foam": 0.12,
		"breakers": 0.08,
		"absorption": 6.0,
		"bed_vegetation": 0.0,
		"tide_height": 0.0,
		"tide_shore_retreat": 0.0,
		"tide_optical_depth": 0.0,
	},
}

const SKY_WEATHER := preload("res://scripts/map/view3d/sky_weather_3d.gd")

## WS-04 baked FFT ocean (WS-03 output). The profile JSON is the source of truth
## for patch sizes, loop periods, frame counts, and channel decode scales.
const OCEAN_FFT_DIR := "res://assets/water/ocean_fft/baltic_reference/"
const OCEAN_FFT_PROFILE_PATH := OCEAN_FFT_DIR + "ocean_fft_profile.json"
const OCEAN_FFT_CASCADES := 3
const OCEAN_FFT_DISP_CASCADES := 2
## Uniform name -> atlas file. C2 has no displacement atlas (and no foam).
const OCEAN_FFT_ATLASES := {
	"fft_c0_disp": "c0_disp.png",
	"fft_c0_deriv": "c0_deriv.png",
	"fft_c1_disp": "c1_disp.png",
	"fft_c1_deriv": "c1_deriv.png",
	"fft_c2_deriv": "c2_deriv.png",
}
## WS-06 seamless foam detail tile (`bake_ocean_fft.py foam-tile`), shared by every
## FFT water material. Missing it leaves the shader's black default: no whitecaps.
const OCEAN_FOAM_TILE_PATH := "res://assets/water/ocean_fft/foam_tile.png"
const OCEAN_FFT_DERIV_KEYS: Array[String] = ["dy_dx", "dy_dz", "dx_dx", "dz_dz"]
const OCEAN_FFT_DISP_KEYS: Array[String] = ["dx", "dy", "dz"]
## Open sea, coastal shallows, and harbour basins take the FFT path. Rivers keep
## Gerstner because FFT trains only travel with the wind, never downstream.
## TERRAIN_WATER basins emulate their standing waves in the shader (step 6a).
const OCEAN_FFT_TERRAINS: Array[StringName] = [
	MapTypes.TERRAIN_SHALLOW_WATER,
	MapTypes.TERRAIN_WATER,
	MapTypes.TERRAIN_DEEP_WATER,
]
const BOAT_FLOAT_SCRIPT_PATH := "res://scripts/map/view3d/boat_float_3d.gd"

## Sea-state table for the FFT path, keyed by the scalar from fft_sea_state_scalar()
## (wind plus 0.4 x rain, so a rain squall reads rougher than the same dry wind).
## Knots are interpolated piecewise-linearly and clamp outside the range, so a
## weather transition (already blended over SkyWeather3D.TRANSITION_SECONDS)
## never jumps. Weights are per cascade C0 (swell), C1 (wind sea), C2 (ripples).
##
## The reference row is the physical bake: weights 1.0 and ocean_amplitude 1.0
## give Hs 1.26 m (WS-03 amendment 3). Cascade Hs add in quadrature, so the
## Hs multiplier is amplitude * sqrt(sum(w_c^2 * Hs_c^2)) / 1.26. Final table
## (WS-04 capture review, 2026-09-25), per SkyWeather regime at its profile wind:
##   clear    sea 0.20 (calm row)     -> 0.13 x reference, Hs 0.16 m
##   cloudy   sea 0.52                -> 1.08 x reference, Hs 1.36 m
##   overcast sea 0.58                -> 1.32 x reference, Hs 1.67 m
##   storm    sea 0.79 (wind 0.70, rain 0.22) -> 2.39 x reference, Hs 3.01 m
##   rain     sea 1.32 (storm row)    -> 2.76 x reference, Hs 3.48 m
## These are shading (slope/Jacobian) sea states; mesh displacement is further
## compressed by fft_geometry_scale to fit the view's water column.
## WS-06: foam_coverage scales the baked whitecap mask (calm 0.2 .. storm 1.8) and
## streaks is the storm share that turns on wind-aligned foam streaks.
const OCEAN_FFT_SEA_STATES: Array[Dictionary] = [
	{
		"sea_state": 0.20,
		"weights": [0.15, 0.45, 0.8],
		"choppiness": 0.6,
		"amplitude": 0.5,
		"foam_coverage": 0.2,
		"streaks": 0.0,
	},
	{
		"sea_state": 0.50,
		"weights": [1.0, 1.0, 1.0],
		"choppiness": 0.9,
		"amplitude": 1.0,
		"foam_coverage": 0.8,
		"streaks": 0.0,
	},
	{
		"sea_state": 0.85,
		"weights": [1.8, 1.4, 1.2],
		"choppiness": 1.15,
		"amplitude": 1.6,
		"foam_coverage": 1.8,
		"streaks": 1.0,
	},
]
const OCEAN_FFT_REFERENCE_SEA_STATE := 0.50
## Crest excursion of the reference C0+C1 sea (2 sigma of Hs 1.25 m = 0.63 m).
## fft_geometry_scale maps it onto the terrain's Gerstner "height" budget, so the
## reference FFT sea displaces the mesh as far as the tuned Gerstner sea did and
## storms grow from there through ocean_amplitude and the cascade weights.
const OCEAN_FFT_REFERENCE_CREST_M := 0.63

static var _cache: Dictionary = {}
static var _ocean_fft_profile: Dictionary = {}
static var _ocean_fft_textures: Dictionary = {}
static var _ocean_fft_quality_tier: StringName = SKY_WEATHER.QUALITY_RECOMMENDED
static var _ripple_off_texture: ImageTexture
## Test and capture hook. Production enablement follows BoatFloat3D.FFT_SUPPORTED
## (declared by WS-05) so hulls never float on a sea they cannot sample.
static var force_ocean_fft_support := false


static func reset() -> void:
	_cache.clear()


## True when water materials may enable the FFT path. Reads the WS-05 constant by
## name so this file does not break before BoatFloat3D declares it.
static func ocean_fft_supported() -> bool:
	if force_ocean_fft_support:
		return true
	var boat_script := load(BOAT_FLOAT_SCRIPT_PATH) as Script
	if boat_script == null:
		return false
	return bool(boat_script.get_script_constant_map().get("FFT_SUPPORTED", false))


static func uses_ocean_fft(terrain_id: StringName) -> bool:
	return (
		OCEAN_FFT_TERRAINS.has(terrain_id)
		and ocean_fft_supported()
		and not ocean_fft_profile().is_empty()
	)


## Changing the tier only applies to materials built afterwards; callers rebuild
## the map view (reset()) to switch, matching the other quality resources.
static func set_ocean_fft_quality_tier(requested: Variant) -> void:
	_ocean_fft_quality_tier = SKY_WEATHER.resolve_quality_tier(requested)


static func ocean_fft_cascade_count() -> int:
	return int(SKY_WEATHER.quality_settings(_ocean_fft_quality_tier)["ocean_fft_cascades"])


## Loaded once and cached; an empty dictionary means the bake is missing and every
## material stays on the Gerstner fallback.
static func ocean_fft_profile() -> Dictionary:
	if not _ocean_fft_profile.is_empty():
		return _ocean_fft_profile
	if not FileAccess.file_exists(OCEAN_FFT_PROFILE_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(OCEAN_FFT_PROFILE_PATH))
	if not parsed is Dictionary:
		push_error("WS-04: unreadable ocean FFT profile %s" % OCEAN_FFT_PROFILE_PATH)
		return {}
	_ocean_fft_profile = parsed
	return _ocean_fft_profile


## The atlases import as CompressedTexture2DArray; they are typed as
## TextureLayered because a Texture2DArray-typed assignment fails at runtime
## (WS-03 amendment 4).
static func ocean_fft_textures() -> Dictionary:
	if not _ocean_fft_textures.is_empty():
		return _ocean_fft_textures
	for uniform_name: String in OCEAN_FFT_ATLASES:
		var texture := load(OCEAN_FFT_DIR + String(OCEAN_FFT_ATLASES[uniform_name])) as TextureLayered
		if texture == null:
			push_error("WS-04: missing ocean FFT atlas %s" % OCEAN_FFT_ATLASES[uniform_name])
			return {}
		_ocean_fft_textures[uniform_name] = texture
	return _ocean_fft_textures


## Static cascade uniforms from the profile: x = patch world size, y = loop period,
## z = frame count, w = weight (reference 1.0 until weather overrides it).
static func ocean_fft_cascade_uniforms(weights: Array = [1.0, 1.0, 1.0]) -> PackedVector4Array:
	var profile := ocean_fft_profile()
	var meters_per_unit := float(profile.get("meters_per_world_unit", 0.87))
	var cascades: Array = profile.get("cascades", [])
	var result := PackedVector4Array()
	for index in OCEAN_FFT_CASCADES:
		var cascade: Dictionary = cascades[index] if index < cascades.size() else {}
		result.append(
			Vector4(
				float(cascade.get("patch_m", 1.0)) / meters_per_unit,
				float(cascade.get("period_s", 1.0)),
				float(cascade.get("frames", 1)),
				float(weights[index]),
			)
		)
	return result


static func _ocean_fft_scales(cascade_count: int, keys: Array[String]) -> PackedVector4Array:
	var cascades: Array = ocean_fft_profile().get("cascades", [])
	var result := PackedVector4Array()
	for index in cascade_count:
		var scales: Dictionary = (cascades[index] as Dictionary).get("channel_scales", {})
		var packed := Vector4.ZERO
		for channel in keys.size():
			packed[channel] = float(scales.get(keys[channel], 0.0))
		result.append(packed)
	return result


## Scalar sea state from the same wind/rain inputs as the Gerstner mapping.
static func fft_sea_state_scalar(wind: float, rain: float) -> float:
	return clampf(wind, 0.0, 1.0) + clampf(rain, 0.0, 1.0) * 0.4


## Single source of the FFT sea state. apply_sea_weather() sends these values to
## the shader; WS-05's CPU sampler must consume the same function.
static func fft_sea_state(wind: float, rain: float) -> Dictionary:
	var state := fft_sea_state_scalar(wind, rain)
	var lower: Dictionary = OCEAN_FFT_SEA_STATES[0]
	var upper: Dictionary = OCEAN_FFT_SEA_STATES[OCEAN_FFT_SEA_STATES.size() - 1]
	var t := 0.0
	if state >= float(upper["sea_state"]):
		lower = upper
	elif state > float(lower["sea_state"]):
		for index in range(1, OCEAN_FFT_SEA_STATES.size()):
			upper = OCEAN_FFT_SEA_STATES[index]
			if state <= float(upper["sea_state"]):
				lower = OCEAN_FFT_SEA_STATES[index - 1]
				t = inverse_lerp(float(lower["sea_state"]), float(upper["sea_state"]), state)
				break
	var weights: Array[float] = []
	for index in OCEAN_FFT_CASCADES:
		weights.append(
			lerpf(float(lower["weights"][index]), float(upper["weights"][index]), t)
		)
	return {
		"weights": weights,
		"choppiness": lerpf(float(lower["choppiness"]), float(upper["choppiness"]), t),
		"amplitude": lerpf(float(lower["amplitude"]), float(upper["amplitude"]), t),
		"foam_coverage": lerpf(float(lower["foam_coverage"]), float(upper["foam_coverage"]), t),
		"streaks": lerpf(float(lower["streaks"]), float(upper["streaks"]), t),
	}


## Mesh displacement per metre of baked sea, in the same units as the shader's
## fft_geometry_scale. WS-05 hull sampling must multiply by the same factor.
static func ocean_fft_geometry_scale(wave_height: float) -> float:
	var meters_per_unit := float(ocean_fft_profile().get("meters_per_world_unit", 0.87))
	return wave_height / (OCEAN_FFT_REFERENCE_CREST_M / meters_per_unit)


## The table choppiness is the open-sea value. Sheltered terrains keep their
## authored chop ratio to deep water, so harbour basins and shallows peak less
## than the open Baltic on both the Gerstner and the FFT path.
static func ocean_fft_choppiness_ratio(wave: Dictionary) -> float:
	var deep: Dictionary = WATER_WAVE_BASE[MapTypes.TERRAIN_DEEP_WATER]
	return float(wave.get("choppiness", 0.85)) / float(deep["choppiness"])


static func _apply_ocean_fft_uniforms(material: ShaderMaterial, wave: Dictionary) -> void:
	var wave_height := float(wave["height"])
	var textures := ocean_fft_textures()
	if textures.is_empty():
		material.set_shader_parameter("use_fft", false)
		return
	for uniform_name: String in textures:
		material.set_shader_parameter(uniform_name, textures[uniform_name])
	material.set_shader_parameter("use_fft", true)
	material.set_shader_parameter("fft_cascade", ocean_fft_cascade_uniforms())
	material.set_shader_parameter(
		"fft_disp_scale", _ocean_fft_scales(OCEAN_FFT_DISP_CASCADES, OCEAN_FFT_DISP_KEYS)
	)
	material.set_shader_parameter(
		"fft_deriv_scale", _ocean_fft_scales(OCEAN_FFT_CASCADES, OCEAN_FFT_DERIV_KEYS)
	)
	material.set_shader_parameter("ocean_amplitude", 1.0)
	material.set_shader_parameter("fft_cascade_count", ocean_fft_cascade_count())
	material.set_shader_parameter("fft_geometry_scale", ocean_fft_geometry_scale(wave_height))
	var reference := fft_sea_state(OCEAN_FFT_REFERENCE_SEA_STATE, 0.0)
	material.set_shader_parameter(
		"choppiness", float(reference["choppiness"]) * ocean_fft_choppiness_ratio(wave)
	)
	material.set_shader_parameter("storm_foam_coverage", float(reference["foam_coverage"]))
	material.set_shader_parameter("storm_streaks", float(reference["streaks"]))
	var foam_tile := load(OCEAN_FOAM_TILE_PATH) as Texture2D
	if foam_tile == null:
		push_warning("WS-06: missing foam tile %s; FFT whitecaps stay off" % OCEAN_FOAM_TILE_PATH)
	else:
		material.set_shader_parameter("foam_tile", foam_tile)


static func puddle_surface() -> ShaderMaterial:
	var key := "puddle_surface"
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = MapViewMaterialShaders.shader_resource(
		"puddle", MapViewMaterialShaders.PUDDLE_SHADER
	)
	# Standing rainwater over a dirty street reads dark, not silver: the film only
	# darkens the ground it covers, and the sky sheen arrives through fresnel.
	material.set_shader_parameter("water_tint", Vector3(0.10, 0.11, 0.11))
	material.set_shader_parameter("damp_tint", Vector3(0.22, 0.20, 0.17))
	material.set_shader_parameter("sheen_tint", Vector3(0.62, 0.70, 0.80))
	_cache[key] = material
	return material


## Animated water surface for water-family terrain cells; colors derive from
## the same frozen palette entry the flat material uses.
## Base wave heights are scaled at runtime by apply_sea_weather() so storms
## raise both the water mesh and floating hulls together.


static func water_surface(terrain_id: StringName, wave_profiles: Dictionary) -> ShaderMaterial:
	var key := "water_surface:%s" % String(terrain_id)
	if _cache.has(key):
		return _cache[key]
	var base := OutdoorTerrainPalette.color(terrain_id)
	var material := ShaderMaterial.new()
	material.shader = MapViewMaterialShaders.shader_resource(
		"water", MapViewMaterialShaders.WATER_SHADER
	)
	material.set_shader_parameter("shallow_color", base.lightened(0.18))
	material.set_shader_parameter("deep_color", base.darkened(0.42))
	# ART_BIBLE highlight #65B1C4 blended toward the terrain palette entry.
	material.set_shader_parameter("highlight_color", base.lerp(Color8(101, 177, 196), 0.55))
	# Keep foam close to the water tint so the shoreline does not flash white.
	material.set_shader_parameter("foam_color", base.lerp(Color8(188, 208, 206), 0.48))
	var wave: Dictionary = (
		wave_profiles.get(terrain_id, wave_profiles[MapTypes.TERRAIN_WATER]) as Dictionary
	)
	material.set_shader_parameter("depth_absorption", float(wave["absorption"]))
	material.set_shader_parameter(
		"optical_depth",
		float(OPTICAL_DEPTH_BY_TERRAIN.get(terrain_id, 0.105)),
	)
	material.set_shader_parameter("wave_height", float(wave["height"]))
	material.set_shader_parameter("wave_chaos", float(wave["chaos"]))
	material.set_shader_parameter("choppiness", float(wave.get("choppiness", 0.85)))
	material.set_shader_parameter("standing_wave_ratio", float(wave.get("standing", 0.12)))
	material.set_shader_parameter("foam_intensity", float(wave["foam"]))
	material.set_shader_parameter("breaker_intensity", float(wave["breakers"]))
	material.set_shader_parameter("bed_vegetation", float(wave.get("bed_vegetation", 1.0)))
	material.set_shader_parameter("flow_direction", Vector2.ZERO)
	material.set_shader_parameter("flow_strength", 0.0)
	material.set_shader_parameter("wind_direction", Vector2(1.0, 0.28).normalized())
	# Two detail layers provide the broken reflection pattern seen in realistic
	# water demos. Keep the river's detail tighter and stronger so its current is
	# legible without changing the shared displacement used by boat buoyancy.
	material.set_shader_parameter("detail_normal_strength", 0.30)
	material.set_shader_parameter("detail_normal_scale", 1.0)
	material.set_shader_parameter("tide_height", float(wave["tide_height"]))
	material.set_shader_parameter("tide_shore_retreat", float(wave["tide_shore_retreat"]))
	material.set_shader_parameter("tide_optical_depth", float(wave["tide_optical_depth"]))
	# WHY: Fast rivers need a pale sand/gravel bed instead of the shared coastal
	# sand+algae look. Without this, low absorption shows a green meadow cast
	# through the default seabed tint even when bed_vegetation is zero.
	if terrain_id == MapTypes.TERRAIN_RIVER_WATER:
		material.set_shader_parameter("sand_bed_color", Color(0.58, 0.50, 0.38))
		material.set_shader_parameter("stone_bed_color", Color(0.36, 0.39, 0.42))
		material.set_shader_parameter("deep_bed_color", Color(0.03, 0.07, 0.12))
		material.set_shader_parameter("foam_color", base.lerp(Color8(186, 204, 214), 0.52))
		# The Pirita flows from south (+Z) to north (-Z). A non-zero flow advects
		# the wave field and drives downstream foam ribbons so the surface reads as
		# a moving current; still water (sea/pond) keeps the default zero flow.
		material.set_shader_parameter("flow_direction", Vector2(0.0, -1.0))
		material.set_shader_parameter("flow_strength", 0.6)
		material.set_shader_parameter("detail_normal_strength", 0.36)
		material.set_shader_parameter("detail_normal_scale", 1.28)
	material.set_shader_parameter("use_fft", false)
	# WS-15: an unset sampler2D defaults to white (h = 1), so every water material starts
	# on the flat 1x1 state with the window marked invalid until a WaterRippleSim binds.
	material.set_shader_parameter("ripple_state", ripple_off_texture())
	material.set_shader_parameter("ripple_window", Vector4(0.0, 0.0, 64.0, 0.0))
	if uses_ocean_fft(terrain_id):
		_apply_ocean_fft_uniforms(material, wave)
	_cache[key] = material
	return material


## Scales cached water materials from SkyWeather wind/rain. Safe to call every
## frame; only shader uniforms change, never the cached material instances.
static func apply_sea_weather(
	wind: float,
	rain: float,
	wave_profiles: Dictionary,
	wind_direction: Vector2 = Vector2(1.0, 0.28)
) -> void:
	var wind_state := clampf(wind, 0.0, 1.0)
	var rain_state := clampf(rain, 0.0, 1.0)
	# Height follows wind and rain; chop tracks wind harder (Water Pro choppiness split).
	var height_mul := lerpf(0.82, 1.95, wind_state) * lerpf(1.0, 1.45, rain_state)
	var chaos_mul := lerpf(0.88, 1.65, wind_state) * lerpf(1.0, 1.35, rain_state)
	var chop_mul := lerpf(0.85, 2.35, wind_state) * lerpf(1.0, 1.08, rain_state)
	var speed := lerpf(0.72, 1.62, wind_state) * lerpf(1.0, 1.18, rain_state)
	var breaker_mul := lerpf(0.72, 1.75, wind_state) * lerpf(1.0, 1.45, rain_state)
	var heading := wind_direction
	if heading.length_squared() < 0.0001:
		heading = Vector2(1.0, 0.28)
	else:
		heading = heading.normalized()
	var sea := fft_sea_state(wind_state, rain_state)
	var cascade_uniforms := ocean_fft_cascade_uniforms(sea["weights"])
	# WS-05: CPU hulls read the same sea the FFT uniforms below describe. Keep in
	# lockstep with OceanFftSampler; per-terrain chop ratio, geometry scale and
	# standing ratio come from OceanFftSampler.terrain_surface(). The default
	# standing ratio is the harbour basin's, where boats are moored.
	var harbour: Dictionary = wave_profiles.get(
		MapTypes.TERRAIN_WATER, WATER_WAVE_BASE[MapTypes.TERRAIN_WATER]
	)
	OceanFftSampler.set_sea_state(
		PackedFloat32Array(sea["weights"]),
		float(sea["choppiness"]),
		float(sea["amplitude"]),
		heading,
		float(harbour.get("standing", 0.42))
	)
	for terrain_id in wave_profiles.keys():
		var material := water_surface(terrain_id as StringName, wave_profiles)
		var wave: Dictionary = wave_profiles[terrain_id]
		material.set_shader_parameter("wave_height", float(wave["height"]) * height_mul)
		material.set_shader_parameter("wave_chaos", float(wave["chaos"]) * chaos_mul)
		if bool(material.get_shader_parameter("use_fft")):
			# The FFT path takes chop and height from the sea-state table; the
			# Gerstner uniforms above stay primed for a fallback rebuild.
			material.set_shader_parameter(
				"choppiness", float(sea["choppiness"]) * ocean_fft_choppiness_ratio(wave)
			)
			material.set_shader_parameter("ocean_amplitude", float(sea["amplitude"]))
			material.set_shader_parameter("fft_cascade", cascade_uniforms)
			material.set_shader_parameter("storm_foam_coverage", float(sea["foam_coverage"]))
			material.set_shader_parameter("storm_streaks", float(sea["streaks"]))
		else:
			material.set_shader_parameter(
				"choppiness", float(wave.get("choppiness", 0.85)) * chop_mul
			)
		material.set_shader_parameter("wave_speed", speed)
		material.set_shader_parameter("breaker_intensity", float(wave["breakers"]) * breaker_mul)
		material.set_shader_parameter(
			"foam_intensity", float(wave["foam"]) * lerpf(0.9, 1.35, rain_state)
		)
		material.set_shader_parameter("wind_direction", heading)


## Pushes sky sun-disk visibility and day/night blend into cached water
## materials so specular sun glints die with the visible sun.
static func apply_water_lighting(
	sun_visibility: float, day_blend: float, wave_profiles: Dictionary
) -> void:
	var visibility := clampf(sun_visibility, 0.0, 1.0)
	var blend := clampf(day_blend, 0.0, 1.0)
	for terrain_id in wave_profiles.keys():
		var material := water_surface(terrain_id as StringName, wave_profiles)
		material.set_shader_parameter("sun_visibility", visibility)
		material.set_shader_parameter("day_blend", blend)


## WS-15 flat ripple state for materials without a live sim (indoors, minimum tier).
static func ripple_off_texture() -> Texture2D:
	if _ripple_off_texture == null:
		var image := Image.create_empty(1, 1, false, Image.FORMAT_RGBAH)
		image.fill(Color(0.0, 0.0, 0.0, 1.0))
		_ripple_off_texture = ImageTexture.create_from_image(image)
	return _ripple_off_texture


## Binds the newest WaterRippleSim state to every cached water material. The sim swaps its
## ping-pong target each step, so this runs once per step; only uniforms change. A null
## texture or window.w == 0 restores the flat, disabled state.
static func apply_water_ripples(
	texture: Texture2D, window: Vector4, texel_count: float, wave_profiles: Dictionary
) -> void:
	var state := texture if texture != null and window.w > 0.5 else ripple_off_texture()
	var bound_window := window if texture != null else Vector4(window.x, window.y, window.z, 0.0)
	for terrain_id in wave_profiles.keys():
		var material := water_surface(terrain_id as StringName, wave_profiles)
		material.set_shader_parameter("ripple_state", state)
		material.set_shader_parameter("ripple_window", bound_window)
		material.set_shader_parameter("ripple_texel_count", maxf(texel_count, 1.0))


## Applies a shared astronomical tide to coastal water families. The generic
## TERRAIN_WATER family represents rivers and enclosed water, so its material
## profile intentionally has zero visual tide response.
static func apply_coastal_tide(level: float, wave_profiles: Dictionary) -> void:
	var normalized_level := clampf(level, -1.0, 1.0)
	for terrain_id in wave_profiles.keys():
		water_surface(terrain_id as StringName, wave_profiles).set_shader_parameter(
			"tide_level", normalized_level
		)


## Pushes the sky state shared by the dome and cached water materials. Reusing
## the catalog texture and astronomical frame keeps reflected stars and celestial
## glints aligned with the visible sky rather than inventing a second night map.
static func apply_water_sky_reflection(
	star_map: Texture2D,
	sun_direction: Vector3,
	moon_direction: Vector3,
	sun_visibility: float,
	moon_visibility: float,
	star_visibility: float,
	observer_latitude: float,
	sidereal_angle: float,
	sun_color: Color,
	wave_profiles: Dictionary,
	sunset_factor: float = 0.0,
	cloud_darken: float = 0.0,
	day_top_color: Color = Color(0.18, 0.38, 0.65),
	day_horizon_color: Color = Color(0.67, 0.75, 0.81),
	night_top_color: Color = Color(0.020, 0.045, 0.130),
	night_horizon_color: Color = Color(0.050, 0.100, 0.220),
	sunset_color: Color = Color(0.98, 0.45, 0.18)
) -> void:
	var sunset := clampf(sunset_factor, 0.0, 1.0)
	var clouds := clampf(cloud_darken, 0.0, 1.0)
	for terrain_id in wave_profiles.keys():
		var material := water_surface(terrain_id as StringName, wave_profiles)
		material.set_shader_parameter("star_map", star_map)
		material.set_shader_parameter("sun_direction", sun_direction)
		material.set_shader_parameter("moon_direction", moon_direction)
		material.set_shader_parameter("sun_reflection_visibility", clampf(sun_visibility, 0.0, 1.0))
		material.set_shader_parameter("moon_visibility", clampf(moon_visibility, 0.0, 1.0))
		material.set_shader_parameter("star_visibility", clampf(star_visibility, 0.0, 1.0))
		material.set_shader_parameter("observer_latitude", observer_latitude)
		material.set_shader_parameter("sidereal_angle", sidereal_angle)
		material.set_shader_parameter("sun_reflection_color", sun_color)
		material.set_shader_parameter("sunset_factor", sunset)
		material.set_shader_parameter("cloud_darken", clouds)
		material.set_shader_parameter(
			"day_top_color", Vector3(day_top_color.r, day_top_color.g, day_top_color.b)
		)
		material.set_shader_parameter(
			"day_horizon_color", Vector3(day_horizon_color.r, day_horizon_color.g, day_horizon_color.b)
		)
		material.set_shader_parameter(
			"night_top_color", Vector3(night_top_color.r, night_top_color.g, night_top_color.b)
		)
		material.set_shader_parameter(
			"night_horizon_color",
			Vector3(night_horizon_color.r, night_horizon_color.g, night_horizon_color.b)
		)
		material.set_shader_parameter(
			"sunset_color", Vector3(sunset_color.r, sunset_color.g, sunset_color.b)
		)

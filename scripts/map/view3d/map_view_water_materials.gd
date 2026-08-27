extends RefCounted

## Cached procedural water and puddle materials for the 3D map view.
##
## This owns water-only shader state so MapViewMaterials can remain the stable
## public facade for terrain, building, foliage, and water material consumers.

const OPTICAL_DEPTH_BY_TERRAIN := {
	MapTypes.TERRAIN_SHALLOW_WATER: 0.038,
	MapTypes.TERRAIN_RIVER_WATER: 0.072,
	MapTypes.TERRAIN_WATER: 0.105,
	MapTypes.TERRAIN_DEEP_WATER: 0.22,
}

static var _cache: Dictionary = {}


static func reset() -> void:
	_cache.clear()


static func puddle_surface() -> ShaderMaterial:
	var key := "puddle_surface"
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = MapViewMaterialShaders.shader(
		"puddle", MapViewMaterialShaders.PUDDLE_SHADER_CODE
	)
	material.set_shader_parameter("wet_tint", Vector3(0.78, 0.82, 0.86))
	material.set_shader_parameter("sheen_tint", Vector3(0.94, 0.96, 0.98))
	material.set_shader_parameter("refraction_strength", 0.032)
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
	material.shader = MapViewMaterialShaders.shader(
		"water", MapViewMaterialShaders.WATER_SHADER_CODE
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
	material.set_shader_parameter("foam_intensity", float(wave["foam"]))
	material.set_shader_parameter("breaker_intensity", float(wave["breakers"]))
	material.set_shader_parameter("bed_vegetation", float(wave.get("bed_vegetation", 1.0)))
	material.set_shader_parameter("flow_direction", Vector2.ZERO)
	material.set_shader_parameter("flow_strength", 0.0)
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
	_cache[key] = material
	return material


## Scales cached water materials from SkyWeather wind/rain. Safe to call every
## frame; only shader uniforms change, never the cached material instances.
static func apply_sea_weather(wind: float, rain: float, wave_profiles: Dictionary) -> void:
	var wind_state := clampf(wind, 0.0, 1.0)
	var rain_state := clampf(rain, 0.0, 1.0)
	var height_mul := lerpf(0.82, 2.15, wind_state) * lerpf(1.0, 1.45, rain_state)
	var chaos_mul := lerpf(0.88, 1.65, wind_state) * lerpf(1.0, 1.35, rain_state)
	var speed := lerpf(0.72, 1.62, wind_state) * lerpf(1.0, 1.18, rain_state)
	var breaker_mul := lerpf(0.72, 1.75, wind_state) * lerpf(1.0, 1.45, rain_state)
	for terrain_id in wave_profiles.keys():
		var material := water_surface(terrain_id as StringName, wave_profiles)
		var wave: Dictionary = wave_profiles[terrain_id]
		material.set_shader_parameter("wave_height", float(wave["height"]) * height_mul)
		material.set_shader_parameter("wave_chaos", float(wave["chaos"]) * chaos_mul)
		material.set_shader_parameter("wave_speed", speed)
		material.set_shader_parameter("breaker_intensity", float(wave["breakers"]) * breaker_mul)
		material.set_shader_parameter(
			"foam_intensity", float(wave["foam"]) * lerpf(0.9, 1.35, rain_state)
		)


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
	wave_profiles: Dictionary
) -> void:
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

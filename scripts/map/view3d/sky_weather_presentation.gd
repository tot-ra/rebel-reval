class_name SkyWeatherPresentation
extends RefCounted

## Keeping these values together prevents lighting, fog, wet ground, wind, and
## water from observing different sides of a weather transition in the same
## rendered frame.

var weather: StringName = SkyWeatherProfiles.WEATHER_CLEAR
var cycle_progress := 0.0
var day_blend := 1.0
var sun_direction := Vector3.UP
var moon_direction := Vector3.UP
var wind_direction := Vector2.RIGHT
var wind_strength := 0.0
var rain_intensity := 0.0
var puddle_wetness := 0.0
## R-1516: 0..1 baked-dry bare soil; cracks open above ~0.45.
var ground_dryness := 0.0
var cloud_coverage := 0.0
var overcast := 0.0
var lightning := 0.0
var fog_quality := 1.0
var sunset_factor := 0.0
var sunset_tint := 0.0
var sun_energy := 1.0
var ambient_energy := 1.0
var sun_visibility := 0.0
var lunar_light_strength := 0.0
var moon_visibility := 0.0
## Share of sunlight / moonlight that gets through the cloud sitting in front of
## each body right now (the same field the dome draws). Drives water glints.
var sun_cloud_clear := 1.0
var moon_cloud_clear := 1.0
## R-1400 discrete clouds, packed for the cloud_cells uniform (CloudCells.uniforms()).
var cloud_cells := PackedVector4Array()
## 0..1: how ragged the cell cover right around the sun is from the camera. A cell
## edge on the sun is what throws visible beams.
var cell_sun_edge := 0.0
var star_visibility := 0.0
var sunrise_hour := 6.0
var fog_potential := 0.0
var sunset_hour := 18.0
var evening_fog_potential := 0.0
var tide_level := 0.0
var sidereal_angle := 0.0
var star_map: Texture2D
var sun_reflection_color := Color.WHITE
var rain_suppressed := false
## WS-11 AtmosphereCpu (4 Hz, smoothed); false without WS-09 LUTs (legacy colours).
var atmosphere_available := false
## Direct sun colour, sRGB like any Godot light Color; brightest channel 1.
var physical_sun_color := Color.WHITE
## Sun luminance relative to today's local noon, 0..1.
var physical_sun_energy := 1.0
## Weather sun multiplier without SUNSET_ENERGY_DIM, which physics replaces.
var weather_sun_energy := 1.0
## Linear, LUT scale: hemisphere irradiance, 2-degree horizon (8-azimuth, towards sun).
var sky_irradiance := Color(0.0, 0.0, 0.0)
var horizon_color := Color(0.0, 0.0, 0.0)
var horizon_sun_color := Color(0.0, 0.0, 0.0)
## Linear horizon as the dome draws it (AtmosphereCpu.displayed_horizon); fog hue.
var horizon_display_color := Color(0.0, 0.0, 0.0)
## Dome sky-view LUT (null on the gradient sky) and art exposure/tint for water.
var sky_lut: Texture2D
var sky_lut_size := Vector2(192.0, 108.0)
var sky_exposure := 0.7
var sky_tint := Color.WHITE
## Sun compass azimuth in radians, measured from -Z (north) towards +X (east).
var sun_azimuth := 0.0
## R-1518: post-rain bow for the water reflection (same values the dome draws).
var rainbow_strength := 0.0
var rainbow_curtain := Vector3.ZERO
## R-1547: per-shower secondary bow visibility (0 = single bow).
var rainbow_secondary := 0.0

class_name SkyWeather3D
extends Node3D
# gdlint: disable=max-file-lines

## Sky dome, sun/moon placement, real stars for medieval Reval, and a
## deterministic weather cycle for the MapView3D view layer. Owns the
## Environment sky (WS-10 physical sky-view LUT via SkyAtmosphereLut, falling back to the
## gradient, + procedural clouds via sky_weather_3d.gdshader),
## blends clear/cloudy/rain profiles, and reports lighting multipliers back to
## MapView3D so sun and ambient follow the sky. Weather randomness comes from a
## fixed seed: the sequence repeats identically every run, keeping the
## deterministic-state rule intact.

const SKY_SHADER := preload("res://scripts/map/view3d/sky_weather_3d.gdshader")
const SkyAtmosphereLutScript := preload("res://scripts/map/view3d/sky_atmosphere_lut.gd")
const AtmosphereCpuScript := preload("res://scripts/map/view3d/atmosphere_cpu.gd")
const SKY_RESOURCES := preload("res://scripts/map/view3d/sky_weather_resources.gd")
const SkyWeatherRoofAudioScript := preload("res://scripts/map/view3d/sky_weather_roof_audio.gd")
const SkyWeatherStateScript := preload("res://scripts/map/view3d/sky_weather_state.gd")
const CloudCellsScript := preload("res://scripts/map/view3d/cloud_cells.gd")
## Catalog stars baked per staged-assembly unit (about 1 ms each).
const STAR_BAKE_SLICE := 1000
const STAR_CATALOG := preload("res://scripts/map/view3d/estonia_star_catalog.gd")
const GAME_CALENDAR := preload("res://scripts/global/game_calendar.gd")

## Fair weather with scattered cumulus ("mostly clear" to "partly cloudy", 20-50%
## cover). The id predates WEATHER_CLOUDLESS and stays for save compatibility.
const WEATHER_CLEAR := &"clear"
## R-1495: a truly clear sky (0-10% cover): no cumulus, at most faint wisps.
## Tallinn spends roughly a fifth of late-spring daylight under such a sky.
const WEATHER_CLOUDLESS := &"cloudless"
const WEATHER_CLOUDY := &"cloudy"
## Full grey cover with no blue showing through — the "you can't see the sky" case.
const WEATHER_OVERCAST := &"overcast"
## Widespread overcast rain: the whole deck rains, with thunder.
const WEATHER_RAIN := &"rain"
## Isolated convection: mostly blue sky with one or a few heavy cells that tower,
## rain in distant walls, and throw lightning — the "specific raining cloud" case.
const WEATHER_STORM := &"storm"
const ALL_WEATHERS: Array[StringName] = [
	WEATHER_CLEAR, WEATHER_CLOUDY, WEATHER_OVERCAST, WEATHER_RAIN, WEATHER_STORM,
	WEATHER_CLOUDLESS
]

## Fixed seed: same weather sequence on every launch (deterministic, reviewable).
const WEATHER_SEED := 24217
const TRANSITION_SECONDS := 12.0
## Bank masses cross the dome at this rate; detail churns faster for edge chaos.
## Speed only: heading comes from wind_direction_xz() (R-955). CLEAR at noon
## still matches this vector so existing plates stay valid.
const CLOUD_DRIFT_PER_SECOND := Vector2(0.0011, 0.00044)
const CLOUD_DETAIL_DRIFT_PER_SECOND := Vector2(0.0019, -0.00075)
## Degrees added to the cloud-drift bearing per weather. CLEAR stays 0 so the
## historical (0.93, 0.37) harbour wind is the noon fair-weather reference.
const WIND_HEADING_OFFSET_DEG: Dictionary = {
	WEATHER_CLEAR: 0.0,
	WEATHER_CLOUDLESS: 0.0,
	WEATHER_CLOUDY: 55.0,
	WEATHER_OVERCAST: 110.0,
	WEATHER_RAIN: -70.0,
	WEATHER_STORM: 165.0,
}
## Slow veer over the day clock. Zero at noon (progress 0.25) so default
## presenters and tests that never call apply_sky_state keep the weather heading.
const WIND_DAY_VEER_DEG := 22.0
## Extra heading shove while a rain-front gust is live, scaled by gust / GUST_PEAK.
const WIND_GUST_VEER_DEG := 18.0

## Golden-hour presentation stays with the weather controller because it blends
## the live weather profile into MapView3D lighting.
const SUNSET_ELEVATION_BAND_DEG := 16.0
const SUNSET_ENERGY_DIM := 0.30
const SUNSET_AMBIENT_DIM := 0.15
const SUNSET_TINT_STRENGTH := 0.65

## Compatibility aliases preserve SkyWeather3D as the public astronomy facade
## while SkyAstronomy owns the scene-tree-free calculations.
const EARTH_AXIAL_TILT_DEGREES := SkyAstronomy.EARTH_AXIAL_TILT_DEGREES
const CAMPAIGN_VERNAL_EQUINOX_DAY_OF_YEAR := SkyAstronomy.CAMPAIGN_VERNAL_EQUINOX_DAY_OF_YEAR
const SYNODIC_MONTH_DAYS := SkyAstronomy.SYNODIC_MONTH_DAYS
const NEW_MOON_EPOCH_JULIAN_DAY := SkyAstronomy.NEW_MOON_EPOCH_JULIAN_DAY
const LUNAR_APPARENT_ROTATIONS_PER_SOLAR_DAY := SkyAstronomy.LUNAR_APPARENT_ROTATIONS_PER_SOLAR_DAY
const LUNAR_ORBITAL_INCLINATION_DEGREES := SkyAstronomy.LUNAR_ORBITAL_INCLINATION_DEGREES
const DRACONIC_MONTH_DAYS := SkyAstronomy.DRACONIC_MONTH_DAYS
const SOLAR_TIDE_FORCE_RATIO := SkyAstronomy.SOLAR_TIDE_FORCE_RATIO
const TIDE_BASIN_LAG_PROGRESS := SkyAstronomy.TIDE_BASIN_LAG_PROGRESS
const OBSERVER_LATITUDE_DEGREES := SkyAstronomy.OBSERVER_LATITUDE_DEGREES
const SKY_EPOCH_YEAR := SkyAstronomy.SKY_EPOCH_YEAR
const REFERENCE_DATE := SkyAstronomy.REFERENCE_DATE
const MIDNIGHT_SIDEREAL_DEGREES := SkyAstronomy.MIDNIGHT_SIDEREAL_DEGREES
const SIDEREAL_ROTATIONS_PER_SOLAR_DAY := SkyAstronomy.SIDEREAL_ROTATIONS_PER_SOLAR_DAY
const SUN_DISK_FADE_START := SkyAstronomy.SUN_DISK_FADE_START
const SUN_DISK_FADE_END := SkyAstronomy.SUN_DISK_FADE_END
## Compatibility aliases for callers that size generated sky resources explicitly.
const STAR_MAP_WIDTH := SKY_RESOURCES.STAR_MAP_WIDTH
const STAR_MAP_HEIGHT := SKY_RESOURCES.STAR_MAP_HEIGHT
## Wraps the twinkle clock so float precision never degrades the flicker.
const STAR_TWINKLE_PERIOD := 3600.0
const LUNAR_ALBEDO_MAP_SIZE := SKY_RESOURCES.LUNAR_ALBEDO_MAP_SIZE


## Quality tiers change renderer cost only. Weather state, profile transitions, cloud
## offsets, and seeded event scheduling stay identical across tiers.
const QUALITY_MINIMUM: StringName = &"minimum"
const QUALITY_RECOMMENDED: StringName = &"recommended"
const QUALITY_AUTO: StringName = &"auto"
const QUALITY_TIER_IDS: Array[StringName] = [QUALITY_MINIMUM, QUALITY_RECOMMENDED]
const QUALITY_TIERS: Dictionary = {
	QUALITY_MINIMUM: {
		"cloud_noise_resolution": SKY_RESOURCES.CLOUD_NOISE_RESOLUTION_MINIMUM,
		"cloud_shape_resolution": SKY_RESOURCES.CLOUD_SHAPE_RESOLUTION_MINIMUM,
		"cloud_shadow_samples": 2,
		# WS-12 ground pass. Sky raymarch keeps 2 so the dome stays identical.
		"cloud_shadow_ground_samples": 1,
		"cloud_shadow_enabled": true,
		"rain_shaft_samples": 3,
		"rain_particles": SKY_RESOURCES.RAIN_PARTICLES_MINIMUM,
		# This scales rendered flash intensity, not deterministic strike timing.
		"lightning_density": 0.65,
		"fog_quality": 0.65,
		"fallback_behavior": &"gradient_only_if_resource_missing",
		"frame_time_budget_ms": 1.50,
		"memory_budget_mib": 8.0,
		"particle_budget": 700,
		"shader_sample_budget": 80,
		# WS-04: C2 slopes off; the procedural detail normal covers the ripples.
		"ocean_fft_cascades": 2,
		# WS-10: half-size sky-view LUT rendered every second frame.
		"sky_lut_size": SkyAtmosphereLutScript.SIZE_MINIMUM,
		"sky_lut_every_n_frames": 2,
		# WS-15: interactive ripple sim off; water keeps the FFT and detail normals.
		"ripple_sim_size": 0,
		# R-1400 discrete clouds: half the volume steps, one sun sample, no sky beams.
		"cloud_cell_steps": 6,
		"cloud_cell_noise_size": 32,
		"cloud_cell_fine_steps": 5,
		"cloud_cell_light_samples": 1,
		"cloud_cell_ray_samples": 0,
	},
	QUALITY_RECOMMENDED: {
		"cloud_noise_resolution": SKY_RESOURCES.CLOUD_NOISE_RESOLUTION_RECOMMENDED,
		"cloud_shape_resolution": SKY_RESOURCES.CLOUD_SHAPE_RESOLUTION_RECOMMENDED,
		"cloud_shadow_samples": 4,
		"cloud_shadow_ground_samples": 3,
		"cloud_shadow_enabled": true,
		"rain_shaft_samples": 6,
		"rain_particles": SKY_RESOURCES.RAIN_PARTICLES_RECOMMENDED,
		"lightning_density": 1.0,
		"fog_quality": 1.0,
		"fallback_behavior": &"gradient_only_if_resource_missing",
		"frame_time_budget_ms": 2.50,
		"memory_budget_mib": 24.0,
		"particle_budget": 2200,
		"shader_sample_budget": 140,
		"ocean_fft_cascades": 3,
		# WS-10: the compressed day moves the sun ~6 deg/s, so the LUT renders every frame.
		"sky_lut_size": SkyAtmosphereLutScript.SIZE_RECOMMENDED,
		"sky_lut_every_n_frames": 1,
		# WS-15: 256^2 texels over the 64 x 64-unit ripple window (0.25 units per texel).
		"ripple_sim_size": 256,
		"cloud_cell_steps": 12,
		"cloud_cell_noise_size": 48,
		"cloud_cell_fine_steps": 10,
		"cloud_cell_light_samples": 2,
		"cloud_cell_ray_samples": 8,
	},
}


## Per-weather visual targets blended during transitions.
## `wind` drives harbor boat heel/heave and water-shader sea state (0..1).
## `chaos` domain-warps cloud banks so clear weather stays partly cloudy with
## torn edges while storms shred into denser, more chaotic cover.
## `storm` drives cumulonimbus development in the shader: the squall wall,
## darkened flat bases, sunlit anvil crowns, and rain curtains. `locality`
## concentrates the storm into isolated cells (1) versus spreading it across the
## whole deck (0), so the same storm strength reads either as one raining
## thundercloud in blue sky or as a solid rain front. `thunder` scales how often
## lightning strikes. Fair-weather states keep all three near zero.
const PROFILES: Dictionary = {
	WEATHER_CLEAR:
	{
		"coverage": 0.30,
		"darken": 0.06,
		"sun_energy": 1.0,
		"ambient_energy": 1.0,
		"gray": 0.0,
		"rain": 0.0,
		"wind": 0.20,
		"chaos": 0.30,
		"storm": 0.0,
		"locality": 0.0,
		"thunder": 0.0,
	},
	# R-1495: below ~0.08 cover CloudCells.counts_for() shows no cumulus and the
	# dome deck fades out (sky_cloud_bulk), leaving only faint high wisps.
	WEATHER_CLOUDLESS:
	{
		"coverage": 0.05,
		"darken": 0.0,
		"sun_energy": 1.0,
		"ambient_energy": 1.0,
		"gray": 0.0,
		"rain": 0.0,
		"wind": 0.20,
		"chaos": 0.2,
		"storm": 0.0,
		"locality": 0.0,
		"thunder": 0.0,
	},
	WEATHER_CLOUDY:
	{
		"coverage": 0.66,
		"darken": 0.40,
		"sun_energy": 0.62,
		"ambient_energy": 0.86,
		"gray": 0.32,
		"rain": 0.0,
		"wind": 0.52,
		"chaos": 0.55,
		"storm": 0.16,
		"locality": 0.35,
		"thunder": 0.0,
	},
	WEATHER_OVERCAST:
	{
		"coverage": 0.98,
		"darken": 0.72,
		"sun_energy": 0.12,
		"ambient_energy": 0.92,
		"gray": 0.75,
		"rain": 0.0,
		"wind": 0.58,
		"chaos": 0.58,
		"storm": 0.30,
		"locality": 0.0,
		"thunder": 0.0,
	},
	WEATHER_RAIN:
	{
		"coverage": 0.94,
		"darken": 0.82,
		"sun_energy": 0.07,
		"ambient_energy": 0.82,
		"gray": 0.62,
		"rain": 1.0,
		"wind": 0.92,
		"chaos": 0.86,
		"storm": 1.0,
		"locality": 0.18,
		"thunder": 0.55,
	},
	WEATHER_STORM:
	{
		"coverage": 0.40,
		"darken": 0.34,
		"sun_energy": 0.74,
		"ambient_energy": 0.90,
		"gray": 0.18,
		"rain": 0.22,
		"wind": 0.70,
		"chaos": 0.82,
		"storm": 1.0,
		"locality": 0.9,
		"thunder": 1.0,
	},
}
## Seconds each weather state holds before the Markov step picks the next one.
## Sized against DayNightCycle.CYCLE_DURATION_SECONDS (60s days) so weather
## visibly turns over within one in-game day. Clear spells are long enough to
## feel like real Estonian sunny stretches; rain and storms pass quickly so they
## punctuate rather than dominate.
const DURATIONS: Dictionary = {
	WEATHER_CLOUDLESS: Vector2(30.0, 60.0),
	WEATHER_CLEAR: Vector2(28.0, 55.0),
	WEATHER_CLOUDY: Vector2(18.0, 35.0),
	WEATHER_OVERCAST: Vector2(20.0, 35.0),
	WEATHER_RAIN: Vector2(15.0, 30.0),
	WEATHER_STORM: Vector2(12.0, 25.0),
}
## R-1495: cumulative transition odds, tuned to Tallinn in late April-May (the
## campaign opens on 21 April). Climatology (weatherspark, Tallinn): the sky is
## clear, mostly clear or partly cloudy about 45% of the time in April and 50-55%
## in May-August, and fully clear (under 20% cover) roughly a fifth of the time.
## Before R-1495 the cycle had no cloudless state at all (`clear` always carried
## ~8 cumulus). A long seeded run of this chain (holds plus 12 s blends) spends
## about: cloudless 18%, clear 31%, cloudy 27%, overcast 12%, rain 10%, storm 1%.
## Clouds must gather before rain: cloudless and clear never jump to rain or
## storms (test_rain_never_starts_from_a_clear_sky); a passing front can clear
## straight to cloudless.
const CLOUDLESS_TO_STAY_CHANCE := 0.35
const CLEAR_TO_CLOUDLESS_CHANCE := 0.30
const CLEAR_TO_STAY_CHANCE := 0.45
const CLOUDY_TO_CLEAR_CHANCE := 0.25
const CLOUDY_TO_OVERCAST_CHANCE := 0.55
const CLOUDY_TO_RAIN_CHANCE := 0.75
const CLOUDY_TO_STORM_CHANCE := 0.82
## Overcast often thins; rain is the more common outcome of a thick deck.
const OVERCAST_TO_CLEAR_CHANCE := 0.12
const OVERCAST_TO_CLOUDY_CHANCE := 0.50
## Rain eases to cloud, or a front passes and the sky opens up.
const RAIN_TO_CLOUDLESS_CHANCE := 0.12
const RAIN_TO_CLEAR_CHANCE := 0.30
const RAIN_TO_CLOUDY_CHANCE := 0.70
## Storms pass and skies clear faster than lingering rain.
const STORM_TO_CLOUDLESS_CHANCE := 0.20
const STORM_TO_CLEAR_CHANCE := 0.45
const STORM_TO_CLOUDY_CHANCE := 0.80

## Gust front: a real squall is preceded by a shove of wind ahead of the rain.
## When the machine commits to rain we fire a transient gust that spikes the wind
## (and, through it, cloud drift, sails, and sea state) then decays back to the
## sustained storm wind. Added on top of the profile wind and clamped to 1.
const GUST_PEAK := 0.4
const GUST_RISE_SECONDS := 1.0
const GUST_DECAY_SECONDS := 5.0

## Lightning. A storm's `thunder` factor scales the strike rate between these mean
## gaps (seconds). R-1400: each strike is born in a mature CloudCells cumulonimbus
## (never in open sky): it is either an in-cloud flash that lights the cell from
## inside or a cloud-to-ground stroke from the cell base. With no charged cell the
## countdown waits LIGHTNING_RETRY_SECONDS and tries again. Deterministic off the
## lightning RNG.
const LIGHTNING_GAP_SECONDS := Vector2(2.5, 9.0)
const LIGHTNING_FLASH_SECONDS := 0.42
const LIGHTNING_RETRY_SECONDS := 0.8
## Share of strikes that reach the ground; the rest stay inside the cloud.
const LIGHTNING_GROUND_CHANCE := 0.4
const LIGHTNING_KIND_CLOUD := 0
const LIGHTNING_KIND_GROUND := 1
## A distant strike lifts scene light less than one overhead (camera distance,
## world units, to the charge centre).
const LIGHTNING_NEAR_DISTANCE := 600.0
const LIGHTNING_FAR_DISTANCE := 2600.0
const LIGHTNING_FAR_SCALE := 0.4
## R-1481: cumulus merged into a thunderstorm tower charge lightning on their own,
## even when the weather profile has no thunder (up to this strike-rate factor), and
## rain under their curtain (up to TOWER_SHOWER_RAIN, presentation only like the
## storm-cell local rain).
const TOWER_THUNDER := 0.6
const TOWER_SHOWER_RAIN := 0.35

const RAIN_EMITTER_HEIGHT := 11.0
## R-1501: rain falls at its terminal speed and drifts with the wind, so it slants
## by atan(wind / fall). Wind strength maps to m/s like the Beaufort sea ladder
## (cloudy 0.52 ~ 8 m/s, storm 0.79 ~ 12.5 m/s); heavy drops fall at about 8 m/s.
## The streaks are drawn faster than that (RAIN_STREAK_SPEED) to read as rain, with
## the horizontal speed scaled to keep the physical angle, capped near 55 degrees.
const WIND_MS_AT_FULL := 16.0
const RAIN_TERMINAL_SPEED := 8.0
const RAIN_STREAK_SPEED := 17.0
const RAIN_MAX_SLANT := 1.4
## A storm's rain curtain leans less than the drops near the ground: the wind under
## the cloud base is weaker and the shaft is rain from the whole column.
const RAIN_SHAFT_SLANT := 0.5
## Local rain under storm cells. The sky shader hangs each cumulonimbus rain
## curtain in a cylinder of RAIN_SHAFT_RADIUS x cell radius; the emitter fades
## over RAIN_SHAFT_EDGE (fraction of that radius) either side of its wall, so
## walking out of the shaft thins the rain instead of cutting it.
const RAIN_SHAFT_RADIUS := 0.55
const RAIN_SHAFT_EDGE := 0.15
## storm_locality range over which visible rain switches from weather-wide (a rain
## front, locality 0.18) to only-under-cells (a thunderstorm, locality 0.9).
const RAIN_LOCAL_FROM := 0.3
const RAIN_LOCAL_TO := 0.8

## Worked-ground puddles start dry, fill while rain reaches the ground, and then
## evaporate gradually. Intensity is accumulated in simulated weather seconds so
## pausing or accelerating the weather clock affects puddles consistently.
const PUDDLE_RAIN_FILL_PER_SECOND := 0.08
const PUDDLE_DRY_PER_SECOND := 0.004

## R-1516 drought. Once the puddles are gone, open sun bakes the bare soil:
## `ground_dryness` climbs with sun height and clear sky. A fair spell only dusts
## it (capped at DRYNESS_FAIR_CAP); cracks need a drought spell, which can start
## only as the sky turns clear/cloudless over ground that is already parched.
## During a drought the sky never builds rain. Rain first soaks the crust back to
## loose earth (DRYNESS_SOAK_PER_SECOND) and only the rain left over fills puddles,
## so the order is always cracks -> damp loose earth -> puddles.
const DRYNESS_GAIN_PER_SECOND := 0.0025
const DRYNESS_DROUGHT_GAIN := 2.5
const DRYNESS_FAIR_CAP := 0.4
const DRYNESS_SOAK_PER_SECOND := 0.06
const DROUGHT_ONSET_DRYNESS := 0.3
const DROUGHT_START_CHANCE := 0.25
const DROUGHT_SECONDS := Vector2(240.0, 480.0)
## In a drought, clear skies mostly fall back to cloudless; cumulus that do form
## break up again instead of thickening to overcast or rain.
const DROUGHT_CLEAR_TO_CLOUDLESS_CHANCE := 0.6
const LAST_RAIN_NEVER := INF

## Cloud drift scales with wind so a gust visibly accelerates the sky and storms
## race while clear days barely stir. Base drift is the light fair-weather rate.
const WIND_DRIFT_FLOOR := 0.5
const WIND_DRIFT_GAIN := 1.6
## Max visual heading change, radians per second (1.5 deg/s: a full 165 degree
## weather swing takes ~110 s, slow enough that the wave field reads as drifting).
const WIND_HEADING_MAX_RATE := 0.026
## Time constant for the strength that scales cloud drift, so a gust or a
## weather change eases the clouds instead of snapping their speed.
const WIND_DRIFT_SMOOTH_SECONDS := 8.0
## Softer than Tidewater 0.85 so painted town materials stay readable.
const CLOUD_SHADOW_STRENGTH := 0.55
## R-1518: cos(80 deg) - the departed shower covers about 160 deg of horizon.
const RAINBOW_CURTAIN_HALF_WIDTH_COS := 0.17


## Keeping these values together prevents lighting, fog, wet ground, wind, and
## water from observing different sides of a weather transition in the same
## rendered frame.
class WeatherPresentation extends RefCounted:
	var weather: StringName = WEATHER_CLEAR
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
var weather: StringName = WEATHER_CLEAR
## When false the current state holds until set_weather() is called.
var auto_weather := true
## Multiplies the per-frame step, so the shared time controls speed up, slow down,
## or (at 0) pause the whole sky together with the sun: cloud drift, the weather
## machine, gusts, and lightning. Tests call advance() directly and are unaffected.
var time_scale := 1.0
## Enclosed room shells (a roofed interior like the Kalev smithy) hide the
## falling-rain particles: you do not get rain indoors. The weather machine still
## runs so wind, lighting, and sea state stay in sync everywhere else — only the
## visible emitter is gated. Roof-drum rain audio is owned by SkyWeatherRoofAudio
## (P0-124) and plays only while this flag is true.
var rain_suppressed := false
## 1 while the sun hugs the horizon (golden hour), 0 the rest of the cycle.
var sunset_factor := 0.0
var calendar_date: Dictionary = GAME_CALENDAR.DEFAULT_DATE.duplicate()
var quality_tier: StringName = QUALITY_RECOMMENDED:
	set(value):
		quality_tier = resolve_quality_tier(value)
		if _material != null:
			_apply_quality_resources()
			_push_cloud_uniforms()

var _current: Dictionary = (PROFILES[WEATHER_CLEAR] as Dictionary).duplicate()
var _from: Dictionary = (PROFILES[WEATHER_CLEAR] as Dictionary).duplicate()
var _transition_from_weather: StringName = WEATHER_CLEAR
var _blend := 1.0
var _time_in_state := 0.0
var _state_duration := 60.0
var _rng := RandomNumberGenerator.new()
var _cloud_offset := Vector2.ZERO
var _cloud_detail_offset := Vector2.ZERO
## Slewed visual wind. The target heading swings up to ~165 degrees across a 12 s
## weather transition and the sea rotates its whole wave field with it, so water
## and cirrus visibly raced. These follow the target at a bounded rate instead.
var _wind_heading_rad := 0.0
var _wind_drift_strength := 0.0
var _wind_smoothing_valid := false
var _cloud_noise_tex: Texture2D
var _cloud_shape_tex: Texture2D
var _sun_direction := Vector3.UP
## Starts dry so a fresh map cannot display puddles before rain has fallen.
var _puddle_wetness := 0.0
## Elapsed simulated seconds since rain last reached the ground. INF means this
## weather controller has never observed rain, useful to mud and save/debug UI.
var _seconds_since_rain := LAST_RAIN_NEVER
## R-1516: 0 = wet or freshly soaked, 1 = drought crust fully cracked.
var _ground_dryness := 0.0
var _drought_seconds_left := 0.0
## Separate stream so drought rolls never perturb the weather sequence.
var _drought_rng := RandomNumberGenerator.new()
## Transient gust magnitude on top of the profile wind. `_gust_time` < 0 is idle.
var _gust := 0.0
var _gust_time := -1.0
## Lightning flash level (0..1), the bearing of the flashing cell, elapsed flash
## time (< 0 while idle), and the countdown to the next strike.
var _lightning := 0.0
var _lightning_dir := Vector2(1.0, 0.0)
var _lightning_time := -1.0
var _time_to_strike := 0.0
## Separate stream so lightning draws never perturb the weather sequence.
var _lightning_rng := RandomNumberGenerator.new()
## R-1400: charge centre of the live strike (inside its storm cell, wrapped into the
## cell domain), the ground point of a cloud-to-ground stroke, and the strike kind.
var _lightning_origin := Vector3(0.0, 600.0, 0.0)
var _lightning_ground := Vector3.ZERO
var _lightning_kind := LIGHTNING_KIND_CLOUD
## Simulated seconds that drive every cloud cell's life cycle.
var _cloud_cell_clock := 0.0
var _cells: CloudCellsScript = CloudCellsScript.new()
var _cell_noise_size := 0
var _material: ShaderMaterial
var _star_map: ImageTexture
var _star_twinkle_time := 0.0
var _camera: Camera3D
var _environment: Environment
var _rain: GPUParticles3D
var _roof_audio: SkyWeatherRoofAudio
var _cloud_resources_available := false
var _atmosphere_lut: SkyAtmosphereLutScript
## WS-11: per-sky smoothing tracker, so two map views never share filter state.
var _atmosphere_cpu := AtmosphereCpuScript.new()
var _sky_uniform_defaults: Dictionary = {}
## Local copy of the shared day clock. apply_state stores the snapshot values so
## wind_direction_xz() matches immediately after restore; it does not write the
## clock itself (R-713 ownership).
var _cycle_progress := 0.25
var _elapsed_days := 0


## Maps user-facing tier requests to a named minimum/recommended row. Auto and
## unknown values fall back to recommended so headless tests and save payloads
## stay deterministic until a runtime probe chooses otherwise.
static func resolve_quality_tier(requested: Variant) -> StringName:
	var normalized := StringName(String(requested))
	if normalized == QUALITY_AUTO:
		return QUALITY_RECOMMENDED
	if normalized in QUALITY_TIERS:
		return normalized
	return QUALITY_RECOMMENDED


static func quality_settings(requested: Variant) -> Dictionary:
	var tier := resolve_quality_tier(requested)
	return (QUALITY_TIERS[tier] as Dictionary).duplicate(true)


## Quality-specific resources are rebuilt only during renderer configuration. Keeping the
## selected tier out of the simulation state preserves deterministic weather results.
func _quality_settings() -> Dictionary:
	return quality_settings(quality_tier)


func fog_quality() -> float:
	return float(_quality_settings()["fog_quality"])


func set_quality_tier(requested: Variant) -> void:
	quality_tier = requested


func _apply_quality_resources(cloud_noise: Texture2D = null, cloud_shape: Texture2D = null) -> void:
	var settings := _quality_settings()
	# R-1095: staged configure() builds the two noise textures as their own units
	# and passes them in; every other caller builds them here as before.
	if cloud_noise == null:
		cloud_noise = SKY_RESOURCES.build_cloud_noise(
			WEATHER_SEED, int(settings["cloud_noise_resolution"])
		)
	if cloud_shape == null:
		cloud_shape = SKY_RESOURCES.build_cloud_shape(
			WEATHER_SEED, int(settings["cloud_shape_resolution"])
		)
	_cloud_resources_available = cloud_noise != null and cloud_shape != null
	_cloud_noise_tex = cloud_noise
	_cloud_shape_tex = cloud_shape
	_material.set_shader_parameter(&"cloud_noise", cloud_noise)
	_material.set_shader_parameter(&"cloud_shape", cloud_shape)
	_material.set_shader_parameter(
		&"cloud_shadow_samples", int(settings["cloud_shadow_samples"])
	)
	_material.set_shader_parameter(
		&"rain_shaft_samples", int(settings["rain_shaft_samples"])
	)
	_material.set_shader_parameter(&"lightning_density", float(settings["lightning_density"]))
	_material.set_shader_parameter(&"cloud_fallback", not _cloud_resources_available)
	# A later tier change rebuilds the cell noise; staged configure binds it in its own unit.
	if _cell_noise_size != 0:
		_bind_cell_noise()
	_apply_atmosphere_lut(settings)
	if _rain != null:
		_rain.amount = int(settings["rain_particles"])


## R-1400: 3D noise for the discrete cloud cells, rebuilt only when the tier changes size.
func _bind_cell_noise() -> void:
	var size := int(_quality_settings()["cloud_cell_noise_size"])
	if size == _cell_noise_size:
		return
	_cell_noise_size = size
	_material.set_shader_parameter(
		&"cell_noise", SKY_RESOURCES.build_cell_noise_3d(WEATHER_SEED, size)
	)


## WS-10: sizes the sky-view LUT for the tier and binds it, or keeps the gradient sky when the
## WS-09 LUT assets are missing (same fail-closed rule as cloud_fallback).
func _apply_atmosphere_lut(settings: Dictionary) -> void:
	var available := false
	if _atmosphere_lut != null and _atmosphere_lut.is_available():
		_atmosphere_lut.set_tier(
			settings["sky_lut_size"] as Vector2i, int(settings["sky_lut_every_n_frames"])
		)
		available = true
		_material.set_shader_parameter(&"sky_view_lut", _atmosphere_lut.sky_view_texture())
		_material.set_shader_parameter(
			&"atmosphere_transmittance_lut", _atmosphere_lut.transmittance_texture()
		)
		_material.set_shader_parameter(&"sky_lut_size", Vector2(_atmosphere_lut.lut_size))
		_material.set_shader_parameter(
			&"sun_illuminance", SkyAtmosphereLutScript.SUN_ILLUMINANCE
		)
	_material.set_shader_parameter(&"sky_lut_available", available)


## True when the sky dome draws from the physical sky-view LUT rather than the gradient.
func uses_atmosphere_lut() -> bool:
	return _atmosphere_lut != null and _atmosphere_lut.is_available()


func atmosphere_lut() -> SkyAtmosphereLutScript:
	return _atmosphere_lut


func _init() -> void:
	_rng.seed = WEATHER_SEED
	_lightning_rng.seed = WEATHER_SEED + 101
	_drought_rng.seed = WEATHER_SEED + 211
	_time_to_strike = _lightning_rng.randf_range(LIGHTNING_GAP_SECONDS.x, LIGHTNING_GAP_SECONDS.y)
	_state_duration = _roll_duration(weather)
	_update_cells()


## Captures only simulation data so a presenter can hand the weather field to the
## next map without serializing renderer nodes or rebuilding the deterministic RNG.
## The owning runtime supplies cycle_progress/elapsed_days because those values
## belong to the shared day clock rather than this scene node.
func snapshot_state(
	cycle_progress: float = 0.25, elapsed_days: int = 0
) -> RefCounted:
	_cycle_progress = wrapf(cycle_progress, 0.0, 1.0)
	_elapsed_days = elapsed_days
	var state = SkyWeatherStateScript.new()
	state.weather = weather
	state.transition_from_weather = _transition_from_weather
	state.transition_progress = _json_safe_float(_blend)
	state.time_in_state = _json_safe_float(_time_in_state)
	state.state_duration = _json_safe_float(_state_duration)
	state.auto_weather = auto_weather
	state.time_scale = time_scale
	state.rain_suppressed = rain_suppressed
	state.calendar_date = calendar_date.duplicate(true)
	state.cycle_progress = cycle_progress
	state.elapsed_days = elapsed_days
	state.cloud_offset = _cloud_offset
	state.cloud_detail_offset = _cloud_detail_offset
	state.wind_smoothing_valid = _wind_smoothing_valid
	# Wind and rain clocks are float64 accumulators; JSON.stringify keeps only ~15
	# significant digits, so unsnapped values drift across a save/map round trip.
	state.wind_heading = _json_safe_float(_wind_heading_rad)
	state.wind_drift_strength = _json_safe_float(_wind_drift_strength)
	state.puddle_wetness = _json_safe_float(_puddle_wetness)
	state.seconds_since_rain = _json_safe_float(_seconds_since_rain)
	state.ground_dryness = _json_safe_float(_ground_dryness)
	state.drought_seconds_left = _json_safe_float(_drought_seconds_left)
	if not is_finite(_seconds_since_rain):
		state.seconds_since_rain = SkyWeatherStateScript.LAST_RAIN_NEVER
	state.gust = _json_safe_float(_gust)
	state.gust_time = _json_safe_float(_gust_time)
	state.lightning = _json_safe_float(_lightning)
	state.lightning_direction = _lightning_dir
	state.lightning_time = _json_safe_float(_lightning_time)
	state.time_to_strike = _json_safe_float(_time_to_strike)
	state.lightning_origin = _lightning_origin
	state.lightning_ground = _lightning_ground
	state.lightning_kind = _lightning_kind
	state.cloud_cell_clock = _json_safe_float(_cloud_cell_clock)
	state.weather_rng_state = _rng.state
	state.lightning_rng_state = _lightning_rng.state
	state.drought_rng_state = _drought_rng.state
	state.current_profile = _profile_for_state(_current)
	state.transition_from_profile = _profile_for_state(_from)
	state.normalize()
	return state


## Restores a validated state produced by snapshot_state(). Returning false keeps
## corrupt/foreign save data from poisoning the active weather controller.
func apply_state(state: RefCounted) -> bool:
	if state == null:
		return false
	var restored = state.duplicate_state()
	if not restored.validation_errors().is_empty():
		return false
	weather = restored.weather
	_transition_from_weather = restored.transition_from_weather
	_blend = restored.transition_progress
	_time_in_state = restored.time_in_state
	_state_duration = restored.state_duration
	auto_weather = restored.auto_weather
	time_scale = restored.time_scale
	rain_suppressed = restored.rain_suppressed
	calendar_date = restored.calendar_date.duplicate(true)
	_cloud_offset = restored.cloud_offset
	_cloud_detail_offset = restored.cloud_detail_offset
	_wind_smoothing_valid = restored.wind_smoothing_valid
	_wind_heading_rad = restored.wind_heading
	_wind_drift_strength = restored.wind_drift_strength
	_puddle_wetness = restored.puddle_wetness
	_seconds_since_rain = restored.seconds_since_rain
	_ground_dryness = restored.ground_dryness
	_drought_seconds_left = restored.drought_seconds_left
	if restored.seconds_since_rain < 0.0:
		_seconds_since_rain = LAST_RAIN_NEVER
	_gust = restored.gust
	_gust_time = restored.gust_time
	_lightning = restored.lightning
	_lightning_dir = restored.lightning_direction
	_lightning_time = restored.lightning_time
	_time_to_strike = restored.time_to_strike
	_lightning_origin = restored.lightning_origin
	_lightning_ground = restored.lightning_ground
	_lightning_kind = restored.lightning_kind
	_cloud_cell_clock = restored.cloud_cell_clock
	if restored.weather_rng_state != -1:
		_rng.state = restored.weather_rng_state
	if restored.lightning_rng_state != -1:
		_lightning_rng.state = restored.lightning_rng_state
	if restored.drought_rng_state != -1:
		_drought_rng.state = restored.drought_rng_state
	_current = _profile_from_state(restored.current_profile, weather)
	_from = _profile_from_state(restored.transition_from_profile, _transition_from_weather)
	_cycle_progress = wrapf(float(restored.cycle_progress), 0.0, 1.0)
	_elapsed_days = int(restored.elapsed_days)
	_update_cells()
	_push_cloud_uniforms()
	_update_rain()
	return true


## Dictionary keys become String after JSON encoding. Convert profile snapshots back
## to StringName keys before the runtime accesses their typed profile identifiers.
func _profile_for_state(profile: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field in SkyWeatherStateScript.PROFILE_FIELDS:
		if profile.has(field):
			result[String(field)] = _json_safe_float(float(profile[field]))
	return result


func _json_safe_float(value: float) -> float:
	return snappedf(value, 0.000000001)


func _profile_from_state(profile: Dictionary, fallback_weather: StringName) -> Dictionary:
	if profile.is_empty():
		return (PROFILES[fallback_weather] as Dictionary).duplicate()
	var result: Dictionary = {}
	for key in profile:
		result[StringName(key)] = float(profile[key])
	return result


func restore_state(snapshot: Variant) -> bool:
	if snapshot is SkyWeatherStateScript:
		return apply_state(snapshot)
	if snapshot is Dictionary:
		return apply_state(SkyWeatherStateScript.from_dict(snapshot))
	return false


func _weather_for_profile(profile: Dictionary) -> StringName:
	for weather_id in PROFILES:
		if profile == PROFILES[weather_id]:
			return weather_id
	return weather


func _process(delta: float) -> void:
	advance(delta * maxf(time_scale, 0.0))
	# R-1443: scintillation runs on real time even when the weather clock is
	# paused; it is presentation only and never saved.
	_star_twinkle_time = fmod(_star_twinkle_time + delta, STAR_TWINKLE_PERIOD)
	if _material != null:
		_material.set_shader_parameter(&"star_twinkle_time", _star_twinkle_time)


## Replaces the environment's flat background with the sky dome and builds the
## rain emitter that shadows the gameplay camera.
func configure(camera: Camera3D, environment: Environment) -> void:
	for step in configure_steps(camera, environment):
		step.call()


## R-1095: configure() as ordered steps, so staged assembly can spend them over
## several frames (the noise textures and star map each cost 2-4 ms). Running
## every step in order is exactly configure().
func configure_steps(camera: Camera3D, environment: Environment) -> Array[Callable]:
	var textures: Array[Texture2D] = [null, null]
	var setup := func() -> void:
		# advance() reads the material; hold it back until the last step ran.
		set_process(false)
		_camera = camera
		_material = ShaderMaterial.new()
		_material.shader = SKY_SHADER
		if _atmosphere_lut == null:
			_atmosphere_lut = SkyAtmosphereLutScript.new()
			_atmosphere_lut.name = "SkyAtmosphereLut"
			add_child(_atmosphere_lut)
		var lut_settings := _quality_settings()
		_atmosphere_lut.configure(
			lut_settings["sky_lut_size"] as Vector2i, int(lut_settings["sky_lut_every_n_frames"])
		)
	var noise := func() -> void:
		textures[0] = SKY_RESOURCES.build_cloud_noise(
			WEATHER_SEED, int(_quality_settings()["cloud_noise_resolution"])
		)
	var shape := func() -> void:
		textures[1] = SKY_RESOURCES.build_cloud_shape(
			WEATHER_SEED, int(_quality_settings()["cloud_shape_resolution"])
		)
	var resources := func() -> void:
		_apply_quality_resources(textures[0], textures[1])
	var moon := func() -> void:
		_material.set_shader_parameter(
			&"lunar_albedo_map", SKY_RESOURCES.build_lunar_albedo_map(WEATHER_SEED)
		)
	var cell_noise := func() -> void:
		_bind_cell_noise()
	var star_image: Array[Image] = []
	var star_slices: Array[Callable] = [
		func() -> void: star_image.append(SKY_RESOURCES.new_star_image())
	]
	for first in range(0, STAR_CATALOG.STARS.size(), STAR_BAKE_SLICE):
		star_slices.append(
			func() -> void:
				SKY_RESOURCES.bake_stars(
					star_image[0],
					STAR_CATALOG.STARS,
					first,
					first + STAR_BAKE_SLICE,
					STAR_CATALOG.CATALOG_EPOCH,
					SKY_EPOCH_YEAR,
					STAR_CATALOG.LIMITING_MAGNITUDE
				)
		)
	var stars := func() -> void:
		_star_map = ImageTexture.create_from_image(star_image[0])
		_material.set_shader_parameter(&"star_map", _star_map)
		_material.set_shader_parameter(&"observer_latitude", deg_to_rad(OBSERVER_LATITUDE_DEGREES))
		var galaxy := SKY_RESOURCES.galactic_frame(STAR_CATALOG.CATALOG_EPOCH, SKY_EPOCH_YEAR)
		_material.set_shader_parameter(&"galactic_pole", galaxy["pole"])
		_material.set_shader_parameter(&"galactic_center", galaxy["center"])
	var sky := func() -> void:
		var dome := Sky.new()
		dome.sky_material = _material
		environment.sky = dome
		environment.background_mode = Environment.BG_SKY
	var rain := func() -> void:
		_rain = SKY_RESOURCES.build_rain(int(_quality_settings()["rain_particles"]))
		add_child(_rain)
	var attach := func() -> void:
		_roof_audio = SkyWeatherRoofAudioScript.new()
		_roof_audio.name = "RoofRainAudio"
		add_child(_roof_audio)
		_push_cloud_uniforms()
		set_process(true)
	var steps: Array[Callable] = [setup, noise, shape, resources, moon, cell_noise]
	steps.append_array(star_slices)
	steps.append_array([stars, sky, rain, attach])
	return steps


## Public photometry and precession helpers remain on SkyWeather3D for callers
## that treat the weather controller as the sky's astronomy facade.
static func magnitude_to_luminance(magnitude: float) -> float:
	return SKY_RESOURCES.magnitude_to_luminance(magnitude, STAR_CATALOG.LIMITING_MAGNITUDE)


static func bv_to_rgb(bv: float) -> Color:
	return SKY_RESOURCES.bv_to_rgb(bv)


static func precess_equatorial(star: Vector4, from_epoch: float, to_epoch: float) -> Vector4:
	return SKY_RESOURCES.precess_equatorial(star, from_epoch, to_epoch)


## Steps the weather state machine and cloud drift. Public so headless tests
## can drive time without a scene tree; _process is the only other caller.
func advance(delta: float) -> void:
	_advance_gust(delta)
	# Wind carries the clouds: gusts race the sky, calm clear days barely stir.
	# Bank and detail drift share the multiplier so detail keeps outpacing banks.
	_advance_wind_smoothing(delta)
	var wind_scale := WIND_DRIFT_FLOOR + _wind_drift_strength * WIND_DRIFT_GAIN
	var drift_turn := _wind_heading_rad - CLOUD_DRIFT_PER_SECOND.angle()
	_cloud_offset += CLOUD_DRIFT_PER_SECOND.rotated(drift_turn) * wind_scale * delta
	_cloud_detail_offset += CLOUD_DETAIL_DRIFT_PER_SECOND.rotated(drift_turn) * wind_scale * delta
	if _blend < 1.0:
		var previous_ease := smoothstep(0.0, 1.0, _blend)
		_blend = minf(1.0, _blend + delta / TRANSITION_SECONDS)
		var remaining_weight := (
			(smoothstep(0.0, 1.0, _blend) - previous_ease)
			/ maxf(1.0 - previous_ease, 0.000001)
		)
		if _blend >= 1.0:
			remaining_weight = 1.0
		# Resume from the saved visible profile, including older linear blends.
		# A zero-time update cannot jump when easing or authored targets change.
		for key in _current:
			_current[key] = lerpf(
				float(_current[key]), float((PROFILES[weather] as Dictionary)[key]),
				remaining_weight
			)
	elif auto_weather:
		_time_in_state += delta
		if _time_in_state >= _state_duration:
			_pick_next_weather()
	# Cells follow the blended profile; lightning then needs this frame's cells.
	_cloud_cell_clock += delta
	_update_cells()
	_advance_lightning(delta)
	_advance_ground_water(delta)
	_update_rain(delta)
	_push_cloud_uniforms()


## Starts a blended transition to the requested weather state.
func set_weather(next_weather: StringName) -> void:
	assert(next_weather in ALL_WEATHERS)
	if next_weather == weather:
		return
	# A gust front shoves ahead of the rain, so arm the pulse as the storm commits.
	if next_weather == WEATHER_RAIN:
		_gust_time = 0.0
	_from = _current.duplicate()
	_transition_from_weather = weather
	weather = next_weather
	_blend = 0.0
	_time_in_state = 0.0
	_state_duration = _roll_duration(next_weather)
	_maybe_start_drought()


## Public astronomy compatibility facade. Existing maps and systems keep using
## SkyWeather3D while the calculations remain independently testable in SkyAstronomy.
static func solar_declination_degrees(date: Dictionary) -> float:
	return SkyAstronomy.solar_declination_degrees(date)


static func celestial_direction(progress: float, declination_degrees: float) -> Vector3:
	return SkyAstronomy.celestial_direction(progress, declination_degrees)


static func solar_direction(progress: float, date: Dictionary = {}) -> Vector3:
	return SkyAstronomy.solar_direction(progress, date)


static func solar_elevation_degrees(progress: float, date: Dictionary = {}) -> float:
	return SkyAstronomy.solar_elevation_degrees(progress, date)


static func sun_disk_visibility(sun_direction: Vector3) -> float:
	return SkyAstronomy.sun_disk_visibility(sun_direction)


static func sunrise_sunset_hours(date: Dictionary = {}) -> Dictionary:
	return SkyAstronomy.sunrise_sunset_hours(date)


static func daylight_blend(progress: float, date: Dictionary = {}) -> float:
	return SkyAstronomy.daylight_blend(progress, date)


static func julian_day(date: Dictionary) -> float:
	return SkyAstronomy.julian_day(date)


static func lunar_phase(date: Dictionary = {}) -> float:
	return SkyAstronomy.lunar_phase(date)


static func lunar_illumination(phase: float) -> float:
	return SkyAstronomy.lunar_illumination(phase)


static func morning_fog_potential(date: Dictionary = {}) -> float:
	return SkyAstronomy.morning_fog_potential(date)


static func evening_fog_potential(date: Dictionary = {}) -> float:
	return SkyAstronomy.evening_fog_potential(date)


static func moonlight_strength(progress: float, date: Dictionary = {}) -> float:
	return SkyAstronomy.moonlight_strength(progress, date)


static func lunar_declination_degrees(date: Dictionary = {}) -> float:
	return SkyAstronomy.lunar_declination_degrees(date)


static func lunar_direction(progress: float, date: Dictionary = {}) -> Vector3:
	return SkyAstronomy.lunar_direction(progress, date)


static func lunar_elevation_degrees(progress: float, date: Dictionary = {}) -> float:
	return SkyAstronomy.lunar_elevation_degrees(progress, date)


static func sun_moon_separation_degrees(progress: float, date: Dictionary = {}) -> float:
	return SkyAstronomy.sun_moon_separation_degrees(progress, date)


static func tide_level(progress: float, date: Dictionary = {}) -> float:
	return SkyAstronomy.tide_level(progress, date)


func set_calendar_date(date: Dictionary) -> void:
	calendar_date = date.duplicate()


## Pushes shared physical sun/moon directions and cycle tints into the sky
## shader. MapView3D uses the same vectors for directional lighting, keeping
## disks, moving shadows, and east-to-west travel in agreement.
## Mirrors sky_clouds.gdshaderinc (uv mapping, bulk, erosion) on the CPU for one sky
## direction, so a water reflection of the sun or moon dims when a cloud covers the
## body, not with the dome-wide coverage. Returns `fallback` when the cloud textures
## have no CPU image yet (headless or before first generation).
func celestial_cloud_clear(
	dir: Vector3, fallback: float, match_sky_deck: bool = false
) -> float:
	if dir.y < 0.02 and not match_sky_deck:
		return fallback
	if _cloud_noise_tex == null or _cloud_shape_tex == null:
		return fallback * cells_clear_toward(dir)
	var noise := _cloud_noise_tex.get_image()
	var shape := _cloud_shape_tex.get_image()
	if noise == null or shape == null or noise.is_empty() or shape.is_empty():
		return fallback * cells_clear_toward(dir)
	var d := dir.normalized()
	var uv := Vector2(d.x, d.z) * (1.0 / sqrt(d.y * d.y + 0.012)) * 0.12 - _cloud_offset
	var storm := storm_intensity()
	var cell := 1.0 - _sample_repeat(shape, uv * 0.12 + Vector2(0.37, 0.71))
	var storm_mask := lerpf(1.0, smoothstep(0.48, 0.8, cell), storm_locality())
	storm_mask *= 1.0 - storm_locality()
	var cover := clampf(cloud_coverage() + storm * storm_mask * 0.38, 0.0, 1.0)
	if match_sky_deck:
		return _cloud_slab_clear(d, cover, storm * storm_mask, noise, shape) * cells_clear_toward(d)
	var opacity := _cloud_opacity_at(uv, cover, noise, shape)
	return (1.0 - smoothstep(0.05, 0.65, opacity)) * cells_clear_toward(d)


func _cloud_opacity_at(uv: Vector2, cover: float, noise: Image, shape: Image) -> float:
	var banks := 1.0 - _sample_repeat(shape, uv * 0.42 + Vector2(0.13, 0.61))
	var heaps := 1.0 - _sample_repeat(shape, uv)
	var base := heaps * lerpf(0.45, 1.0, smoothstep(0.30, 0.72, banks))
	var floor_thr := lerpf(0.66, 0.04, cover)
	# Mirrors sky_cloud_clear_fade(): the deck leaves a cloudless sky (R-1495).
	var bulk := clampf((base - floor_thr) / 0.58, 0.0, 1.0) * smoothstep(0.02, 0.16, cover)
	var detail := (
		_sample_repeat(noise, uv * 1.9 + _cloud_detail_offset) * 0.5
		+ _sample_repeat(noise, uv * 4.6 - _cloud_detail_offset * 0.6) * 0.32
		+ _sample_repeat(noise, uv * 9.4 + _cloud_detail_offset * 0.3) * 0.18
	)
	var lo := detail * lerpf(0.18, 0.42, cloud_chaos())
	return clampf((bulk - lo) / maxf(1.0 - lo, 1e-4), 0.0, 1.0)


## Mirror cloud_field's Beer-Lambert slab, stratiform floor, cirrus and horizon
## fade. A single heap sample misses the closed deck that hides the Moon in sky.
func _cloud_slab_clear(
	dir: Vector3, cover: float, storm: float, noise: Image, shape: Image
) -> float:
	var steps := int(_quality_settings()["cloud_shadow_samples"]) * 2
	var step_length := 1.0 / float(steps)
	var optical_step := (step_length * lerpf(9.0, 15.0, storm)
		/ maxf(sqrt(maxf(dir.y, 0.0)), 0.38))
	var transmittance := 1.0
	var wind := wind_direction_xz()
	for i in steps:
		var h := (float(i) + 0.5) * step_length
		var uv := _cloud_uv_at(dir, 1.0 + h * lerpf(0.14, 0.32, storm))
		uv += wind * h * 0.008
		var body := _cloud_opacity_at(uv, cover, noise, shape)
		var profile := smoothstep(0.0, 0.16, h) * (1.0 - smoothstep(0.48, 1.0, h))
		var billows := _sample_repeat(noise,
			uv * 5.2 + _cloud_detail_offset + Vector2.ONE * h * 0.12)
		var density := maxf(body - h * h * 0.38, 0.0) * profile * lerpf(0.55, 1.25, billows)
		density += smoothstep(0.84, 0.98, cover) * profile * 0.32
		transmittance *= exp(-density * optical_step)
	var high_uv := _cloud_uv_at(dir, 2.1) + _cloud_offset * 0.65
	var high_wind := Vector2(wind.x * 0.825 - wind.y * 0.565, wind.x * 0.565 + wind.y * 0.825)
	var across := Vector2(-high_wind.y, high_wind.x)
	var cirrus := _sample_repeat(noise, Vector2(high_uv.dot(high_wind) * 0.45,
		high_uv.dot(across) * 1.8))
	cirrus = (smoothstep(0.58, 0.85, cirrus) * 0.20
		* smoothstep(0.25, 0.65, cloud_coverage()) * (1.0 - storm))
	var density := 1.0 - transmittance * (1.0 - cirrus)
	return 1.0 - density * smoothstep(-0.025, 0.055, dir.y)


func _cloud_uv_at(dir: Vector3, altitude: float) -> Vector2:
	return (Vector2(dir.x, dir.z) * (altitude / sqrt(dir.y * dir.y + 0.012)) * 0.12
		- _cloud_offset)


## R-1400: share of light from `dir` that passes the discrete cells, seen from the
## camera (the world origin before configure()).
func cells_clear_toward(dir: Vector3) -> float:
	return 1.0 - _cells.shadow_at(_view_position(), dir.normalized())


## How broken the cell cover right around the sun is (0 = open or solid, 1 = a
## ragged edge on the sun). Five probes within ~6 degrees of the sun disk.
func cell_sun_edge(sun_dir: Vector3) -> float:
	if sun_dir.y <= 0.0:
		return 0.0
	var origin := _view_position()
	var axis := sun_dir.normalized()
	var side := axis.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.5:
		side = Vector3.RIGHT
	var up := side.cross(axis).normalized()
	var lo := 1.0
	var hi := 0.0
	for probe: Vector2 in [Vector2.ZERO, Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var d := (axis + (side * probe.x + up * probe.y) * 0.1).normalized()
		var s: float = _cells.shadow_at(origin, d)
		lo = minf(lo, s)
		hi = maxf(hi, s)
	return clampf(hi - lo, 0.0, 1.0)


## True when the sky is drawn through a perspective camera (third/first person), the
## only lens that shows a horizon; the orthographic overview must not get distance haze.
func view_is_perspective() -> bool:
	var active := get_viewport().get_camera_3d() if is_inside_tree() else null
	if active == null:
		active = _camera
	return is_instance_valid(active) and active.projection != Camera3D.PROJECTION_ORTHOGONAL


func _view_position() -> Vector3:
	if _camera != null and is_instance_valid(_camera) and _camera.is_inside_tree():
		return _camera.global_position
	return Vector3.ZERO


## The discrete cloud field (R-1400). Read-only for callers.
func cloud_cells() -> CloudCellsScript:
	return _cells


func cloud_cell_clock() -> float:
	return _cloud_cell_clock


func _update_cells() -> void:
	_cells.update(
		_cloud_cell_clock, _cloud_offset,
		CloudCellsScript.counts_for(cloud_coverage(), storm_intensity()),
		_wind_drift_strength
	)


## Bilinear, wrapping red-channel lookup with shader uv semantics (uv 1.0 = one tile).
static func _sample_repeat(image: Image, uv: Vector2) -> float:
	var w := image.get_width()
	var h := image.get_height()
	var x := uv.x * w - 0.5
	var y := uv.y * h - 0.5
	var x0 := floori(x)
	var y0 := floori(y)
	var fx := x - x0
	var fy := y - y0
	var r00 := image.get_pixel(posmod(x0, w), posmod(y0, h)).r
	var r10 := image.get_pixel(posmod(x0 + 1, w), posmod(y0, h)).r
	var r01 := image.get_pixel(posmod(x0, w), posmod(y0 + 1, h)).r
	var r11 := image.get_pixel(posmod(x0 + 1, w), posmod(y0 + 1, h)).r
	return lerpf(lerpf(r00, r10, fx), lerpf(r01, r11, fx), fy)


func apply_sky_state(progress: float, day_blend: float, sun_direction: Vector3) -> void:
	_cycle_progress = wrapf(progress, 0.0, 1.0)
	_sun_direction = sun_direction
	var elevation := rad_to_deg(asin(clampf(sun_direction.y, -1.0, 1.0)))
	sunset_factor = clampf(1.0 - absf(elevation) / SUNSET_ELEVATION_BAND_DEG, 0.0, 1.0)
	var phase := lunar_phase(calendar_date)
	var moon_direction := lunar_direction(progress, calendar_date)
	_material.set_shader_parameter(&"sun_direction", sun_direction)
	_material.set_shader_parameter(&"moon_direction", moon_direction)
	_material.set_shader_parameter(&"moon_phase", phase)
	_material.set_shader_parameter(&"day_blend", day_blend)
	_material.set_shader_parameter(&"sunset_factor", sunset_factor)
	_material.set_shader_parameter(&"sun_flare_strength", day_blend)
	_material.set_shader_parameter(&"camera_direction", _camera_forward())
	_material.set_shader_parameter(
		&"sidereal_angle", sidereal_angle_for_progress(progress, calendar_date)
	)
	if _atmosphere_lut != null:
		_atmosphere_lut.update(sun_direction, Engine.get_process_frames())
	_publish_cloud_shadow_globals()


## Builds one immutable-in-practice presentation handoff from the current weather
## profile and cycle inputs. Callers should retain this value for the frame rather
## than reading individual weather accessors between lighting and material passes.
func presentation_snapshot(progress: float, day_blend: float) -> WeatherPresentation:
	_cycle_progress = wrapf(progress, 0.0, 1.0)
	var snapshot := WeatherPresentation.new()
	snapshot.weather = weather
	snapshot.cycle_progress = _cycle_progress
	snapshot.day_blend = clampf(day_blend, 0.0, 1.0)
	snapshot.sun_direction = solar_direction(progress, calendar_date)
	snapshot.moon_direction = lunar_direction(progress, calendar_date)
	snapshot.wind_direction = wind_direction_xz()
	snapshot.wind_strength = wind_strength()
	snapshot.rain_intensity = rain_intensity()
	snapshot.puddle_wetness = puddle_wetness()
	snapshot.ground_dryness = ground_dryness()
	snapshot.cloud_coverage = cloud_coverage()
	var modifiers := lighting_modifiers()
	snapshot.overcast = float(modifiers["overcast"])
	snapshot.lightning = float(modifiers["lightning"])
	snapshot.fog_quality = fog_quality()
	snapshot.sunset_factor = sunset_factor
	snapshot.sunset_tint = float(modifiers["sunset_tint"])
	snapshot.sun_energy = float(modifiers["sun_energy"])
	snapshot.ambient_energy = float(modifiers["ambient_energy"])
	snapshot.sun_visibility = sun_disk_visibility(snapshot.sun_direction)
	snapshot.lunar_light_strength = moonlight_strength(progress, calendar_date)
	var sunrise_data := sunrise_sunset_hours(calendar_date)
	snapshot.sunrise_hour = float(sunrise_data["sunrise"])
	snapshot.sunset_hour = float(sunrise_data["sunset"])
	snapshot.fog_potential = morning_fog_potential(calendar_date)
	snapshot.evening_fog_potential = evening_fog_potential(calendar_date)
	var cloud_occlusion := 1.0 - snapshot.cloud_coverage
	snapshot.sun_cloud_clear = celestial_cloud_clear(snapshot.sun_direction, cloud_occlusion)
	snapshot.moon_cloud_clear = celestial_cloud_clear(
		snapshot.moon_direction, cloud_occlusion, true
	)
	snapshot.moon_visibility = (SkyAstronomy.lunar_reflection_strength(progress, calendar_date)
		* snapshot.moon_cloud_clear)
	snapshot.cloud_cells = _cells.uniforms()
	snapshot.cell_sun_edge = cell_sun_edge(snapshot.sun_direction)
	snapshot.star_visibility = pow(1.0 - snapshot.day_blend, 3.0) * cloud_occlusion
	snapshot.tide_level = tide_level(progress, calendar_date)
	snapshot.sidereal_angle = sidereal_angle_for_progress(progress, calendar_date)
	snapshot.star_map = star_map_texture()
	# Color8: Color(255, ...) is a 0..255 float colour that blew the water's sky
	# reflection out to white whenever the sun stood ahead of the camera.
	snapshot.sun_reflection_color = Color8(255, 243, 222).lerp(
		Color8(255, 148, 64), snapshot.sunset_tint
	)
	snapshot.rain_suppressed = rain_suppressed
	snapshot.weather_sun_energy = float(_current["sun_energy"])
	snapshot.sun_azimuth = atan2(snapshot.sun_direction.x, -snapshot.sun_direction.z)
	snapshot.rainbow_strength = rainbow_strength()
	snapshot.rainbow_curtain = rainbow_curtain()
	_fill_atmosphere(snapshot)
	return snapshot


## WS-11: physical sun/sky/horizon colours and the dome's LUT binding. The water's sun colour
## becomes the physical one, so the disk, the light and the glitter share one hue.
func _fill_atmosphere(snapshot: WeatherPresentation) -> void:
	if uses_atmosphere_lut():
		snapshot.sky_lut = _atmosphere_lut.sky_view_texture()
		snapshot.sky_lut_size = Vector2(_atmosphere_lut.lut_size)
	snapshot.sky_exposure = float(_sky_uniform(&"sky_exposure", snapshot.sky_exposure))
	var tint: Variant = _sky_uniform(&"sky_tint", snapshot.sky_tint)
	snapshot.sky_tint = tint if tint is Color else Color.WHITE
	if not _atmosphere_cpu.sample(snapshot.sun_direction, Time.get_ticks_usec()):
		return
	snapshot.atmosphere_available = true
	snapshot.physical_sun_color = _atmosphere_cpu.sun_color.linear_to_srgb()
	# Relative to today's culmination, not the zenith: SUN_DAY_ENERGY was tuned at game noon,
	# so noon keeps its authored energy and only the rest of the day follows transmittance.
	var noon_energy := AtmosphereCpuScript.sun_energy_for(solar_direction(0.5, calendar_date))
	snapshot.physical_sun_energy = clampf(
		_atmosphere_cpu.sun_energy / maxf(noon_energy, 1e-6), 0.0, 1.0
	)
	snapshot.sky_irradiance = _atmosphere_cpu.sky_irradiance
	snapshot.horizon_color = _atmosphere_cpu.horizon_color
	snapshot.horizon_sun_color = _atmosphere_cpu.horizon_sun_color
	snapshot.horizon_display_color = _atmosphere_cpu.displayed_horizon(
		snapshot.sky_exposure, snapshot.sky_tint, snapshot.day_blend, _sky_uniform
	)
	snapshot.sun_reflection_color = snapshot.physical_sun_color


## Live sky-shader uniform, or the shader's own default when the script never set it, so
## the dome shader stays the single source of the art exposure and tint.
func _sky_uniform(uniform_name: StringName, fallback: Variant) -> Variant:
	if _material != null:
		var value: Variant = _material.get_shader_parameter(uniform_name)
		if value != null:
			return value
	# Defaults are cached: presentation_snapshot runs every frame and the RenderingServer
	# lookup is not free.
	if not _sky_uniform_defaults.has(uniform_name):
		_sky_uniform_defaults[uniform_name] = RenderingServer.shader_get_parameter_default(
			SKY_SHADER.get_rid(), uniform_name
		)
	var default_value: Variant = _sky_uniform_defaults[uniform_name]
	return default_value if default_value != null else fallback


## Multipliers/tints MapView3D applies on top of its day/night lerp. Overcast
## skies also mute the sunset tint: gray clouds do not glow orange.
func lighting_modifiers() -> Dictionary:
	return {
		"sun_energy": float(_current["sun_energy"]) * (1.0 - SUNSET_ENERGY_DIM * sunset_factor),
		"ambient_energy":
		float(_current["ambient_energy"]) * (1.0 - SUNSET_AMBIENT_DIM * sunset_factor),
		"sunset_tint": sunset_factor * SUNSET_TINT_STRENGTH * float(_current["sun_energy"]),
		"overcast": float(_current["gray"]),
		"lightning": _effective_lightning(),
	}


func cloud_coverage() -> float:
	return float(_current["coverage"])


func cloud_chaos() -> float:
	return float(_current["chaos"])


## Bank-layer UV drift. Exposed for tests that prove clouds translate across
## the dome instead of only changing a global coverage threshold.
func cloud_offset() -> Vector2:
	return _cloud_offset


func cloud_detail_offset() -> Vector2:
	return _cloud_detail_offset


## Weather-wide rainfall from the blended profile. Deterministic and saved; it
## drives puddles, mud and the snapshot. What the camera sees falling is
## local_rain_intensity().
func rain_intensity() -> float:
	return float(_current["rain"])


## Rain falling at the camera: rain_intensity() scaled by local_rain_factor().
## Presentation only (emitter, roof audio); never saved, never fed to puddles.
func local_rain_intensity() -> float:
	return maxf(rain_intensity() * local_rain_factor(), tower_shower_intensity())


## R-1481: rain falling where the camera stands under a cumulus that merged into a
## thunderstorm tower. Presentation only (puddles stay on rain_intensity()); 0
## without a camera in the tree, so headless simulation stays weather-wide.
func tower_shower_intensity() -> float:
	if _camera == null or not is_instance_valid(_camera) or not _camera.is_inside_tree():
		return 0.0
	var point := _view_position()
	var flat := Vector2(point.x, point.z)
	var slant := rain_slant() * RAIN_SHAFT_SLANT
	var cover := 0.0
	for slot in CloudCellsScript.CUMULUS_SLOTS:
		if _cells.tower_level(slot) <= 0.5:
			continue
		# R-1501: only the copy storming in the hotspot nearest the camera rains.
		var shape := _cells.copy_shape(slot, _cells.tower_copy_centre(slot, flat))
		var t: float = shape[5]
		var foot := Vector2(shape[0], shape[2]) + slant * (shape[1] - point.y)
		var shaft := maxf(shape[3] * RAIN_SHAFT_RADIUS, 1.0)
		var inside := 1.0 - smoothstep(
			1.0 - RAIN_SHAFT_EDGE, 1.0 + RAIN_SHAFT_EDGE, flat.distance_to(foot) / shaft
		)
		# Same ramp as the sky curtain (smoothstep(0.5, 0.9, storminess)).
		cover = maxf(cover, float(_cells.weights[slot]) * inside * smoothstep(0.5, 0.9, t))
	return cover * TOWER_SHOWER_RAIN


## R-1501: horizontal metres the falling rain drifts per metre of fall, downwind
## (world x, z). Gusts lean it further.
func rain_slant() -> Vector2:
	var ratio := wind_strength() * WIND_MS_AT_FULL / RAIN_TERMINAL_SPEED
	return wind_direction_xz() * minf(ratio, RAIN_MAX_SLANT)


## 0..1 share of the weather rain that falls where the camera stands. A widespread
## front (low storm_locality) rains everywhere (1). A localized thunderstorm only
## rains inside the curtain the sky draws under each cumulonimbus. Without a
## camera in the tree (headless simulation) the camera counts as under the storm,
## as _lightning_proximity() does.
func local_rain_factor() -> float:
	var localized := smoothstep(RAIN_LOCAL_FROM, RAIN_LOCAL_TO, storm_locality())
	if localized <= 0.0:
		return 1.0
	if _camera == null or not is_instance_valid(_camera) or not _camera.is_inside_tree():
		return 1.0
	return lerpf(1.0, storm_rain_cover_at(_view_position()), localized)


## 0..1 how far `point` stands inside a storm cell's rain shaft, scaled by the
## cell's visible weight (the same `b.y` factor the sky shader puts on the curtain).
func storm_rain_cover_at(point: Vector3) -> float:
	var cover := 0.0
	for slot in range(CloudCellsScript.CUMULUS_SLOTS, CloudCellsScript.SLOTS):
		var weight: float = _cells.weights[slot]
		if weight <= 0.0:
			continue
		var c: Vector3 = _cells.centers[slot]
		# R-1501: the curtain leans downwind, so it reaches the ground off-centre.
		var foot := Vector2(c.x, c.z) + rain_slant() * RAIN_SHAFT_SLANT * (c.y - point.y)
		var offset := CloudCellsScript.wrap_delta(
			Vector2(point.x, point.z), foot, CloudCellsScript.KIND_STORM
		)
		var shaft := maxf(float(_cells.radii[slot]) * RAIN_SHAFT_RADIUS, 1.0)
		var inside := 1.0 - smoothstep(
			1.0 - RAIN_SHAFT_EDGE, 1.0 + RAIN_SHAFT_EDGE, offset.length() / shaft
		)
		cover = maxf(cover, weight * inside)
	return cover


## Persistent surface water created only by rain that has already reached the
## ground. A storm can leave puddles behind after the rain particles stop.
## Decision (R-1400 follow-up): puddles stay weather-wide on rain_intensity(), not
## on local rain. Storm cells drift over the whole town during one storm, so the
## profile's low storm rain (0.22) stands in for that average; a camera-dependent
## fill would make saved ground water depend on where the player stood.
func puddle_wetness() -> float:
	return _puddle_wetness


## 0..1 post-rain rainbow visibility. Recent rain and retained ground wetness
## are required; cloud cover suppresses it. R-1518: a LOW sun is the best case
## (the bow is a 42 deg cone around the antisolar point, so a sunset bow is a full
## half circle). Above ~54 deg even the secondary sinks below the horizon, so the
## strength fades there; the shader draws the exact geometry in between.
func rainbow_strength() -> float:
	if _seconds_since_rain < 0.0 or rain_intensity() > 0.04:
		return 0.0
	var recent_rain := 1.0 - smoothstep(0.0, 900.0, _seconds_since_rain)
	var sun_up := smoothstep(-0.02, 0.03, _sun_direction.y)
	var below_bow_limit := 1.0 - smoothstep(0.74, 0.81, _sun_direction.y)
	var open_sky := 1.0 - smoothstep(0.52, 0.9, cloud_coverage())
	return clampf(recent_rain * _puddle_wetness * sun_up * below_bow_limit * open_sky, 0.0, 1.0)


## R-1518: where the lit drops are. The shower drifted downwind (rain_slant() and the
## clouds move along wind_direction_xz()), so only that part of the bow shows. xz is
## the unit world direction, y the cosine of the curtain's half-width (about 80 deg).
func rainbow_curtain() -> Vector3:
	var downwind := wind_direction_xz()
	if downwind.length_squared() < 1e-6:
		return Vector3.ZERO
	downwind = downwind.normalized()
	return Vector3(downwind.x, RAINBOW_CURTAIN_HALF_WIDTH_COS, downwind.y)


func _camera_forward() -> Vector3:
	if _camera != null and is_instance_valid(_camera) and _camera.is_inside_tree():
		return -_camera.global_basis.z.normalized()
	return Vector3(0.0, 0.0, -1.0)


## Mud uses the same retained ground water as puddles, so viscosity changes from
## both current rainfall and elapsed drying rather than a disconnected timer.
func mud_wetness() -> float:
	return _puddle_wetness


func seconds_since_rain() -> float:
	return _seconds_since_rain


## R-1516: 0..1 sun-baked bare soil. Cracks open in the puddle basins above ~0.45.
func ground_dryness() -> float:
	return _ground_dryness


func drought_active() -> bool:
	return _drought_seconds_left > 0.0


func drought_seconds_left() -> float:
	return _drought_seconds_left


## Debug and test entry point: start (or with 0, end) a drought spell now.
func start_drought(seconds: float) -> void:
	_drought_seconds_left = maxf(seconds, 0.0)


## Rolled once per real weather change (never on a "stay" re-pick): a clear or
## cloudless sky over ground that a fair spell has already parched may settle
## into a drought.
func _maybe_start_drought() -> void:
	if drought_active() or not (weather == WEATHER_CLEAR or weather == WEATHER_CLOUDLESS):
		return
	# A shower still easing out of the blend would cancel the drought next frame.
	if _ground_dryness < DROUGHT_ONSET_DRYNESS or rain_intensity() > 0.001:
		return
	if _drought_rng.randf() < DROUGHT_START_CHANCE:
		_drought_seconds_left = _drought_rng.randf_range(DROUGHT_SECONDS.x, DROUGHT_SECONDS.y)


## Rain, puddles and dryness share one ground-water budget, in weather seconds.
func _advance_ground_water(delta: float) -> void:
	var rain := rain_intensity()
	var rain_fill := rain * PUDDLE_RAIN_FILL_PER_SECOND
	if rain > 0.001:
		# Rain (even a forced debug shower) breaks a drought, and the dry crust
		# drinks first: puddles only get the share the soil could not absorb.
		_drought_seconds_left = 0.0
		var soak := rain * DRYNESS_SOAK_PER_SECOND * delta
		var absorbed := minf(soak, _ground_dryness)
		_ground_dryness -= absorbed
		rain_fill *= 1.0 - absorbed / maxf(soak, 0.000001)
	else:
		_drought_seconds_left = maxf(_drought_seconds_left - delta, 0.0)
		if _puddle_wetness <= 0.0:
			_ground_dryness = _bake_dryness(_ground_dryness, delta)
	var drying := PUDDLE_DRY_PER_SECOND if rain <= 0.001 else 0.0
	_puddle_wetness = clampf(_puddle_wetness + (rain_fill - drying) * delta, 0.0, 1.0)
	if rain > 0.001:
		_seconds_since_rain = 0.0
	elif not is_inf(_seconds_since_rain):
		_seconds_since_rain += delta


## Sustained profile wind plus any transient gust front, clamped to the 0..1
## range the sea-state and world-wind materials expect.
func wind_strength() -> float:
	return clampf(float(_current["wind"]) + _gust, 0.0, 1.0)


## The transient gust component alone (0 when no squall is rolling in). Exposed so
## callers can react to the shove of wind that precedes rain, not just steady wind.
func wind_gust() -> float:
	return _gust


## Cumulonimbus development, 0 (fair weather) to 1 (towering anvil). Mirrors the
## `storm_intensity` uniform the sky shader uses for the squall wall and crowns.
func storm_intensity() -> float:
	return float(_current["storm"])


## How concentrated the storm is: 0 spreads it across the whole deck (a rain
## front), 1 isolates it into a few heavy cells in otherwise open sky.
func storm_locality() -> float:
	return float(_current.get("locality", 0.0))


## Current lightning flash level (0..1). Exposed so scene lighting and audio can
## react to the same strike the sky shader draws.
func lightning_flash() -> float:
	return _effective_lightning()


func _effective_lightning() -> float:
	return _lightning * _lightning_flash_scale() * _lightning_proximity()


## Scene light lift falls off with camera distance to the charge centre. Without a
## camera (headless simulation) the strike counts as overhead.
func _lightning_proximity() -> float:
	if _camera == null or not is_instance_valid(_camera) or not _camera.is_inside_tree():
		return 1.0
	var view := _view_position()
	var offset := CloudCellsScript.wrap_delta(
		Vector2(_lightning_origin.x, _lightning_origin.z), Vector2(view.x, view.z),
		CloudCellsScript.KIND_STORM
	)
	var distance := Vector3(offset.x, _lightning_origin.y - view.y, offset.y).length()
	return lerpf(
		1.0, LIGHTNING_FAR_SCALE,
		smoothstep(LIGHTNING_NEAR_DISTANCE, LIGHTNING_FAR_DISTANCE, distance)
	)


## Charge centre of the current strike in world units (wrapped into the cell domain).
func lightning_origin() -> Vector3:
	return _lightning_origin


## Ground point of the current cloud-to-ground stroke (unused for in-cloud flashes).
func lightning_ground() -> Vector3:
	return _lightning_ground


## LIGHTNING_KIND_CLOUD or LIGHTNING_KIND_GROUND.
func lightning_kind() -> int:
	return _lightning_kind


## Ground bearing (unit vec2, x = east, y = north) of the cell currently flashing.
func lightning_direction() -> Vector2:
	return _lightning_dir


func _lightning_flash_scale() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or not tree.root.has_node("/root/UserSettings"):
		return 1.0
	var settings: Node = tree.root.get_node("/root/UserSettings")
	if not ("gameplay" in settings):
		return 1.0
	var gameplay: Variant = settings.get("gameplay")
	if gameplay == null or not gameplay.has_method("lightning_flash_scale"):
		return 1.0
	return float(gameplay.lightning_flash_scale())


## Prevailing wind. Deterministic from weather, day clock, and the live gust
## envelope so save/load and map handoff reconstruct the same heading. Consumers
## keep calling this accessor; they do not need the clock.
func wind_direction_xz() -> Vector2:
	if _wind_smoothing_valid:
		return Vector2.from_angle(_wind_heading_rad)
	return _target_wind_direction()


func _target_wind_direction() -> Vector2:
	return wind_direction_at(
		weather, _cycle_progress, _gust, _transition_from_weather, _blend
	)


## Jumps the visual wind to its target. Tests that assert the settled heading use
## it; restore_state() does the same implicitly.
func settle_wind() -> void:
	_wind_smoothing_valid = false


func _advance_wind_smoothing(delta: float) -> void:
	var target := _target_wind_direction().angle()
	var target_strength := wind_strength()
	if not _wind_smoothing_valid:
		_wind_heading_rad = target
		_wind_drift_strength = target_strength
		_wind_smoothing_valid = true
		return
	var step := WIND_HEADING_MAX_RATE * delta
	_wind_heading_rad += clampf(angle_difference(_wind_heading_rad, target), -step, step)
	_wind_drift_strength = lerpf(
		_wind_drift_strength, target_strength,
		1.0 - exp(-delta / WIND_DRIFT_SMOOTH_SECONDS)
	)


## Scene-tree-free heading used by tests and by wind_direction_xz().
static func wind_direction_at(
	weather_id: StringName,
	cycle_progress: float,
	gust: float = 0.0,
	from_weather: StringName = &"",
	blend: float = 1.0
) -> Vector2:
	var to_id := weather_id if WIND_HEADING_OFFSET_DEG.has(weather_id) else WEATHER_CLEAR
	var from_id := from_weather if WIND_HEADING_OFFSET_DEG.has(from_weather) else to_id
	var blend_t := smoothstep(0.0, 1.0, clampf(blend, 0.0, 1.0))
	var heading := lerp_angle(
		_weather_heading_rad(from_id), _weather_heading_rad(to_id), blend_t
	)
	var progress := wrapf(cycle_progress, 0.0, 1.0)
	# Zero at noon so the default clock and unset presenters keep the weather bearing.
	heading += deg_to_rad(WIND_DAY_VEER_DEG) * sin(TAU * (progress - 0.25))
	heading += deg_to_rad(WIND_GUST_VEER_DEG) * clampf(gust / GUST_PEAK, 0.0, 1.0)
	return Vector2.from_angle(heading)


static func _weather_heading_rad(weather_id: StringName) -> float:
	var offset := float(WIND_HEADING_OFFSET_DEG.get(weather_id, 0.0))
	return CLOUD_DRIFT_PER_SECOND.angle() + deg_to_rad(offset)


## Returns the exact catalog texture bound to the sky shader. Water reuses this
## resource so reflected constellations cannot drift from their visible source.
func star_map_texture() -> Texture2D:
	return _star_map


## Sky and water retain this compatibility entry point while SkyAstronomy owns
## the sidereal rate used by both render paths.
static func sidereal_angle_for_progress(progress: float, date: Dictionary = {}) -> float:
	return SkyAstronomy.sidereal_angle_for_progress(progress, date)


## Clouds must gather before rain, so wet regimes are only ever reached through
## cloudy or overcast -- never straight off a clear sky. Every state can
## eventually reach clear, giving the sky a chance to break open after any
## weather. The probabilities are tuned to Estonian spring averages: sunny
## spells are common, rain and storms are punctuations rather than the norm.
func _pick_next_weather() -> void:
	if drought_active():
		_pick_drought_weather()
		return
	match weather:
		WEATHER_CLOUDLESS:
			# A blue sky either holds or fair-weather cumulus start to bubble up.
			if _rng.randf() < CLOUDLESS_TO_STAY_CHANCE:
				set_weather(WEATHER_CLOUDLESS)
			else:
				set_weather(WEATHER_CLEAR)
		WEATHER_CLEAR:
			# Sunny spells can hold -- real spring days in Reval often stay fair.
			var roll := _rng.randf()
			if roll < CLEAR_TO_CLOUDLESS_CHANCE:
				set_weather(WEATHER_CLOUDLESS)
			elif roll < CLEAR_TO_STAY_CHANCE:
				set_weather(WEATHER_CLEAR)
			else:
				set_weather(WEATHER_CLOUDY)
		WEATHER_CLOUDY:
			# The hub state: clouds can break, thicken, or produce rain/storms.
			var roll := _rng.randf()
			if roll < CLOUDY_TO_CLEAR_CHANCE:
				set_weather(WEATHER_CLEAR)
			elif roll < CLOUDY_TO_OVERCAST_CHANCE:
				set_weather(WEATHER_OVERCAST)
			elif roll < CLOUDY_TO_RAIN_CHANCE:
				set_weather(WEATHER_RAIN)
			elif roll < CLOUDY_TO_STORM_CHANCE:
				set_weather(WEATHER_STORM)
			else:
				set_weather(WEATHER_CLOUDY)
		WEATHER_OVERCAST:
			# Grey skies can break open, thin to clouds, or start raining.
			var roll := _rng.randf()
			if roll < OVERCAST_TO_CLEAR_CHANCE:
				set_weather(WEATHER_CLEAR)
			elif roll < OVERCAST_TO_CLOUDY_CHANCE:
				set_weather(WEATHER_CLOUDY)
			else:
				set_weather(WEATHER_RAIN)
		WEATHER_RAIN:
			# Showers pass: the sky clears or eases to cloud cover.
			var roll := _rng.randf()
			if roll < RAIN_TO_CLOUDLESS_CHANCE:
				set_weather(WEATHER_CLOUDLESS)
			elif roll < RAIN_TO_CLEAR_CHANCE:
				set_weather(WEATHER_CLEAR)
			elif roll < RAIN_TO_CLOUDY_CHANCE:
				set_weather(WEATHER_CLOUDY)
			else:
				set_weather(WEATHER_OVERCAST)
		WEATHER_STORM:
			# Storms clear faster than steady rain -- convective cells move on.
			var roll := _rng.randf()
			if roll < STORM_TO_CLOUDLESS_CHANCE:
				set_weather(WEATHER_CLOUDLESS)
			elif roll < STORM_TO_CLEAR_CHANCE:
				set_weather(WEATHER_CLEAR)
			elif roll < STORM_TO_CLOUDY_CHANCE:
				set_weather(WEATHER_CLOUDY)
			else:
				set_weather(WEATHER_OVERCAST)


## Sun on dry ground raises dryness up to the fair-weather cap, or past it in a
## drought. Nothing lowers it except rain: cracks outlast the drought that made them.
func _bake_dryness(dryness: float, delta: float) -> float:
	var sun := smoothstep(0.0, 0.35, _sun_direction.y) * (1.0 - 0.85 * cloud_coverage())
	var gain := DRYNESS_GAIN_PER_SECOND * sun
	var cap := DRYNESS_FAIR_CAP
	if drought_active():
		gain *= DRYNESS_DROUGHT_GAIN
		cap = 1.0
	if dryness >= cap:
		return dryness
	return minf(dryness + gain * delta, cap)


func _roll_duration(for_weather: StringName) -> float:
	var span: Vector2 = DURATIONS[for_weather]
	return _rng.randf_range(span.x, span.y)


## R-1516: a drought keeps the sky dry. One roll per pick like the normal chain;
## no outcome leads towards overcast, rain or storm.
func _pick_drought_weather() -> void:
	var roll := _rng.randf()
	match weather:
		WEATHER_CLEAR:
			set_weather(
				WEATHER_CLOUDLESS if roll < DROUGHT_CLEAR_TO_CLOUDLESS_CHANCE else WEATHER_CLOUDY
			)
		WEATHER_CLOUDLESS:
			set_weather(WEATHER_CLEAR)
		_:
			set_weather(WEATHER_CLEAR)


## Envelopes the gust front: a quick rise to the peak, then an exponential decay
## back to calm. Deterministic in delta, so the seeded weather run stays reviewable.
func _advance_gust(delta: float) -> void:
	if _gust_time < 0.0:
		_gust = 0.0
		return
	_gust_time += delta
	if _gust_time < GUST_RISE_SECONDS:
		_gust = GUST_PEAK * (_gust_time / GUST_RISE_SECONDS)
	else:
		_gust = GUST_PEAK * exp(-(_gust_time - GUST_RISE_SECONDS) / GUST_DECAY_SECONDS)
	if _gust < 0.005:
		_gust = 0.0
		_gust_time = -1.0


## Runs the lightning: decays any flash in progress, then, while the current
## state has thunder, counts down (faster the stronger the thunder) to the next
## strike and fires one at a fresh bearing. When thunder drops to zero the
## strike timer resets and any in-flight flash is killed so lightning never
## appears during fair weather.
func _advance_lightning(delta: float) -> void:
	# A merged cumulus tower (R-1481) brings its own thunder into fair weather.
	var thunder := maxf(
		float(_current.get("thunder", 0.0)),
		TOWER_THUNDER * smoothstep(CloudCellsScript.TOWER_MATURE, 1.0, _cells.max_tower())
	)
	# Fair weather: suppress lightning immediately and reset the countdown so
	# strikes do not queue up and fire the instant weather turns stormy.
	if thunder <= 0.01:
		_lightning = 0.0
		_lightning_time = -1.0
		_time_to_strike = _lightning_rng.randf_range(
			LIGHTNING_GAP_SECONDS.x, LIGHTNING_GAP_SECONDS.y
		)
		return
	if _lightning_time >= 0.0:
		_lightning_time += delta
		_lightning = _lightning_envelope(_lightning_time)
		if _lightning_time >= LIGHTNING_FLASH_SECONDS:
			_lightning = 0.0
			_lightning_time = -1.0
	else:
		_lightning = 0.0
	_time_to_strike -= delta * thunder
	if _time_to_strike <= 0.0 and _lightning_time < 0.0:
		var charged: Array[int] = _cells.mature_storm_cells()
		if charged.is_empty():
			# No thunderhead is grown yet: hold the charge instead of striking blue sky.
			_time_to_strike = LIGHTNING_RETRY_SECONDS
			return
		_place_strike(charged[_lightning_rng.randi() % charged.size()])
		_lightning_time = 0.0
		_lightning = _lightning_envelope(0.0)
		_time_to_strike = _lightning_rng.randf_range(
			LIGHTNING_GAP_SECONDS.x, LIGHTNING_GAP_SECONDS.y
		)


## Puts the strike inside storm cell `slot`: a charge centre in the cell's lower
## half, and for a ground stroke a point under the cell's rain core. The bearing
## from the camera keeps the dome's directional flash on that cell.
func _place_strike(slot: int) -> void:
	var center: Vector3 = _cells.centers[slot]
	var view_at := _view_position()
	var radius: float = _cells.radii[slot]
	var height: float = _cells.heights[slot]
	if CloudCellsScript.kind_of(slot) == CloudCellsScript.KIND_CUMULUS:
		# R-1501: a merged cluster storms only in its hotspot copy; strike from the
		# one nearest the camera, which is then also the nearest copy on the storm
		# tile the strike origin is wrapped on.
		var shape := _cells.copy_shape(
			slot, _cells.tower_copy_centre(slot, Vector2(view_at.x, view_at.z))
		)
		center = Vector3(shape[0], shape[1], shape[2])
		radius = shape[3]
		height = shape[4]
	var angle := _lightning_rng.randf() * TAU
	var reach := sqrt(_lightning_rng.randf()) * radius * 0.45
	_lightning_kind = (
		LIGHTNING_KIND_GROUND if _lightning_rng.randf() < LIGHTNING_GROUND_CHANCE
		else LIGHTNING_KIND_CLOUD
	)
	var lift := height * _lightning_rng.randf_range(0.15, 0.55)
	if _lightning_kind == LIGHTNING_KIND_GROUND:
		lift = height * 0.08
	_lightning_origin = Vector3(
		center.x + cos(angle) * reach, center.y + lift, center.z + sin(angle) * reach
	)
	var ground_angle := _lightning_rng.randf() * TAU
	var ground_reach := sqrt(_lightning_rng.randf()) * radius * 0.6
	_lightning_ground = Vector3(
		center.x + cos(ground_angle) * ground_reach, 0.0, center.z + sin(ground_angle) * ground_reach
	)
	var view := _view_position()
	var bearing := CloudCellsScript.wrap_delta(
		Vector2(_lightning_origin.x, _lightning_origin.z), Vector2(view.x, view.z),
		CloudCellsScript.KIND_STORM
	)
	# Ground bearing convention: x = east, y = north (world -Z).
	_lightning_dir = Vector2(bearing.x, -bearing.y).normalized()
	if _lightning_dir.length_squared() < 0.5:
		_lightning_dir = Vector2.RIGHT


## Flash shape: a sharp leader stroke plus a fast return-stroke flicker, both
## decaying within a few tenths of a second so lightning reads as a flicker.
func _lightning_envelope(t: float) -> float:
	var leader := exp(-t / 0.09)
	var flicker := 0.0
	if t > 0.11:
		flicker = 0.75 * exp(-(t - 0.11) / 0.06)
	return clampf(maxf(leader, flicker), 0.0, 1.0)


## Whether the falling-rain particle emitter should draw this frame: only when
## it is actually raining where the camera stands (see local_rain_factor()) and
## the player is not under an enclosed roof. Exposed so headless tests can assert
## indoor suppression without building a renderer.
func rain_emitter_visible() -> bool:
	return not rain_suppressed and local_rain_intensity() > 0.02


func roof_audio_active() -> bool:
	return _roof_audio != null and _roof_audio.roof_audio_active()


func roof_audio_linear_volume() -> float:
	if _roof_audio == null:
		return 0.0
	return _roof_audio.roof_audio_linear_volume()


func set_roof_audio_enabled(enabled: bool) -> void:
	if _roof_audio != null:
		_roof_audio.set_audio_enabled(enabled)


func _update_rain(delta: float = 0.0) -> void:
	# Headless tests drive advance() without configure(); no emitter exists then.
	if _rain == null:
		return
	var local_rain := local_rain_intensity()
	_rain.visible = rain_emitter_visible()
	if _rain.visible:
		_rain.amount_ratio = clampf(local_rain, 0.05, 1.0)
	var process := _rain.process_material as ParticleProcessMaterial
	if process != null:
		# R-1501: drops drift with the wind at the physical angle; no gravity, they
		# already fall at terminal speed.
		var velocity := Vector3(0.0, -RAIN_STREAK_SPEED, 0.0)
		var slant := rain_slant()
		velocity += Vector3(slant.x, 0.0, slant.y) * RAIN_STREAK_SPEED
		process.direction = velocity.normalized()
		process.initial_velocity_min = velocity.length() * 0.9
		process.initial_velocity_max = velocity.length() * 1.1
	if _camera != null:
		# Emit upwind so the slanted rain still lands around the camera.
		var drift := rain_slant() * RAIN_EMITTER_HEIGHT
		_rain.global_position = (
			_camera.global_position + Vector3(-drift.x, RAIN_EMITTER_HEIGHT, -drift.y)
		)
	if _roof_audio != null:
		# A roof only drums when the storm cell is over the building.
		_roof_audio.sync(rain_suppressed, local_rain, delta)


func _push_cloud_uniforms() -> void:
	if _material == null:
		return
	_material.set_shader_parameter(&"rainbow_strength", rainbow_strength())
	_material.set_shader_parameter(&"rainbow_curtain", rainbow_curtain())
	_material.set_shader_parameter(&"camera_direction", _camera_forward())
	_material.set_shader_parameter(&"cloud_coverage", cloud_coverage())
	_material.set_shader_parameter(&"cloud_darken", float(_current["darken"]))
	_material.set_shader_parameter(&"cloud_offset", _cloud_offset)
	_material.set_shader_parameter(&"cloud_detail_offset", _cloud_detail_offset)
	_material.set_shader_parameter(&"cloud_chaos", cloud_chaos())
	var settings := _quality_settings()
	_material.set_shader_parameter(&"cloud_shadow_samples", int(settings["cloud_shadow_samples"]))
	_material.set_shader_parameter(&"rain_shaft_samples", int(settings["rain_shaft_samples"]))
	_material.set_shader_parameter(&"lightning_density", float(settings["lightning_density"]))
	_material.set_shader_parameter(&"cloud_fallback", not _cloud_resources_available)
	_material.set_shader_parameter(&"storm_intensity", storm_intensity())
	_material.set_shader_parameter(&"storm_locality", storm_locality())
	# The dome draws the strike at full brightness wherever it is; only the scene
	# light lift (lighting_modifiers) falls off with distance to the cell.
	_material.set_shader_parameter(&"lightning", _lightning * _lightning_flash_scale())
	_material.set_shader_parameter(&"lightning_dir", _lightning_dir)
	_material.set_shader_parameter(&"lightning_origin", _lightning_origin)
	_material.set_shader_parameter(&"lightning_ground", _lightning_ground)
	_material.set_shader_parameter(&"lightning_kind", float(_lightning_kind))
	_material.set_shader_parameter(&"cloud_cells", _cells.uniforms())
	_material.set_shader_parameter(&"rain_slant", rain_slant() * RAIN_SHAFT_SLANT)
	_material.set_shader_parameter(&"cloud_gloom", smoothstep(0.55, 0.95, cloud_coverage()))
	_material.set_shader_parameter(&"cell_steps", int(settings["cloud_cell_steps"]))
	_material.set_shader_parameter(&"cell_fine_steps", int(settings["cloud_cell_fine_steps"]))
	_material.set_shader_parameter(
		&"cell_light_samples", int(settings["cloud_cell_light_samples"])
	)
	_material.set_shader_parameter(&"cell_ray_samples", int(settings["cloud_cell_ray_samples"]))
	_material.set_shader_parameter(&"wind_dir", wind_direction_xz())
	_publish_cloud_shadow_globals()


func cloud_shadow_enabled() -> bool:
	return bool(_quality_settings()["cloud_shadow_enabled"])


func cloud_shadow_ground_samples() -> int:
	return int(_quality_settings()["cloud_shadow_ground_samples"])


func _publish_cloud_shadow_globals() -> void:
	if _cloud_noise_tex != null:
		RenderingServer.global_shader_parameter_set(&"cloud_noise_tex", _cloud_noise_tex)
	if _cloud_shape_tex != null:
		RenderingServer.global_shader_parameter_set(&"cloud_shape_tex", _cloud_shape_tex)
	RenderingServer.global_shader_parameter_set(&"cloud_offset_g", _cloud_offset)
	RenderingServer.global_shader_parameter_set(&"cloud_detail_offset_g", _cloud_detail_offset)
	# Fold the storm lift into coverage so the ground pass stays in its sample budget.
	# R-1400: only the widespread share; an isolated storm shades through its cells.
	var cover := clampf(
		cloud_coverage() + storm_intensity() * (1.0 - storm_locality()) * 0.38, 0.0, 1.0
	)
	RenderingServer.global_shader_parameter_set(&"cloud_coverage_g", cover)
	RenderingServer.global_shader_parameter_set(&"cloud_chaos_g", cloud_chaos())
	RenderingServer.global_shader_parameter_set(&"storm_intensity_g", storm_intensity())
	RenderingServer.global_shader_parameter_set(&"storm_locality_g", storm_locality())
	RenderingServer.global_shader_parameter_set(&"cloud_sun_dir", _sun_direction)
	RenderingServer.global_shader_parameter_set(&"cloud_shadow_strength", CLOUD_SHADOW_STRENGTH)

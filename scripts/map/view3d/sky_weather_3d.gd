class_name SkyWeather3D
extends Node3D

## Sky dome, sun/moon placement, real stars for medieval Reval, and a
## deterministic weather cycle for the MapView3D view layer. Owns the
## Environment sky (gradient + procedural clouds via sky_weather_3d.gdshader),
## blends clear/cloudy/rain profiles, and reports lighting multipliers back to
## MapView3D so sun and ambient follow the sky. Weather randomness comes from a
## fixed seed: the sequence repeats identically every run, keeping the
## deterministic-state rule intact.

const SKY_SHADER := preload("res://scripts/map/view3d/sky_weather_3d.gdshader")
const SKY_RESOURCES := preload("res://scripts/map/view3d/sky_weather_resources.gd")
const SkyWeatherRoofAudioScript := preload("res://scripts/map/view3d/sky_weather_roof_audio.gd")
const SkyWeatherStateScript := preload("res://scripts/map/view3d/sky_weather_state.gd")
const STAR_CATALOG := preload("res://scripts/map/view3d/estonia_star_catalog.gd")
const GAME_CALENDAR := preload("res://scripts/global/game_calendar.gd")

const WEATHER_CLEAR := &"clear"
const WEATHER_CLOUDY := &"cloudy"
## Full grey cover with no blue showing through — the "you can't see the sky" case.
const WEATHER_OVERCAST := &"overcast"
## Widespread overcast rain: the whole deck rains, with thunder.
const WEATHER_RAIN := &"rain"
## Isolated convection: mostly blue sky with one or a few heavy cells that tower,
## rain in distant walls, and throw lightning — the "specific raining cloud" case.
const WEATHER_STORM := &"storm"
const ALL_WEATHERS: Array[StringName] = [
	WEATHER_CLEAR, WEATHER_CLOUDY, WEATHER_OVERCAST, WEATHER_RAIN, WEATHER_STORM
]

## Fixed seed: same weather sequence on every launch (deterministic, reviewable).
const WEATHER_SEED := 24217
const TRANSITION_SECONDS := 5.0
## Bank masses cross the dome at this rate; detail churns faster for edge chaos.
const CLOUD_DRIFT_PER_SECOND := Vector2(0.0045, 0.0018)
const CLOUD_DETAIL_DRIFT_PER_SECOND := Vector2(0.0078, -0.0031)

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
	},
	QUALITY_RECOMMENDED: {
		"cloud_noise_resolution": SKY_RESOURCES.CLOUD_NOISE_RESOLUTION_RECOMMENDED,
		"cloud_shape_resolution": SKY_RESOURCES.CLOUD_SHAPE_RESOLUTION_RECOMMENDED,
		"cloud_shadow_samples": 4,
		"rain_shaft_samples": 6,
		"rain_particles": SKY_RESOURCES.RAIN_PARTICLES_RECOMMENDED,
		"lightning_density": 1.0,
		"fog_quality": 1.0,
		"fallback_behavior": &"gradient_only_if_resource_missing",
		"frame_time_budget_ms": 2.50,
		"memory_budget_mib": 24.0,
		"particle_budget": 2200,
		"shader_sample_budget": 140,
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
		"sun_energy": 0.44,
		"ambient_energy": 0.80,
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
		"sun_energy": 0.32,
		"ambient_energy": 0.70,
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
	WEATHER_CLEAR: Vector2(28.0, 55.0),
	WEATHER_CLOUDY: Vector2(18.0, 35.0),
	WEATHER_OVERCAST: Vector2(20.0, 35.0),
	WEATHER_RAIN: Vector2(15.0, 30.0),
	WEATHER_STORM: Vector2(12.0, 25.0),
}
## Cumulative odds for what a cloudy spell becomes next. Normalized to match
## real Estonian spring weather: fair spells persist, rain comes from clouds
## gathering, and storms are rare.
const CLOUDY_TO_CLEAR_CHANCE := 0.30
const CLOUDY_TO_OVERCAST_CHANCE := 0.55
const CLOUDY_TO_RAIN_CHANCE := 0.72
const CLOUDY_TO_STORM_CHANCE := 0.80
## Clear skies can hold or cloud over, but never jump to rain — clouds must
## gather first (tested in test_rain_never_starts_from_a_clear_sky).
const CLEAR_TO_STAY_CHANCE := 0.40
## Overcast often clears or thins; rain is the minority outcome.
const OVERCAST_TO_CLEAR_CHANCE := 0.20
const OVERCAST_TO_CLOUDY_CHANCE := 0.55
## Rain eases to clear or cloudy; lingering overcast is less common.
const RAIN_TO_CLEAR_CHANCE := 0.25
const RAIN_TO_CLOUDY_CHANCE := 0.75
## Storms pass and skies clear faster than lingering rain.
const STORM_TO_CLEAR_CHANCE := 0.20
const STORM_TO_CLOUDY_CHANCE := 0.70

## Gust front: a real squall is preceded by a shove of wind ahead of the rain.
## When the machine commits to rain we fire a transient gust that spikes the wind
## (and, through it, cloud drift, sails, and sea state) then decays back to the
## sustained storm wind. Added on top of the profile wind and clamped to 1.
const GUST_PEAK := 0.4
const GUST_RISE_SECONDS := 1.0
const GUST_DECAY_SECONDS := 5.0

## Lightning. A storm's `thunder` factor scales the strike rate between these mean
## gaps (seconds); each strike picks a bearing (a cell to light up) and fires a
## short, flickering flash envelope that brightens that cell, glows the sky, and
## briefly lifts scene lighting. Deterministic off the weather RNG.
const LIGHTNING_GAP_SECONDS := Vector2(2.5, 9.0)
const LIGHTNING_FLASH_SECONDS := 0.42

const RAIN_EMITTER_HEIGHT := 11.0

## Worked-ground puddles start dry, fill while rain reaches the ground, and then
## evaporate gradually. Intensity is accumulated in simulated weather seconds so
## pausing or accelerating the weather clock affects puddles consistently.
const PUDDLE_RAIN_FILL_PER_SECOND := 0.08
const PUDDLE_DRY_PER_SECOND := 0.004
const LAST_RAIN_NEVER := INF

## Cloud drift scales with wind so a gust visibly accelerates the sky and storms
## race while clear days barely stir. Base drift is the light fair-weather rate.
const WIND_DRIFT_FLOOR := 0.5
const WIND_DRIFT_GAIN := 1.6


## Keeping these values together prevents lighting, fog, wet ground, wind, and
## water from observing different sides of a weather transition in the same
## rendered frame.
class WeatherPresentation extends RefCounted:
	var weather: StringName = WEATHER_CLEAR
	var day_blend := 1.0
	var sun_direction := Vector3.UP
	var moon_direction := Vector3.UP
	var wind_direction := Vector2.RIGHT
	var wind_strength := 0.0
	var rain_intensity := 0.0
	var puddle_wetness := 0.0
	var cloud_coverage := 0.0
	var overcast := 0.0
	var lightning := 0.0
	var fog_quality := 1.0
	var sunset_factor := 0.0
	var sunset_tint := 0.0
	var sun_energy := 1.0
	var ambient_energy := 1.0
	var sun_visibility := 0.0
	var moon_visibility := 0.0
	var star_visibility := 0.0
	var tide_level := 0.0
	var sidereal_angle := 0.0
	var star_map: Texture2D
	var sun_reflection_color := Color.WHITE
	var rain_suppressed := false


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
## Starts dry so a fresh map cannot display puddles before rain has fallen.
var _puddle_wetness := 0.0
## Elapsed simulated seconds since rain last reached the ground. INF means this
## weather controller has never observed rain, useful to mud and save/debug UI.
var _seconds_since_rain := LAST_RAIN_NEVER
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
var _material: ShaderMaterial
var _star_map: ImageTexture
var _camera: Camera3D
var _environment: Environment
var _rain: GPUParticles3D
var _roof_audio: SkyWeatherRoofAudio
var _cloud_resources_available := false


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


func _apply_quality_resources() -> void:
	var settings := _quality_settings()
	var cloud_noise := SKY_RESOURCES.build_cloud_noise(
		WEATHER_SEED, int(settings["cloud_noise_resolution"])
	)
	var cloud_shape := SKY_RESOURCES.build_cloud_shape(
		WEATHER_SEED, int(settings["cloud_shape_resolution"])
	)
	_cloud_resources_available = cloud_noise != null and cloud_shape != null
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
	if _rain != null:
		_rain.amount = int(settings["rain_particles"])


func _init() -> void:
	_rng.seed = WEATHER_SEED
	_lightning_rng.seed = WEATHER_SEED + 101
	_time_to_strike = _lightning_rng.randf_range(LIGHTNING_GAP_SECONDS.x, LIGHTNING_GAP_SECONDS.y)
	_state_duration = _roll_duration(weather)


## Captures only simulation data so a presenter can hand the weather field to the
## next map without serializing renderer nodes or rebuilding the deterministic RNG.
## The owning runtime supplies cycle_progress/elapsed_days because those values
## belong to the shared day clock rather than this scene node.
func snapshot_state(
	cycle_progress: float = 0.25, elapsed_days: int = 0
) -> RefCounted:
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
	state.puddle_wetness = _json_safe_float(_puddle_wetness)
	state.seconds_since_rain = _seconds_since_rain
	if not is_finite(_seconds_since_rain):
		state.seconds_since_rain = SkyWeatherStateScript.LAST_RAIN_NEVER
	state.gust = _json_safe_float(_gust)
	state.gust_time = _json_safe_float(_gust_time)
	state.lightning = _json_safe_float(_lightning)
	state.lightning_direction = _lightning_dir
	state.lightning_time = _json_safe_float(_lightning_time)
	state.time_to_strike = _json_safe_float(_time_to_strike)
	state.weather_rng_state = _rng.state
	state.lightning_rng_state = _lightning_rng.state
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
	_puddle_wetness = restored.puddle_wetness
	_seconds_since_rain = restored.seconds_since_rain
	if restored.seconds_since_rain < 0.0:
		_seconds_since_rain = LAST_RAIN_NEVER
	_gust = restored.gust
	_gust_time = restored.gust_time
	_lightning = restored.lightning
	_lightning_dir = restored.lightning_direction
	_lightning_time = restored.lightning_time
	_time_to_strike = restored.time_to_strike
	if restored.weather_rng_state != -1:
		_rng.state = restored.weather_rng_state
	if restored.lightning_rng_state != -1:
		_lightning_rng.state = restored.lightning_rng_state
	_current = _profile_from_state(restored.current_profile, weather)
	_from = _profile_from_state(restored.transition_from_profile, _transition_from_weather)
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




## Replaces the environment's flat background with the sky dome and builds the
## rain emitter that shadows the gameplay camera.
func configure(camera: Camera3D, environment: Environment) -> void:
	_camera = camera
	_material = ShaderMaterial.new()
	_material.shader = SKY_SHADER
	_apply_quality_resources()
	_material.set_shader_parameter(
		&"lunar_albedo_map", SKY_RESOURCES.build_lunar_albedo_map(WEATHER_SEED)
	)
	_star_map = SKY_RESOURCES.build_star_map(
		STAR_CATALOG.STARS,
		STAR_CATALOG.CATALOG_EPOCH,
		SKY_EPOCH_YEAR,
		STAR_CATALOG.LIMITING_MAGNITUDE
	)
	_material.set_shader_parameter(&"star_map", _star_map)
	_material.set_shader_parameter(&"observer_latitude", deg_to_rad(OBSERVER_LATITUDE_DEGREES))
	var sky := Sky.new()
	sky.sky_material = _material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY

	_rain = SKY_RESOURCES.build_rain(int(_quality_settings()["rain_particles"]))
	add_child(_rain)
	_roof_audio = SkyWeatherRoofAudioScript.new()
	_roof_audio.name = "RoofRainAudio"
	add_child(_roof_audio)
	_push_cloud_uniforms()


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
	_advance_lightning(delta)
	# Wind carries the clouds: gusts race the sky, calm clear days barely stir.
	# Bank and detail drift share the multiplier so detail keeps outpacing banks.
	var wind_scale := WIND_DRIFT_FLOOR + wind_strength() * WIND_DRIFT_GAIN
	_cloud_offset += CLOUD_DRIFT_PER_SECOND * wind_scale * delta
	_cloud_detail_offset += CLOUD_DETAIL_DRIFT_PER_SECOND * wind_scale * delta
	if _blend < 1.0:
		_blend = minf(1.0, _blend + delta / TRANSITION_SECONDS)
		for key in _current:
			_current[key] = lerpf(
				float(_from[key]), float((PROFILES[weather] as Dictionary)[key]), _blend
			)
	elif auto_weather:
		_time_in_state += delta
		if _time_in_state >= _state_duration:
			_pick_next_weather()
	_advance_puddle_wetness(delta)
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
func apply_sky_state(progress: float, day_blend: float, sun_direction: Vector3) -> void:
	var elevation := rad_to_deg(asin(clampf(sun_direction.y, -1.0, 1.0)))
	sunset_factor = clampf(1.0 - absf(elevation) / SUNSET_ELEVATION_BAND_DEG, 0.0, 1.0)
	var phase := lunar_phase(calendar_date)
	var moon_direction := lunar_direction(progress, calendar_date)
	_material.set_shader_parameter(&"sun_direction", sun_direction)
	_material.set_shader_parameter(&"moon_direction", moon_direction)
	_material.set_shader_parameter(&"moon_phase", phase)
	_material.set_shader_parameter(&"day_blend", day_blend)
	_material.set_shader_parameter(&"sunset_factor", sunset_factor)
	_material.set_shader_parameter(&"sidereal_angle", sidereal_angle_for_progress(progress))


## Builds one immutable-in-practice presentation handoff from the current weather
## profile and cycle inputs. Callers should retain this value for the frame rather
## than reading individual weather accessors between lighting and material passes.
func presentation_snapshot(progress: float, day_blend: float) -> WeatherPresentation:
	var snapshot := WeatherPresentation.new()
	snapshot.weather = weather
	snapshot.day_blend = clampf(day_blend, 0.0, 1.0)
	snapshot.sun_direction = solar_direction(progress, calendar_date)
	snapshot.moon_direction = lunar_direction(progress, calendar_date)
	snapshot.wind_direction = wind_direction_xz()
	snapshot.wind_strength = wind_strength()
	snapshot.rain_intensity = rain_intensity()
	snapshot.puddle_wetness = puddle_wetness()
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
	var cloud_occlusion := 1.0 - snapshot.cloud_coverage
	snapshot.moon_visibility = moonlight_strength(progress, calendar_date) * cloud_occlusion
	snapshot.star_visibility = pow(1.0 - snapshot.day_blend, 3.0) * cloud_occlusion
	snapshot.tide_level = tide_level(progress, calendar_date)
	snapshot.sidereal_angle = sidereal_angle_for_progress(progress)
	snapshot.star_map = star_map_texture()
	snapshot.sun_reflection_color = Color(255, 243, 222).lerp(
		Color(255, 148, 64), snapshot.sunset_tint
	)
	snapshot.rain_suppressed = rain_suppressed
	return snapshot


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


func rain_intensity() -> float:
	return float(_current["rain"])


## Persistent surface water created only by rain that has already reached the
## ground. A storm can leave puddles behind after the rain particles stop.
func puddle_wetness() -> float:
	return _puddle_wetness


## Mud uses the same retained ground water as puddles, so viscosity changes from
## both current rainfall and elapsed drying rather than a disconnected timer.
func mud_wetness() -> float:
	return _puddle_wetness


func seconds_since_rain() -> float:
	return _seconds_since_rain


func _advance_puddle_wetness(delta: float) -> void:
	var rain_fill := rain_intensity() * PUDDLE_RAIN_FILL_PER_SECOND
	var drying := PUDDLE_DRY_PER_SECOND if rain_fill <= 0.0 else 0.0
	_puddle_wetness = clampf(_puddle_wetness + (rain_fill - drying) * delta, 0.0, 1.0)
	if rain_intensity() > 0.001:
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
	return _lightning * _lightning_flash_scale()


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


## Prevailing wind follows the authored cloud drift so smoke, sails, and floating
## hulls lean the same way as the sky weather field.
func wind_direction_xz() -> Vector2:
	return CLOUD_DRIFT_PER_SECOND.normalized()


## Returns the exact catalog texture bound to the sky shader. Water reuses this
## resource so reflected constellations cannot drift from their visible source.
func star_map_texture() -> Texture2D:
	return _star_map


## Sky and water retain this compatibility entry point while SkyAstronomy owns
## the sidereal rate used by both render paths.
static func sidereal_angle_for_progress(progress: float) -> float:
	return SkyAstronomy.sidereal_angle_for_progress(progress)


## Clouds must gather before rain, so wet regimes are only ever reached through
## cloudy or overcast -- never straight off a clear sky. Every state can
## eventually reach clear, giving the sky a chance to break open after any
## weather. The probabilities are tuned to Estonian spring averages: sunny
## spells are common, rain and storms are punctuations rather than the norm.
func _pick_next_weather() -> void:
	match weather:
		WEATHER_CLEAR:
			# Sunny spells can hold -- real spring days in Reval often stay fair.
			if _rng.randf() < CLEAR_TO_STAY_CHANCE:
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
			if roll < RAIN_TO_CLEAR_CHANCE:
				set_weather(WEATHER_CLEAR)
			elif roll < RAIN_TO_CLOUDY_CHANCE:
				set_weather(WEATHER_CLOUDY)
			else:
				set_weather(WEATHER_OVERCAST)
		WEATHER_STORM:
			# Storms clear faster than steady rain -- convective cells move on.
			var roll := _rng.randf()
			if roll < STORM_TO_CLEAR_CHANCE:
				set_weather(WEATHER_CLEAR)
			elif roll < STORM_TO_CLOUDY_CHANCE:
				set_weather(WEATHER_CLOUDY)
			else:
				set_weather(WEATHER_OVERCAST)


func _roll_duration(for_weather: StringName) -> float:
	var span: Vector2 = DURATIONS[for_weather]
	return _rng.randf_range(span.x, span.y)


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
	var thunder := float(_current.get("thunder", 0.0))
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
		var angle := _lightning_rng.randf() * TAU
		_lightning_dir = Vector2(cos(angle), sin(angle))
		_lightning_time = 0.0
		_lightning = _lightning_envelope(0.0)
		_time_to_strike = _lightning_rng.randf_range(
			LIGHTNING_GAP_SECONDS.x, LIGHTNING_GAP_SECONDS.y
		)


## Flash shape: a sharp leader stroke plus a fast return-stroke flicker, both
## decaying within a few tenths of a second so lightning reads as a flicker.
func _lightning_envelope(t: float) -> float:
	var leader := exp(-t / 0.09)
	var flicker := 0.0
	if t > 0.11:
		flicker = 0.75 * exp(-(t - 0.11) / 0.06)
	return clampf(maxf(leader, flicker), 0.0, 1.0)


## Whether the falling-rain particle emitter should draw this frame: only when
## it is actually raining and the player is not under an enclosed roof. Exposed
## so headless tests can assert indoor suppression without building a renderer.
func rain_emitter_visible() -> bool:
	return not rain_suppressed and rain_intensity() > 0.02


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
	_rain.visible = rain_emitter_visible()
	if _rain.visible:
		_rain.amount_ratio = clampf(rain_intensity(), 0.05, 1.0)
	if _camera != null:
		_rain.global_position = _camera.global_position + Vector3.UP * RAIN_EMITTER_HEIGHT
	if _roof_audio != null:
		_roof_audio.sync(rain_suppressed, rain_intensity(), delta)


func _push_cloud_uniforms() -> void:
	if _material == null:
		return
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
	_material.set_shader_parameter(&"lightning", _effective_lightning())
	_material.set_shader_parameter(&"lightning_dir", _lightning_dir)
	_material.set_shader_parameter(&"wind_dir", wind_direction_xz())

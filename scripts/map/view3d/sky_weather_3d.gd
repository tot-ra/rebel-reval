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
const STAR_CATALOG := preload("res://scripts/map/view3d/estonia_star_catalog.gd")
const GAME_CALENDAR := preload("res://scripts/global/game_calendar.gd")

const WEATHER_CLEAR := &"clear"
const WEATHER_CLOUDY := &"cloudy"
const WEATHER_RAIN := &"rain"
const ALL_WEATHERS: Array[StringName] = [WEATHER_CLEAR, WEATHER_CLOUDY, WEATHER_RAIN]

## Fixed seed: same weather sequence on every launch (deterministic, reviewable).
const WEATHER_SEED := 24217
const TRANSITION_SECONDS := 5.0
const CLOUD_DRIFT_PER_SECOND := Vector2(0.0045, 0.0018)

## Approximate solar orbit used for the visible sun and directional light. World
## +X is east, -Z north, and +Y zenith, matching the star projection below.
## The axial tilt changes declination through the calendar year and therefore
## changes both the noon elevation and the sunrise/sunset times in Reval.
const EARTH_AXIAL_TILT_DEGREES := 23.44
## In 1343 the Julian calendar was about eight days behind the seasonal equinox.
const CAMPAIGN_VERNAL_EQUINOX_DAY_OF_YEAR := 72.0
const SUNSET_ELEVATION_BAND_DEG := 16.0
const SUNSET_ENERGY_DIM := 0.30
const SUNSET_AMBIENT_DIM := 0.15
const SUNSET_TINT_STRENGTH := 0.65

## Keep in sync with MapView3D.SUN_NIGHT_ROTATION_DEGREES: the moon disk shares
## the night light's direction so sky and shadows never disagree.
const MOON_ROTATION_DEGREES := Vector3(-36.0, 142.0, 0.0)

## Astronomical reference for Reval (Tallinn) on St George's Night. The catalog
## is J2000, then precessed to the canonical campaign year so even Polaris and
## the circumpolar constellations sit where a 1343 observer would see them.
const OBSERVER_LATITUDE_DEGREES := 59.437
const SKY_EPOCH_YEAR := 1343.0
const REFERENCE_DATE := "1343-04-23"
## Local apparent sidereal angle at midnight on 1343-04-23 (Julian calendar).
## The day/night cycle advances it by one full celestial turn per in-game day.
const MIDNIGHT_SIDEREAL_DEGREES := 218.31
const STAR_MAP_WIDTH := 2048
const STAR_MAP_HEIGHT := 1024

## Per-weather visual targets blended during transitions.
const PROFILES: Dictionary = {
	WEATHER_CLEAR: {
		"coverage": 0.22, "darken": 0.05,
		"sun_energy": 1.0, "ambient_energy": 1.0,
		"gray": 0.0, "rain": 0.0,
	},
	WEATHER_CLOUDY: {
		"coverage": 0.68, "darken": 0.45,
		"sun_energy": 0.60, "ambient_energy": 0.85,
		"gray": 0.35, "rain": 0.0,
	},
	WEATHER_RAIN: {
		"coverage": 0.92, "darken": 0.80,
		"sun_energy": 0.32, "ambient_energy": 0.70,
		"gray": 0.60, "rain": 1.0,
	},
}
## Seconds each weather state holds before the Markov step picks the next one.
## Sized against DayNightCycle.CYCLE_DURATION_SECONDS (60s days) so weather
## visibly turns over within one in-game day.
const DURATIONS: Dictionary = {
	WEATHER_CLEAR: Vector2(40.0, 80.0),
	WEATHER_CLOUDY: Vector2(25.0, 50.0),
	WEATHER_RAIN: Vector2(15.0, 35.0),
}
const RAIN_FROM_CLOUDY_CHANCE := 0.45

const RAIN_EMITTER_HEIGHT := 11.0

var weather: StringName = WEATHER_CLEAR
## When false the current state holds until set_weather() is called.
var auto_weather := true
## 1 while the sun hugs the horizon (golden hour), 0 the rest of the cycle.
var sunset_factor := 0.0
var calendar_date: Dictionary = GAME_CALENDAR.DEFAULT_DATE.duplicate()

var _current: Dictionary = (PROFILES[WEATHER_CLEAR] as Dictionary).duplicate()
var _from: Dictionary = (PROFILES[WEATHER_CLEAR] as Dictionary).duplicate()
var _blend := 1.0
var _time_in_state := 0.0
var _state_duration := 60.0
var _rng := RandomNumberGenerator.new()
var _cloud_offset := Vector2.ZERO
var _material: ShaderMaterial
var _camera: Camera3D
var _rain: GPUParticles3D


## State is seeded here, not in configure(), so headless tests can exercise the
## weather machine without building any rendering resources.
func _init() -> void:
	_rng.seed = WEATHER_SEED
	_state_duration = _roll_duration(weather)


func _process(delta: float) -> void:
	advance(delta)


## Replaces the environment's flat background with the sky dome and builds the
## rain emitter that shadows the gameplay camera.
func configure(camera: Camera3D, environment: Environment) -> void:
	_camera = camera
	_material = ShaderMaterial.new()
	_material.shader = SKY_SHADER
	_material.set_shader_parameter(&"cloud_noise", _build_cloud_noise())
	_material.set_shader_parameter(&"star_map", _build_star_map())
	_material.set_shader_parameter(&"observer_latitude", deg_to_rad(OBSERVER_LATITUDE_DEGREES))
	var sky := Sky.new()
	sky.sky_material = _material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY

	_rain = _build_rain()
	add_child(_rain)
	_push_cloud_uniforms()


## Deterministic 256px seamless noise; authored in code so no runtime art
## assets are added while the asset pipeline freeze (P0-040) is in effect.
func _build_cloud_noise() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = WEATHER_SEED
	noise.frequency = 0.03
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	return texture




## Bakes the real star catalog into an equatorial equirectangular map. A texture
## keeps the sky shader to one sample per pixel instead of looping over 1,600
## stars, while preserving exact catalog positions, brightness, and B-V color.
func _build_star_map() -> ImageTexture:
	var image := Image.create(STAR_MAP_WIDTH, STAR_MAP_HEIGHT, false, Image.FORMAT_RGBAH)
	image.fill(Color.TRANSPARENT)
	for j2000_star in STAR_CATALOG.STARS:
		var star: Vector4 = precess_equatorial(j2000_star, STAR_CATALOG.CATALOG_EPOCH, SKY_EPOCH_YEAR)
		var x := wrapi(roundi(star.x / 360.0 * float(STAR_MAP_WIDTH)), 0, STAR_MAP_WIDTH)
		var y := clampi(roundi((90.0 - star.y) / 180.0 * float(STAR_MAP_HEIGHT - 1)), 0, STAR_MAP_HEIGHT - 1)
		var luminosity := magnitude_to_luminance(star.z)
		var color := bv_to_rgb(star.w) * luminosity
		# Brighter stars receive a compact cross-shaped bloom. Dim stars remain a
		# single texel so recognisable constellation geometry is not distorted.
		_set_star_texel(image, x, y, color)
		if star.z <= 2.5:
			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				_set_star_texel(image, x + offset.x, y + offset.y, color * 0.28)
	return ImageTexture.create_from_image(image)


func _set_star_texel(image: Image, x: int, y: int, color: Color) -> void:
	var wrapped_x := wrapi(x, 0, STAR_MAP_WIDTH)
	var clamped_y := clampi(y, 0, STAR_MAP_HEIGHT - 1)
	var existing := image.get_pixel(wrapped_x, clamped_y)
	image.set_pixel(wrapped_x, clamped_y, Color(
		maxf(existing.r, color.r),
		maxf(existing.g, color.g),
		maxf(existing.b, color.b),
		1.0
	))


static func magnitude_to_luminance(magnitude: float) -> float:
	# Pogson's relation: five magnitudes equal a factor of 100 in brightness.
	return clampf(pow(10.0, -0.4 * (magnitude - STAR_CATALOG.LIMITING_MAGNITUDE)), 1.0, 180.0)


static func bv_to_rgb(bv: float) -> Color:
	# Ballesteros temperature approximation followed by a black-body RGB fit.
	# This preserves blue Rigel/Vega and warm Betelgeuse/Arcturus at a glance.
	var clamped_bv := clampf(bv, -0.4, 2.0)
	var temperature := 4600.0 * (
		1.0 / (0.92 * clamped_bv + 1.7) + 1.0 / (0.92 * clamped_bv + 0.62)
	)
	var scaled := temperature / 100.0
	var red: float
	var green: float
	var blue: float
	if scaled <= 66.0:
		red = 1.0
		green = clampf((99.4708025861 * log(scaled) - 161.1195681661) / 255.0, 0.0, 1.0)
	else:
		red = clampf(329.698727446 * pow(scaled - 60.0, -0.1332047592) / 255.0, 0.0, 1.0)
		green = clampf(288.1221695283 * pow(scaled - 60.0, -0.0755148492) / 255.0, 0.0, 1.0)
	if scaled >= 66.0:
		blue = 1.0
	elif scaled <= 19.0:
		blue = 0.0
	else:
		blue = clampf((138.5177312231 * log(scaled - 10.0) - 305.0447927307) / 255.0, 0.0, 1.0)
	return Color(red, green, blue)


## IAU 1976 precession is sufficiently accurate across the 657-year offset and
## moves the entire constellation pattern together from J2000 to spring 1343.
static func precess_equatorial(star: Vector4, from_epoch: float, to_epoch: float) -> Vector4:
	var centuries := (to_epoch - from_epoch) / 100.0
	var zeta := deg_to_rad((
		2306.2181 * centuries
		+ 0.30188 * centuries * centuries
		+ 0.017998 * centuries * centuries * centuries
	) / 3600.0)
	var z := deg_to_rad((
		2306.2181 * centuries
		+ 1.09468 * centuries * centuries
		+ 0.018203 * centuries * centuries * centuries
	) / 3600.0)
	var theta := deg_to_rad((
		2004.3109 * centuries
		- 0.42665 * centuries * centuries
		- 0.041833 * centuries * centuries * centuries
	) / 3600.0)
	var right_ascension := deg_to_rad(star.x)
	var declination := deg_to_rad(star.y)
	var a := cos(declination) * sin(right_ascension + zeta)
	var b := (
		cos(theta) * cos(declination) * cos(right_ascension + zeta)
		- sin(theta) * sin(declination)
	)
	var c := (
		sin(theta) * cos(declination) * cos(right_ascension + zeta)
		+ cos(theta) * sin(declination)
	)
	return Vector4(
		wrapf(rad_to_deg(atan2(a, b) + z), 0.0, 360.0),
		rad_to_deg(asin(clampf(c, -1.0, 1.0))),
		star.z,
		star.w
	)


func _build_rain() -> GPUParticles3D:
	var rain := GPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 1400
	rain.lifetime = 1.1
	# World-space particles so camera motion does not drag the rain volume along.
	rain.local_coords = false
	rain.visibility_aabb = AABB(Vector3(-36.0, -20.0, -36.0), Vector3(72.0, 40.0, 72.0))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(26.0, 0.5, 26.0)
	process.direction = Vector3(0.06, -1.0, 0.02)
	process.spread = 2.0
	process.initial_velocity_min = 15.0
	process.initial_velocity_max = 19.0
	process.gravity = Vector3(0.0, -10.0, 0.0)
	process.set_particle_flag(ParticleProcessMaterial.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY, true)
	rain.process_material = process
	# Stretched unshaded streaks; built from primitives, no texture assets.
	var streak := BoxMesh.new()
	streak.size = Vector3(0.014, 0.3, 0.014)
	var streak_material := StandardMaterial3D.new()
	streak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak_material.albedo_color = Color(0.65, 0.74, 0.86, 0.38)
	streak.material = streak_material
	rain.draw_pass_1 = streak
	rain.visible = false
	return rain


## Steps the weather state machine and cloud drift. Public so headless tests
## can drive time without a scene tree; _process is the only other caller.
func advance(delta: float) -> void:
	_cloud_offset += CLOUD_DRIFT_PER_SECOND * delta
	if _blend < 1.0:
		_blend = minf(1.0, _blend + delta / TRANSITION_SECONDS)
		for key in _current:
			_current[key] = lerpf(float(_from[key]), float((PROFILES[weather] as Dictionary)[key]), _blend)
	elif auto_weather:
		_time_in_state += delta
		if _time_in_state >= _state_duration:
			_pick_next_weather()
	_update_rain()
	_push_cloud_uniforms()


## Starts a blended transition to the requested weather state.
func set_weather(next_weather: StringName) -> void:
	assert(next_weather in ALL_WEATHERS)
	if next_weather == weather:
		return
	_from = _current.duplicate()
	weather = next_weather
	_blend = 0.0
	_time_in_state = 0.0
	_state_duration = _roll_duration(next_weather)


## Solar declination follows the campaign's Julian calendar. The approximation is
## intentionally deterministic and is accurate enough to reproduce Reval's long
## summer days, short winter days, and east-to-west daily traversal.
static func solar_declination_degrees(date: Dictionary) -> float:
	var year := int(date.get("year", GAME_CALENDAR.DEFAULT_DATE["year"]))
	var year_length := float(GAME_CALENDAR.days_in_year(year))
	var ordinal := float(GAME_CALENDAR.day_of_year(date))
	return EARTH_AXIAL_TILT_DEGREES * sin(TAU * (ordinal - CAMPAIGN_VERNAL_EQUINOX_DAY_OF_YEAR) / year_length)


## Returns the observer-to-sun direction in the sky shader's ENU world frame:
## +X east, -Z north, and +Y up. Local solar noon is progress 0.5.
static func solar_direction(progress: float, date: Dictionary = {}) -> Vector3:
	var effective_date := GAME_CALENDAR.DEFAULT_DATE if date.is_empty() else date
	var latitude := deg_to_rad(OBSERVER_LATITUDE_DEGREES)
	var declination := deg_to_rad(solar_declination_degrees(effective_date))
	var hour_angle := (wrapf(progress, 0.0, 1.0) - 0.5) * TAU
	var east := -cos(declination) * sin(hour_angle)
	var north := (
		cos(latitude) * sin(declination)
		- sin(latitude) * cos(declination) * cos(hour_angle)
	)
	var up := (
		sin(latitude) * sin(declination)
		+ cos(latitude) * cos(declination) * cos(hour_angle)
	)
	return Vector3(east, up, -north).normalized()


static func solar_elevation_degrees(progress: float, date: Dictionary = {}) -> float:
	return rad_to_deg(asin(clampf(solar_direction(progress, date).y, -1.0, 1.0)))


static func sunrise_sunset_hours(date: Dictionary = {}) -> Dictionary:
	var effective_date := GAME_CALENDAR.DEFAULT_DATE if date.is_empty() else date
	var latitude := deg_to_rad(OBSERVER_LATITUDE_DEGREES)
	var declination := deg_to_rad(solar_declination_degrees(effective_date))
	var horizon_hour_angle := acos(clampf(-tan(latitude) * tan(declination), -1.0, 1.0))
	var half_day_hours := rad_to_deg(horizon_hour_angle) / 15.0
	return {
		"sunrise": 12.0 - half_day_hours,
		"sunset": 12.0 + half_day_hours,
		"day_length": half_day_hours * 2.0,
	}


static func daylight_blend(progress: float, date: Dictionary = {}) -> float:
	# Civil twilight keeps dawn/dusk gradual while 0.5 still marks the geometric
	# horizon, so the day bucket spans exactly the date-dependent daylight hours.
	return smoothstep(-6.0, 6.0, solar_elevation_degrees(progress, date))


func set_calendar_date(date: Dictionary) -> void:
	calendar_date = date.duplicate()


## Pushes a shared physical sun direction and cycle tints into the sky shader.
## MapView3D uses the same vector for its directional light, keeping the disk,
## moving shadows, sunrise in the east, and sunset in the west in agreement.
func apply_sky_state(progress: float, day_blend: float, sun_direction: Vector3) -> void:
	var elevation := rad_to_deg(asin(clampf(sun_direction.y, -1.0, 1.0)))
	sunset_factor = clampf(1.0 - absf(elevation) / SUNSET_ELEVATION_BAND_DEG, 0.0, 1.0)
	var moon_direction := Basis.from_euler(Vector3(
		deg_to_rad(MOON_ROTATION_DEGREES.x),
		deg_to_rad(MOON_ROTATION_DEGREES.y),
		0.0
	)).z
	_material.set_shader_parameter(&"sun_direction", sun_direction)
	_material.set_shader_parameter(&"moon_direction", moon_direction)
	_material.set_shader_parameter(&"day_blend", day_blend)
	_material.set_shader_parameter(&"sunset_factor", sunset_factor)
	_material.set_shader_parameter(&"sidereal_angle", deg_to_rad(MIDNIGHT_SIDEREAL_DEGREES) + progress * TAU)


## Multipliers/tints MapView3D applies on top of its day/night lerp. Overcast
## skies also mute the sunset tint: gray clouds do not glow orange.
func lighting_modifiers() -> Dictionary:
	return {
		"sun_energy": float(_current["sun_energy"]) * (1.0 - SUNSET_ENERGY_DIM * sunset_factor),
		"ambient_energy": float(_current["ambient_energy"]) * (1.0 - SUNSET_AMBIENT_DIM * sunset_factor),
		"sunset_tint": sunset_factor * SUNSET_TINT_STRENGTH * float(_current["sun_energy"]),
		"overcast": float(_current["gray"]),
	}


func cloud_coverage() -> float:
	return float(_current["coverage"])


func rain_intensity() -> float:
	return float(_current["rain"])


func _pick_next_weather() -> void:
	match weather:
		WEATHER_CLEAR:
			set_weather(WEATHER_CLOUDY)
		WEATHER_CLOUDY:
			if _rng.randf() < RAIN_FROM_CLOUDY_CHANCE:
				set_weather(WEATHER_RAIN)
			else:
				set_weather(WEATHER_CLEAR)
		WEATHER_RAIN:
			set_weather(WEATHER_CLOUDY)


func _roll_duration(for_weather: StringName) -> float:
	var span: Vector2 = DURATIONS[for_weather]
	return _rng.randf_range(span.x, span.y)


func _update_rain() -> void:
	# Headless tests drive advance() without configure(); no emitter exists then.
	if _rain == null:
		return
	var intensity := rain_intensity()
	_rain.visible = intensity > 0.02
	if _rain.visible:
		_rain.amount_ratio = clampf(intensity, 0.05, 1.0)
	if _camera != null:
		_rain.global_position = _camera.global_position + Vector3.UP * RAIN_EMITTER_HEIGHT


func _push_cloud_uniforms() -> void:
	if _material == null:
		return
	_material.set_shader_parameter(&"cloud_coverage", cloud_coverage())
	_material.set_shader_parameter(&"cloud_darken", float(_current["darken"]))
	_material.set_shader_parameter(&"cloud_offset", _cloud_offset)

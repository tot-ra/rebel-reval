class_name SkyWeather3D
extends Node3D

## Sky dome, sun/moon placement, and a deterministic weather cycle for the
## MapView3D view layer. Owns the Environment sky (gradient + procedural
## clouds via sky_weather_3d.gdshader), blends clear/cloudy/rain profiles, and
## reports lighting multipliers back to MapView3D so sun and ambient follow
## the sky. Weather randomness comes from a fixed seed: the sequence repeats
## identically every run, keeping the deterministic-state rule intact.

const SKY_SHADER := preload("res://scripts/map/view3d/sky_weather_3d.gdshader")

const WEATHER_CLEAR := &"clear"
const WEATHER_CLOUDY := &"cloudy"
const WEATHER_RAIN := &"rain"
const ALL_WEATHERS: Array[StringName] = [WEATHER_CLEAR, WEATHER_CLOUDY, WEATHER_RAIN]

## Fixed seed: same weather sequence on every launch (deterministic, reviewable).
const WEATHER_SEED := 24217
const TRANSITION_SECONDS := 5.0
const CLOUD_DRIFT_PER_SECOND := Vector2(0.0045, 0.0018)

## Sun path: elevation swings from -58 deg (midnight) to +58 deg (noon), so the
## disk visibly rises at 06:00 and sets at 18:00 of the cycle.
const SUN_PATH_MAX_ELEVATION_DEG := 58.0
## Elevation window (degrees above/below the horizon) that counts as golden hour.
const SUNSET_ELEVATION_BAND_DEG := 16.0
const SUNSET_ENERGY_DIM := 0.30
const SUNSET_AMBIENT_DIM := 0.15
const SUNSET_TINT_STRENGTH := 0.65

## Keep in sync with MapView3D.SUN_NIGHT_ROTATION_DEGREES: the moon disk shares
## the night light's direction so sky and shadows never disagree.
const MOON_ROTATION_DEGREES := Vector3(-36.0, 142.0, 0.0)

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


## Pushes sun/moon placement and cycle tints into the sky shader. The sun disk
## azimuth follows the gameplay light so sky and shadows agree, while the
## elevation comes from the sun path so dawn/dusk actually reach the horizon.
func apply_sky_state(progress: float, day_blend: float, sun_yaw_degrees: float) -> void:
	var elevation := sin((progress - 0.25) * TAU) * SUN_PATH_MAX_ELEVATION_DEG
	sunset_factor = clampf(1.0 - absf(elevation) / SUNSET_ELEVATION_BAND_DEG, 0.0, 1.0)
	var sun_direction := Basis.from_euler(Vector3(
		deg_to_rad(-elevation),
		deg_to_rad(sun_yaw_degrees),
		0.0
	)).z
	var moon_direction := Basis.from_euler(Vector3(
		deg_to_rad(MOON_ROTATION_DEGREES.x),
		deg_to_rad(MOON_ROTATION_DEGREES.y),
		0.0
	)).z
	_material.set_shader_parameter(&"sun_direction", sun_direction)
	_material.set_shader_parameter(&"moon_direction", moon_direction)
	_material.set_shader_parameter(&"day_blend", day_blend)
	_material.set_shader_parameter(&"sunset_factor", sunset_factor)


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

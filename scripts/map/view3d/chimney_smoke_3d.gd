class_name ChimneySmoke3D
extends GPUParticles3D

## Per-chimney smoke plume: lit, noise-carved puffs (chimney_smoke.gdshader)
## that read as a small volume of gas, curl-noise turbulence so the column
## billows and breaks up as it ages, world wind from SkyWeather, a tiny
## building-specific bias, gust-driven sway, and day/night emission schedules.

enum Schedule { NEVER, DAY_ONLY, NIGHT_ONLY, ALWAYS }

const SMOKE_LIFETIME := 11.0
## Plumes stream in as Kalev walks (CityChimneySmoke): prewarm a whole
## lifetime so a new plume appears as a full trail, not a column growing
## out of the stack in front of the player.
const SMOKE_PREWARM_SECONDS := SMOKE_LIFETIME
const PerfProbeScript := preload("res://scripts/debug/perf_probe.gd")
const SMOKE_SHADER := preload("res://scripts/map/view3d/chimney_smoke.gdshader")

static var _material: ShaderMaterial

var _building_seed: int = 0
var _horizontal_wind := Vector3(0.2, 0.0, 0.08)
var _phase := 0.0
var _schedule: Schedule = Schedule.ALWAYS
var _day_amount := 20
var _night_amount := 28
var _time_of_day: StringName = MapView3D.TIME_DAY


static func schedule_for(building_seed: int) -> Schedule:
	match building_seed % 17:
		0, 1:
			return Schedule.NEVER
		2, 3:
			return Schedule.DAY_ONLY
		4, 5:
			return Schedule.NIGHT_ONLY
		_:
			return Schedule.ALWAYS


func configure(building_id: StringName) -> void:
	_building_seed = String(building_id).hash()
	_schedule = schedule_for(_building_seed)
	_phase = float((_building_seed & 0xffff) % 6283) / 1000.0
	# Seed a tiny local bias so adjacent chimneys do not lock into one ribbon;
	# prevailing direction still comes from SkyWeather every frame.
	var wind_angle := fmod(float((_building_seed >> 3) % 6283) / 1000.0, TAU)
	_horizontal_wind = Vector3(cos(wind_angle), 0.0, sin(wind_angle)).normalized() * 0.18
	# Overlapping puffs build the body of the column; each one is mostly
	# transparent noise, so the plume needs more of them than flat discs did.
	_day_amount = (22 + ((_building_seed >> 5) % 14)) * 3
	_night_amount = (30 + ((_building_seed >> 7) % 16)) * 3
	_setup_particles(building_id)
	apply_time_of_day(_time_of_day)


func apply_time_of_day(next_time: StringName) -> void:
	_time_of_day = next_time
	var night := next_time == MapView3D.TIME_NIGHT
	var should_emit := false
	match _schedule:
		Schedule.NEVER:
			should_emit = false
		Schedule.DAY_ONLY:
			should_emit = not night
		Schedule.NIGHT_ONLY:
			should_emit = night
		Schedule.ALWAYS:
			should_emit = true
	visible = should_emit
	emitting = should_emit
	if not should_emit:
		return
	amount = _night_amount if night else _day_amount
	_update_color_ramp(night)


func _setup_particles(building_id: StringName) -> void:
	name = "ChimneySmoke"
	amount = _day_amount
	lifetime = SMOKE_LIFETIME
	preprocess = SMOKE_PREWARM_SECONDS
	local_coords = true
	explosiveness = 0.0
	randomness = 0.12
	# Lit puffs differ in brightness, so far ones must not paint over near ones.
	draw_order = DRAW_ORDER_VIEW_DEPTH
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_aabb = AABB(Vector3(-8.0, -1.5, -8.0), Vector3(16.0, 14.0, 16.0))

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	# Launch straight up from the chimney mouth; horizontal drift comes later via gravity.
	process.direction = Vector3.UP
	process.spread = 6.0 + float((_building_seed >> 9) % 6)
	process.flatness = 0.0
	# Warm smoke keeps rising a few metres before the wind lays it over.
	process.initial_velocity_min = 1.0
	process.initial_velocity_max = 1.3 + float((_building_seed >> 11) % 12) * 0.02
	process.gravity = Vector3.ZERO
	process.linear_accel_min = -0.04
	process.linear_accel_max = -0.01
	process.damping_min = 0.1
	process.damping_max = 0.22
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.angular_velocity_min = -12.0
	process.angular_velocity_max = 12.0
	process.scale_min = 1.0
	process.scale_max = 2.2
	process.hue_variation_min = 0.0
	process.hue_variation_max = 0.0
	# Curl-noise turbulence: the fresh column leaves the flue coherent, then
	# rolls into eddies and tears apart as it cools and spreads.
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 1.6
	process.turbulence_noise_scale = 3.2
	process.turbulence_noise_speed = Vector3(0.0, 0.25, 0.0)
	process.turbulence_noise_speed_random = 0.3
	process.turbulence_influence_min = 0.05
	process.turbulence_influence_max = 0.12
	var swirl_curve := Curve.new()
	swirl_curve.add_point(Vector2(0.0, 0.1))
	swirl_curve.add_point(Vector2(0.35, 0.6))
	swirl_curve.add_point(Vector2(1.0, 1.0))
	var swirl_texture := CurveTexture.new()
	swirl_texture.curve = swirl_curve
	process.turbulence_influence_over_life = swirl_texture

	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.18))
	scale_curve.add_point(Vector2(0.18, 0.5))
	scale_curve.add_point(Vector2(1.0, 1.0))
	var curve_texture := CurveTexture.new()
	curve_texture.curve = scale_curve
	process.scale_curve = curve_texture

	process_material = process
	_update_color_ramp(false)

	var puff := QuadMesh.new()
	puff.size = Vector2.ONE
	puff.material = smoke_material()
	draw_pass_1 = puff

	set_meta("building_id", building_id)


## Shared puff material: all plumes use one shader instance, so they batch.
static func smoke_material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SMOKE_SHADER
	return _material


func _update_color_ramp(night: bool) -> void:
	var process := process_material as ParticleProcessMaterial
	if process == null:
		return
	# The puffs are lit now, so the ramp is albedo: wood smoke leaves the flue
	# a sooty brown-grey and pales to blue-grey as it thins out.
	var warmth := float((_building_seed >> 4) % 100) / 100.0
	var base := Color(
		lerpf(0.46, 0.54, warmth), lerpf(0.46, 0.50, warmth), lerpf(0.48, 0.44, warmth), 1.0
	)
	if night:
		base = base.lerp(Color(0.55, 0.60, 0.70), 0.25)
	var mid := base.lerp(Color(0.74, 0.75, 0.78), 0.45)
	var fade := base.lerp(Color(0.80, 0.82, 0.86), 0.6)
	var alpha_ramp := Gradient.new()
	alpha_ramp.set_color(0, Color(base.r, base.g, base.b, 0.0))
	# Configure both default endpoints before inserting sorted intermediate points.
	alpha_ramp.set_color(1, Color(fade.r, fade.g, fade.b, 0.0))
	# The trail must stay readable from the iso camera, so mid-life puffs keep
	# most of their opacity and only the last third thins out.
	alpha_ramp.add_point(0.07, Color(base.r, base.g, base.b, 0.3 if night else 0.27))
	alpha_ramp.add_point(0.3, Color(mid.r, mid.g, mid.b, 0.3 if night else 0.27))
	alpha_ramp.add_point(0.62, Color(mid.r, mid.g, mid.b, 0.2 if night else 0.18))
	alpha_ramp.add_point(0.88, Color(fade.r, fade.g, fade.b, 0.06))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = alpha_ramp
	process.color_ramp = ramp_texture


func _process(_delta: float) -> void:
	var probe_start := PerfProbeScript.start()
	_process_timed(_delta)
	PerfProbeScript.stop(&"chimney_smoke", probe_start)


func _process_timed(_delta: float) -> void:
	if not emitting:
		return
	var process := process_material as ParticleProcessMaterial
	if process == null:
		return
	var t := Time.get_ticks_msec() * 0.001
	var sky := _find_sky_weather()
	var wind_dir := Vector2(_horizontal_wind.x, _horizontal_wind.z)
	var wind_power := 0.28
	if sky != null:
		wind_dir = sky.wind_direction_xz()
		wind_power = sky.wind_strength()
	var gust := Vector2(
		sin(t * 0.43 + _phase) * 0.42 + sin(t * 1.65 + _phase * 2.1) * 0.18,
		cos(t * 0.39 + _phase * 1.15) * 0.40 + cos(t * 1.95 + _phase * 0.7) * 0.16
	)
	var prevailing := Vector3(wind_dir.x, 0.0, wind_dir.y) * lerpf(0.55, 1.45, wind_power)
	var sway := (
		prevailing + _horizontal_wind + Vector3(gust.x, 0.0, gust.y) * lerpf(0.45, 1.1, wind_power)
	)
	# Gravity bends the rising column; new puffs still launch upward from the chimney.
	process.gravity = Vector3(sway.x * 0.38, -0.03 + sin(t * 0.55 + _phase) * 0.02, sway.z * 0.38)


func _find_sky_weather() -> SkyWeather3D:
	var node: Node = self
	while node != null:
		if node.has_method(&"sky_weather"):
			return node.call(&"sky_weather") as SkyWeather3D
		node = node.get_parent()
	return null

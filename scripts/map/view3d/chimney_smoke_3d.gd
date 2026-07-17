class_name ChimneySmoke3D
extends GPUParticles3D

## Per-chimney smoke plume: soft billboards, building-specific tint and wind
## bias, gust-driven direction, and day/night emission schedules.

enum Schedule { NEVER, DAY_ONLY, NIGHT_ONLY, ALWAYS }

const SMOKE_LIFETIME := 7.5
const SMOKE_PREPROCESS := 7.5

var _building_seed: int = 0
var _base_wind := Vector3(0.2, 1.0, 0.08)
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
	var wind_angle := fmod(float((_building_seed >> 3) % 6283) / 1000.0, TAU)
	_base_wind = Vector3(
		cos(wind_angle) * 0.55 + 0.08,
		1.0,
		sin(wind_angle) * 0.55 + 0.06
	).normalized()
	_day_amount = 14 + ((_building_seed >> 5) % 12)
	_night_amount = 20 + ((_building_seed >> 7) % 14)
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
	preprocess = SMOKE_PREPROCESS
	local_coords = true
	explosiveness = 0.0
	randomness = 0.35
	visibility_aabb = AABB(Vector3(-4.0, -1.0, -4.0), Vector3(8.0, 10.0, 8.0))

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	process.direction = _base_wind
	process.spread = 18.0 + float((_building_seed >> 9) % 14)
	process.flatness = 0.35
	process.initial_velocity_min = 0.25
	process.initial_velocity_max = 0.65 + float((_building_seed >> 11) % 20) * 0.01
	process.gravity = Vector3(_base_wind.x * 0.18, 0.14, _base_wind.z * 0.18)
	process.linear_accel_min = 0.02
	process.linear_accel_max = 0.12
	process.damping_min = 0.35
	process.damping_max = 0.75
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.angular_velocity_min = -12.0
	process.angular_velocity_max = 12.0
	process.scale_min = 0.55
	process.scale_max = 1.65 + float((_building_seed >> 13) % 8) * 0.08
	var hue_span := 0.04 + float((_building_seed >> 15) % 6) * 0.01
	process.hue_variation_min = -hue_span
	process.hue_variation_max = hue_span
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 1.6 + float((_building_seed >> 17) % 10) * 0.12
	process.turbulence_noise_scale = 1.8
	process.turbulence_noise_speed = Vector3(0.35, 0.15, 0.3)
	process.turbulence_influence_min = 0.12
	process.turbulence_influence_max = 0.42

	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.22))
	scale_curve.add_point(Vector2(0.18, 0.55))
	scale_curve.add_point(Vector2(0.55, 1.0))
	scale_curve.add_point(Vector2(1.0, 1.35))
	var curve_texture := CurveTexture.new()
	curve_texture.curve = scale_curve
	process.scale_curve = curve_texture

	process_material = process
	_update_color_ramp(false)

	var puff := QuadMesh.new()
	puff.size = Vector2(1.35, 1.35)
	puff.material = MapViewMaterials.smoke()
	draw_pass_1 = puff

	set_meta("building_id", building_id)


func _update_color_ramp(night: bool) -> void:
	var process := process_material as ParticleProcessMaterial
	if process == null:
		return
	var warmth := float((_building_seed >> 4) % 100) / 100.0
	var base := Color(
		lerpf(0.62, 0.84, warmth),
		lerpf(0.66, 0.72, warmth),
		lerpf(0.74, 0.58, warmth),
		1.0
	)
	if night:
		base = base.lerp(Color(0.58, 0.64, 0.78), 0.35).darkened(0.08)
	else:
		base = base.lightened(0.04)
	var mid := base.lightened(0.08)
	var fade := base.lerp(Color(0.9, 0.9, 0.92), 0.25)
	var alpha_ramp := Gradient.new()
	alpha_ramp.set_color(0, Color(fade.r, fade.g, fade.b, 0.0))
	alpha_ramp.add_point(0.12, Color(base.r, base.g, base.b, 0.42 if night else 0.36))
	alpha_ramp.add_point(0.45, Color(mid.r, mid.g, mid.b, 0.28 if night else 0.24))
	alpha_ramp.set_color(1, Color(fade.r, fade.g, fade.b, 0.0))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = alpha_ramp
	process.color_ramp = ramp_texture


func _process(_delta: float) -> void:
	if not emitting:
		return
	var process := process_material as ParticleProcessMaterial
	if process == null:
		return
	var t := Time.get_ticks_msec() * 0.001
	var gust := Vector3(
		sin(t * 0.43 + _phase) * 0.38 + sin(t * 1.65 + _phase * 2.1) * 0.16,
		0.0,
		cos(t * 0.39 + _phase * 1.15) * 0.36 + cos(t * 1.95 + _phase * 0.7) * 0.14
	)
	var swirl := Vector3(
		sin(t * 2.4 + _phase * 3.0) * 0.12,
		sin(t * 0.8 + _phase) * 0.05,
		cos(t * 2.2 + _phase * 2.4) * 0.12
	)
	var dir := (_base_wind + gust + swirl).normalized()
	process.direction = dir
	process.gravity = Vector3(dir.x * 0.22, 0.1 + sin(t * 0.55 + _phase) * 0.04, dir.z * 0.22)

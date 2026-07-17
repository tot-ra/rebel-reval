class_name ChimneySmoke3D
extends GPUParticles3D

## Per-chimney smoke plume: simple rounded billboards with building-specific
## wind bias, gust-driven sway, and day/night emission schedules.

enum Schedule { NEVER, DAY_ONLY, NIGHT_ONLY, ALWAYS }

const SMOKE_LIFETIME := 8.5

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
	var wind_angle := fmod(float((_building_seed >> 3) % 6283) / 1000.0, TAU)
	_horizontal_wind = Vector3(cos(wind_angle), 0.0, sin(wind_angle)).normalized()
	_day_amount = (22 + ((_building_seed >> 5) % 14)) * 2
	_night_amount = (30 + ((_building_seed >> 7) % 16)) * 2
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
	# Keep at zero so puffs spawn at the chimney mouth and travel outward instead
	# of appearing mid-plume from a long warm-up simulation.
	preprocess = 0.0
	local_coords = true
	explosiveness = 0.0
	randomness = 0.12
	visibility_aabb = AABB(Vector3(-5.0, -1.5, -5.0), Vector3(10.0, 12.0, 10.0))

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	# Launch straight up from the chimney mouth; horizontal drift comes later via gravity.
	process.direction = Vector3.UP
	process.spread = 6.0 + float((_building_seed >> 9) % 6)
	process.flatness = 0.0
	process.initial_velocity_min = 0.85
	process.initial_velocity_max = 1.15 + float((_building_seed >> 11) % 12) * 0.02
	process.gravity = Vector3.ZERO
	process.linear_accel_min = -0.04
	process.linear_accel_max = -0.01
	process.damping_min = 0.18
	process.damping_max = 0.42
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.angular_velocity_min = -12.0
	process.angular_velocity_max = 12.0
	process.scale_min = 0.9
	process.scale_max = 1.5
	process.hue_variation_min = 0.0
	process.hue_variation_max = 0.0
	process.turbulence_enabled = false

	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.12))
	scale_curve.add_point(Vector2(0.18, 0.45))
	scale_curve.add_point(Vector2(1.0, 1.0))
	var curve_texture := CurveTexture.new()
	curve_texture.curve = scale_curve
	process.scale_curve = curve_texture

	process_material = process
	_update_color_ramp(false)

	var puff := _rounded_puff_mesh()
	puff.surface_set_material(0, MapViewMaterials.smoke())
	draw_pass_1 = puff

	set_meta("building_id", building_id)


## Eight-sided fan mesh: flat-tinted billboards without per-vertex alpha gradients.
static func _rounded_puff_mesh() -> ArrayMesh:
	const SIDES := 8
	const RADIUS := 0.5
	var vertices := PackedVector3Array([Vector3.ZERO])
	var indices := PackedInt32Array()
	for point in SIDES:
		var angle := TAU * float(point) / float(SIDES) + PI / 8.0
		vertices.append(Vector3(cos(angle) * RADIUS, sin(angle) * RADIUS, 0.0))
	for point in SIDES:
		indices.append(0)
		indices.append(point + 1)
		indices.append((point + 1) % SIDES + 1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _update_color_ramp(night: bool) -> void:
	var process := process_material as ParticleProcessMaterial
	if process == null:
		return
	var warmth := float((_building_seed >> 4) % 100) / 100.0
	var base := Color(
		lerpf(0.70, 0.78, warmth),
		lerpf(0.71, 0.75, warmth),
		lerpf(0.73, 0.69, warmth),
		1.0
	)
	if night:
		base = base.lerp(Color(0.62, 0.66, 0.74), 0.28).darkened(0.06)
	else:
		base = base.lightened(0.03)
	var mid := base.lightened(0.05)
	var fade := base.lerp(Color(0.88, 0.88, 0.90), 0.35)
	var alpha_ramp := Gradient.new()
	alpha_ramp.set_color(0, Color(fade.r, fade.g, fade.b, 0.0))
	# Configure both default endpoints before inserting sorted intermediate points.
	alpha_ramp.set_color(1, Color(fade.r, fade.g, fade.b, 0.0))
	alpha_ramp.add_point(0.1, Color(base.r, base.g, base.b, 0.28 if night else 0.22))
	alpha_ramp.add_point(0.4, Color(mid.r, mid.g, mid.b, 0.18 if night else 0.14))
	alpha_ramp.add_point(0.75, Color(fade.r, fade.g, fade.b, 0.06))
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
	var gust := Vector2(
		sin(t * 0.43 + _phase) * 0.42 + sin(t * 1.65 + _phase * 2.1) * 0.18,
		cos(t * 0.39 + _phase * 1.15) * 0.40 + cos(t * 1.95 + _phase * 0.7) * 0.16
	)
	var sway := _horizontal_wind + Vector3(gust.x, 0.0, gust.y)
	# Gravity bends the rising column; new puffs still launch upward from the chimney.
	process.gravity = Vector3(sway.x * 0.38, -0.03 + sin(t * 0.55 + _phase) * 0.02, sway.z * 0.38)

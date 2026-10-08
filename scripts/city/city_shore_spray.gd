extends Node3D

## Spray thrown off the waterline in a blow (docs/SYSTEMS/CITY_SEA.md).
##
## WHY: a gale breaks hard on the beach and the quays, but foam alone reads flat.
## A handful of GPU particle emitters sit on the waterline nearest the camera and
## throw white droplets up and landward; the wind scales how many. Emitters hop to
## the contour near the camera as it moves, so the cost stays constant over a
## coastline several kilometres long.

const EMITTERS := 10
## Contour is searched this far (world units) around the camera for emitter spots.
const NEAR_RANGE := 50.0
const REPLACE_DISTANCE := 12.0
## Wind (0..1) at which spray starts and where it is at full strength.
const WIND_ON := 0.35
const WIND_FULL := 0.9
## Sea level for the emitters, world units; crests ride above it in a gale.
const WATERLINE_Y := 0.35
## Offshore of the contour where the surf breaks, world units.
const BREAK_OFFSET := 1.2

var _contour := PackedVector2Array()
var _plan: CityPlan
var _emitters: Array[GPUParticles3D] = []
var _anchor := Vector2(1.0e9, 1.0e9)
var _intensity := 0.0
var _time := 0.0


func configure(plan: CityPlan, contour: PackedVector2Array) -> void:
	_plan = plan
	_contour = contour
	for index in EMITTERS:
		var emitter := _make_emitter()
		emitter.emitting = false
		add_child(emitter)
		_emitters.append(emitter)


## Wind strength 0..1 from the sky weather; below WIND_ON the spray is off.
func set_wind(wind: float) -> void:
	_intensity = smoothstep(WIND_ON, WIND_FULL, wind)
	for emitter in _emitters:
		emitter.emitting = _intensity > 0.01 and emitter.visible
		emitter.amount_ratio = clampf(_intensity, 0.05, 1.0)
		var material := emitter.process_material as ParticleProcessMaterial
		# Taller, harder throws as the gale builds.
		material.initial_velocity_min = lerpf(1.5, 3.0, _intensity)
		material.initial_velocity_max = lerpf(3.0, 7.5, _intensity)


func _process(delta: float) -> void:
	if _plan == null or _contour.is_empty() or _intensity <= 0.01:
		return
	_time += delta
	if _time < 0.5:
		return
	_time = 0.0
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var at := Vector2(camera.global_position.x, camera.global_position.z)
	if at.distance_to(_anchor) < REPLACE_DISTANCE:
		return
	_anchor = at
	_place_emitters(at)


func _place_emitters(at: Vector2) -> void:
	var near := PackedVector2Array()
	for point in _contour:
		if point.distance_squared_to(at) < NEAR_RANGE * NEAR_RANGE:
			near.append(point)
	for index in _emitters.size():
		var emitter := _emitters[index]
		emitter.visible = not near.is_empty()
		if near.is_empty():
			emitter.emitting = false
			continue
		# Evenly spread picks through the nearby contour (it is stored in scan order).
		var point := near[(index * near.size()) / _emitters.size()]
		# Uphill is landward; the surf breaks a little offshore of the waterline.
		var uphill := Vector2(
			_plan.ground_height(point + Vector2(1.0, 0.0)) - _plan.ground_height(point - Vector2(1.0, 0.0)),
			_plan.ground_height(point + Vector2(0.0, 1.0)) - _plan.ground_height(point - Vector2(0.0, 1.0))
		)
		var landward := uphill.normalized() if uphill.length() > 0.0001 else Vector2.ZERO
		var spot := point - landward * BREAK_OFFSET
		emitter.global_position = Vector3(spot.x, WATERLINE_Y, spot.y)
		var material := emitter.process_material as ParticleProcessMaterial
		# A little drift landward so droplets fall on the sand, not back into the sea.
		material.direction = Vector3(landward.x * 0.5, 1.0, landward.y * 0.5).normalized()
		emitter.emitting = _intensity > 0.01


static func _make_emitter() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = 90
	particles.lifetime = 1.6
	particles.preprocess = 1.0
	particles.local_coords = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-14, -2, -14), Vector3(28, 16, 28))
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	# Spread along the shore, thin across it.
	material.emission_box_extents = Vector3(5.0, 0.2, 5.0)
	material.direction = Vector3(0.0, 1.0, 0.0)
	material.spread = 32.0
	material.initial_velocity_min = 1.5
	material.initial_velocity_max = 3.0
	material.gravity = Vector3(0.0, -9.0, 0.0)
	material.damping_min = 0.3
	material.damping_max = 0.9
	material.scale_min = 0.25
	material.scale_max = 0.8
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	fade.add_point(0.15, Color(1.0, 1.0, 1.0, 0.95))
	fade.add_point(0.6, Color(0.95, 0.97, 1.0, 0.5))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	material.color_ramp = ramp
	particles.process_material = material
	var soft := Gradient.new()
	soft.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	soft.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var disc := GradientTexture2D.new()
	disc.gradient = soft
	disc.fill = GradientTexture2D.FILL_RADIAL
	disc.fill_from = Vector2(0.5, 0.5)
	disc.fill_to = Vector2(1.0, 0.5)
	disc.width = 64
	disc.height = 64
	var quad_material := StandardMaterial3D.new()
	quad_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad_material.vertex_color_use_as_albedo = true
	quad_material.albedo_texture = disc
	quad_material.disable_receive_shadows = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.8, 0.8)
	quad.material = quad_material
	particles.draw_pass_1 = quad
	return particles

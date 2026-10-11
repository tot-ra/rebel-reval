extends GPUParticles3D

## ADR 0045 snowfall: one pooled GPUParticles3D that replaces the rain streaks when
## the precipitation falls as snow (SeasonState.snow_share). Three looks, picked
## from intensity and wind, never from RNG, so the same weather snows the same way:
##   fine   - light, small, slow, drifting flakes (a dusting)
##   flakes - big soft flakes sinking slowly and tumbling in still air
##   heavy  - dense quick snow driven sideways by wind (a blizzard)
## Same volume and particle budget as the rain emitter, but cheaper per particle
## (one billboard quad instead of a box). Presentation only: no state, no saving.

const KIND_FINE := &"fine"
const KIND_FLAKES := &"flakes"
const KIND_HEAVY := &"heavy"
const KINDS: Array[StringName] = [KIND_FINE, KIND_FLAKES, KIND_HEAVY]

## The follow camera looks down from a few metres up, so the flake column runs
## from EMIT_HEIGHT above the lens to well below it, down to the ground.
const EMIT_HEIGHT := 8.0
const FALL_HEIGHT := 16.0
## Half-width of the emission slab and how far ahead of the camera it is centred:
## flakes behind the lens are wasted, so the volume sits where the view looks.
const EMIT_HALF := 11.0
const EMIT_AHEAD := 10.0

## size: flake quad edge in metres. speed: fall m/s. count: share of the tier's
## particle budget. flutter: sideways sway m/s. Wind drives the rest: see
## snowfall_particles.gdshader, where every flake's velocity chases wind + fall.
const PROFILES := {
	KIND_FINE: {"size": 0.12, "speed": 1.7, "count": 0.9, "flutter": 0.35, "alpha": 0.95},
	KIND_FLAKES: {"size": 0.22, "speed": 1.2, "count": 0.6, "flutter": 0.6, "alpha": 1.0},
	KIND_HEAVY: {"size": 0.15, "speed": 4.5, "count": 1.0, "flutter": 0.15, "alpha": 0.95},
}
## Snow rides the wind at this share of its speed (flakes are light, but not weightless).
const WIND_FOLLOW := 0.85
## Horizontal metres per second at wind strength 1 (matches SkyWeather3D.WIND_MS_AT_FULL).
const WIND_MS_AT_FULL := 16.0
const PARTICLE_SHADER := preload("res://scripts/map/view3d/snowfall_particles.gdshader")
## Height the stream is assumed to drop between spawn and the view, to push the
## emitter upwind by the drift it will pick up on the way down.
const DRIFT_DROP := 10.0

var kind: StringName = KIND_FINE
var _params: ShaderMaterial
var _material: StandardMaterial3D
var _budget := 700
var _alpha := 0.8


## Chooses the look for a snowfall of `intensity` (0..1) in `wind` (0..1).
## Blizzard when heavy or windy, big slow flakes in mid intensity and calm air,
## otherwise fine snow.
static func kind_for(intensity: float, wind: float) -> StringName:
	if intensity * (0.55 + wind) > 0.62 or wind > 0.7:
		return KIND_HEAVY
	if intensity > 0.3 and wind < 0.45:
		return KIND_FLAKES
	return KIND_FINE


## Where the emitter sits: EMIT_HEIGHT above the camera, EMIT_AHEAD along its
## horizontal facing, and upwind by the drift the flakes pick up on the way down.
func place(camera_position: Vector3, camera_forward: Vector3, wind: Vector2) -> void:
	var ahead := Vector3(camera_forward.x, 0.0, camera_forward.z)
	ahead = ahead.normalized() * EMIT_AHEAD if ahead.length() > 0.01 else Vector3.ZERO
	var drift := wind * WIND_FOLLOW * (DRIFT_DROP / float(PROFILES[kind]["speed"]))
	global_position = (
		camera_position + ahead + Vector3(-drift.x, EMIT_HEIGHT, -drift.y)
	)


func set_budget(budget: int) -> void:
	_budget = budget
	amount = budget


## Builds the particle material and flake quad. Call once before add_child.
func configure(budget: int) -> void:
	name = "Snow"
	_budget = budget
	amount = budget
	local_coords = false
	visibility_aabb = AABB(Vector3(-36.0, -20.0, -36.0), Vector3(72.0, 40.0, 72.0))
	_params = ShaderMaterial.new()
	_params.shader = PARTICLE_SHADER
	_params.set_shader_parameter("emit_half", Vector3(EMIT_HALF, 0.5, EMIT_HALF))
	process_material = _params
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# Without this the per-particle scale (flake size) is dropped.
	_material.billboard_keep_scale = true
	_material.particles_anim_h_frames = 1
	_material.particles_anim_v_frames = 1
	_material.vertex_color_use_as_albedo = true
	_material.albedo_texture = _flake_texture()
	_material.no_depth_test = false
	quad.material = _material
	draw_pass_1 = quad
	visible = false
	_apply_kind(KIND_FINE)


## Soft round flake from a procedural radial gradient (no texture asset).
static func _flake_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	gradient.offsets = PackedFloat32Array([0.5, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 32
	texture.height = 32
	return texture


## Applies a look's size, fall speed, wobble and opacity. Only on a change of
## kind: lifetime and speed are fixed per kind so live particles never restart.
func _apply_kind(next: StringName) -> void:
	kind = next
	var profile: Dictionary = PROFILES[next]
	var speed := float(profile["speed"])
	var size := float(profile["size"])
	_params.set_shader_parameter("fall_speed", speed)
	_params.set_shader_parameter("size_min", size * 0.7)
	_params.set_shader_parameter("size_max", size * 1.3)
	_params.set_shader_parameter("flutter", float(profile["flutter"]))
	# The slowest flake (75% of speed) must still reach the bottom of the column.
	lifetime = FALL_HEIGHT / (speed * 0.75)
	_alpha = float(profile["alpha"])


## Per-frame update. `wind` is the 0..1 wind strength, `wind_direction` the unit
## world x,z heading it blows toward; gusts are already inside `wind`.
## `brightness` dims the unshaded flakes at night (0..1).
func update_snowfall(
	intensity: float, wind: float, wind_direction: Vector2, brightness: float
) -> void:
	var next := kind_for(intensity, wind)
	if next != kind:
		_apply_kind(next)
	var profile: Dictionary = PROFILES[kind]
	var wind_ms := wind_direction * wind * WIND_MS_AT_FULL * WIND_FOLLOW
	_params.set_shader_parameter("wind_velocity", Vector3(wind_ms.x, 0.0, wind_ms.y))
	amount_ratio = clampf((0.3 + 0.7 * intensity) * float(profile["count"]), 0.1, 1.0)
	var grey := clampf(brightness, 0.0, 1.0)
	_material.albedo_color = Color(grey, grey, minf(grey * 1.04, 1.0), _alpha)

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
const FALL_HEIGHT := 20.0
## Half-width of the emission slab and how far ahead of the camera it is centred:
## flakes behind the lens are wasted, so the volume sits where the view looks.
const EMIT_HALF := 15.0
const EMIT_AHEAD := 10.0

## size: flake quad edge in metres. speed: fall m/s. count: share of the tier's
## particle budget. spread: cone half-angle in degrees, so flakes drift on
## slightly different diagonals instead of falling in lockstep (turbulence was
## tried and rejected: in the Mobile renderer it flings the flakes away).
const PROFILES := {
	KIND_FINE: {"size": 0.12, "speed": 1.2, "count": 0.9, "spread": 12.0, "alpha": 0.95},
	KIND_FLAKES: {"size": 0.22, "speed": 0.85, "count": 0.6, "spread": 24.0, "alpha": 1.0},
	KIND_HEAVY: {"size": 0.15, "speed": 3.2, "count": 1.0, "spread": 4.0, "alpha": 0.95},
}

var kind: StringName = KIND_FINE
var _params: ParticleProcessMaterial
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


## Where the emitter sits: `height` above the camera, pushed ahead along its
## horizontal facing and upwind by `slant` so slanted snow still lands in view.
static func emitter_position(
	camera_position: Vector3, camera_forward: Vector3, slant: Vector2, height: float
) -> Vector3:
	var ahead := Vector3(camera_forward.x, 0.0, camera_forward.z)
	ahead = ahead.normalized() * EMIT_AHEAD if ahead.length() > 0.01 else Vector3.ZERO
	return camera_position + ahead + Vector3(-slant.x * height, height, -slant.y * height)


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
	_params = ParticleProcessMaterial.new()
	_params.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_params.emission_box_extents = Vector3(EMIT_HALF, 0.5, EMIT_HALF)
	_params.gravity = Vector3.ZERO
	_params.angle_min = 0.0
	_params.angle_max = 360.0
	_params.scale_min = 0.6
	_params.scale_max = 1.3
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
	_params.initial_velocity_min = speed * 0.85
	_params.initial_velocity_max = speed * 1.15
	_params.scale_min = float(profile["size"]) * 0.7
	_params.scale_max = float(profile["size"]) * 1.3
	_params.spread = float(profile["spread"])
	lifetime = FALL_HEIGHT / speed
	_alpha = float(profile["alpha"])


## Per-frame update. `slant` is SkyWeather3D.rain_slant() (world x,z drift per
## metre of fall); `brightness` dims the unshaded flakes at night (0..1).
func update_snowfall(intensity: float, wind: float, slant: Vector2, brightness: float) -> void:
	var next := kind_for(intensity, wind)
	if next != kind:
		_apply_kind(next)
	var profile: Dictionary = PROFILES[kind]
	var speed := float(profile["speed"])
	var heading := Vector3(slant.x * speed, -speed, slant.y * speed).normalized()
	_params.direction = heading
	amount_ratio = clampf((0.3 + 0.7 * intensity) * float(profile["count"]), 0.1, 1.0)
	var grey := clampf(brightness, 0.0, 1.0)
	_material.albedo_color = Color(grey, grey, minf(grey * 1.04, 1.0), _alpha)

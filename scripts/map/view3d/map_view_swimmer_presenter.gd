class_name MapViewSwimmerPresenter
extends RefCounted

## ADR 0021 presentation for the player rig in water. Logic stays on the flat
## plane; this only places and poses the 3D rig: feet on the rendered seabed while
## wading, floating on the FFT swell while swimming, pitched prone with a crawl
## stroke when moving, upright treading water when still, and sunk below the
## surface while diving. It also feeds the WS-15 ripple sim so the body leaves a wake.

const SwimStrokeModifierScript := preload("res://scripts/characters/swim_stroke_modifier.gd")

## Hip height of the shared rig above its feet (hips bone rest, times model scale).
const HIP_HEIGHT := 0.85
## Upright treading: shoulders sit at the surface, so feet hang this far below it.
const TREAD_FEET_DROP := 1.55
## Prone floating: the hip is this far under the still surface (back just awash).
const PRONE_HIP_DROP := 0.14
const PITCH_UPRIGHT := 0.06
const PITCH_PRONE := 1.42
const PITCH_DESCENDING := 1.72
const PITCH_ASCENDING := 1.05
const PITCH_RATE := 5.0
const HIP_RATE := 9.0
const INFLUENCE_RATE := 6.0
## Logic px/s under which the swimmer counts as still (treading water).
const MOVING_SPEED := 8.0
const CRAWL_HZ_MIN := 0.55
const CRAWL_HZ_MAX := 1.0
const TREAD_HZ := 0.45
const MIN_CLEARANCE_OVER_BED := 0.22
## Camera anchor targets above the swell while floating (see MapViewRuntimeCameraFollow).
const CAMERA_ABOVE_SURFACE_THIRD := 1.7
const CAMERA_ABOVE_SURFACE_FIRST := 0.35
const CAMERA_LIFT_RATE := 6.0
## Head-submersion at which the lift has fully faded and the lens may go under.
const CAMERA_LIFT_FADE_DEPTH := 0.6
## While diving the third-person boom would still hold the lens above the water; drop the
## camera this far (world units) so a diver is actually seen from under the surface.
const CAMERA_DIVE_DROP_THIRD := 1.7
const CAMERA_DIVE_FULL_DEPTH := 1.3
const WAKE_HALF_LENGTH := 0.7
const WAKE_HALF_BEAM := 0.32
const ENTRY_SPLASH_RADIUS := 0.7
const ENTRY_SPLASH_STRENGTH := 0.035

var _model_rest := Transform3D.IDENTITY
var _model_rest_captured := false
var _pitch := PITCH_UPRIGHT
var _hip_y := 0.0
var _hip_primed := false
var _phase := 0.0
var _modifier: SwimStrokeModifier
var _previous_submersion := 0.0
var _was_in_water := false
var _previous_medium := 0
var _camera_lift := Vector3.ZERO


## Places and poses `rig` for the player's current water medium. Returns true while
## the presenter owns the rig's vertical placement and pose.
func apply(
	rig: SharedCharacterRig,
	player: CharacterBody2D,
	view: MapView3D,
	parent_offset_xz: Vector2,
	logic_speed: float,
	delta: float
) -> bool:
	var depth := float(player.call("water_depth"))
	var medium: int = player.call("water_medium")
	var local_xz := Vector2(rig.position.x, rig.position.z) - parent_offset_xz
	var surface := view.water_surface_height_at(local_xz)
	if depth <= 0.0 or is_nan(surface):
		_release(rig)
		return false
	var model := rig.get_node_or_null("Model") as Node3D
	if model == null:
		return false
	if not _model_rest_captured:
		_model_rest = model.transform
		_model_rest_captured = true
	var swimming := (
		medium == PlayerSwimState.Medium.SWIM or medium == PlayerSwimState.Medium.DIVE
	)
	# Rendered seabed under the actor: the gameplay bed sync_actor set, minus the
	# WS-13b basin the terrain mesh digs below it (depth also carries the tiny lift).
	var bed_y := rig.position.y - maxf(depth - MapViewMeshBuilderConfig.WATER_SURFACE_LIFT, 0.0)
	var moving := logic_speed > MOVING_SPEED
	var submersion := float(player.call("swim_submersion"))
	var target_pitch := PITCH_UPRIGHT
	var target_hip := bed_y + HIP_HEIGHT
	if swimming:
		var lift_rate := (submersion - _previous_submersion) / maxf(delta, 0.0001)
		if medium == PlayerSwimState.Medium.DIVE:
			target_pitch = (
				PITCH_DESCENDING if lift_rate > 0.15
				else PITCH_ASCENDING if lift_rate < -0.15
				else PITCH_PRONE
			)
		elif moving:
			target_pitch = PITCH_PRONE
		var upright_hip := maxf(surface - TREAD_FEET_DROP, bed_y) + HIP_HEIGHT
		var prone_hip := surface - PRONE_HIP_DROP - submersion
		var weight := clampf(target_pitch / PITCH_PRONE, 0.0, 1.0)
		target_hip = lerpf(upright_hip, prone_hip, weight)
		target_hip = maxf(target_hip, bed_y + MIN_CLEARANCE_OVER_BED)
	_previous_submersion = submersion
	if swimming and _hip_primed:
		_hip_y = lerpf(_hip_y, target_hip, 1.0 - exp(-HIP_RATE * delta))
	else:
		_hip_y = target_hip
	_hip_primed = swimming
	_pitch = lerpf(_pitch, target_pitch if swimming else 0.0, 1.0 - exp(-PITCH_RATE * delta))
	var pitch := _pitch
	# The rig node keeps its yaw and moves to the virtual feet position (so the camera,
	# which follows rig.position, tracks a diver). Only the Model child pitches, about
	# the hip, which keeps the health ring, equipment slots and facing logic untouched.
	rig.position.y = _hip_y - HIP_HEIGHT
	var pitch_basis := Basis(Vector3.RIGHT, pitch)
	model.transform = Transform3D(
		pitch_basis * _model_rest.basis,
		_model_rest.origin + Vector3(0.0, HIP_HEIGHT, 0.0) - pitch_basis * Vector3(0.0, HIP_HEIGHT, 0.0)
	)
	_sync_ring(rig, pitch)
	_sync_stowed_tools(rig, swimming)
	_sync_camera_lift(rig, surface, submersion, delta)
	_sync_stroke(rig, swimming, moving, medium, logic_speed, delta)
	_sync_wake(view, local_xz, player, depth, swimming, medium)
	_was_in_water = true
	_previous_medium = medium
	return true


func is_stroking() -> bool:
	return _modifier != null and _modifier.influence > 0.02


func _release(rig: SharedCharacterRig) -> void:
	_sync_stowed_tools(rig, false)
	_camera_lift = Vector3.ZERO
	if rig != null and rig.has_meta(&"camera_lift"):
		rig.remove_meta(&"camera_lift")
	if _was_in_water and rig != null:
		var model := rig.get_node_or_null("Model") as Node3D
		if model != null:
			model.transform = _model_rest
		_sync_ring(rig, 0.0)
		if _modifier != null:
			_modifier.influence = 0.0
	_was_in_water = false
	_hip_primed = false
	_pitch = PITCH_UPRIGHT
	_previous_submersion = 0.0


## ADR 0021: the hammer rides stowed on the back while swimming and cannot be used, so the
## hand slot is hidden instead of dangling through the stroke.
func _sync_stowed_tools(rig: SharedCharacterRig, stowed: bool) -> void:
	if rig == null:
		return
	var tool_node := rig.equipped(&"right_hand")
	if tool_node != null:
		tool_node.visible = not stowed


func _sync_camera_lift(
	rig: SharedCharacterRig, surface: float, submersion: float, delta: float
) -> void:
	var fade := 1.0 - clampf(submersion / CAMERA_LIFT_FADE_DEPTH, 0.0, 1.0)
	var target := Vector3(
		maxf(surface + CAMERA_ABOVE_SURFACE_THIRD - (rig.position.y + 1.15), 0.0),
		maxf(surface + CAMERA_ABOVE_SURFACE_FIRST - (rig.position.y + 1.65), 0.0),
		0.0
	) * fade
	# The orthographic camera never goes under water, so its anchor stays on the surface
	# for the whole dive; letting it sink would pan the framing across the ground plane.
	target.z = maxf(surface - rig.position.y, 0.0)
	var sunk := clampf(
		(submersion - CAMERA_LIFT_FADE_DEPTH) / (CAMERA_DIVE_FULL_DEPTH - CAMERA_LIFT_FADE_DEPTH),
		0.0,
		1.0
	)
	target.x -= CAMERA_DIVE_DROP_THIRD * sunk
	_camera_lift = _camera_lift.lerp(target, 1.0 - exp(-CAMERA_LIFT_RATE * delta))
	rig.set_meta(&"camera_lift", _camera_lift)


func _sync_ring(rig: SharedCharacterRig, pitch: float) -> void:
	# The overhead health ring is authored for an upright body.
	var ring := rig.get_node_or_null("HealthRing") as Node3D
	if ring != null:
		ring.visible = pitch < 0.4


func _sync_stroke(
	rig: SharedCharacterRig,
	swimming: bool,
	moving: bool,
	medium: int,
	logic_speed: float,
	delta: float
) -> void:
	if _modifier == null:
		var skeleton := rig.skeleton()
		if skeleton == null:
			return
		_modifier = SwimStrokeModifierScript.new()
		_modifier.name = "SwimStrokeModifier"
		_modifier.influence = 0.0
		skeleton.add_child(_modifier)
	_modifier.rig = rig.get_node_or_null("Model") as Node3D
	var crawl := swimming and (moving or medium == PlayerSwimState.Medium.DIVE)
	_modifier.style = SwimStrokeModifier.Style.CRAWL if crawl else SwimStrokeModifier.Style.TREAD
	var hz := TREAD_HZ
	if crawl:
		var speed_ratio := clampf(
			logic_speed / 80.0, 0.0, 1.0
		)
		hz = lerpf(CRAWL_HZ_MIN, CRAWL_HZ_MAX, speed_ratio)
	_phase = fposmod(_phase + TAU * hz * delta, TAU * 8.0)
	_modifier.phase = _phase
	var target := 1.0 if swimming else 0.0
	_modifier.influence = move_toward(_modifier.influence, target, INFLUENCE_RATE * delta)


func _sync_wake(
	view: MapView3D,
	local_xz: Vector2,
	player: CharacterBody2D,
	depth: float,
	swimming: bool,
	medium: int
) -> void:
	var sim := view.water_ripple_sim()
	if sim == null:
		return
	var scale := MapViewBridge.world_scale(view.definition.cell_size)
	var velocity := player.velocity * scale
	var entered := (
		not _was_in_water
		or (
			_previous_medium != medium
			and (medium == PlayerSwimState.Medium.SWIM or medium == PlayerSwimState.Medium.DIVE)
		)
	)
	if entered:
		sim.add_impulse(local_xz, ENTRY_SPLASH_RADIUS, ENTRY_SPLASH_STRENGTH)
	if velocity.length() < 0.05 and not swimming:
		return
	var reach := 1.0 if swimming else clampf(depth, 0.2, 1.0)
	sim.add_moving_body(
		local_xz, velocity, WAKE_HALF_LENGTH * reach, WAKE_HALF_BEAM * reach
	)

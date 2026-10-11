class_name HayRickReaction
extends Node3D

## A hay stack that gives under a body leaning on it (docs/SYSTEMS/FARMLAND.md).
## The walker cannot enter the stack: a logic-plane circle blocks it (CityFarmland).
## This node supplies the other half, the stack's response. When the actor presses
## against the flank, the body mesh compresses on that side, bulges across it and
## the crown leans away; on release it springs back with a short damped wobble.
## Pure presentation driven by a static actor pose, deterministic for the same
## inputs, and idle (one distance check) when nobody is near.

## How far outside the blocking radius the flank starts to yield (world metres).
const GIVE_RANGE := 0.7
## Largest compression across the push axis and crown lean (shear per metre).
const MAX_SQUASH := 0.11
const MAX_LEAN := 0.13
const SPRING := 46.0
const DAMPING := 7.5
const REST_EPSILON := 0.0008

## Actor ground position and velocity in world XZ; set once per frame by the view.
static var _actor_xz := Vector2(INF, INF)
static var _actor_velocity := Vector2.ZERO

## Blocking radius in world metres (already includes the node's scale).
var collision_radius := 1.0
## Mesh that is deformed; the ground litter next to it stays put.
var body: Node3D

var _offset := Vector2.ZERO
var _velocity := Vector2.ZERO


static func set_actor(world_xz: Vector2, velocity_xz: Vector2) -> void:
	_actor_xz = world_xz
	_actor_velocity = velocity_xz


static func clear_actor() -> void:
	_actor_xz = Vector2(INF, INF)
	_actor_velocity = Vector2.ZERO


## Target displacement (world XZ, away from the actor) for an actor at `to_actor`
## from the stack axis. Zero outside GIVE_RANGE; grows to 1 at the blocking radius.
## `closing_speed` (m/s toward the stack) adds a shove so a run shakes it harder.
static func push_target(to_actor: Vector2, radius: float, closing_speed: float) -> Vector2:
	var distance := to_actor.length()
	if distance < 0.0001:
		return Vector2.ZERO
	var depth := clampf((radius + GIVE_RANGE - distance) / GIVE_RANGE, 0.0, 1.0)
	if depth <= 0.0:
		return Vector2.ZERO
	var amount := smoothstep(0.0, 1.0, depth) * (1.0 + clampf(closing_speed, 0.0, 6.0) * 0.12)
	return -to_actor / distance * amount


func _process(delta: float) -> void:
	if body == null:
		return
	var here := Vector2(global_position.x, global_position.z)
	var to_actor := _actor_xz - here
	var target := Vector2.ZERO
	# Far-away actors (or none) leave a settled stack alone.
	if is_finite(_actor_xz.x) and to_actor.length() < collision_radius + GIVE_RANGE + 0.1:
		var closing := 0.0
		if to_actor.length() > 0.0001:
			closing = maxf(-_actor_velocity.dot(to_actor / to_actor.length()), 0.0)
		target = push_target(to_actor, collision_radius, closing)
	var settled := _offset.length() < REST_EPSILON and _velocity.length() < REST_EPSILON
	if target == Vector2.ZERO and settled:
		if _offset != Vector2.ZERO:
			_offset = Vector2.ZERO
			_velocity = Vector2.ZERO
			body.transform = Transform3D.IDENTITY
		return
	# Semi-implicit spring, clamped step so a hitch cannot blow it up.
	var step := minf(delta, 1.0 / 30.0)
	_velocity += ((target - _offset) * SPRING - _velocity * DAMPING) * step
	_offset += _velocity * step
	body.transform = Transform3D(deformation_basis(_offset, global_transform.basis), Vector3.ZERO)


## Basis of the body for a displacement `offset` (world XZ, away from the actor).
## Compresses along the push axis on the actor's side, widens across it and shears
## the crown away. `parent_basis` maps the body's local axes to world.
static func deformation_basis(offset: Vector2, parent_basis: Basis) -> Basis:
	var magnitude := offset.length()
	if magnitude < 0.00001:
		return Basis.IDENTITY
	var world_dir := Vector3(offset.x, 0.0, offset.y) / magnitude
	var local_dir := (parent_basis.inverse() * world_dir)
	local_dir.y = 0.0
	if local_dir.length_squared() < 0.000001:
		return Basis.IDENTITY
	local_dir = local_dir.normalized()
	var squash := 1.0 - MAX_SQUASH * minf(magnitude, 1.4)
	var widen := 1.0 + MAX_SQUASH * 0.5 * minf(magnitude, 1.4)
	# Scale along local_dir by `squash`, across it by `widen`.
	var across := Vector3(-local_dir.z, 0.0, local_dir.x)
	var x_axis := (
		local_dir * local_dir.dot(Vector3.RIGHT) * squash
		+ across * across.dot(Vector3.RIGHT) * widen
	)
	var z_axis := (
		local_dir * local_dir.dot(Vector3.BACK) * squash
		+ across * across.dot(Vector3.BACK) * widen
	)
	# Shear: the higher a point, the further it slides away from the actor.
	var y_axis := Vector3.UP + local_dir * MAX_LEAN * minf(magnitude, 1.4)
	return Basis(x_axis, y_axis, z_axis)

class_name MapViewGroundWander
extends RefCounted

## Shared waypoint walking for ground fauna actors (P2-024 urban, P0-106 penned).
##
## Ambient animals used to be positioned with sin/cos of an ever-growing phase,
## which made every actor slide around its home point on a fixed ellipse and read
## as "circling on the floor". Instead, an actor picks one destination inside its
## authored radius, walks there in a straight line, pauses, and picks the next
## one. All motion stays on the ground plane; the vertical component is always
## taken from the actor's home position.
##
## Everything is derived from the map seed and the placement index, so playback
## stays deterministic across runs.

const WAYPOINT_EPSILON := 0.04


## Installs walking state on an actor. Config keys:
## home (Vector3), radius (float), speed (float, 0 keeps the actor still),
## roam_scale (float share of radius used for destinations),
## pause_range (Vector2 seconds), flee_speed (float, 0 disables fleeing),
## flee_radius (float listener distance that triggers a flee).
static func setup(actor: Node3D, seed_key: StringName, index: int, config: Dictionary) -> void:
	var home: Vector3 = config.get("home", actor.position)
	var pause_range: Vector2 = config.get("pause_range", Vector2(0.9, 3.2))
	actor.set_meta(&"home", home)
	actor.set_meta(&"radius", float(config.get("radius", 1.0)))
	actor.set_meta(&"walk_speed", float(config.get("speed", 0.0)))
	actor.set_meta(&"roam_scale", float(config.get("roam_scale", 0.8)))
	actor.set_meta(&"pause_range", pause_range)
	actor.set_meta(&"flee_speed", float(config.get("flee_speed", 0.0)))
	actor.set_meta(&"flee_radius", float(config.get("flee_radius", 0.0)))
	actor.set_meta(&"placement_index", index)
	actor.set_meta(&"waypoint_index", 0)
	actor.set_meta(&"target", home)
	actor.set_meta(&"pause_remaining", _initial_pause(seed_key, index, pause_range))
	_select_next_target(actor, seed_key)


static func advance(
	actor: Node3D, seed_key: StringName, listener_position: Vector3, delta: float
) -> void:
	var home: Vector3 = actor.get_meta(&"home", actor.position)
	# Ambient fauna is a ground-only actor kit: never let a walk step introduce
	# height, otherwise animals appear to hover over the cobbles.
	actor.position.y = home.y
	var speed := float(actor.get_meta(&"walk_speed", 0.0))
	if delta <= 0.0 or speed <= 0.0:
		return

	var pause_remaining := maxf(float(actor.get_meta(&"pause_remaining", 0.0)) - delta, 0.0)
	var flee_target := _flee_target(actor, listener_position, home)
	var is_fleeing := flee_target != Vector3.INF
	if is_fleeing:
		actor.set_meta(&"target", flee_target)
		pause_remaining = 0.0
		speed = float(actor.get_meta(&"flee_speed", speed))
	actor.set_meta(&"pause_remaining", pause_remaining)
	if pause_remaining > 0.0:
		return

	var target: Vector3 = actor.get_meta(&"target", home)
	var flat_position := Vector3(actor.position.x, home.y, actor.position.z)
	var to_target := target - flat_position
	to_target.y = 0.0
	if to_target.length() <= WAYPOINT_EPSILON:
		if not is_fleeing:
			_select_next_target(actor, seed_key)
			actor.set_meta(&"pause_remaining", _pause_after_arrival(actor, seed_key))
		actor.position = flat_position
		return

	var next_position := flat_position.move_toward(target, speed * delta)
	next_position.y = home.y
	var movement := next_position - flat_position
	actor.position = next_position
	if movement.length_squared() > 0.000001:
		# Face the travel direction, not the offset from home. Facing the offset
		# was what made straight-walking animals look like they orbited a pivot.
		actor.look_at(next_position + movement.normalized(), Vector3.UP)


static func hash_seed(seed_key: StringName, placement_index: int, salt: int = 0) -> int:
	return hash([String(seed_key), placement_index, salt])


static func _select_next_target(actor: Node3D, seed_key: StringName) -> void:
	var waypoint_index := int(actor.get_meta(&"waypoint_index", 0)) + 1
	actor.set_meta(&"waypoint_index", waypoint_index)
	var home: Vector3 = actor.get_meta(&"home", actor.position)
	var radius := float(actor.get_meta(&"radius", 1.0))
	var roam_scale := float(actor.get_meta(&"roam_scale", 0.8))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash_seed(
		seed_key, int(actor.get_meta(&"placement_index", 0)), 1009 + waypoint_index * 37
	)
	var angle := rng.randf_range(0.0, TAU)
	# sqrt spreads destinations evenly over the yard instead of clustering every
	# route near its center.
	var distance := sqrt(rng.randf()) * radius * roam_scale
	actor.set_meta(&"target", home + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance))


static func _flee_target(actor: Node3D, listener_position: Vector3, home: Vector3) -> Vector3:
	var flee_radius := float(actor.get_meta(&"flee_radius", 0.0))
	if flee_radius <= 0.0 or float(actor.get_meta(&"flee_speed", 0.0)) <= 0.0:
		return Vector3.INF
	var flat_position := Vector3(actor.position.x, home.y, actor.position.z)
	var away := flat_position - Vector3(listener_position.x, home.y, listener_position.z)
	if away.length() >= flee_radius:
		return Vector3.INF
	if away.length_squared() < 0.0001:
		# Standing exactly on the listener: break the tie deterministically.
		var rng := RandomNumberGenerator.new()
		rng.seed = hash_seed(&"flee", int(actor.get_meta(&"placement_index", 0)), 31)
		var angle := rng.randf_range(0.0, TAU)
		away = Vector3(cos(angle), 0.0, sin(angle))
	var radius := float(actor.get_meta(&"radius", 1.0))
	var desired := flat_position + away.normalized() * radius
	var from_home := desired - home
	from_home.y = 0.0
	if from_home.length() > radius:
		desired = home + from_home.normalized() * radius
	return desired


static func _initial_pause(seed_key: StringName, index: int, pause_range: Vector2) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash_seed(seed_key, index, 701)
	return rng.randf_range(minf(0.2, pause_range.x), maxf(pause_range.y, 0.3))


static func _pause_after_arrival(actor: Node3D, seed_key: StringName) -> float:
	var pause_range: Vector2 = actor.get_meta(&"pause_range", Vector2(0.9, 3.2))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash_seed(
		seed_key,
		int(actor.get_meta(&"placement_index", 0)),
		2003 + int(actor.get_meta(&"waypoint_index", 0)) * 53
	)
	return rng.randf_range(pause_range.x, pause_range.y)

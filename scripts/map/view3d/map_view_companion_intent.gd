class_name MapViewCompanionIntent
extends RefCounted

## Deterministic hunt / play / groom cycles for urban cats and dogs.
##
## Authored wander used to leave companions parked on a near-static Idle clip
## for seconds at a time, which read as stuffed animals. This director keeps
## them on short purposeful legs (stalk a rat, dart at a playmate, sniff a
## yard corner) while GroundWander still owns the straight-line walk.

const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")
const GroundWander := preload("res://scripts/map/view3d/map_view_ground_wander.gd")

const INTENT_WANDER := &"wander"
const INTENT_HUNT := &"hunt"
const INTENT_PLAY := &"play"
const INTENT_GROOM := &"groom"
const INTENT_REST := &"rest"
const INTENT_INVESTIGATE := &"investigate"
const MOVING_INTENTS: Array[StringName] = [
	INTENT_WANDER,
	INTENT_HUNT,
	INTENT_PLAY,
	INTENT_INVESTIGATE,
]
const CAT_STALK_SPEED := 0.46
const CAT_PLAY_SPEED := 0.88
const DOG_PLAY_SPEED := 1.18
const DOG_INVESTIGATE_SPEED := 0.48
const HUNT_RETARGET_SEC := 1.8
const PLAY_RETARGET_SEC := 1.2


static func directs(species: StringName) -> bool:
	return species == MammalSpecies.SPECIES_CAT or species == MammalSpecies.SPECIES_DOG


static func setup(actor: Node3D, seed_key: StringName, index: int) -> void:
	var species: StringName = actor.get_meta(&"species", &"")
	if not directs(species):
		return
	actor.set_meta(&"companion_default_speed", float(actor.get_meta(&"walk_speed", 0.0)))
	actor.set_meta(&"companion_default_pause", actor.get_meta(&"pause_range", Vector2(0.5, 1.6)))
	actor.set_meta(&"companion_generation", 0)
	actor.set_meta(&"companion_retarget", 0.0)
	var authored: StringName = actor.get_meta(&"behavior", INTENT_WANDER)
	var initial := _initial_intent(authored)
	_apply_intent(actor, seed_key, index, initial, 0, [])


static func advance(
	actor: Node3D, seed_key: StringName, siblings: Array[Node3D], delta: float
) -> void:
	var species: StringName = actor.get_meta(&"species", &"")
	if not directs(species) or delta <= 0.0:
		return
	var remaining := float(actor.get_meta(&"companion_remaining", 0.0)) - delta
	if remaining <= 0.0:
		var generation := int(actor.get_meta(&"companion_generation", 0)) + 1
		var authored: StringName = actor.get_meta(&"behavior", INTENT_WANDER)
		var next := _next_intent(species, authored, seed_key, actor, generation)
		_apply_intent(
			actor,
			seed_key,
			int(actor.get_meta(&"placement_index", 0)),
			next,
			generation,
			siblings
		)
		return
	actor.set_meta(&"companion_remaining", remaining)
	var intent: StringName = actor.get_meta(&"companion_intent", INTENT_WANDER)
	if intent == INTENT_HUNT or intent == INTENT_PLAY:
		var retarget := float(actor.get_meta(&"companion_retarget", 0.0)) - delta
		if retarget <= 0.0:
			_aim_focus(actor, seed_key, siblings, intent)
			actor.set_meta(
				&"companion_retarget",
				HUNT_RETARGET_SEC if intent == INTENT_HUNT else PLAY_RETARGET_SEC
			)
		else:
			actor.set_meta(&"companion_retarget", retarget)


static func refresh_focus(
	actor: Node3D, seed_key: StringName, siblings: Array[Node3D]
) -> void:
	if not directs(actor.get_meta(&"species", &"")):
		return
	var intent: StringName = actor.get_meta(&"companion_intent", INTENT_WANDER)
	if intent == INTENT_HUNT or intent == INTENT_PLAY:
		_aim_focus(actor, seed_key, siblings, intent)


static func is_moving_intent(intent: StringName) -> bool:
	return intent in MOVING_INTENTS


static func _initial_intent(authored: StringName) -> StringName:
	match authored:
		INTENT_HUNT:
			return INTENT_HUNT
		INTENT_PLAY:
			return INTENT_PLAY
		&"idle":
			return INTENT_REST
		_:
			return INTENT_WANDER


static func _next_intent(
	species: StringName,
	authored: StringName,
	seed_key: StringName,
	actor: Node3D,
	generation: int
) -> StringName:
	var rng := RandomNumberGenerator.new()
	rng.seed = GroundWander.hash_seed(
		seed_key, int(actor.get_meta(&"placement_index", 0)), 4409 + generation * 17
	)
	var roll := rng.randf()
	var cumulative := 0.0
	var table: Array[Array] = _weights(species, authored)
	for row: Array in table:
		cumulative += float(row[1])
		if roll <= cumulative:
			return row[0]
	return INTENT_WANDER


static func _weights(species: StringName, authored: StringName) -> Array[Array]:
	if species == MammalSpecies.SPECIES_CAT:
		if authored == INTENT_HUNT:
			return [
				[INTENT_HUNT, 0.42],
				[INTENT_PLAY, 0.16],
				[INTENT_WANDER, 0.16],
				[INTENT_GROOM, 0.16],
				[INTENT_REST, 0.10],
			]
		if authored == &"idle":
			return [
				[INTENT_GROOM, 0.26],
				[INTENT_HUNT, 0.22],
				[INTENT_REST, 0.22],
				[INTENT_WANDER, 0.16],
				[INTENT_PLAY, 0.14],
			]
		return [
			[INTENT_HUNT, 0.30],
			[INTENT_WANDER, 0.22],
			[INTENT_PLAY, 0.20],
			[INTENT_GROOM, 0.18],
			[INTENT_REST, 0.10],
		]
	if authored == INTENT_PLAY:
		return [
			[INTENT_PLAY, 0.46],
			[INTENT_INVESTIGATE, 0.22],
			[INTENT_WANDER, 0.20],
			[INTENT_REST, 0.12],
		]
	return [
		[INTENT_PLAY, 0.30],
		[INTENT_WANDER, 0.28],
		[INTENT_INVESTIGATE, 0.26],
		[INTENT_REST, 0.16],
	]


static func _apply_intent(
	actor: Node3D,
	seed_key: StringName,
	index: int,
	intent: StringName,
	generation: int,
	siblings: Array[Node3D]
) -> void:
	actor.set_meta(&"companion_intent", intent)
	actor.set_meta(&"companion_generation", generation)
	actor.set_meta(&"companion_remaining", _duration(seed_key, index, generation, intent))
	actor.set_meta(&"companion_retarget", 0.0)
	var species: StringName = actor.get_meta(&"species", &"")
	var default_speed := float(actor.get_meta(&"companion_default_speed", 0.4))
	var default_pause: Vector2 = actor.get_meta(&"companion_default_pause", Vector2(0.5, 1.6))
	match intent:
		INTENT_HUNT:
			actor.set_meta(
				&"walk_speed",
				CAT_STALK_SPEED if species == MammalSpecies.SPECIES_CAT else DOG_INVESTIGATE_SPEED
			)
			actor.set_meta(&"pause_range", Vector2(0.25, 0.8))
			_aim_focus(actor, seed_key, siblings, intent)
		INTENT_PLAY:
			actor.set_meta(
				&"walk_speed",
				CAT_PLAY_SPEED if species == MammalSpecies.SPECIES_CAT else DOG_PLAY_SPEED
			)
			actor.set_meta(&"pause_range", Vector2(0.15, 0.55))
			_aim_focus(actor, seed_key, siblings, intent)
		INTENT_INVESTIGATE:
			actor.set_meta(&"walk_speed", DOG_INVESTIGATE_SPEED)
			actor.set_meta(&"pause_range", Vector2(0.7, 1.6))
			GroundWander.select_next_target(actor, seed_key)
		INTENT_GROOM, INTENT_REST:
			actor.set_meta(&"walk_speed", 0.0)
			actor.set_meta(&"pause_remaining", 0.0)
		_:
			actor.set_meta(&"walk_speed", default_speed)
			actor.set_meta(&"pause_range", default_pause)
			actor.set_meta(&"pause_remaining", 0.0)


static func _duration(
	seed_key: StringName, index: int, generation: int, intent: StringName
) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = GroundWander.hash_seed(seed_key, index, 5107 + generation * 23)
	var span := Vector2(4.4, 6.2)
	match intent:
		INTENT_PLAY:
			span = Vector2(3.2, 5.0)
		INTENT_GROOM:
			span = Vector2(3.0, 4.6)
		INTENT_REST:
			span = Vector2(2.2, 3.6)
		INTENT_INVESTIGATE:
			span = Vector2(3.8, 5.6)
		INTENT_HUNT:
			span = Vector2(4.6, 7.0)
	return rng.randf_range(span.x, span.y)


static func _aim_focus(
	actor: Node3D, seed_key: StringName, siblings: Array[Node3D], intent: StringName
) -> void:
	var species: StringName = actor.get_meta(&"species", &"")
	var wanted: Array[StringName] = [MammalSpecies.SPECIES_RAT]
	if intent == INTENT_PLAY:
		wanted = [MammalSpecies.SPECIES_CAT, MammalSpecies.SPECIES_DOG]
	var focus := _nearest_focus(actor, siblings, wanted)
	var home: Vector3 = actor.get_meta(&"home", actor.position)
	var aim := home
	if focus != null:
		aim = focus.position
		if intent == INTENT_PLAY and int(actor.get_meta(&"companion_generation", 0)) % 2 == 1:
			# Odd play legs dart away so two dogs do not merge into one pile.
			aim = home + (home - focus.position)
	else:
		aim = _seeded_yard_point(actor, seed_key, 7919 if intent == INTENT_HUNT else 8039)
	GroundWander.aim_toward(actor, aim)


static func _nearest_focus(
	actor: Node3D, siblings: Array[Node3D], species_filter: Array[StringName]
) -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	var origin := Vector2(actor.position.x, actor.position.z)
	for other in siblings:
		if other == actor or not is_instance_valid(other):
			continue
		var other_species: StringName = other.get_meta(&"species", &"")
		if other_species not in species_filter:
			continue
		var distance := origin.distance_to(Vector2(other.position.x, other.position.z))
		if distance < best_distance:
			best = other
			best_distance = distance
	return best


static func _seeded_yard_point(actor: Node3D, seed_key: StringName, salt: int) -> Vector3:
	var home: Vector3 = actor.get_meta(&"home", actor.position)
	var radius := float(actor.get_meta(&"radius", 1.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = GroundWander.hash_seed(
		seed_key,
		int(actor.get_meta(&"placement_index", 0)),
		salt + int(actor.get_meta(&"companion_generation", 0)) * 41
	)
	var angle := rng.randf_range(0.0, TAU)
	var distance := sqrt(rng.randf()) * radius * 0.78
	return home + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)

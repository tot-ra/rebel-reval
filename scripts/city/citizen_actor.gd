class_name CitizenActor
extends CharacterBody2D

## One census resident in the seamless city (docs/SYSTEMS/CITIZENS.md). Logic
## body only: MapViewRuntime mirrors the rig. The position is not simulated, it is
## read from the roster's timetable every physics frame, so the resident is
## always where the hour says (door, workplace, mid-street). At home in a
## furnished house (CityInteriors) the resident is shown inside: walking in
## from the door, then asleep in bed, seated at the table, at the hearth, at the
## workbench or standing about (docs/SYSTEMS/HOUSEHOLDS.md).

const PerfProbeScript := preload("res://scripts/debug/perf_probe.gd")
const VARIANTS_DIR := "res://assets/characters/variants/%s.tscn"
## Sit_Chair_Idle on the shared rig (see CitySiteActor): the hips sit SIT_BACK
## behind the origin and the thighs SIT_SURFACE above it.
const SIT_BACK := 0.44
const SIT_SURFACE := 0.95
## A lying body's back rests this far above the bed's top.
const LIE_LIFT := 0.12
const POSE_ANIMATION := {
	&"walk": &"walk", &"sit": &"sit_idle", &"sleep": &"idle", &"stand": &"idle",
	&"hearth": &"idle", &"work": &"idle",
}

var rig_scene: PackedScene
var roster: CitizenRoster
var index := -1
var record: Dictionary = {}
## Callable returning the current hour 0..24.
var hour_source: Callable
## False once the resident has gone indoors; CityCitizens then frees the body
## unless their house is furnished and they are shown at home.
var outdoors := true
## Shown inside their furnished house (CityInteriors.indoor_state).
var at_home := false
## Indoor pose: walk, sleep, sit, stand, hearth, work.
var pose: StringName = &"walk"
var pose_h := 0.0
## On the way home from the woodyard with an armful of firewood.
var carrying_wood := false
var rig_styled := false
## CityInteriors of the scene, or null (then residents vanish at their door).
var interiors: CityInteriors

## Physical fight state (R-1756), or null for a peaceful resident. CityCitizens
## owns it so it survives the body being pooled away.
var brawler: CitizenBrawler
## Health and stamina for the overhead bars (MapViewRuntimeActors reads these).
var health: float:
	get:
		return brawler.vitals.health if brawler != null else 0.0
var max_health: float:
	get:
		return brawler.vitals.max_health if brawler != null else 0.0
var stamina: float:
	get:
		return brawler.vitals.stamina if brawler != null else 0.0
var max_stamina: float:
	get:
		return brawler.vitals.max_stamina if brawler != null else 0.0
## Callable(actor, amount, attacker, swing_id, pierces_guard) -> float, set by CityCitizens.
var hit_handler: Callable

## R-1887: a conversation or spirit duel holds the person where they stand, turned to the
## hero (`toward`, a logic-plane body); the clock takes over again on release. A spirit duel
## may move the held body itself (SpiritArenaMotion); holding never fights it.
var held_for_talk := false
var _held_toward: Node2D
var _facing := Vector2.DOWN
var _moving := false
## Sideways give-way from the player (CrowdYield), on top of the scheduled spot.
var _yield := Vector2.ZERO
var _player: CharacterBody2D


static func create(citizen_roster: CitizenRoster, resident: int, hours: Callable) -> CitizenActor:
	var actor := CitizenActor.new()
	actor.roster = citizen_roster
	actor.index = resident
	actor.record = citizen_roster.residents[resident]
	actor.hour_source = hours
	actor.name = "Citizen_%s" % String(actor.record["id"]).replace(".", "_")
	actor.rig_scene = load(VARIANTS_DIR % String(actor.record["body"]))
	var state := citizen_roster.resolve(resident, float(hours.call()))
	actor.global_position = CityPlan.to_logic(state["pos"])
	actor._facing = state["facing"]
	return actor


func _ready() -> void:
	CollisionLayers.apply_crowd(self)
	add_to_group(&"map_view_actor")
	add_to_group(&"city_citizen")
	# A real swing or arrow can hit a peaceful resident, but clicks and soft-lock
	# ignore bystanders (MeleeAttackResolver.BYSTANDER_GROUP).
	add_to_group(MeleeAttackResolver.BYSTANDER_GROUP)
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 8.0 * float(record["height_scale"])
	capsule.height = 18.0 * float(record["height_scale"])
	shape.shape = capsule
	add_child(shape)



func _physics_process(delta: float) -> void:
	var probe_start := PerfProbeScript.start()
	_physics_process_timed(delta)
	PerfProbeScript.stop(&"citizen_physics", probe_start)


func _physics_process_timed(delta: float) -> void:
	var h := float(hour_source.call())
	var state := roster.resolve(index, h)
	if brawler != null and brawler.owns_motion():
		_step_brawl(delta, CityPlan.to_logic(state["pos"]))
		return
	if _step_held():
		return
	outdoors = state["visible"]
	carrying_wood = state["moving"] and state["dest"] == "home" and state["from"] == "fuel"
	var moving: bool = state["moving"]
	var pos: Vector2 = state["pos"]
	var facing: Vector2 = state["facing"]
	at_home = false
	pose = &"walk"
	pose_h = 0.0
	if not outdoors and interiors != null and state["dest"] == "home":
		var inside := interiors.indoor_state(index, h, float(state["arrived"]))
		if not inside.is_empty():
			at_home = true
			pose = inside["pose"]
			pose_h = float(inside["h"])
			moving = inside["moving"]
			facing = inside["facing"]
			pos = inside["pos"]
			if pose == &"sit":
				pos += facing * SIT_BACK
	_set_solid(outdoors)
	var logic := CityPlan.to_logic(pos)
	# Only people in the open make way; residents shown at home keep their bed/bench.
	if _player == null or not is_instance_valid(_player):
		_player = CrowdYield.find_player(get_tree())
	if _player != null and outdoors and not at_home:
		_yield = CrowdYield.step_offset(_yield, logic, _player.global_position, _player.velocity, delta)
	else:
		_yield = _yield.move_toward(Vector2.ZERO, CrowdYield.EASE_SPEED * delta)
	logic += _yield
	velocity = (logic - global_position) / maxf(delta, 0.0001)
	global_position = logic
	_moving = moving and velocity.length_squared() > 4.0
	if moving or velocity.length_squared() < 4.0:
		_facing = facing


## The fight, not the timetable, moves the resident: chase, retreat or run in the
## open, colliding with walls; a fallen body lies where it fell.
func _step_brawl(delta: float, home: Vector2) -> void:
	outdoors = true
	at_home = false
	pose = &"walk"
	_yield = Vector2.ZERO
	brawler.position = global_position
	var wanted := brawler.step(delta, _brawl_target(), home)
	if brawler.is_down():
		_set_solid(false)
		velocity = Vector2.ZERO
		_moving = false
		_facing = brawler.facing
		_sync_brawl_groups()
		return
	_set_solid(true)
	collision_mask = CollisionLayers.MASK_WORLD
	velocity = wanted
	move_and_slide()
	brawler.position = global_position
	_moving = not wanted.is_zero_approx()
	_facing = brawler.facing
	# A man who gave up the fight is a bystander again on his way home.
	_sync_brawl_groups()
	if not brawler.owns_motion():
		# Back on the timetable: the crowd masks nothing again (CrowdYield).
		collision_mask = 0


func _brawl_target() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_player = CrowdYield.find_player(get_tree())
	return _player


## Melee and arrow contract (MeleeAttackResolver, ArrowProjectile).
func take_damage(
	amount: float,
	source: Node = null,
	_damage_type: StringName = &"",
	swing_id: int = 0,
	pierces_guard: bool = false
) -> float:
	if not hit_handler.is_valid():
		return 0.0
	var dealt := float(hit_handler.call(self, amount, source as Node2D, swing_id, pierces_guard))
	_sync_brawl_groups()
	return dealt


## A resident who fights back is a hostile target (clicks, soft-lock); one who runs,
## walks home or lies fallen stays a bystander.
func _sync_brawl_groups() -> void:
	var hostile := brawler != null and brawler.mode == CitizenBrawler.Mode.FIGHT
	if hostile and not is_in_group(MeleeAttackResolver.DAMAGEABLE_GROUP):
		add_to_group(MeleeAttackResolver.DAMAGEABLE_GROUP)
		remove_from_group(MeleeAttackResolver.BYSTANDER_GROUP)
	elif not hostile and is_in_group(MeleeAttackResolver.DAMAGEABLE_GROUP):
		remove_from_group(MeleeAttackResolver.DAMAGEABLE_GROUP)
		add_to_group(MeleeAttackResolver.BYSTANDER_GROUP)


func is_combat_dead() -> bool:
	return brawler != null and brawler.is_down()


## PhysicalBlowGuilt: a resident struck before turning on the hero is a provoked
## (or, unarmed, an unarmed-victim) blow.
func guilt_context() -> Dictionary:
	return {
		"id": String(record.get("id", name)),
		"aggressor": brawler != null and brawler.aggressor,
		"armed": brawler != null and brawler.armed,
		"defending_other": false,
	}


func hold_for_talk(toward: Node2D) -> void:
	held_for_talk = true
	_held_toward = toward


func release_talk() -> void:
	held_for_talk = false
	_held_toward = null


## Standing still, turned to the hero. True while held.
func _step_held() -> bool:
	if not held_for_talk:
		return false
	velocity = Vector2.ZERO
	_moving = false
	if not is_instance_valid(_held_toward):
		return true
	var toward := _held_toward.global_position - global_position
	if toward.length_squared() > 1.0:
		_facing = toward.normalized()
	return true


func world_xz() -> Vector2:
	return CityPlan.to_world_xz(global_position)


func view_facing() -> Vector2:
	return _facing


func view_animation() -> StringName:
	if brawler != null and brawler.owns_motion():
		return brawler.view_animation()
	if at_home and not _moving:
		return POSE_ANIMATION.get(pose, &"idle")
	return &"walk" if _moving else &"idle"


## Seats the sit pose on its bench and lays a sleeper on the bed (MapViewRuntimeActors).
func view_height_offset() -> float:
	if not at_home:
		return 0.0
	match pose:
		&"sit":
			return pose_h - SIT_SURFACE
		&"sleep":
			return pose_h + LIE_LIFT
	return 0.0


func is_lying() -> bool:
	return at_home and pose == &"sleep"


## People at home do not block Kalev (they sit on benches and lie in beds).
func _set_solid(solid: bool) -> void:
	var shape := get_child(0) as CollisionShape2D if get_child_count() > 0 else null
	if shape != null and shape.disabled == solid:
		shape.set_deferred(&"disabled", not solid)

class_name CitizenBrawler
extends RefCounted

## One census resident caught in a physical fight with the hero (task R-1756,
## docs/SYSTEMS/COMBAT.md "Brawls with citizens"). Created lazily on the first blow,
## so a peaceful crowd costs nothing. Health and stamina come from the roster
## (age, sex, build, trade, duty kit). Able-bodied men and armed watchmen fight back
## through the shared EnemyCombatStateMachine; everyone else runs. At 0 health the
## person falls and stays down for the session. CityCitizens keeps the brawler
## while the body is pooled away, so a wounded or fallen resident stays that way.

enum Mode { CALM, FIGHT, FLEE, RETURN, DOWN }

## Logic px per second (32 px = 1 m). The hero runs at 180, so he can catch anyone.
const CHASE_SPEED := 125.0
const RETREAT_SPEED := 110.0
const FLEE_SPEED := 150.0
const RETURN_SPEED := 45.0
## A fleeing resident stops running this far from the hero or after FLEE_SEC.
const FLEE_SAFE_PX := 320.0
const FLEE_SEC := 7.0
const RETURN_ARRIVE_PX := 6.0
const STAMINA_REGEN_PER_SEC := 6.0
const HEALTH_REGEN_PER_SEC := 0.4
## Trades whose daily work builds a stronger body (more health, harder blows).
const HEAVY_TRADES: Array[String] = [
	"smith", "blacksmith", "brickmaker", "mason", "carpenter", "porter", "butcher",
	"fisherman", "cooper", "stonemason", "carter", "boatman", "dockworker", "farrier",
]

var index := -1
var mode: Mode = Mode.CALM
var vitals := CombatVitals.new()
var machine := EnemyCombatStateMachine.new()
var fights := false
## Logic position while the fight (or the fallen body) owns the resident.
var position := Vector2.ZERO
var facing := Vector2.DOWN
## True once the resident had already turned on the hero before a later blow.
var aggressor := false
var armed := false
var _flee_sec := 0.0
var _swing_counter := 0
var _moving := false
## Set by the machine's attack_impact during a tick; the blow lands after it.
var _strike_due := false


static func create(resident_index: int, record: Dictionary) -> CitizenBrawler:
	var brawler := CitizenBrawler.new()
	brawler.index = resident_index
	var stats := stats_for(record)
	brawler.fights = bool(stats["fights"])
	brawler.armed = bool(stats["armed"])
	brawler.vitals.configure(stats["health"], stats["health"], stats["stamina"], stats["stamina"])
	brawler.machine.configure(archetype_for(stats))
	# A method Callable keeps no strong reference, so brawler and machine do not cycle.
	brawler.machine.attack_impact.connect(brawler._on_attack_impact)
	# Unique per resident so two brawlers never share a swing id with the player's.
	brawler._swing_counter = 500000 + resident_index * 1000
	return brawler


## Deterministic body stats from a roster record.
static func stats_for(record: Dictionary) -> Dictionary:
	var age := int(record.get("age", 30))
	var male := String(record.get("sex", "m")) == "m"
	var build := String((record.get("appearance", {}) as Dictionary).get("build", "average"))
	var trade := String(record.get("trade", "")).to_lower()
	var duty: Dictionary = record.get("duty", {})
	var kit := String(duty.get("kit", ""))
	var armed_kit := kit in ["watch", "crown", "sergeant"]
	var health := 60.0 if male else 45.0
	var stamina := 50.0
	if age < 14:
		health = 25.0
		stamina = 30.0
	elif age > 60:
		health -= 20.0
		stamina -= 15.0
	match build:
		"heavy", "stout", "broad":
			health += 10.0
		"thin", "slight":
			health -= 5.0
	var strong := false
	for heavy: String in HEAVY_TRADES:
		if trade.contains(heavy):
			strong = true
			break
	if strong:
		health += 10.0
		stamina += 10.0
	if armed_kit:
		health += 15.0
	var fights := armed_kit or (male and age >= 16 and age <= 55)
	return {
		"health": health,
		"stamina": stamina,
		"fights": fights,
		"armed": armed_kit,
		"strong": strong,
		"weapon": String(CitizenGear.KITS.get(kit, {}).get("hand", "")) if armed_kit else "",
	}


## A townsman's fight: unarmed punches, or the watch kit's spear or sword.
static func archetype_for(stats: Dictionary) -> EnemyArchetype:
	var profile := EnemyArchetype.new()
	profile.id = &"enemy.townsman"
	profile.display_label = "Townsman"
	profile.detect_radius = 200.0
	profile.engage_radius = 80.0
	profile.lose_sight_radius = 320.0
	profile.retreat_health_ratio = 0.25
	profile.cornered_radius = 34.0
	profile.detect_duration_sec = 0.25
	profile.telegraph_duration_sec = 0.5
	profile.attack_duration_sec = 0.6
	profile.attack_impact_sec = 0.24
	profile.react_duration_sec = 0.35
	profile.disengage_duration_sec = 0.6
	profile.attack_damage = 8.0 if bool(stats.get("strong", false)) else 6.0
	profile.attack_reach_px = 40.0
	profile.attack_stamina_cost = 8.0
	profile.attack_damage_type = &"blunt"
	profile.attack_animation = &"unarmed_attack"
	match String(stats.get("weapon", "")):
		"spear":
			profile.attack_damage = 11.0
			profile.attack_reach_px = 70.0
			profile.attack_damage_type = &"pierce"
			profile.attack_animation = &"spear_attack"
		"sword":
			profile.attack_damage = 12.0
			profile.attack_reach_px = 56.0
			profile.attack_damage_type = &"slash"
			profile.attack_animation = &"sword_attack"
	return profile


func is_down() -> bool:
	return mode == Mode.DOWN


## True while the brawl, not the timetable, moves the resident.
func owns_motion() -> bool:
	return mode != Mode.CALM


## Shows the overhead health and stamina bars.
func shows_bars() -> bool:
	return mode == Mode.FIGHT or mode == Mode.FLEE


## Resolves a blow on the resident and turns them on (or away from) `attacker`.
## Returns the health damage dealt.
func take_hit(
	amount: float, attacker: Node2D, from_position: Vector2, swing_id: int, pierces_guard: bool
) -> float:
	if mode == Mode.DOWN:
		return 0.0
	if mode == Mode.CALM or mode == Mode.RETURN:
		position = from_position
	aggressor = mode == Mode.FIGHT and machine.state != EnemyCombatState.State.PATROL
	var result := vitals.resolve_hit(amount, CombatDefensePose.open(), swing_id, pierces_guard)
	if result.died:
		_fall()
		return result.health_damage
	if fights:
		mode = Mode.FIGHT
		if attacker != null:
			machine.set_perception(true, from_position.distance_to(attacker.global_position))
		machine.set_health_ratio(vitals.health / maxf(1.0, vitals.max_health))
		machine.apply_hit()
	else:
		mode = Mode.FLEE
		_flee_sec = 0.0
	return result.health_damage


## One step of the fight. `home` is where the timetable wants the resident now
## (logic px); `target` is the hero. Returns the velocity to apply.
func step(delta: float, target: Node2D, home: Vector2) -> Vector2:
	vitals.tick(delta)
	_moving = false
	match mode:
		Mode.FIGHT:
			return _step_fight(delta, target)
		Mode.FLEE:
			return _step_flee(delta, target)
		Mode.RETURN:
			return _step_return(delta, home)
	return Vector2.ZERO


func view_animation() -> StringName:
	match mode:
		Mode.DOWN:
			return &"fall"
		Mode.FLEE:
			return &"run"
		Mode.RETURN:
			return &"walk" if _moving else &"idle"
		Mode.FIGHT:
			match machine.state:
				EnemyCombatState.State.ATTACK:
					return machine.archetype.attack_animation
				EnemyCombatState.State.REACT:
					return &"hit"
				EnemyCombatState.State.TELEGRAPH:
					return &"guard"
				EnemyCombatState.State.CHASE, EnemyCombatState.State.RETREAT:
					return &"run" if _moving else &"idle"
	return &"idle"


func _step_fight(delta: float, target: Node2D) -> Vector2:
	if target == null or not is_instance_valid(target) or _target_dead(target):
		machine.force_disengage()
		_end_fight()
		return Vector2.ZERO
	var to_target := target.global_position - position
	var distance := to_target.length()
	machine.set_perception(true, distance)
	machine.set_health_ratio(vitals.health / maxf(1.0, vitals.max_health))
	_strike_due = false
	machine.tick(delta)
	if distance > 1.0:
		facing = to_target / distance
	if _strike_due:
		_strike(target, distance)
	if machine.state != EnemyCombatState.State.ATTACK:
		vitals.stamina = minf(vitals.max_stamina, vitals.stamina + STAMINA_REGEN_PER_SEC * delta)
	match machine.state:
		EnemyCombatState.State.CHASE:
			_moving = true
			return facing * CHASE_SPEED
		EnemyCombatState.State.RETREAT:
			_moving = true
			return -facing * RETREAT_SPEED
		EnemyCombatState.State.PATROL, EnemyCombatState.State.DISENGAGE:
			if machine.state == EnemyCombatState.State.PATROL:
				_end_fight()
	return Vector2.ZERO


func _on_attack_impact() -> void:
	_strike_due = true


func _strike(target: Node2D, distance: float) -> void:
	var profile := machine.current_attack_profile()
	if vitals.stamina < machine.archetype.attack_stamina_cost:
		return
	vitals.stamina -= machine.archetype.attack_stamina_cost
	if distance > profile.reach_px or not target.has_method("take_damage"):
		return
	_swing_counter += 1
	target.call("take_damage", profile.damage, null, profile.damage_type, _swing_counter, false)


func _step_flee(delta: float, target: Node2D) -> Vector2:
	_flee_sec += delta
	var away := facing
	if target != null and is_instance_valid(target):
		var offset := position - target.global_position
		if offset.length() >= FLEE_SAFE_PX:
			_flee_sec = FLEE_SEC
		if offset.length_squared() > 1.0:
			away = offset.normalized()
	vitals.stamina = maxf(0.0, vitals.stamina - delta * 2.0)
	if _flee_sec >= FLEE_SEC:
		mode = Mode.RETURN
		return Vector2.ZERO
	facing = away
	_moving = true
	return away * FLEE_SPEED


func _step_return(delta: float, home: Vector2) -> Vector2:
	vitals.stamina = minf(vitals.max_stamina, vitals.stamina + STAMINA_REGEN_PER_SEC * delta)
	vitals.heal(HEALTH_REGEN_PER_SEC * delta)
	var to_home := home - position
	if to_home.length() <= RETURN_ARRIVE_PX:
		mode = Mode.CALM
		return Vector2.ZERO
	facing = to_home.normalized()
	_moving = true
	return facing * RETURN_SPEED


func _end_fight() -> void:
	machine.reset()
	mode = Mode.RETURN


func _fall() -> void:
	mode = Mode.DOWN
	machine.mark_dead()


static func _target_dead(target: Node2D) -> bool:
	return target.has_method("is_combat_dead") and bool(target.call("is_combat_dead"))

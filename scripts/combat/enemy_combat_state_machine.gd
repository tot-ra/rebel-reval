class_name EnemyCombatStateMachine
extends RefCounted

## Shared enemy AI loop. Controllers use the same readable patrol -> detect ->
## chase -> telegraph -> attack -> react/retreat -> disengage phases.

signal state_changed(previous: EnemyCombatState.State, current: EnemyCombatState.State)
signal attack_impact
signal detected
signal telegraphed
signal disengaged
signal died

var archetype: EnemyArchetype = EnemyArchetype.watchman()
var state: EnemyCombatState.State = EnemyCombatState.State.PATROL
var state_elapsed_sec: float = 0.0

## Abstract distance to the current hostile target. INF means no target.
var target_distance: float = INF
var target_in_sight: bool = false
var health_ratio: float = 1.0

var _attack_impact_emitted := false
var _dead := false


func configure(next_archetype: EnemyArchetype) -> void:
	archetype = next_archetype if next_archetype != null else EnemyArchetype.watchman()
	reset()


func reset() -> void:
	_dead = false
	_attack_impact_emitted = false
	target_distance = INF
	target_in_sight = false
	health_ratio = 1.0
	_set_state(EnemyCombatState.State.PATROL)


func tick(delta: float) -> void:
	if delta <= 0.0 or _dead:
		return
	state_elapsed_sec += delta
	match state:
		EnemyCombatState.State.PATROL:
			_tick_patrol()
		EnemyCombatState.State.DETECT:
			_tick_detect()
		EnemyCombatState.State.CHASE:
			_tick_chase()
		EnemyCombatState.State.TELEGRAPH:
			_tick_telegraph()
		EnemyCombatState.State.ATTACK:
			_tick_attack()
		EnemyCombatState.State.REACT:
			_tick_react()
		EnemyCombatState.State.RETREAT:
			_tick_retreat()
		EnemyCombatState.State.DISENGAGE:
			_tick_disengage()
		EnemyCombatState.State.DEAD:
			pass


func set_health_ratio(value: float) -> void:
	health_ratio = clampf(value, 0.0, 1.0)


func set_perception(in_sight: bool, distance: float) -> void:
	target_in_sight = in_sight
	if in_sight:
		target_distance = maxf(0.0, distance)
	else:
		target_distance = INF


func clear_target() -> void:
	set_perception(false, INF)


func apply_hit() -> void:
	if _dead or state == EnemyCombatState.State.DEAD:
		return
	if state == EnemyCombatState.State.DISENGAGE or state == EnemyCombatState.State.PATROL:
		# Surprise hit on patrol jumps straight into detect, then combat.
		_set_state(EnemyCombatState.State.DETECT)
		return
	# After stagger, recalculate whether to fight, chase, or retreat.
	_set_state(EnemyCombatState.State.REACT)


func mark_dead() -> void:
	if _dead:
		return
	_dead = true
	_set_state(EnemyCombatState.State.DEAD)
	died.emit()


func force_disengage() -> void:
	if _dead or state == EnemyCombatState.State.DEAD:
		return
	_set_state(EnemyCombatState.State.DISENGAGE)


func is_dead() -> bool:
	return _dead or state == EnemyCombatState.State.DEAD


func current_attack_profile() -> AttackProfile:
	return archetype.make_attack_profile()


func _tick_patrol() -> void:
	if _can_detect_target():
		_set_state(EnemyCombatState.State.DETECT)


func _tick_detect() -> void:
	if _should_lose_target():
		_set_state(EnemyCombatState.State.DISENGAGE)
		return
	if state_elapsed_sec < archetype.detect_duration_sec:
		return
	_set_state(_desired_engagement_state())


func _tick_chase() -> void:
	if _should_lose_target():
		_set_state(EnemyCombatState.State.DISENGAGE)
		return
	var desired := _desired_engagement_state()
	if desired != EnemyCombatState.State.CHASE:
		_set_state(desired)


func _tick_telegraph() -> void:
	if _should_lose_target():
		_set_state(EnemyCombatState.State.DISENGAGE)
		return
	var desired := _desired_engagement_state()
	if desired == EnemyCombatState.State.RETREAT or desired == EnemyCombatState.State.CHASE:
		_set_state(desired)
		return
	if state_elapsed_sec >= archetype.telegraph_duration_sec:
		_set_state(EnemyCombatState.State.ATTACK)


func _tick_attack() -> void:
	if not _attack_impact_emitted and state_elapsed_sec >= archetype.attack_impact_sec:
		_attack_impact_emitted = true
		attack_impact.emit()
	if state_elapsed_sec < archetype.attack_duration_sec:
		return
	_set_state(_desired_engagement_state())


func _tick_react() -> void:
	if state_elapsed_sec >= archetype.react_duration_sec:
		if _should_lose_target():
			_set_state(EnemyCombatState.State.DISENGAGE)
		else:
			_set_state(_desired_engagement_state())


func _tick_retreat() -> void:
	if _should_lose_target():
		_set_state(EnemyCombatState.State.DISENGAGE)
		return
	# A cornered wounded enemy fights instead of oscillating between retreat and attack.
	if target_distance <= archetype.cornered_radius:
		_set_state(EnemyCombatState.State.TELEGRAPH)


func _tick_disengage() -> void:
	if _can_detect_target() and state_elapsed_sec >= archetype.disengage_duration_sec * 0.35:
		# Re-acquire mid-disengage if the target stays inside detect radius.
		_set_state(EnemyCombatState.State.DETECT)
		return
	if state_elapsed_sec >= archetype.disengage_duration_sec:
		clear_target()
		_set_state(EnemyCombatState.State.PATROL)


func _can_detect_target() -> bool:
	return target_in_sight and target_distance <= archetype.detect_radius


func _target_still_engaged() -> bool:
	return target_in_sight and target_distance <= archetype.engage_radius


func _desired_engagement_state() -> EnemyCombatState.State:
	if health_ratio <= archetype.retreat_health_ratio and target_distance > archetype.cornered_radius:
		return EnemyCombatState.State.RETREAT
	if target_distance > archetype.attack_reach_px:
		return EnemyCombatState.State.CHASE
	return EnemyCombatState.State.TELEGRAPH


func _should_lose_target() -> bool:
	if not target_in_sight:
		return true
	return target_distance > archetype.lose_sight_radius


func _set_state(next: EnemyCombatState.State) -> void:
	if state == next and next != EnemyCombatState.State.PATROL:
		state_elapsed_sec = 0.0
		if next == EnemyCombatState.State.ATTACK:
			_attack_impact_emitted = false
		return
	var previous := state
	state = next
	state_elapsed_sec = 0.0
	if next == EnemyCombatState.State.ATTACK:
		_attack_impact_emitted = false
	state_changed.emit(previous, next)
	match next:
		EnemyCombatState.State.DETECT:
			if previous != EnemyCombatState.State.DETECT:
				detected.emit()
		EnemyCombatState.State.TELEGRAPH:
			if previous != EnemyCombatState.State.TELEGRAPH:
				telegraphed.emit()
		EnemyCombatState.State.DISENGAGE:
			if previous != EnemyCombatState.State.DISENGAGE:
				disengaged.emit()
		_:
			pass

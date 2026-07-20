class_name CombatVitals
extends RefCounted

## Shared health/stamina/death and incoming-hit resolution for player and combat actors.
## Attack profiles stay separate; this owns only defensive resolution contracts from P1-024c.

signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal died
signal hit_resolved(result: CombatHitResult)

const DEFAULT_PARRY_WINDOW_SEC := 0.18
const DEFAULT_HIT_INVULNERABILITY_SEC := 0.35
const DEFAULT_GUARD_STAMINA_PER_DAMAGE := 1.0
const DEFAULT_PARRY_STAMINA_COST := 0.0

var health: float = 100.0
var max_health: float = 100.0
var stamina: float = 100.0
var max_stamina: float = 100.0

var hit_invulnerability_sec: float = DEFAULT_HIT_INVULNERABILITY_SEC
var parry_window_sec: float = DEFAULT_PARRY_WINDOW_SEC
var guard_stamina_per_damage: float = DEFAULT_GUARD_STAMINA_PER_DAMAGE
var parry_stamina_cost: float = DEFAULT_PARRY_STAMINA_COST

var _invuln_remaining_sec: float = 0.0
var _dead: bool = false
## Swing ids already applied to this actor. Prevents duplicate damage from one melee pulse.
var _resolved_swing_ids: Dictionary = {}


func configure(
	current_health: float,
	health_cap: float,
	current_stamina: float,
	stamina_cap: float
) -> void:
	max_health = maxf(0.0, health_cap)
	max_stamina = maxf(0.0, stamina_cap)
	health = clampf(current_health, 0.0, max_health)
	stamina = clampf(current_stamina, 0.0, max_stamina)
	_dead = health <= 0.0 and max_health > 0.0
	_invuln_remaining_sec = 0.0
	_resolved_swing_ids.clear()


func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	_invuln_remaining_sec = maxf(0.0, _invuln_remaining_sec - delta)


func is_dead() -> bool:
	return _dead


func is_hit_invulnerable() -> bool:
	return _invuln_remaining_sec > 0.0


func reset_swing_tracking() -> void:
	_resolved_swing_ids.clear()


func resolve_hit(
	amount: float,
	pose: CombatDefensePose = null,
	swing_id: int = 0
) -> CombatHitResult:
	var defense := pose if pose != null else CombatDefensePose.open()
	if amount <= 0.0:
		return _finish(CombatHitResult.make(CombatHitResult.OUTCOME_IGNORED, amount, 0.0, 0.0, false, swing_id))
	# External health restores (tests/debug) may raise health after death; trust the
	# live health value rather than a sticky dead flag alone.
	if health <= 0.0:
		_dead = true
		return _finish(CombatHitResult.make(CombatHitResult.OUTCOME_IGNORED, amount, 0.0, 0.0, true, swing_id))
	_dead = false
	if swing_id > 0 and _resolved_swing_ids.has(swing_id):
		return _finish(CombatHitResult.make(CombatHitResult.OUTCOME_IGNORED, amount, 0.0, 0.0, false, swing_id))
	if defense.is_action_invulnerable or is_hit_invulnerable():
		_mark_swing(swing_id)
		return _finish(CombatHitResult.make(CombatHitResult.OUTCOME_INVULNERABLE, amount, 0.0, 0.0, false, swing_id))

	if defense.is_parry_window():
		var parry_stamina := minf(stamina, maxf(0.0, parry_stamina_cost))
		stamina = maxf(0.0, stamina - parry_stamina)
		_mark_swing(swing_id)
		_begin_hit_invulnerability()
		stamina_changed.emit(stamina, max_stamina)
		return _finish(CombatHitResult.make(
			CombatHitResult.OUTCOME_PARRIED,
			amount,
			0.0,
			parry_stamina,
			false,
			swing_id
		))

	if defense.is_guarding:
		return _resolve_guarded(amount, swing_id)

	return _resolve_open_hit(amount, swing_id)


func _resolve_guarded(amount: float, swing_id: int) -> CombatHitResult:
	var stamina_need := amount * maxf(0.0, guard_stamina_per_damage)
	var stamina_taken := minf(stamina, stamina_need)
	stamina = maxf(0.0, stamina - stamina_taken)
	var uncovered := 0.0
	if stamina_need > stamina_taken and guard_stamina_per_damage > 0.0:
		uncovered = (stamina_need - stamina_taken) / guard_stamina_per_damage
	var health_taken := 0.0
	var became_dead := false
	if uncovered > 0.0:
		var previous_health := health
		health = clampf(health - uncovered, 0.0, max_health)
		health_taken = previous_health - health
		became_dead = _check_death()
		health_changed.emit(health, max_health)
	_mark_swing(swing_id)
	_begin_hit_invulnerability()
	stamina_changed.emit(stamina, max_stamina)
	return _finish(CombatHitResult.make(
		CombatHitResult.OUTCOME_GUARDED,
		amount,
		health_taken,
		stamina_taken,
		became_dead,
		swing_id
	))


func _resolve_open_hit(amount: float, swing_id: int) -> CombatHitResult:
	var previous_health := health
	health = clampf(health - amount, 0.0, max_health)
	var health_taken := previous_health - health
	var became_dead := _check_death()
	_mark_swing(swing_id)
	_begin_hit_invulnerability()
	health_changed.emit(health, max_health)
	return _finish(CombatHitResult.make(
		CombatHitResult.OUTCOME_HIT,
		amount,
		health_taken,
		0.0,
		became_dead,
		swing_id
	))


func _check_death() -> bool:
	if _dead:
		return true
	if health > 0.0:
		return false
	_dead = true
	died.emit()
	return true


func _begin_hit_invulnerability() -> void:
	_invuln_remaining_sec = maxf(_invuln_remaining_sec, hit_invulnerability_sec)


func _mark_swing(swing_id: int) -> void:
	if swing_id > 0:
		_resolved_swing_ids[swing_id] = true


func _finish(result: CombatHitResult) -> CombatHitResult:
	hit_resolved.emit(result)
	return result

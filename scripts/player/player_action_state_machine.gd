class_name PlayerActionStateMachine
extends RefCounted

signal state_changed(previous: PlayerActionState.State, current: PlayerActionState.State)
signal action_started(kind: PlayerActionKind.Kind)
signal attack_impact

const DEFAULT_ATTACK_SEC := 0.55
const DEFAULT_ATTACK_IMPACT_SEC := 0.22
const DEFAULT_GUARD_SEC := 8.0
const DEFAULT_DODGE_SEC := 0.28
const DEFAULT_HIT_SEC := 0.4
const DEFAULT_RECOVERY_SEC := 0.18
const DEFAULT_ROLL_SEC := 0.62
## Roll i-frames: the body is airborne/tucked, not the wind-up or the get-up.
const DEFAULT_ROLL_IFRAME_START_SEC := 0.04
const DEFAULT_ROLL_IFRAME_END_SEC := 0.40
## A buffered action may leave the roll once the body is back on its feet.
const DEFAULT_ROLL_CANCEL_SEC := 0.48
const DEFAULT_CAST_SEC := 0.5

var attack_duration_sec: float = DEFAULT_ATTACK_SEC
var attack_impact_sec: float = DEFAULT_ATTACK_IMPACT_SEC
## Elapsed ATTACK time after which a buffered attack chains immediately (combo).
## INF keeps the legacy rule: buffered actions wait for recovery.
var attack_cancel_sec: float = INF
## Elapsed ATTACK time after which a buffered dodge/roll interrupts the swing.
var evade_cancel_sec: float = INF
var guard_max_duration_sec: float = DEFAULT_GUARD_SEC
var dodge_duration_sec: float = DEFAULT_DODGE_SEC
var hit_duration_sec: float = DEFAULT_HIT_SEC
var recovery_duration_sec: float = DEFAULT_RECOVERY_SEC
var roll_duration_sec: float = DEFAULT_ROLL_SEC
var roll_iframe_start_sec: float = DEFAULT_ROLL_IFRAME_START_SEC
var roll_iframe_end_sec: float = DEFAULT_ROLL_IFRAME_END_SEC
var roll_cancel_sec: float = DEFAULT_ROLL_CANCEL_SEC
var cast_duration_sec: float = DEFAULT_CAST_SEC
var combo_grace_sec: float = CombatMoveCatalog.COMBO_GRACE_SEC

var state: PlayerActionState.State = PlayerActionState.State.MOVE
var state_elapsed_sec: float = 0.0
## 0-based index of the running (or last) light attack in the weapon chain.
var combo_step: int = 0
## Light strikes in the equipped weapon's chain; the step after the last wraps
## to 0. The owner sets it from CombatMoveCatalog before an attack starts.
var combo_length: int = 3
## True while the running attack is a heavy (held) strike.
var attack_is_heavy: bool = false
## Optional owner hook for resource/cooldown gates. Buffered actions are validated
## again when recovery actually tries to start them.
var action_start_validator: Callable

var _input_buffer := PlayerInputBuffer.new()
var _guard_held := false
var _attack_impact_emitted := false
var _buffered_heavy := false
var _pending_heavy := false
## Combo continuity: true from an attack until the grace after recovery ends.
var _combo_open := false
var _combo_grace_left := 0.0


func reset() -> void:
	_input_buffer.clear()
	_guard_held = false
	_attack_impact_emitted = false
	_buffered_heavy = false
	_pending_heavy = false
	_reset_combo()
	_set_state(PlayerActionState.State.MOVE)


func tick(delta: float) -> void:
	_input_buffer.tick(delta)
	state_elapsed_sec += delta
	match state:
		PlayerActionState.State.ATTACK:
			if not _attack_impact_emitted and state_elapsed_sec >= attack_impact_sec:
				_attack_impact_emitted = true
				attack_impact.emit()
			if _try_cancel_attack():
				return
			if state_elapsed_sec >= attack_duration_sec:
				_enter_recovery()
		PlayerActionState.State.GUARD:
			if not _guard_held or state_elapsed_sec >= guard_max_duration_sec:
				_set_state(PlayerActionState.State.MOVE)
		PlayerActionState.State.DODGE:
			if state_elapsed_sec >= dodge_duration_sec:
				_enter_recovery()
		PlayerActionState.State.ROLL:
			if state_elapsed_sec >= roll_cancel_sec and _input_buffer.peek() != PlayerActionKind.Kind.NONE:
				_consume_buffered_action_or_move()
			elif state_elapsed_sec >= roll_duration_sec:
				_consume_buffered_action_or_move()
		PlayerActionState.State.CAST:
			if state_elapsed_sec >= cast_duration_sec:
				_enter_recovery()
		PlayerActionState.State.HIT:
			if state_elapsed_sec >= hit_duration_sec:
				_enter_recovery()
		PlayerActionState.State.RECOVERY:
			if state_elapsed_sec >= recovery_duration_sec:
				_consume_buffered_action_or_move()
		PlayerActionState.State.MOVE:
			if _combo_open:
				_combo_grace_left -= delta
				if _combo_grace_left <= 0.0:
					_reset_combo()


func allows_movement() -> bool:
	return PlayerActionState.allows_movement(state)


func is_invulnerable() -> bool:
	if state == PlayerActionState.State.DODGE:
		return true
	return (
		state == PlayerActionState.State.ROLL
		and state_elapsed_sec >= roll_iframe_start_sec
		and state_elapsed_sec <= roll_iframe_end_sec
	)


func get_animation_base() -> String:
	match state:
		PlayerActionState.State.ATTACK:
			return "attack"
		PlayerActionState.State.GUARD:
			return "guard"
		PlayerActionState.State.DODGE:
			return "dodge"
		PlayerActionState.State.ROLL:
			return "roll"
		PlayerActionState.State.CAST:
			return "cast"
		PlayerActionState.State.HIT:
			return "hit"
		PlayerActionState.State.RECOVERY:
			return "recovery"
		_:
			return "idle"


## Light step the next attack would use if it started now. The owner resolves
## the move (and its stamina cost) from this before the attack begins.
func next_combo_step(heavy: bool = false) -> int:
	if heavy or not _combo_open or attack_is_heavy:
		return 0
	return posmod(combo_step + 1, maxi(combo_length, 1))


## Heavy attacks are a separate verb from the light chain: they share the
## ATTACK state but reset the chain instead of advancing it.
func next_attack_is_heavy() -> bool:
	return _pending_heavy


func try_start_action(kind: PlayerActionKind.Kind) -> bool:
	return _try_start(kind, false)


func try_start_attack(heavy: bool) -> bool:
	return _try_start(PlayerActionKind.Kind.ATTACK, heavy)


## Cast gestures are presentation locks requested by the spell controller after
## a successful cast; they are never buffered from input.
func try_start_cast(duration_sec: float) -> bool:
	if state != PlayerActionState.State.MOVE and state != PlayerActionState.State.RECOVERY:
		return false
	cast_duration_sec = maxf(0.05, duration_sec)
	_input_buffer.clear()
	_reset_combo()
	_set_state(PlayerActionState.State.CAST)
	return true


func set_guard_held(held: bool) -> void:
	_guard_held = held
	if held:
		if state == PlayerActionState.State.MOVE:
			_begin_action(PlayerActionKind.Kind.GUARD)
		elif _can_buffer(PlayerActionKind.Kind.GUARD):
			_input_buffer.store(PlayerActionKind.Kind.GUARD)
	elif state == PlayerActionState.State.GUARD:
		_set_state(PlayerActionState.State.MOVE)


func apply_hit() -> void:
	if is_invulnerable():
		return
	_input_buffer.clear()
	_reset_combo()
	_set_state(PlayerActionState.State.HIT)


func force_recovery() -> void:
	_enter_recovery()


func get_input_buffer() -> PlayerInputBuffer:
	return _input_buffer


func _try_start(kind: PlayerActionKind.Kind, heavy: bool) -> bool:
	if kind == PlayerActionKind.Kind.NONE:
		return false
	if state == PlayerActionState.State.MOVE:
		_pending_heavy = heavy
		return _begin_action(kind)
	if _can_buffer(kind):
		_input_buffer.store(kind)
		_buffered_heavy = heavy and kind == PlayerActionKind.Kind.ATTACK
		# Inside an open cancel window the follow-up starts on this very input.
		_try_cancel_attack()
		return false
	return false


## Combo and evade cancels let a buffered follow-up interrupt the follow-
## through of a landed swing, which is what makes chains read as one motion.
func _try_cancel_attack() -> bool:
	if state != PlayerActionState.State.ATTACK or not _attack_impact_emitted:
		return false
	var buffered := _input_buffer.peek()
	var window := INF
	if buffered == PlayerActionKind.Kind.ATTACK:
		window = attack_cancel_sec
	elif buffered == PlayerActionKind.Kind.DODGE or buffered == PlayerActionKind.Kind.ROLL:
		window = evade_cancel_sec
	if state_elapsed_sec < window:
		return false
	var heavy := _buffered_heavy
	_input_buffer.clear()
	_buffered_heavy = false
	_pending_heavy = heavy
	return _begin_action(buffered)


func _begin_action(kind: PlayerActionKind.Kind) -> bool:
	if action_start_validator.is_valid() and not bool(action_start_validator.call(kind)):
		_pending_heavy = false
		return false
	match kind:
		PlayerActionKind.Kind.ATTACK:
			combo_step = next_combo_step(_pending_heavy)
			attack_is_heavy = _pending_heavy
			_pending_heavy = false
			_combo_open = true
			_set_state(PlayerActionState.State.ATTACK, true)
			action_started.emit(kind)
			return true
		PlayerActionKind.Kind.GUARD:
			_guard_held = true
			_reset_combo()
			_set_state(PlayerActionState.State.GUARD)
			action_started.emit(kind)
			return true
		PlayerActionKind.Kind.DODGE:
			_reset_combo()
			_set_state(PlayerActionState.State.DODGE, true)
			action_started.emit(kind)
			return true
		PlayerActionKind.Kind.ROLL:
			_reset_combo()
			_set_state(PlayerActionState.State.ROLL, true)
			action_started.emit(kind)
			return true
		_:
			return false


func _enter_recovery() -> void:
	_set_state(PlayerActionState.State.RECOVERY)


func _consume_buffered_action_or_move() -> void:
	var heavy := _buffered_heavy
	_buffered_heavy = false
	var buffered := _input_buffer.consume()
	if buffered != PlayerActionKind.Kind.NONE:
		_pending_heavy = heavy
		if _begin_action(buffered):
			return
	if _combo_open:
		_combo_grace_left = combo_grace_sec
	_set_state(PlayerActionState.State.MOVE)


func _reset_combo() -> void:
	_combo_open = false
	_combo_grace_left = 0.0
	combo_step = 0
	attack_is_heavy = false


func _can_buffer(kind: PlayerActionKind.Kind) -> bool:
	if kind == PlayerActionKind.Kind.NONE:
		return false
	return (
		state
		in [
			PlayerActionState.State.ATTACK,
			PlayerActionState.State.DODGE,
			PlayerActionState.State.ROLL,
			PlayerActionState.State.CAST,
			PlayerActionState.State.HIT,
			PlayerActionState.State.RECOVERY,
		]
	)


## restart: re-entering the same action state (combo step after combo step,
## roll after roll) still counts as a new action for listeners.
func _set_state(next: PlayerActionState.State, restart: bool = false) -> void:
	if state == next and not restart:
		state_elapsed_sec = 0.0
		return
	var previous := state
	state = next
	state_elapsed_sec = 0.0
	if next == PlayerActionState.State.ATTACK:
		_attack_impact_emitted = false
	state_changed.emit(previous, next)

class_name PlayerActionStateMachine
extends RefCounted

signal state_changed(previous: PlayerActionState.State, current: PlayerActionState.State)

const DEFAULT_ATTACK_SEC := 0.35
const DEFAULT_GUARD_SEC := 8.0
const DEFAULT_DODGE_SEC := 0.28
const DEFAULT_HIT_SEC := 0.4
const DEFAULT_RECOVERY_SEC := 0.18

var attack_duration_sec: float = DEFAULT_ATTACK_SEC
var guard_max_duration_sec: float = DEFAULT_GUARD_SEC
var dodge_duration_sec: float = DEFAULT_DODGE_SEC
var hit_duration_sec: float = DEFAULT_HIT_SEC
var recovery_duration_sec: float = DEFAULT_RECOVERY_SEC

var state: PlayerActionState.State = PlayerActionState.State.MOVE
var state_elapsed_sec: float = 0.0

var _input_buffer := PlayerInputBuffer.new()
var _guard_held := false


func reset() -> void:
	_input_buffer.clear()
	_guard_held = false
	_set_state(PlayerActionState.State.MOVE)


func tick(delta: float) -> void:
	_input_buffer.tick(delta)
	state_elapsed_sec += delta
	match state:
		PlayerActionState.State.ATTACK:
			if state_elapsed_sec >= attack_duration_sec:
				_enter_recovery()
		PlayerActionState.State.GUARD:
			if not _guard_held or state_elapsed_sec >= guard_max_duration_sec:
				_set_state(PlayerActionState.State.MOVE)
		PlayerActionState.State.DODGE:
			if state_elapsed_sec >= dodge_duration_sec:
				_enter_recovery()
		PlayerActionState.State.HIT:
			if state_elapsed_sec >= hit_duration_sec:
				_enter_recovery()
		PlayerActionState.State.RECOVERY:
			if state_elapsed_sec >= recovery_duration_sec:
				_consume_buffered_action_or_move()
		PlayerActionState.State.MOVE:
			pass


func allows_movement() -> bool:
	return PlayerActionState.allows_movement(state)


func is_invulnerable() -> bool:
	return state == PlayerActionState.State.DODGE


func get_animation_base() -> String:
	match state:
		PlayerActionState.State.ATTACK:
			return "attack"
		PlayerActionState.State.GUARD:
			return "guard"
		PlayerActionState.State.DODGE:
			return "dodge"
		PlayerActionState.State.HIT:
			return "hit"
		PlayerActionState.State.RECOVERY:
			return "recovery"
		_:
			return "idle"


func try_start_action(kind: PlayerActionKind.Kind) -> bool:
	if kind == PlayerActionKind.Kind.NONE:
		return false
	if state == PlayerActionState.State.MOVE:
		return _begin_action(kind)
	if _can_buffer(kind):
		_input_buffer.store(kind)
		return false
	return false


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
	if state == PlayerActionState.State.DODGE:
		return
	_input_buffer.clear()
	_set_state(PlayerActionState.State.HIT)


func force_recovery() -> void:
	_enter_recovery()


func get_input_buffer() -> PlayerInputBuffer:
	return _input_buffer


func _begin_action(kind: PlayerActionKind.Kind) -> bool:
	match kind:
		PlayerActionKind.Kind.ATTACK:
			_set_state(PlayerActionState.State.ATTACK)
			return true
		PlayerActionKind.Kind.GUARD:
			_guard_held = true
			_set_state(PlayerActionState.State.GUARD)
			return true
		PlayerActionKind.Kind.DODGE:
			_set_state(PlayerActionState.State.DODGE)
			return true
		_:
			return false


func _enter_recovery() -> void:
	_set_state(PlayerActionState.State.RECOVERY)


func _consume_buffered_action_or_move() -> void:
	var buffered := _input_buffer.consume()
	if buffered != PlayerActionKind.Kind.NONE and _begin_action(buffered):
		return
	_set_state(PlayerActionState.State.MOVE)


func _can_buffer(kind: PlayerActionKind.Kind) -> bool:
	if kind == PlayerActionKind.Kind.NONE:
		return false
	return state in [
		PlayerActionState.State.ATTACK,
		PlayerActionState.State.DODGE,
		PlayerActionState.State.HIT,
		PlayerActionState.State.RECOVERY,
	]


func _set_state(next: PlayerActionState.State) -> void:
	if state == next:
		state_elapsed_sec = 0.0
		return
	var previous := state
	state = next
	state_elapsed_sec = 0.0
	state_changed.emit(previous, next)

class_name PlayerInputBuffer
extends RefCounted

const DEFAULT_WINDOW_SEC := 0.5

var buffer_window_sec: float = DEFAULT_WINDOW_SEC

var _kind: PlayerActionKind.Kind = PlayerActionKind.Kind.NONE
var _age_sec: float = 0.0


func clear() -> void:
	_kind = PlayerActionKind.Kind.NONE
	_age_sec = 0.0


func store(kind: PlayerActionKind.Kind) -> void:
	if kind == PlayerActionKind.Kind.NONE:
		return
	_kind = kind
	_age_sec = 0.0


func tick(delta: float) -> void:
	if _kind == PlayerActionKind.Kind.NONE:
		return
	_age_sec += delta
	if _age_sec > buffer_window_sec:
		clear()


func peek() -> PlayerActionKind.Kind:
	if _kind == PlayerActionKind.Kind.NONE:
		return PlayerActionKind.Kind.NONE
	if _age_sec > buffer_window_sec:
		clear()
		return PlayerActionKind.Kind.NONE
	return _kind


func consume() -> PlayerActionKind.Kind:
	var kind := peek()
	clear()
	return kind

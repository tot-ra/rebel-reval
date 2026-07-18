class_name ForgeCommissionController
extends Node

const OVERLAY_SCENE := preload("res://scenes/ui/forge_commission_overlay.tscn")
const RunnerScript := preload("res://scripts/forge/forge_commission_runner.gd")
const PresenterScript := preload("res://scripts/forge/forge_commission_ui_presenter.gd")

signal commission_finished(commission_id: StringName)

var _overlay: ForgeCommissionOverlay
var _runner: ForgeCommissionRunner
var _presenter: RefCounted


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = OVERLAY_SCENE.instantiate() as ForgeCommissionOverlay
	_overlay.visible = false
	add_child(_overlay)

	_runner = RunnerScript.new()
	add_child(_runner)

	_presenter = PresenterScript.new()
	_presenter.configure(_overlay, _runner)
	_runner.configure(SessionState.content_db, SessionState.state, _presenter)
	_overlay.closed.connect(_on_overlay_closed)
	_runner.finished.connect(_on_runner_finished)

	if not SessionState.debug_state_applied.is_connected(_on_debug_state_applied):
		SessionState.debug_state_applied.connect(_on_debug_state_applied)


func _exit_tree() -> void:
	if SessionState.debug_state_applied.is_connected(_on_debug_state_applied):
		SessionState.debug_state_applied.disconnect(_on_debug_state_applied)


func _on_debug_state_applied(_preset_id: StringName) -> void:
	_runner.configure(SessionState.content_db, SessionState.state, _presenter)


func is_open() -> bool:
	return _overlay != null and _overlay.is_open()


func is_active() -> bool:
	return _runner != null and _runner.is_active()


func open_commission(commission_id: StringName) -> bool:
	if _runner == null:
		return false
	_runner.configure(SessionState.content_db, SessionState.state, _presenter)
	return _runner.open(commission_id)


func _on_overlay_closed() -> void:
	if _runner != null and _runner.is_active():
		_runner.cancel()


func _on_runner_finished(commission_id: StringName) -> void:
	commission_finished.emit(commission_id)

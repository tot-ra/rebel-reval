class_name ForgeCommissionUiPresenter
extends "res://scripts/forge/forge_commission_presenter.gd"

## Bridges ForgeCommissionRunner to ForgeCommissionOverlay and ForgeFeedbackOverlay.


var _overlay: Node
var _feedback_overlay: ForgeFeedbackOverlay
var _runner: Node


func configure(overlay: Node, runner: Node, feedback_overlay: ForgeFeedbackOverlay = null) -> void:
	if _overlay != null and _overlay.option_selected.is_connected(_on_option_selected):
		_overlay.option_selected.disconnect(_on_option_selected)
	_overlay = overlay
	_runner = runner
	_feedback_overlay = feedback_overlay
	if _overlay != null:
		_overlay.option_selected.connect(_on_option_selected)


func present_commission(snapshot: Dictionary) -> void:
	if _overlay != null:
		_overlay.present_commission(snapshot)


func begin_forging(option_id: String, snapshot: Dictionary, on_complete: Callable) -> void:
	if _overlay != null:
		_overlay.close()
	if _feedback_overlay != null:
		_feedback_overlay.start_forging(option_id, snapshot, on_complete)
	elif on_complete.is_valid():
		on_complete.call()


func close() -> void:
	if _feedback_overlay != null and _feedback_overlay.is_open():
		_feedback_overlay.close()
	if _overlay != null:
		_overlay.close()


func _on_option_selected(option_id: String) -> void:
	if _runner != null:
		_runner.select_option(option_id)

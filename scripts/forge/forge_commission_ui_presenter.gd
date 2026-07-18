class_name ForgeCommissionUiPresenter
extends "res://scripts/forge/forge_commission_presenter.gd"

## Bridges ForgeCommissionRunner to ForgeCommissionOverlay.


var _overlay: Node
var _runner: Node


func configure(overlay: Node, runner: Node) -> void:
	if _overlay != null and _overlay.option_selected.is_connected(_on_option_selected):
		_overlay.option_selected.disconnect(_on_option_selected)
	_overlay = overlay
	_runner = runner
	if _overlay != null:
		_overlay.option_selected.connect(_on_option_selected)


func present_commission(snapshot: Dictionary) -> void:
	if _overlay != null:
		_overlay.present_commission(snapshot)


func close() -> void:
	if _overlay != null:
		_overlay.close()


func _on_option_selected(option_id: String) -> void:
	if _runner != null:
		_runner.select_option(option_id)

class_name DialogueUiPresenter
extends "res://scripts/dialogue/dialogue_presenter.gd"

## Bridges DialogueRunner to DialogueUI and routes choice selection back to the runner.

var _ui: Node
var _runner: Node


func configure(ui: Node, runner: Node) -> void:
	if _ui != null:
		if _ui.choice_selected.is_connected(_on_choice_selected):
			_ui.choice_selected.disconnect(_on_choice_selected)
		if _ui.continue_requested.is_connected(_on_continue_requested):
			_ui.continue_requested.disconnect(_on_continue_requested)
		if _ui.skip_requested.is_connected(_on_skip_requested):
			_ui.skip_requested.disconnect(_on_skip_requested)
	_ui = ui
	_runner = runner
	if _ui != null:
		_ui.choice_selected.connect(_on_choice_selected)
		_ui.continue_requested.connect(_on_continue_requested)
		_ui.skip_requested.connect(_on_skip_requested)


func present_line(
	speaker_id: StringName,
	speaker_name: String,
	text: String,
	node_id: String
) -> void:
	if _ui != null:
		_ui.present_line(speaker_id, speaker_name, text, node_id)


func present_choices(choices: Array) -> void:
	if _ui != null:
		_ui.present_choices(choices)


func close() -> void:
	if _ui != null:
		_ui.close()


func consume_line_advance() -> bool:
	if _ui != null and _ui.has_method("consume_line_advance"):
		return _ui.consume_line_advance()
	return true


func _on_choice_selected(choice_id: String) -> void:
	if _runner != null:
		_runner.select_choice(choice_id)


func _on_continue_requested() -> void:
	if _runner != null and _runner.is_active() and not _runner.is_waiting_for_choice():
		_runner.advance()


func _on_skip_requested() -> void:
	if _runner != null and _runner.is_active() and not _runner.is_waiting_for_choice():
		_runner.advance()

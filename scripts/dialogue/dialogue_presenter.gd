class_name DialoguePresenter
extends RefCounted

## Presenter contract for DialogueRunner. P1-012 supplies DialogueUiPresenter.


func present_line(
	_speaker_id: StringName, _speaker_name: String, _text: String, _node_id: String
) -> void:
	pass


func present_choices(_choices: Array) -> void:
	pass


func close() -> void:
	pass


func consume_line_advance() -> bool:
	return true

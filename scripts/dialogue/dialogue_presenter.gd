class_name DialoguePresenter
extends RefCounted

## Presenter contract for DialogueRunner. P1-012 supplies DialogueUiPresenter.


func present_line(
	speaker_id: StringName,
	speaker_name: String,
	text: String,
	node_id: String
) -> void:
	pass


func present_choices(choices: Array) -> void:
	pass


func close() -> void:
	pass

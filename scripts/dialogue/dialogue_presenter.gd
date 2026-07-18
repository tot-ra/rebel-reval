class_name DialoguePresenter
extends RefCounted

## Minimal presenter contract for P1-011. P1-012 replaces this with the full UI.


func present_line(speaker_name: String, text: String, node_id: String) -> void:
	pass


func present_choices(choices: Array) -> void:
	pass


func close() -> void:
	pass

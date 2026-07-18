class_name DialogueTestPresenter
extends "res://scripts/dialogue/dialogue_presenter.gd"

var last_speaker := ""
var last_text := ""
var last_node_id := ""
var last_choices: Array = []
var closed := false


func present_line(speaker_name: String, text: String, node_id: String) -> void:
	last_speaker = speaker_name
	last_text = text
	last_node_id = node_id
	closed = false


func present_choices(choices: Array) -> void:
	last_choices = choices.duplicate(true)
	closed = false


func close() -> void:
	closed = true
	last_choices.clear()


func enabled_choice_ids() -> Array[String]:
	var ids: Array[String] = []
	for choice_value in last_choices:
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_value
		if bool(choice.get("enabled", false)):
			ids.append(String(choice.get("id", "")))
	return ids

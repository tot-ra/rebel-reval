class_name UserSettingsStore
extends RefCounted

## Persists accessibility, dialogue, and input settings outside save slots.

const DialogueSettingsScript := preload("res://scripts/settings/dialogue_settings.gd")
const InputBindingSettingsScript := preload("res://scripts/settings/input_binding_settings.gd")
const CURRENT_VERSION := 2
const LEGACY_VERSION := 1
const DEFAULT_DIRECTORY := "user://settings"

var settings_directory: String = DEFAULT_DIRECTORY


func settings_path() -> String:
	return "%s/user_settings.json" % settings_directory.trim_suffix("/")


func load_dialogue_settings():
	var envelope := _load_envelope()
	var dialogue_value: Variant = envelope.get("dialogue", {})
	if typeof(dialogue_value) != TYPE_DICTIONARY:
		return DialogueSettingsScript.default_settings()
	return DialogueSettingsScript.from_dict(dialogue_value as Dictionary)


func load_input_bindings():
	var envelope := _load_envelope()
	var bindings_value: Variant = envelope.get("input_bindings", {})
	if typeof(bindings_value) != TYPE_DICTIONARY:
		return InputBindingSettingsScript.default_settings()
	return InputBindingSettingsScript.from_dict(bindings_value as Dictionary)


func save_dialogue_settings(settings) -> bool:
	if settings == null:
		return false
	return _save_all(settings, load_input_bindings())


func save_input_bindings(bindings) -> bool:
	if bindings == null:
		return false
	return _save_all(load_dialogue_settings(), bindings)


func _load_envelope() -> Dictionary:
	var path := settings_path()
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var envelope: Dictionary = parsed
	var version := int(envelope.get("version", 0))
	if version not in [LEGACY_VERSION, CURRENT_VERSION]:
		return {}
	return envelope


func _save_all(dialogue_settings, input_bindings) -> bool:
	if dialogue_settings == null or input_bindings == null or not _ensure_directory():
		return false
	var envelope := {
		"version": CURRENT_VERSION,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"dialogue": dialogue_settings.to_dict(),
		"input_bindings": input_bindings.to_dict(),
	}
	var file := FileAccess.open(settings_path(), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(envelope, "\t"))
	file.flush()
	file.close()
	return true


func _ensure_directory() -> bool:
	var normalized := settings_directory.trim_suffix("/")
	if normalized.is_empty():
		return false
	if DirAccess.dir_exists_absolute(normalized):
		return true
	return DirAccess.make_dir_recursive_absolute(normalized) == OK

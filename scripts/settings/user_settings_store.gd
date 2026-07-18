class_name UserSettingsStore
extends RefCounted

## Persists accessibility and dialogue settings outside save slots (P1-013).

const DialogueSettingsScript := preload("res://scripts/settings/dialogue_settings.gd")
const CURRENT_VERSION := 1
const DEFAULT_DIRECTORY := "user://settings"

var settings_directory: String = DEFAULT_DIRECTORY


func settings_path() -> String:
	return "%s/user_settings.json" % settings_directory.trim_suffix("/")


func load_dialogue_settings():
	var path := settings_path()
	if not FileAccess.file_exists(path):
		return DialogueSettingsScript.default_settings()

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return DialogueSettingsScript.default_settings()

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return DialogueSettingsScript.default_settings()

	var envelope: Dictionary = parsed
	var version := int(envelope.get("version", 0))
	if version != CURRENT_VERSION:
		return DialogueSettingsScript.default_settings()

	var dialogue_value: Variant = envelope.get("dialogue", {})
	if typeof(dialogue_value) != TYPE_DICTIONARY:
		return DialogueSettingsScript.default_settings()

	return DialogueSettingsScript.from_dict(dialogue_value as Dictionary)


func save_dialogue_settings(settings) -> bool:
	if settings == null:
		return false

	if not _ensure_directory():
		return false

	var envelope := {
		"version": CURRENT_VERSION,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"dialogue": settings.to_dict(),
	}
	var json := JSON.stringify(envelope, "\t")
	var path := settings_path()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(json)
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

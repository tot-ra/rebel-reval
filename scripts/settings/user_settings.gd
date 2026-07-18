extends Node

## Autoload that owns persisted player settings separate from save slots (P1-013).

const DialogueSettingsScript := preload("res://scripts/settings/dialogue_settings.gd")
const StoreScript := preload("res://scripts/settings/user_settings_store.gd")

signal dialogue_settings_changed(settings)

var store = StoreScript.new()
var dialogue = DialogueSettingsScript.default_settings()


func _ready() -> void:
	reload_dialogue_settings()


func reload_dialogue_settings() -> void:
	dialogue = store.load_dialogue_settings()
	dialogue_settings_changed.emit(dialogue)


func apply_dialogue_settings(settings, persist: bool = true) -> void:
	if settings == null:
		return
	dialogue = settings.duplicate_settings()
	dialogue.normalize()
	dialogue_settings_changed.emit(dialogue)
	if persist:
		if not store.save_dialogue_settings(dialogue):
			push_warning("Failed to persist dialogue settings.")

extends Node

## Autoload that owns persisted player settings separate from save slots (P1-013/P1-028).

const DialogueSettingsScript := preload("res://scripts/settings/dialogue_settings.gd")
const InputBindingSettingsScript := preload("res://scripts/settings/input_binding_settings.gd")
const StoreScript := preload("res://scripts/settings/user_settings_store.gd")

signal dialogue_settings_changed(settings)
signal input_bindings_changed(bindings)

var store = StoreScript.new()
var dialogue = DialogueSettingsScript.default_settings()
var input_bindings = InputBindingSettingsScript.default_settings()


func _ready() -> void:
	reload_dialogue_settings()
	reload_input_bindings()


func reload_dialogue_settings() -> void:
	dialogue = store.load_dialogue_settings()
	dialogue_settings_changed.emit(dialogue)


func reload_input_bindings() -> void:
	input_bindings = store.load_input_bindings()
	input_bindings.apply_to_input_map()
	input_bindings_changed.emit(input_bindings)


func apply_dialogue_settings(settings, persist: bool = true) -> void:
	if settings == null:
		return
	dialogue = settings.duplicate_settings()
	dialogue.normalize()
	dialogue_settings_changed.emit(dialogue)
	if persist and not store.save_dialogue_settings(dialogue):
		push_warning("Failed to persist dialogue settings.")


func apply_input_bindings(bindings, persist: bool = true) -> bool:
	if bindings == null:
		return false
	input_bindings = bindings.duplicate_settings()
	input_bindings.apply_to_input_map()
	input_bindings_changed.emit(input_bindings)
	if persist and not store.save_input_bindings(input_bindings):
		push_warning("Failed to persist input bindings.")
		return false
	return true


func rebind_action(
	action: StringName,
	device: StringName,
	event: InputEvent,
	persist: bool = true
) -> bool:
	var changed = input_bindings.duplicate_settings()
	if not changed.replace_device_binding(action, device, event):
		return false
	return apply_input_bindings(changed, persist)


func restore_default_input_bindings(persist: bool = true) -> bool:
	return apply_input_bindings(InputBindingSettingsScript.default_settings(), persist)

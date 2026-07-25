extends Node

## Autoload that owns persisted player settings separate from save slots (P1-013/P1-028).

const AudioBusServiceScript := preload("res://scripts/settings/audio_bus_service.gd")
const AudioSettingsScript := preload("res://scripts/settings/audio_settings.gd")
const DialogueSettingsScript := preload("res://scripts/settings/dialogue_settings.gd")
const InputBindingSettingsScript := preload("res://scripts/settings/input_binding_settings.gd")
const StoreScript := preload("res://scripts/settings/user_settings_store.gd")

signal audio_settings_changed(settings)
signal dialogue_settings_changed(settings)
signal input_bindings_changed(bindings)

var store = StoreScript.new()
var audio = AudioSettingsScript.default_settings()
var dialogue = DialogueSettingsScript.default_settings()
var input_bindings = InputBindingSettingsScript.default_settings()


func _ready() -> void:
	reload_dialogue_settings()
	reload_input_bindings()
	reload_audio_settings()


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index == MOUSE_BUTTON_LEFT or not mouse_button.is_action(&"ui_accept"):
		return
	# Godot's GUI activates focused controls for key/gamepad ui_accept events, but
	# treats other mouse buttons only as positional clicks. Mirror a rebound mouse
	# confirm into the same action path so remapping does not silently break focus UI.
	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = mouse_button.pressed
	accept.strength = 1.0 if mouse_button.pressed else 0.0
	get_viewport().push_input(accept, true)
	get_viewport().set_input_as_handled()


func reload_dialogue_settings() -> void:
	dialogue = store.load_dialogue_settings()
	dialogue_settings_changed.emit(dialogue)


func reload_input_bindings() -> void:
	input_bindings = store.load_input_bindings()
	input_bindings.apply_to_input_map()
	input_bindings_changed.emit(input_bindings)


func reload_audio_settings() -> void:
	audio = store.load_audio_settings()
	apply_audio_settings(audio, false)


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


func apply_audio_settings(settings, persist: bool = true) -> void:
	if settings == null:
		return
	audio = settings.duplicate_settings()
	audio.normalize()
	AudioBusServiceScript.apply_settings(audio)
	audio_settings_changed.emit(audio)
	if persist and not store.save_audio_settings(audio):
		push_warning("Failed to persist audio settings.")

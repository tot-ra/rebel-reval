class_name GameSettingsOverlay
extends CanvasLayer

## In-game settings surface for audio volume and accessibility. Open with Esc when no other modal is active.

signal closed()
signal controls_requested()

const AudioSettingsScript := preload("res://scripts/settings/audio_settings.gd")
const DialogueSettingsScript := preload("res://scripts/settings/dialogue_settings.gd")
const GameplaySettingsScript := preload("res://scripts/settings/gameplay_accessibility_settings.gd")
const TextScaleScript := preload("res://scripts/dialogue/dialogue_text_scale.gd")
const PANEL_MIN_SIZE := Vector2(560, 520)

var _settings_owner: Node
var _music_slider: HSlider
var _music_value: Label
var _sfx_slider: HSlider
var _sfx_value: Label
var _close_button: Button
var _text_scale_option: OptionButton
var _text_speed_option: OptionButton
var _high_contrast_check: CheckButton
var _subtitle_background_check: CheckButton
var _reduced_motion_check: CheckButton
var _guard_mode_option: OptionButton
var _screen_shake_check: CheckButton
var _reduced_flashing_check: CheckButton
var _enhanced_focus_check: CheckButton
var _remap_controls_button: Button


func configure(settings_owner: Node) -> void:
	_settings_owner = settings_owner
	if is_node_ready():
		_sync_from_settings()


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _settings_owner == null and has_node("/root/UserSettings"):
		_settings_owner = get_node("/root/UserSettings")
	_build_ui()
	visible = false


func open() -> void:
	_sync_from_settings()
	visible = true
	add_to_group(&"modal_input_overlay")
	if _music_slider != null:
		_music_slider.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	remove_from_group(&"modal_input_overlay")
	closed.emit()


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var root := Control.new()
	root.name = "SettingsRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.025, 0.03, 0.045, 0.92)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "SettingsPanel"
	panel.custom_minimum_size = PANEL_MIN_SIZE
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 22)
	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	layout.add_child(header)

	var title := Label.new()
	title.text = "Settings"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.94, 0.81, 0.5, 1.0))
	header.add_child(title)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "Close"
	_close_button.focus_mode = Control.FOCUS_ALL
	_close_button.pressed.connect(close)
	header.add_child(_close_button)

	var intro := Label.new()
	intro.text = "Adjust audio and accessibility. Changes save outside campaign slots."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_color_override("font_color", Color(0.78, 0.82, 0.9, 1.0))
	layout.add_child(intro)

	_add_section_heading(layout, "Audio")
	_add_volume_row(layout, "Music volume", true)
	_add_volume_row(layout, "Sound effects volume", false)

	_add_section_heading(layout, "Dialogue accessibility")
	_text_scale_option = _add_option_row(
		layout,
		"Text size",
		TextScaleScript.supported_scale_names()
	)
	_text_scale_option.item_selected.connect(_on_text_scale_selected)
	_text_speed_option = _add_option_row(
		layout,
		"Text speed",
		DialogueSettingsScript.TEXT_SPEEDS
	)
	_text_speed_option.item_selected.connect(_on_text_speed_selected)
	_high_contrast_check = _add_toggle_row(layout, "High contrast")
	_high_contrast_check.toggled.connect(_on_high_contrast_toggled)
	_subtitle_background_check = _add_toggle_row(layout, "Subtitle background")
	_subtitle_background_check.toggled.connect(_on_subtitle_background_toggled)
	_reduced_motion_check = _add_toggle_row(layout, "Reduced motion")
	_reduced_motion_check.toggled.connect(_on_reduced_motion_toggled)

	_add_section_heading(layout, "Gameplay accessibility")
	_guard_mode_option = _add_option_row(
		layout,
		"Guard input",
		GameplaySettingsScript.GUARD_MODES
	)
	_guard_mode_option.item_selected.connect(_on_guard_mode_selected)
	_screen_shake_check = _add_toggle_row(layout, "Screen shake")
	_screen_shake_check.toggled.connect(_on_screen_shake_toggled)
	_reduced_flashing_check = _add_toggle_row(layout, "Reduced flashing")
	_reduced_flashing_check.toggled.connect(_on_reduced_flashing_toggled)
	_enhanced_focus_check = _add_toggle_row(layout, "Enhanced focus contrast")
	_enhanced_focus_check.toggled.connect(_on_enhanced_focus_toggled)

	_remap_controls_button = Button.new()
	_remap_controls_button.text = "Remap controls"
	_remap_controls_button.focus_mode = Control.FOCUS_ALL
	_remap_controls_button.pressed.connect(_on_remap_controls_pressed)
	layout.add_child(_remap_controls_button)

	var hint := Label.new()
	hint.text = "Esc closes this menu. Remap controls opens the full binding editor."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82, 1.0))
	layout.add_child(hint)

	if _music_slider != null and _close_button != null:
		_music_slider.focus_neighbor_top = _music_slider.get_path_to(_close_button)
		_close_button.focus_neighbor_bottom = _close_button.get_path_to(_music_slider)


func _add_section_heading(parent: VBoxContainer, text: String) -> void:
	var heading := Label.new()
	heading.text = text
	heading.add_theme_font_size_override("font_size", 18)
	heading.add_theme_color_override("font_color", Color(0.9, 0.76, 0.45, 1.0))
	parent.add_child(heading)


func _add_volume_row(parent: VBoxContainer, label_text: String, is_music: bool) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	var label_row := HBoxContainer.new()
	row.add_child(label_row)

	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_row.add_child(label)

	var value_label := Label.new()
	value_label.text = "100%"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(56, 0)
	label_row.add_child(value_label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_ALL
	if is_music:
		slider.value_changed.connect(_on_music_changed)
		_music_slider = slider
		_music_value = value_label
	else:
		slider.value_changed.connect(_on_sfx_changed)
		_sfx_slider = slider
		_sfx_value = value_label
	row.add_child(slider)


func _add_option_row(parent: VBoxContainer, label_text: String, values: Array) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(160, 0)
	row.add_child(label)

	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.focus_mode = Control.FOCUS_ALL
	for value in values:
		option.add_item(String(value))
	row.add_child(option)
	return option


func _add_toggle_row(parent: VBoxContainer, label_text: String) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = label_text
	toggle.focus_mode = Control.FOCUS_ALL
	parent.add_child(toggle)
	return toggle


func _sync_from_settings() -> void:
	var audio_settings = _current_audio_settings()
	_music_slider.set_value_no_signal(audio_settings.music_volume * 100.0)
	_sfx_slider.set_value_no_signal(audio_settings.sfx_volume * 100.0)
	_update_value_label(_music_value, audio_settings.music_volume)
	_update_value_label(_sfx_value, audio_settings.sfx_volume)

	var dialogue_settings = _current_dialogue_settings()
	_select_option_value(_text_scale_option, dialogue_settings.text_scale)
	_select_option_value(_text_speed_option, dialogue_settings.text_speed)
	_high_contrast_check.set_pressed_no_signal(dialogue_settings.high_contrast)
	_subtitle_background_check.set_pressed_no_signal(dialogue_settings.subtitle_background)
	_reduced_motion_check.set_pressed_no_signal(dialogue_settings.reduced_motion)

	var gameplay_settings = _current_gameplay_settings()
	_select_option_value(_guard_mode_option, gameplay_settings.guard_mode)
	_screen_shake_check.set_pressed_no_signal(gameplay_settings.screenshake_enabled)
	_reduced_flashing_check.set_pressed_no_signal(gameplay_settings.reduced_flashing)
	_enhanced_focus_check.set_pressed_no_signal(gameplay_settings.enhanced_focus_contrast)


func _on_music_changed(value: float) -> void:
	var audio = _current_audio_settings()
	audio.music_volume = value / 100.0
	_apply_audio_settings(audio)
	_update_value_label(_music_value, audio.music_volume)


func _on_sfx_changed(value: float) -> void:
	var audio = _current_audio_settings()
	audio.sfx_volume = value / 100.0
	_apply_audio_settings(audio)
	_update_value_label(_sfx_value, audio.sfx_volume)


func _on_text_scale_selected(index: int) -> void:
	var dialogue = _current_dialogue_settings()
	dialogue.text_scale = _text_scale_option.get_item_text(index)
	_apply_dialogue_settings(dialogue)


func _on_text_speed_selected(index: int) -> void:
	var dialogue = _current_dialogue_settings()
	dialogue.text_speed = _text_speed_option.get_item_text(index)
	_apply_dialogue_settings(dialogue)


func _on_high_contrast_toggled(pressed: bool) -> void:
	var dialogue = _current_dialogue_settings()
	dialogue.high_contrast = pressed
	_apply_dialogue_settings(dialogue)


func _on_subtitle_background_toggled(pressed: bool) -> void:
	var dialogue = _current_dialogue_settings()
	dialogue.subtitle_background = pressed
	_apply_dialogue_settings(dialogue)


func _on_reduced_motion_toggled(pressed: bool) -> void:
	var dialogue = _current_dialogue_settings()
	dialogue.reduced_motion = pressed
	_apply_dialogue_settings(dialogue)


func _on_guard_mode_selected(index: int) -> void:
	var gameplay = _current_gameplay_settings()
	gameplay.guard_mode = _guard_mode_option.get_item_text(index)
	_apply_gameplay_settings(gameplay)


func _on_screen_shake_toggled(pressed: bool) -> void:
	var gameplay = _current_gameplay_settings()
	gameplay.screenshake_enabled = pressed
	_apply_gameplay_settings(gameplay)


func _on_reduced_flashing_toggled(pressed: bool) -> void:
	var gameplay = _current_gameplay_settings()
	gameplay.reduced_flashing = pressed
	_apply_gameplay_settings(gameplay)


func _on_enhanced_focus_toggled(pressed: bool) -> void:
	var gameplay = _current_gameplay_settings()
	gameplay.enhanced_focus_contrast = pressed
	_apply_gameplay_settings(gameplay)


func _on_remap_controls_pressed() -> void:
	controls_requested.emit()


func _apply_audio_settings(settings) -> void:
	if _settings_owner == null or not _settings_owner.has_method("apply_audio_settings"):
		return
	_settings_owner.call("apply_audio_settings", settings, true)


func _apply_dialogue_settings(settings) -> void:
	if _settings_owner == null or not _settings_owner.has_method("apply_dialogue_settings"):
		return
	_settings_owner.call("apply_dialogue_settings", settings, true)


func _apply_gameplay_settings(settings) -> void:
	if _settings_owner == null or not _settings_owner.has_method("apply_gameplay_accessibility_settings"):
		return
	_settings_owner.call("apply_gameplay_accessibility_settings", settings, true)


func _current_audio_settings():
	if _settings_owner == null:
		return AudioSettingsScript.default_settings()
	var value: Variant = _settings_owner.get("audio")
	return value if value != null else AudioSettingsScript.default_settings()


func _current_dialogue_settings():
	if _settings_owner == null:
		return DialogueSettingsScript.default_settings()
	var value: Variant = _settings_owner.get("dialogue")
	return value if value != null else DialogueSettingsScript.default_settings()


func _current_gameplay_settings():
	if _settings_owner == null:
		return GameplaySettingsScript.default_settings()
	var value: Variant = _settings_owner.get("gameplay")
	return value if value != null else GameplaySettingsScript.default_settings()


func _select_option_value(option: OptionButton, current: String) -> void:
	for index in option.item_count:
		if option.get_item_text(index) == current:
			option.select(index)
			return
	option.select(0)


func _update_value_label(label: Label, linear_volume: float) -> void:
	if label == null:
		return
	label.text = "%d%%" % int(roundf(linear_volume * 100.0))

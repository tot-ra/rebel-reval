extends Node

## Manual dialogue UI smoke scene for P1-012/P1-013 settings review.

const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const UiPresenterScript := preload("res://scripts/dialogue/dialogue_ui_presenter.gd")
const UiScript := preload("res://scripts/dialogue/dialogue_ui.gd")
const SettingsScript := preload("res://scripts/settings/dialogue_settings.gd")
const DIALOGUE_ID := &"dialogue.test_ui.branching"

const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]

var _ui: DialogueUI
var _runner: DialogueRunner
var _scale_option: OptionButton
var _speed_option: OptionButton
var _contrast_check: CheckButton
var _subtitle_check: CheckButton
var _motion_check: CheckButton


func _ready() -> void:
	_ui = UiScript.new()
	add_child(_ui)
	_ui.apply_settings(UserSettings.dialogue)
	UserSettings.dialogue_settings_changed.connect(_on_dialogue_settings_changed)

	var db := ContentDB.new()
	if not db.load_from_directories(CONTENT_DIRS):
		push_error("Dialogue UI test scene failed to load content.")
		return

	var state := GameState.new()
	_runner = RunnerScript.new()
	add_child(_runner)

	var presenter: RefCounted = UiPresenterScript.new()
	presenter.configure(_ui, _runner)
	_runner.configure(db, state, presenter)
	_build_settings_panel()
	_runner.start(DIALOGUE_ID)


func _build_settings_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(280, 0)
	layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Dialogue settings"
	column.add_child(title)

	_scale_option = _add_option_setting(
		column,
		"Font size",
		["small", "normal", "large", "extra_large"],
		UserSettings.dialogue.text_scale
	)
	_speed_option = _add_option_setting(
		column,
		"Text speed",
		SettingsScript.TEXT_SPEEDS,
		UserSettings.dialogue.text_speed
	)
	_contrast_check = _add_toggle_setting(column, "High contrast", UserSettings.dialogue.high_contrast)
	_subtitle_check = _add_toggle_setting(column, "Subtitle background", UserSettings.dialogue.subtitle_background)
	_motion_check = _add_toggle_setting(column, "Reduced motion", UserSettings.dialogue.reduced_motion)

	var apply_button := Button.new()
	apply_button.text = "Apply and persist"
	apply_button.pressed.connect(_apply_panel_settings)
	column.add_child(apply_button)

	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "Settings reload from user://settings on scene start."
	column.add_child(hint)


func _add_option_setting(parent: VBoxContainer, label_text: String, values: Array, current: String) -> OptionButton:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120, 0)
	row.add_child(label)

	var option := OptionButton.new()
	for value in values:
		option.add_item(String(value))
		if String(value) == current:
			option.select(option.item_count - 1)
	option.item_selected.connect(func(_index: int) -> void: _apply_panel_settings())
	row.add_child(option)
	return option


func _add_toggle_setting(parent: VBoxContainer, label_text: String, pressed: bool) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = label_text
	toggle.button_pressed = pressed
	toggle.toggled.connect(func(_on: bool) -> void: _apply_panel_settings())
	parent.add_child(toggle)
	return toggle


func _apply_panel_settings() -> void:
	var settings := SettingsScript.default_settings()
	settings.text_scale = _scale_option.get_item_text(_scale_option.selected)
	settings.text_speed = _speed_option.get_item_text(_speed_option.selected)
	settings.high_contrast = _contrast_check.button_pressed
	settings.subtitle_background = _subtitle_check.button_pressed
	settings.reduced_motion = _motion_check.button_pressed
	UserSettings.apply_dialogue_settings(settings)


func _on_dialogue_settings_changed(settings) -> void:
	_ui.apply_settings(settings)

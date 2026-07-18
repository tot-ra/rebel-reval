extends Node

## Manual overflow review scene for P1-014 pseudo-localization stress testing.

const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const UiPresenterScript := preload("res://scripts/dialogue/dialogue_ui_presenter.gd")
const UiScript := preload("res://scripts/dialogue/dialogue_ui.gd")
const SettingsScript := preload("res://scripts/settings/dialogue_settings.gd")
const DIALOGUE_ID := &"dialogue.test_overflow"

const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]


func _ready() -> void:
	var ui = UiScript.new()
	add_child(ui)

	var settings = SettingsScript.default_settings()
	settings.text_speed = "instant"
	settings.pseudo_localization = true
	settings.text_scale = "extra_large"
	ui.apply_settings(settings)

	var db := ContentDB.new()
	if not db.load_from_directories(CONTENT_DIRS):
		push_error("Dialogue overflow test scene failed to load content.")
		return

	var state := GameState.new()
	var runner = RunnerScript.new()
	add_child(runner)

	var presenter: RefCounted = UiPresenterScript.new()
	presenter.configure(ui, runner)
	runner.configure(db, state, presenter)
	runner.start(DIALOGUE_ID)

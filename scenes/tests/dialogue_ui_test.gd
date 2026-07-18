extends Node

## Manual dialogue UI smoke scene for P1-012.

const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const UiPresenterScript := preload("res://scripts/dialogue/dialogue_ui_presenter.gd")
const UiScript := preload("res://scripts/dialogue/dialogue_ui.gd")
const DIALOGUE_ID := &"dialogue.test_ui.branching"

const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]


func _ready() -> void:
	var ui = UiScript.new()
	add_child(ui)

	var db := ContentDB.new()
	if not db.load_from_directories(CONTENT_DIRS):
		push_error("Dialogue UI test scene failed to load content.")
		return

	var state := GameState.new()
	var runner = RunnerScript.new()
	add_child(runner)

	var presenter: RefCounted = UiPresenterScript.new()
	presenter.configure(ui, runner)
	runner.configure(db, state, presenter)
	runner.start(DIALOGUE_ID)

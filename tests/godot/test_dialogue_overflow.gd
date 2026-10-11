extends "res://tests/godot/test_case.gd"

const TextLayoutScript := preload("res://scripts/dialogue/dialogue_text_layout.gd")
const TextScaleScript := preload("res://scripts/dialogue/dialogue_text_scale.gd")
const SettingsScript := preload("res://scripts/settings/dialogue_settings.gd")
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const UiPresenterScript := preload("res://scripts/dialogue/dialogue_ui_presenter.gd")
const UiScript := preload("res://scripts/dialogue/dialogue_ui.gd")
const PseudoLocalizationScript := preload("res://scripts/dialogue/dialogue_pseudo_localization.gd")

const FONT_PATH := "res://assets/fonts/NotoSans-Regular.ttf"
const DIALOGUE_ID := &"dialogue.test_overflow"

const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]


func test_overflow_fixture_fits_or_scrolls_at_target_resolutions() -> void:
	var font := load(FONT_PATH) as Font
	assert_true(font != null)

	for viewport_size in TextLayoutScript.TARGET_VIEWPORTS:
		for scale_name in TextScaleScript.supported_scale_names():
			_assert_fixture_lines_fit_or_scroll(font, viewport_size, scale_name)


func test_pseudo_localized_overflow_fixture_fits_or_scrolls() -> void:
	var font := load(FONT_PATH) as Font
	assert_true(font != null)

	for viewport_size in TextLayoutScript.TARGET_VIEWPORTS:
		_assert_fixture_lines_fit_or_scroll(
			font,
			viewport_size,
			"extra_large",
			true
		)


func test_dialogue_ui_applies_pseudo_localization_setting() -> void:
	var setup := _make_setup("normal", true)
	var ui = setup["ui"]
	var source := "Short line."
	var localized: String = ui.localize_text_for_display(source)
	assert_ne(localized, source)
	assert_true(localized.begins_with("["))
	_cleanup_setup(setup)


func test_branching_overflow_dialogue_starts_under_pseudo_localization() -> void:
	var setup := _make_setup("large", true)
	var ui = setup["ui"]
	var runner = setup["runner"]
	assert_true(runner.start(DIALOGUE_ID))
	assert_true(ui.is_showing())
	assert_true(ui.get_visible_line_text().begins_with("["))
	_cleanup_setup(setup)


func _assert_fixture_lines_fit_or_scroll(
	font: Font,
	viewport_size: Vector2i,
	text_scale: String,
	use_pseudo_localization: bool = false
) -> void:
	var dialogue := _load_overflow_dialogue()
	for node_value in dialogue.get("nodes", []):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var text := String(node.get("text", ""))
		if use_pseudo_localization:
			text = PseudoLocalizationScript.expand(text)
		var choice_count := int((node.get("choices", []) as Array).size())
		var has_disabled_reason := false
		for choice_value in node.get("choices", []):
			if typeof(choice_value) != TYPE_DICTIONARY:
				continue
			var choice: Dictionary = choice_value
			if not String(choice.get("disabled_reason", "")).is_empty():
				has_disabled_reason = true
				var reason := String(choice.get("disabled_reason", ""))
				if use_pseudo_localization:
					reason = PseudoLocalizationScript.expand(reason)
				assert_true(
					TextLayoutScript.text_fits_or_needs_scroll(
						font,
						reason,
						viewport_size,
						text_scale,
						choice_count,
						true
					),
					"Disabled reason should fit or scroll at %s %s" % [viewport_size, text_scale]
				)
			var choice_text := String(choice.get("text", ""))
			if use_pseudo_localization:
				choice_text = PseudoLocalizationScript.expand(choice_text)
			assert_true(
				TextLayoutScript.text_fits_or_needs_scroll(
					font,
					choice_text,
					viewport_size,
					text_scale,
					choice_count,
					has_disabled_reason
				),
				"Choice text should fit or scroll at %s %s" % [viewport_size, text_scale]
			)
		if text.is_empty():
			continue
		assert_true(
			TextLayoutScript.text_fits_or_needs_scroll(
				font,
				text,
				viewport_size,
				text_scale,
				choice_count,
				has_disabled_reason
			),
			"Line text should fit or scroll at %s %s" % [viewport_size, text_scale]
		)


func _load_overflow_dialogue() -> Dictionary:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))
	var dialogue := db.get_dialogue(DIALOGUE_ID)
	assert_false(dialogue.is_empty())
	return dialogue


func _make_setup(scale_name: String, pseudo_localization: bool) -> Dictionary:
	var root := _make_root()
	var ui = UiScript.new()
	root.add_child(ui)
	ui.set_text_scale(scale_name)
	var settings = SettingsScript.default_settings()
	settings.text_scale = scale_name
	settings.text_speed = "instant"
	settings.pseudo_localization = pseudo_localization
	ui.apply_settings(settings)

	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))

	var state := GameState.new()
	var runner = RunnerScript.new()
	root.add_child(runner)

	var presenter: RefCounted = UiPresenterScript.new()
	presenter.configure(ui, runner)
	runner.configure(db, state, presenter)

	return {
		"root": root,
		"ui": ui,
		"runner": runner,
		"state": state,
	}


func _cleanup_setup(setup: Dictionary) -> void:
	_cleanup_node(setup.get("root"))


func _make_root() -> Node:
	var root := Node.new()
	(_tree().root as Node).add_child(root)
	return root


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _cleanup_node(node: Node) -> void:
	if is_instance_valid(node):
		node.free()

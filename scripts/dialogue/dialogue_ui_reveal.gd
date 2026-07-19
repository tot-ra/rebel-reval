class_name DialogueUiReveal
extends RefCounted

## Typewriter line reveal for DialogueUI.


static func process(ui: DialogueUI, delta: float) -> void:
	if ui._reveal_complete or ui._full_line_text.is_empty():
		ui.set_process(false)
		return

	ui._reveal_accumulator += delta * ui._settings.chars_per_second()
	while ui._reveal_accumulator >= 1.0 and ui._revealed_char_count < ui._full_line_text.length():
		ui._revealed_char_count += 1
		ui._reveal_accumulator -= 1.0
		ui._text_label.text = ui._full_line_text.left(ui._revealed_char_count)

	if ui._revealed_char_count >= ui._full_line_text.length():
		complete(ui)


static func start(ui: DialogueUI) -> void:
	ui._revealed_char_count = 0
	ui._reveal_accumulator = 0.0
	if ui._settings.reveal_instantly() or ui._full_line_text.is_empty():
		complete(ui)
		return
	ui._reveal_complete = false
	ui._text_label.text = ""
	ui.set_process(true)


static func restart(ui: DialogueUI) -> void:
	if ui._full_line_text.is_empty():
		return
	start(ui)


static func complete(ui: DialogueUI) -> void:
	ui._revealed_char_count = ui._full_line_text.length()
	ui._text_label.text = ui._full_line_text
	ui._reveal_complete = true
	ui._reveal_accumulator = 0.0
	ui.set_process(false)

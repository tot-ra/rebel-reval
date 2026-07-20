extends CanvasLayer

class_name CombatFeedbackHud

## Readable combat feedback for the P1-024 test room. Always visible in that
## scene so outcomes do not rely on a hotkey alone.

## P1-025a enemy loops emit detect/telegraph/attack/react/disengage lines; keep
## enough history so headless room tests can assert readable phase feedback.
const MAX_LOG_LINES := 16

var _status_label: Label
var _log_label: Label
var _controls_label: Label
var _log_lines: PackedStringArray = PackedStringArray()


func _ready() -> void:
	layer = 40
	_build_ui()


func set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func push_event(text: String) -> void:
	_log_lines.append(text)
	while _log_lines.size() > MAX_LOG_LINES:
		_log_lines.remove_at(0)
	if _log_label != null:
		_log_label.text = "\n".join(_log_lines)


func clear_log() -> void:
	_log_lines.clear()
	if _log_label != null:
		_log_label.text = ""


func describe_hit_result(actor_label: String, result: CombatHitResult) -> String:
	if result == null:
		return "%s: no result" % actor_label
	var detail := String(result.outcome)
	if result.health_damage > 0.0:
		detail += " hp-%.0f" % result.health_damage
	if result.stamina_damage > 0.0:
		detail += " sta-%.0f" % result.stamina_damage
	if result.guard_pierced:
		detail += " (Iron jam)"
	if result.died:
		detail += " DEAD"
	return "%s: %s" % [actor_label, detail]


func _build_ui() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 16)
	root.add_theme_constant_override("margin_top", 16)
	root.add_theme_constant_override("margin_right", 16)
	root.add_theme_constant_override("margin_bottom", 16)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)

	var title := Label.new()
	title.text = "Combat room (P1-024 / P1-025a)"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35, 1.0))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(520, 0)
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.93, 0.96, 1.0))
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_status_label)

	_log_label = Label.new()
	_log_label.name = "EventLog"
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.custom_minimum_size = Vector2(520, 120)
	_log_label.add_theme_font_size_override("font_size", 13)
	_log_label.add_theme_color_override("font_color", Color(0.75, 0.88, 0.78, 1.0))
	_log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_log_label)

	_controls_label = Label.new()
	_controls_label.name = "ControlsLabel"
	_controls_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_controls_label.custom_minimum_size = Vector2(520, 0)
	_controls_label.add_theme_font_size_override("font_size", 12)
	_controls_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82, 0.95))
	_controls_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls_label.text = (
		"Attack: Space / gamepad X (hold for charged hammer)\n"
		+ "Guard / parry: F or right mouse / gamepad LB\n"
		+ "Dodge: Q / gamepad RB\n"
		+ "Iron: Quick-access Iron button (mouse)\n"
		+ "Enemies: approach Watchman (gold) or Sergeant (magenta)\n"
		+ "Reset: Reset room button"
	)
	column.add_child(_controls_label)

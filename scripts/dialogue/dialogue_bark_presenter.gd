class_name DialogueBarkPresenter
extends Node

## Non-blocking speech bubbles for authored bark lines. Unlike DialogueUI, this
## presenter never captures input or pauses interaction; it follows the speaker's
## 3D rig while the line is visible and expires automatically.

const FONT_PATH := "res://assets/fonts/NotoSans-Regular.ttf"
const DEFAULT_DURATION_SEC := 3.2
const BUBBLE_WIDTH := 320.0
const WORLD_HEAD_HEIGHT := 1.85
const SCREEN_TOP_MARGIN := 24.0
const SCREEN_SIDE_MARGIN := 18.0

var _layer: CanvasLayer
var _panel: PanelContainer
var _speaker_label: Label
var _text_label: Label
var _anchor: Node2D
var _view_runtime: Node
var _remaining_sec := 0.0
var _visible_active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide_bark()


func is_showing() -> bool:
	return _visible_active


func get_speaker_text() -> String:
	return _speaker_label.text if _speaker_label != null else ""


func get_bark_text() -> String:
	return _text_label.text if _text_label != null else ""


func get_remaining_seconds() -> float:
	return _remaining_sec


func show_bark(
	feedback: Dictionary,
	anchor: Node2D = null,
	view_runtime: Node = null,
	duration_sec: float = DEFAULT_DURATION_SEC
) -> bool:
	if _panel == null:
		return false
	var text := String(feedback.get("text", "")).strip_edges()
	if text.is_empty():
		return false

	_anchor = anchor
	_view_runtime = view_runtime
	_speaker_label.text = String(feedback.get("speaker_name", "")).strip_edges()
	_speaker_label.visible = not _speaker_label.text.is_empty()
	_text_label.text = text
	_remaining_sec = maxf(duration_sec, 0.1)
	_visible_active = true
	_panel.visible = true
	_update_position()
	return true


func hide_bark() -> void:
	_visible_active = false
	_remaining_sec = 0.0
	_anchor = null
	_view_runtime = null
	if _panel != null:
		_panel.visible = false
	if _speaker_label != null:
		_speaker_label.text = ""
	if _text_label != null:
		_text_label.text = ""


func _process(delta: float) -> void:
	if not _visible_active:
		return
	_remaining_sec = maxf(0.0, _remaining_sec - delta)
	if _remaining_sec <= 0.0:
		hide_bark()
		return
	_update_position()


func _update_position() -> void:
	if _panel == null or not _visible_active:
		return
	var screen_position := _screen_position_for_anchor()
	var viewport_size := get_viewport().get_visible_rect().size
	var bubble_size := _panel.size
	if bubble_size.x <= 0.0:
		bubble_size.x = BUBBLE_WIDTH
	if bubble_size.y <= 0.0:
		bubble_size.y = 72.0
	var x := clampf(
		screen_position.x - bubble_size.x * 0.5,
		SCREEN_SIDE_MARGIN,
		maxf(SCREEN_SIDE_MARGIN, viewport_size.x - bubble_size.x - SCREEN_SIDE_MARGIN)
	)
	var y := clampf(
		screen_position.y - bubble_size.y - 18.0,
		SCREEN_TOP_MARGIN,
		maxf(SCREEN_TOP_MARGIN, viewport_size.y - bubble_size.y - SCREEN_SIDE_MARGIN)
	)
	_panel.position = Vector2(x, y)


func _screen_position_for_anchor() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	if _anchor == null or not is_instance_valid(_anchor):
		return Vector2(viewport_size.x * 0.5, viewport_size.y * 0.24)

	if _view_runtime != null and _view_runtime.has_method("get_actor_rig"):
		var rig := _view_runtime.call("get_actor_rig", _anchor) as Node3D
		if rig != null:
			var camera := get_viewport().get_camera_3d()
			if camera != null:
				var world_position := rig.global_position + Vector3.UP * WORLD_HEAD_HEIGHT
				if camera.is_position_behind(world_position):
					return Vector2(viewport_size.x * 0.5, SCREEN_TOP_MARGIN)
				return camera.unproject_position(world_position)

	# Compatibility fallback for 2D-only preview scenes and tests. The shipped
	# forge scene uses the 3D rig path above, so screen bubbles stay over the model.
	return _anchor.global_position


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "DialogueBarkLayer"
	_layer.layer = 44
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(BUBBLE_WIDTH, 0.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _bubble_style())
	_layer.add_child(_panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 3)
	margin.add_child(column)

	var font := load(FONT_PATH) as Font
	_speaker_label = Label.new()
	_speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speaker_label.add_theme_font_override("font", font)
	_speaker_label.add_theme_font_size_override("font_size", 15)
	_speaker_label.add_theme_color_override("font_color", Color(0.92, 0.76, 0.39, 1.0))
	column.add_child(_speaker_label)

	_text_label = Label.new()
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(BUBBLE_WIDTH - 28.0, 0.0)
	_text_label.add_theme_font_override("font", font)
	_text_label.add_theme_font_size_override("font_size", 18)
	_text_label.add_theme_color_override("font_color", Color(0.96, 0.95, 0.9, 1.0))
	column.add_child(_text_label)


func _bubble_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.06, 0.96)
	style.border_color = Color(0.72, 0.52, 0.23, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 6
	return style

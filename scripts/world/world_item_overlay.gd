class_name WorldItemOverlay
extends Node

## Tooltip, pickup bark, SFX, and cursor feedback for WorldItemController.

const PickupFeedbackScript := preload("res://scripts/world/world_item_pickup_feedback.gd")

var feedback_text := ""
var cursor_over_pickup := false

var _tooltip: Label
var _bark_label: Label
var _audio_player: AudioStreamPlayer
var _feedback_timer := 0.0
var _bark_timer := 0.0
var _pickup_bark_runner: DialogueRunner


func _ready() -> void:
	_build_ui()


func tick(delta: float) -> void:
	if _feedback_timer > 0.0:
		_feedback_timer = maxf(0.0, _feedback_timer - delta)
		if _feedback_timer <= 0.0:
			feedback_text = ""
	if _bark_timer > 0.0:
		_bark_timer = maxf(0.0, _bark_timer - delta)
		if _bark_timer <= 0.0 and _bark_label != null:
			_bark_label.visible = false
			_bark_label.text = ""


func show_feedback(message: String) -> void:
	feedback_text = message
	_feedback_timer = 1.4


func update_tooltip(
	hovered: WorldItem,
	blocking_pickup: bool,
	name_text: String,
	action_text: String,
	mouse_position: Vector2
) -> void:
	if _tooltip == null:
		return
	if hovered == null or blocking_pickup:
		_tooltip.visible = false
		_tooltip.text = ""
		return
	var action := action_text
	if not feedback_text.is_empty():
		action = feedback_text
	_tooltip.visible = true
	_tooltip.text = "%s\n%s" % [name_text, action]
	_tooltip.global_position = mouse_position + Vector2(18.0, 18.0)


func update_cursor(wants_grab: bool) -> void:
	if wants_grab == cursor_over_pickup:
		return
	cursor_over_pickup = wants_grab
	if wants_grab:
		Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	else:
		restore_cursor()


func restore_cursor() -> void:
	cursor_over_pickup = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func resolve_pickup_feedback(
	item_id: StringName,
	item_record: Dictionary,
	content_db: ContentDB,
	state: GameState,
	location_id: StringName
) -> Dictionary:
	var resolved := PickupFeedbackScript.resolve_feedback(
		item_id,
		item_record,
		content_db,
		state,
		location_id,
		_pickup_bark_runner
	)
	_pickup_bark_runner = resolved.get("bark_runner", _pickup_bark_runner)
	return resolved.get("feedback", {})


func show_pickup_bark(feedback: Dictionary) -> void:
	_bark_timer = PickupFeedbackScript.show_bark(_bark_label, feedback)


func play_pickup_sfx(item_record: Dictionary) -> void:
	PickupFeedbackScript.play_pickup_sfx(_audio_player, item_record)


func _build_ui() -> void:
	var tooltip_layer := CanvasLayer.new()
	tooltip_layer.layer = 30
	add_child(tooltip_layer)

	_tooltip = Label.new()
	_tooltip.add_theme_color_override("font_color", Color(0.96, 0.95, 0.9, 1.0))
	_tooltip.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.08, 1.0))
	_tooltip.add_theme_constant_override("outline_size", 4)
	_tooltip.visible = false
	tooltip_layer.add_child(_tooltip)

	_bark_label = Label.new()
	_bark_label.anchor_left = 0.5
	_bark_label.anchor_right = 0.5
	_bark_label.anchor_top = 1.0
	_bark_label.anchor_bottom = 1.0
	_bark_label.offset_left = -360.0
	_bark_label.offset_right = 360.0
	_bark_label.offset_top = -96.0
	_bark_label.offset_bottom = -48.0
	_bark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bark_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bark_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.9, 1.0))
	_bark_label.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.08, 1.0))
	_bark_label.add_theme_constant_override("outline_size", 5)
	_bark_label.visible = false
	tooltip_layer.add_child(_bark_label)

	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "PickupSfx"
	add_child(_audio_player)

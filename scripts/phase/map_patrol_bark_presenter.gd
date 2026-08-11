class_name MapPatrolBarkPresenter
extends Node

## Shows authored patrol barks when a patrol body passes near the player.

const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const FeedbackScript := preload("res://scripts/world/world_item_pickup_feedback.gd")

const BARK_INTERVAL_SEC := 14.0
const PROXIMITY_RADIUS_SQ := 96.0 * 96.0

var location_id: StringName = &""
var bark_pool_id: StringName = &""

var _player: Node2D
var _patrol_body: CharacterBody2D
var _layer: CanvasLayer
var _label: Label
var _runner: DialogueRunner
var _timer := 0.0
var _bark_timer := 0.0
var _enabled := false


func setup(
	scene_root: Node,
	location: StringName,
	pool_id: StringName,
	player: Node2D,
	patrol_body: CharacterBody2D
) -> void:
	location_id = location
	bark_pool_id = pool_id
	_player = player
	_patrol_body = patrol_body
	_build_ui(scene_root)
	_runner = RunnerScript.new()
	_runner.name = "PatrolBarkRunner"
	add_child(_runner)
	_runner.configure(SessionState.content_db, SessionState.state, null)
	if not SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.connect(_on_state_replaced)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not _enabled and _label != null:
		_label.visible = false
		_label.text = ""
		_bark_timer = 0.0


func _exit_tree() -> void:
	if SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.disconnect(_on_state_replaced)


func _on_state_replaced(_previous: GameState, current: GameState, _reason: StringName) -> void:
	if _runner != null:
		_runner.configure(SessionState.content_db, current, null)


func _process(delta: float) -> void:
	if not _enabled or _player == null or _patrol_body == null or SessionState.state == null:
		return
	if _bark_timer > 0.0:
		_bark_timer = maxf(0.0, _bark_timer - delta)
		if _bark_timer <= 0.0 and _label != null:
			_label.visible = false
			_label.text = ""
		return
	_timer += delta
	if _timer < BARK_INTERVAL_SEC:
		return
	if (
		(_patrol_body.global_position - _player.global_position).length_squared()
		> PROXIMITY_RADIUS_SQ
	):
		return
	_timer = 0.0
	_try_show_bark()


func _try_show_bark() -> void:
	if bark_pool_id.is_empty() or _runner == null or SessionState.state == null:
		return
	_runner.configure(SessionState.content_db, SessionState.state, null)
	var bark := _runner.resolve_bark(bark_pool_id, SessionState.state.get_phase(), location_id)
	if bark.is_empty():
		return
	_bark_timer = FeedbackScript.show_bark(_label, bark)


func _build_ui(scene_root: Node) -> void:
	_layer = CanvasLayer.new()
	_layer.name = "PatrolBarkPresenter"
	_layer.layer = 24
	scene_root.add_child(_layer)

	_label = Label.new()
	_label.anchor_left = 0.5
	_label.anchor_right = 0.5
	_label.anchor_top = 1.0
	_label.anchor_bottom = 1.0
	_label.offset_left = -360.0
	_label.offset_right = 360.0
	_label.offset_top = -120.0
	_label.offset_bottom = -72.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.9, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.08, 1.0))
	_label.add_theme_constant_override("outline_size", 5)
	_label.visible = false
	_layer.add_child(_label)

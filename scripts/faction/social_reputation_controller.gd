class_name SocialReputationController
extends Node

## Presents one-shot crowd reactions when faction standing crosses authored thresholds.

const ModelScript := preload("res://scripts/faction/social_reputation_model.gd")
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const FeedbackScript := preload("res://scripts/world/world_item_pickup_feedback.gd")

var location_id: StringName = &""

var _scene_root: Node
var _player: Node2D
var _layer: CanvasLayer
var _label: Label
var _runner: DialogueRunner
var _audio_player: AudioStreamPlayer
var _bark_timer := 0.0
var _state: GameState


func setup(scene_root: Node, map_location_id: StringName, player: Node2D) -> void:
	location_id = map_location_id
	_scene_root = scene_root
	_player = player
	_build_ui()
	_runner = RunnerScript.new()
	_runner.name = "SocialReputationBarkRunner"
	add_child(_runner)
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "SocialReputationSfx"
	_audio_player.bus = &"SFX"
	add_child(_audio_player)
	_connect_state(SessionState.state)
	if not SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.connect(_on_state_replaced)


func _exit_tree() -> void:
	if SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.disconnect(_on_state_replaced)
	_disconnect_state(_state)


func _process(delta: float) -> void:
	if _bark_timer <= 0.0 or _label == null:
		return
	_bark_timer = maxf(0.0, _bark_timer - delta)
	if _bark_timer <= 0.0:
		_label.visible = false
		_label.text = ""


func _on_state_replaced(_previous: GameState, current: GameState, _reason: StringName) -> void:
	_connect_state(current)


func _connect_state(state: GameState) -> void:
	_disconnect_state(_state)
	_state = state
	if _state == null:
		return
	if not _state.faction_event_recorded.is_connected(_on_faction_event_recorded):
		_state.faction_event_recorded.connect(_on_faction_event_recorded)
	_evaluate_pending()


func _disconnect_state(state: GameState) -> void:
	if state != null and state.faction_event_recorded.is_connected(_on_faction_event_recorded):
		state.faction_event_recorded.disconnect(_on_faction_event_recorded)


func _on_faction_event_recorded(_event_id: StringName, _faction_id: StringName) -> void:
	_evaluate_pending()


func _evaluate_pending() -> void:
	if _state == null or SessionState.content_db == null:
		return
	for event in ModelScript.events_to_fire(_state, location_id):
		ModelScript.mark_fired(_state, event)
		_present_reaction(event)


func _present_reaction(event: Dictionary) -> void:
	if _runner == null or _state == null:
		return
	_runner.configure(SessionState.content_db, _state, null)
	var bark_pool_id: StringName = event.get("bark_pool_id", &"")
	var bark := _runner.resolve_bark(bark_pool_id, _state.get_phase(), location_id)
	if not bark.is_empty() and _label != null:
		_bark_timer = FeedbackScript.show_bark(_label, bark)
	_play_reaction_sfx(event)


func _play_reaction_sfx(event: Dictionary) -> void:
	if _audio_player == null:
		return
	var path := String(event.get("sfx_path", "")).strip_edges()
	if path.is_empty():
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	_audio_player.stream = stream
	_audio_player.pitch_scale = float(event.get("sfx_pitch", 1.0))
	_audio_player.volume_db = float(event.get("sfx_volume_db", -8.0))
	_audio_player.play()


func _build_ui() -> void:
	if _scene_root == null:
		return
	_layer = CanvasLayer.new()
	_layer.name = "SocialReputationPresenter"
	_layer.layer = 23
	_scene_root.add_child(_layer)

	_label = Label.new()
	_label.anchor_left = 0.5
	_label.anchor_right = 0.5
	_label.anchor_top = 1.0
	_label.anchor_bottom = 1.0
	_label.offset_left = -380.0
	_label.offset_right = 380.0
	_label.offset_top = -168.0
	_label.offset_bottom = -120.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.08, 1.0))
	_label.add_theme_constant_override("outline_size", 5)
	_label.visible = false
	_layer.add_child(_label)

class_name CutscenePlayer
extends CanvasLayer
## Plays a `cutscene` content record (ADR 0034): letterboxed frame with a slow camera
## move, a place-and-date caption, a speaker plate, and a chain to whatever comes next.
##
## Input (keyboard, mouse and gamepad through the existing actions):
##   interact / ui_accept / left click - advance one line, then one shot
##   ui_cancel tapped                  - skip the rest of the current shot
##   ui_cancel held HOLD_TO_SKIP_SEC   - skip the whole sequence
##
## The player owns no story logic. It reads a CutsceneSequence and, when the last shot
## ends, follows the record's `next` block. Tests set `auto_continue = false` to stop
## before any scene change.

signal shot_changed(shot_id: StringName, index: int)
signal line_changed(shot_id: StringName, line_index: int)
signal finished(sequence_id: StringName, skipped: bool)

const HOLD_TO_SKIP_SEC := 0.6
const LETTERBOX_RATIO := 0.072
const FADE_SEC := 0.6
## Breathing room after a spoken line ends, so the next one does not start on its heels.
const VOICE_TAIL_SEC := 0.9
## Longer pause when the line closes a shot, so the image can sit before the cut.
const VOICE_SHOT_END_TAIL_SEC := 1.8
const VOICE_BUS := &"Voice"
## Narration trim, so the underscore can be raised without drowning the narrator.
const VOICE_DB := -4.0
const MUSIC_BUS := &"Music"
const MUSIC_FADE_IN_SEC := 2.0
const MUSIC_FADE_OUT_SEC := 3.0
const MUSIC_SILENT_DB := -60.0
## Shown instead of the frame when a still is missing, so a not-yet-generated shot
## degrades to a readable title card rather than a crash or a blank screen.
const MISSING_STILL_COLOR := Color(0.05, 0.05, 0.07, 1.0)

## When false the player stops at the end instead of changing scene. Tests use this.
var auto_continue := true
var sequence: CutsceneSequence
var shot_index := -1
var line_index := -1
var is_playing := false

var _elapsed_in_line := 0.0
var _shot_elapsed := 0.0
var _fade_elapsed := 0.0
var _cancel_held := 0.0
var _skipped := false
var _finished := false

var _frame_clip: Control
var _frame: TextureRect
var _vignette: ColorRect
var _caption_label: Label
var _chapter_label: Label
var _speaker_label: Label
var _line_label: Label
var _hint_label: Label
var _text_plate: ColorRect
var _voice: AudioStreamPlayer
var _music: AudioStreamPlayer
var _music_path := ""
## Seconds the current line holds before auto-advance: the authored `seconds`, stretched
## to cover its voice take so narration is never cut off by the timer.
var _line_hold := 0.0


func _init() -> void:
	layer = 95
	# The opening may run while nothing else is ticking; never depend on the tree's pause state.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_build_ui()
	if sequence != null and not is_playing:
		play(sequence)


## Load a sequence by content ID and start it. Returns false when the record is missing
## or unusable, so callers can fall back to whatever they did before.
func play_id(db: ContentDB, cutscene_id: StringName) -> bool:
	if db == null:
		return false
	var parsed := CutsceneSequence.from_record(db.get_cutscene(cutscene_id))
	if parsed == null:
		push_warning("Cutscene record is missing or unusable: %s" % String(cutscene_id))
		return false
	play(parsed)
	return true


func play(target: CutsceneSequence) -> void:
	sequence = target
	shot_index = -1
	line_index = -1
	_skipped = false
	_finished = false
	is_playing = true
	add_to_group(&"cutscene_active")
	if _frame_clip != null and not sequence.chapter.is_empty():
		_chapter_label.text = sequence.chapter
	_advance_shot()


func current_shot() -> CutsceneSequence.Shot:
	if sequence == null or shot_index < 0 or shot_index >= sequence.shots.size():
		return null
	return sequence.shots[shot_index]


func _unhandled_input(event: InputEvent) -> void:
	if not is_playing:
		return
	# Cached: advancing/skipping can finish the cutscene and leave the tree.
	var viewport := get_viewport()
	if event.is_action_pressed(&"ui_cancel"):
		_cancel_held = 0.0
		viewport.set_input_as_handled()
		return
	if event.is_action_released(&"ui_cancel"):
		# A tap skips the shot; the hold path already fired in _process.
		if is_playing and _cancel_held < HOLD_TO_SKIP_SEC:
			_advance_shot()
		_cancel_held = -1.0
		viewport.set_input_as_handled()
		return
	var is_advance := (
		event.is_action_pressed(&"interact")
		or event.is_action_pressed(&"ui_accept")
		or (
			event is InputEventMouseButton
			and (event as InputEventMouseButton).pressed
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
		)
	)
	if is_advance:
		advance()
		viewport.set_input_as_handled()


func _process(delta: float) -> void:
	if not is_playing:
		return
	if Input.is_action_pressed(&"ui_cancel") and _cancel_held >= 0.0:
		_cancel_held += delta
		if _cancel_held >= HOLD_TO_SKIP_SEC and sequence != null and sequence.skippable:
			skip()
			return
	_fade_elapsed += delta
	_shot_elapsed += delta
	_elapsed_in_line += delta
	_apply_motion()
	_apply_fade()

	var shot := current_shot()
	if shot == null:
		return
	if shot.lines.is_empty():
		if _shot_elapsed >= shot.hold_seconds:
			_advance_shot()
		return
	if line_index < 0 or line_index >= shot.lines.size():
		return
	# WHY the playing check: a take must never be cut off by the timer, even if the
	# decoded stream length was underestimated.
	if _elapsed_in_line >= _line_hold and not (_voice != null and _voice.playing):
		advance()


## One step forward: next line inside the shot, or the next shot.
func advance() -> void:
	if not is_playing:
		return
	var shot := current_shot()
	if shot == null:
		_advance_shot()
		return
	if line_index + 1 < shot.lines.size():
		_set_line(line_index + 1)
		return
	_advance_shot()


## Abandon the whole sequence and go straight to the chain target.
func skip() -> void:
	if not is_playing:
		return
	_skipped = true
	_finish()


func _advance_shot() -> void:
	if sequence == null:
		_finish()
		return
	shot_index += 1
	if shot_index >= sequence.shots.size():
		_finish()
		return
	_shot_elapsed = 0.0
	_fade_elapsed = 0.0
	line_index = -1
	var shot := sequence.shots[shot_index]
	_load_frame(shot)
	_caption_label.text = shot.caption
	_start_music(shot)
	_chapter_label.visible = shot_index == 0 and not sequence.chapter.is_empty()
	shot_changed.emit(shot.id, shot_index)
	if shot.lines.is_empty():
		_stop_voice()
		_set_text("", "")
	else:
		_set_line(0)


func _set_line(index: int) -> void:
	var shot := current_shot()
	if shot == null or index < 0 or index >= shot.lines.size():
		return
	line_index = index
	_elapsed_in_line = 0.0
	var line := shot.lines[index]
	_set_text(line.speaker, line.text)
	_line_hold = line.seconds
	_play_voice(line)
	line_changed.emit(shot.id, index)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	is_playing = false
	remove_from_group(&"cutscene_active")
	_stop_voice()
	_release_music()
	finished.emit(sequence.id if sequence != null else &"", _skipped)
	if auto_continue:
		_follow_next()


## Act on the record's `next` block. Scene changes live here and nowhere else.
func _follow_next() -> void:
	var target: Dictionary = sequence.next_target if sequence != null else {}
	match String(target.get("kind", "return")):
		"cutscene":
			var next_id := StringName(String(target.get("cutscene_id", "")))
			if not play_id(SessionState.content_db, next_id):
				queue_free()
		"door":
			DoorNavigator.go_to_scene(
				StringName(String(target.get("scene_id", ""))),
				StringName(String(target.get("spawn_id", "")))
			)
		"scene_file":
			var path := String(target.get("scene_path", ""))
			if not path.is_empty():
				get_tree().change_scene_to_file(path)
		_:
			queue_free()


## Play the line's voice take, replacing whatever was speaking. A missing or unloadable
## file degrades to the silent timed line instead of failing the cutscene.
func _play_voice(line: CutsceneSequence.Line) -> void:
	_stop_voice()
	if _voice == null or line.voice_path.is_empty() or not ResourceLoader.exists(line.voice_path):
		return
	var stream := load(line.voice_path)
	if not stream is AudioStream:
		return
	_voice.stream = stream
	_voice.play()
	var shot := current_shot()
	var closes_shot := shot != null and line_index == shot.lines.size() - 1
	var tail := VOICE_SHOT_END_TAIL_SEC if closes_shot else VOICE_TAIL_SEC
	_line_hold = maxf(line.seconds, (stream as AudioStream).get_length() + tail)


## Start the shot's underscore unless that track is already playing. A new track replaces
## the old one; an empty `music` leaves the current one running across shots.
func _start_music(shot: CutsceneSequence.Shot) -> void:
	if _music == null or shot.music_path.is_empty() or shot.music_path == _music_path:
		return
	if not ResourceLoader.exists(shot.music_path):
		push_warning("Cutscene music is missing: %s" % shot.music_path)
		return
	var stream := load(shot.music_path)
	if not stream is AudioStream:
		return
	_music_path = shot.music_path
	_music.stream = stream
	_music.volume_db = MUSIC_SILENT_DB
	_music.play()
	create_tween().tween_property(_music, "volume_db", shot.music_db, MUSIC_FADE_IN_SEC)


## Fade the underscore out when the sequence ends. The player node is usually freed by the
## scene change that follows, so the music node moves to the tree root and a SceneTree
## tween frees it after the fade, which lets the fade finish across the cut.
func _release_music() -> void:
	if _music == null or not _music.playing or not is_inside_tree():
		return
	var tree := get_tree()
	var music := _music
	_music = null
	music.reparent(tree.root)
	var tween := tree.create_tween()
	tween.tween_property(music, "volume_db", MUSIC_SILENT_DB, MUSIC_FADE_OUT_SEC)
	tween.tween_callback(music.queue_free)


func _stop_voice() -> void:
	if _voice != null and _voice.playing:
		_voice.stop()


# --- presentation ---------------------------------------------------------------


func _load_frame(shot: CutsceneSequence.Shot) -> void:
	if _frame == null:
		return
	var path := shot.media_path()
	# WHY: a shot whose art has not been generated yet must still read as a title card.
	# ResourceLoader.exists keeps a missing file from spamming load errors every shot.
	if path.is_empty() or not ResourceLoader.exists(path):
		_frame.texture = null
		_vignette.color = MISSING_STILL_COLOR
		return
	var texture := load(path)
	_frame.texture = texture if texture is Texture2D else null
	_vignette.color = Color(0, 0, 0, 0)


func _apply_motion() -> void:
	var shot := current_shot()
	if shot == null or _frame == null:
		return
	var span := maxf(shot.duration(), 0.001)
	var t: float = clampf(_shot_elapsed / span, 0.0, 1.0)
	# Ease-out so the move is fastest at the cut and settles, which reads as a camera
	# rather than as a uniform slide.
	var eased := 1.0 - pow(1.0 - t, 2.0)
	var zoom: float = lerpf(shot.zoom_from, shot.zoom_to, eased)
	var size := _frame_clip.size
	_frame.pivot_offset = size * 0.5
	_frame.scale = Vector2(zoom, zoom)

	# Pans slide inside the overscan that the zoom already provides.
	var slack: Vector2 = size * (zoom - 1.0) * 0.5
	var offset := Vector2.ZERO
	match String(shot.motion_kind):
		"pan_left":
			offset.x = lerpf(-slack.x, slack.x, eased)
		"pan_right":
			offset.x = lerpf(slack.x, -slack.x, eased)
		"tilt_up":
			offset.y = lerpf(-slack.y, slack.y, eased)
		"tilt_down":
			offset.y = lerpf(slack.y, -slack.y, eased)
	_frame.position = offset


func _apply_fade() -> void:
	var shot := current_shot()
	if shot == null or _frame == null:
		return
	if String(shot.transition_in) == "cut":
		_frame.modulate.a = 1.0
		return
	var span := FADE_SEC if String(shot.transition_in) == "dissolve" else FADE_SEC * 1.8
	_frame.modulate.a = clampf(_fade_elapsed / span, 0.0, 1.0)


func _set_text(speaker: String, text: String) -> void:
	if _line_label == null:
		return
	_line_label.text = text
	_speaker_label.text = speaker
	_speaker_label.visible = not speaker.is_empty()
	# Narration is centred and italic-weight by size; a named speaker gets a left plate.
	_line_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_LEFT if not speaker.is_empty() else HORIZONTAL_ALIGNMENT_CENTER
	)
	_text_plate.visible = not text.is_empty()


func _build_ui() -> void:
	_voice = AudioStreamPlayer.new()
	# The Voice bus exists in audio/default_bus_layout.tres; fall back to Master if a
	# custom layout ever drops it.
	_voice.bus = VOICE_BUS if AudioServer.get_bus_index(VOICE_BUS) >= 0 else &"Master"
	_voice.volume_db = VOICE_DB
	add_child(_voice)

	_music = AudioStreamPlayer.new()
	_music.bus = MUSIC_BUS if AudioServer.get_bus_index(MUSIC_BUS) >= 0 else &"Master"
	add_child(_music)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 1)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)

	_frame_clip = Control.new()
	_frame_clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame_clip.clip_contents = true
	_frame_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_frame_clip)

	_frame = TextureRect.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame_clip.add_child(_frame)

	_vignette = ColorRect.new()
	_vignette.color = Color(0, 0, 0, 0)
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_vignette)

	for is_top: bool in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 1)
		bar.set_anchors_preset(
			Control.PRESET_TOP_WIDE if is_top else Control.PRESET_BOTTOM_WIDE
		)
		bar.anchor_bottom = LETTERBOX_RATIO if is_top else 1.0
		bar.anchor_top = 0.0 if is_top else 1.0 - LETTERBOX_RATIO
		bar.offset_top = 0.0
		bar.offset_bottom = 0.0
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bar)

	_chapter_label = _make_label(root, 34, HORIZONTAL_ALIGNMENT_CENTER)
	_chapter_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_chapter_label.anchor_right = 1.0
	_chapter_label.offset_top = 96.0
	_chapter_label.offset_left = 0.0
	_chapter_label.offset_right = 0.0

	_caption_label = _make_label(root, 20, HORIZONTAL_ALIGNMENT_LEFT)
	_caption_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_caption_label.offset_top = 104.0
	_caption_label.offset_left = 72.0
	_caption_label.offset_right = -72.0

	_text_plate = ColorRect.new()
	_text_plate.color = Color(0, 0, 0, 0.55)
	_text_plate.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_text_plate.anchor_top = 1.0
	_text_plate.offset_top = -210.0
	_text_plate.offset_bottom = -92.0
	_text_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_text_plate)

	_speaker_label = _make_label(root, 20, HORIZONTAL_ALIGNMENT_LEFT)
	_speaker_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_speaker_label.anchor_top = 1.0
	_speaker_label.offset_top = -202.0
	_speaker_label.offset_bottom = -174.0
	_speaker_label.offset_left = 120.0
	_speaker_label.offset_right = -120.0

	_line_label = _make_label(root, 26, HORIZONTAL_ALIGNMENT_CENTER)
	_line_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_line_label.anchor_top = 1.0
	_line_label.offset_top = -172.0
	_line_label.offset_bottom = -100.0
	_line_label.offset_left = 120.0
	_line_label.offset_right = -120.0

	_hint_label = _make_label(root, 15, HORIZONTAL_ALIGNMENT_RIGHT)
	_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_label.anchor_top = 1.0
	_hint_label.offset_top = -46.0
	_hint_label.offset_bottom = -16.0
	_hint_label.offset_right = -72.0
	_hint_label.modulate = Color(1, 1, 1, 0.55)
	_hint_label.text = "Space / click to continue      Esc to skip (hold to skip all)"


func _make_label(parent: Control, size: int, align: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.horizontal_alignment = align
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

class_name WorldItemPickupFeedback
extends RefCounted

## Bark lines and pickup SFX resolved from item content records.

const DEFAULT_PICKUP_SFX := "res://sounds/door.mp3"
const PICKUP_BARK_DURATION := 3.5


static func resolve_feedback(
	item_id: StringName,
	item_record: Dictionary,
	content_db: ContentDB,
	state: GameState,
	location_id: StringName,
	bark_runner: DialogueRunner
) -> Dictionary:
	var gameplay: Dictionary = item_record.get("gameplay", {})
	var pickup: Dictionary = gameplay.get("pickup", {})
	if pickup.is_empty():
		return {"feedback": {}, "bark_runner": bark_runner}

	var bark_pool_id := StringName(String(pickup.get("bark_pool_id", "")))
	if not bark_pool_id.is_empty() and state != null and content_db != null:
		var runner := bark_runner
		if runner == null:
			runner = DialogueRunner.new()
			runner.configure(content_db, state, null)
		var bark := runner.resolve_bark(bark_pool_id, state.get_phase(), location_id)
		if not bark.is_empty():
			return {"feedback": bark, "bark_runner": runner}

	var comment := String(pickup.get("comment", "")).strip_edges()
	if comment.is_empty():
		return {"feedback": {}, "bark_runner": bark_runner}

	var speaker_id := StringName(String(pickup.get("speaker_id", "char.kalev")))
	return {
		"feedback": {
			"speaker_id": speaker_id,
			"speaker_name": speaker_name(content_db, speaker_id),
			"text": comment,
		},
		"bark_runner": bark_runner,
	}


static func speaker_name(content_db: ContentDB, speaker_id: StringName) -> String:
	if content_db != null and content_db.is_loaded():
		var character := content_db.get_character(speaker_id)
		if not character.is_empty():
			return String(character.get("name", String(speaker_id)))
	return String(speaker_id)


static func show_bark(bark_label: Label, feedback: Dictionary) -> float:
	if bark_label == null or feedback.is_empty():
		return 0.0
	var text := String(feedback.get("text", "")).strip_edges()
	if text.is_empty():
		return 0.0
	var speaker := String(feedback.get("speaker_name", "")).strip_edges()
	bark_label.text = "%s: %s" % [speaker, text] if not speaker.is_empty() else text
	bark_label.visible = true
	return PICKUP_BARK_DURATION


static func play_pickup_sfx(audio_player: AudioStreamPlayer, item_record: Dictionary) -> void:
	if audio_player == null:
		return
	var gameplay: Dictionary = item_record.get("gameplay", {})
	var pickup: Dictionary = gameplay.get("pickup", {})
	var path := String(pickup.get("sfx_path", DEFAULT_PICKUP_SFX))
	if path.is_empty():
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	audio_player.stream = stream
	audio_player.pitch_scale = 1.35
	audio_player.volume_db = -8.0
	audio_player.play()

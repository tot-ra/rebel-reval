class_name CutsceneSequence
extends RefCounted
## Typed view over a `cutscene` content record (ADR 0034). Parsing lives here so the
## player script only deals with shots and lines, and so tests can assert the parse
## without building any UI.
##
## The authoring block (`image_prompt`, `video_prompt`, `direction`) is deliberately
## NOT parsed: it is tooling data, and ignoring it keeps the runtime independent of it.

const DEFAULT_HOLD_SECONDS := 5.0
const DEFAULT_LINE_SECONDS := 5.0
## Underscore sits well below the Voice bus so narration stays clear; tune per shot via
## `sound.music_volume_db`.
const DEFAULT_MUSIC_DB := -16.0
const DEFAULT_TRANSITION := &"dissolve"

## One spoken or narrated line inside a shot.
class Line extends RefCounted:
	var id: StringName = &""
	var speaker: String = ""
	var speaker_id: StringName = &""
	var text: String = ""
	var seconds: float = DEFAULT_LINE_SECONDS
	## Optional spoken take (res:// mp3/ogg/wav). Empty means a silent, timed line.
	var voice_path: String = ""

	## Narration has no speaker and is presented without a name plate.
	func is_narration() -> bool:
		return speaker.is_empty()


## One image (or, later, one video clip) with its captions and lines.
class Shot extends RefCounted:
	var id: StringName = &""
	var still_path: String = ""
	var video_path: String = ""
	var transition_in: StringName = DEFAULT_TRANSITION
	var motion_kind: StringName = &"hold"
	var zoom_from: float = 1.0
	var zoom_to: float = 1.0
	var hold_seconds: float = DEFAULT_HOLD_SECONDS
	var caption: String = ""
	## Underscore started with this shot (res:// mp3/ogg). Empty keeps whatever is playing.
	var music_path: String = ""
	## Level of that underscore on the Music bus; quiet by default so it sits under a narrator.
	var music_db: float = DEFAULT_MUSIC_DB
	var lines: Array[Line] = []

	## The frame to show. The video tier wins when it has been authored.
	func media_path() -> String:
		return video_path if not video_path.is_empty() else still_path

	## Total time the shot runs when nobody presses anything.
	func duration() -> float:
		if lines.is_empty():
			return hold_seconds
		var total := 0.0
		for line: Line in lines:
			total += line.seconds
		return total


var id: StringName = &""
var title: String = ""
var chapter: String = ""
var grade: StringName = &"present_warm"
var skippable := true
var shots: Array[Shot] = []
## Raw `next` block; interpreted by the player, which owns scene changes.
var next_target: Dictionary = {}


## Build from a ContentDB record. Returns null when the record is not a usable cutscene,
## so callers can fall back instead of half-playing a broken sequence. Lines with
## `conditions` are kept only when `state` satisfies them; without a state they are dropped,
## so a context-free player never shows an echo of a choice the player did not make.
static func from_record(record: Dictionary, state: GameState = null) -> CutsceneSequence:
	if String(record.get("type", "")) != "cutscene":
		return null
	var shot_records: Array = record.get("shots", [])
	if shot_records.is_empty():
		return null

	var sequence := CutsceneSequence.new()
	sequence.id = StringName(String(record.get("id", "")))
	sequence.title = String(record.get("title", ""))
	sequence.chapter = String(record.get("chapter", ""))
	sequence.grade = StringName(String(record.get("grade", "present_warm")))
	sequence.skippable = bool(record.get("skippable", true))
	var next_value: Variant = record.get("next", {})
	sequence.next_target = (next_value as Dictionary) if typeof(next_value) == TYPE_DICTIONARY else {}

	for entry: Variant in shot_records:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		sequence.shots.append(_parse_shot(entry as Dictionary, state))
	return null if sequence.shots.is_empty() else sequence


static func _parse_shot(record: Dictionary, state: GameState) -> Shot:
	var shot := Shot.new()
	shot.id = StringName(String(record.get("id", "")))
	shot.still_path = String(record.get("still", ""))
	shot.video_path = String(record.get("video", ""))
	shot.transition_in = StringName(String(record.get("transition_in", String(DEFAULT_TRANSITION))))
	shot.caption = String(record.get("caption", ""))
	shot.hold_seconds = float(record.get("hold_seconds", DEFAULT_HOLD_SECONDS))

	var sound_value: Variant = record.get("sound", {})
	if typeof(sound_value) == TYPE_DICTIONARY:
		var sound: Dictionary = sound_value
		shot.music_path = String(sound.get("music", ""))
		shot.music_db = float(sound.get("music_volume_db", DEFAULT_MUSIC_DB))

	var motion_value: Variant = record.get("motion", {})
	if typeof(motion_value) == TYPE_DICTIONARY:
		var motion: Dictionary = motion_value
		shot.motion_kind = StringName(String(motion.get("kind", "hold")))
		shot.zoom_from = float(motion.get("zoom_from", 1.0))
		shot.zoom_to = float(motion.get("zoom_to", shot.zoom_from))

	for entry: Variant in record.get("lines", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var line_record: Dictionary = entry
		if not _line_conditions_met(line_record, state):
			continue
		var line := Line.new()
		line.id = StringName(String(line_record.get("id", "")))
		line.speaker = String(line_record.get("speaker", ""))
		line.speaker_id = StringName(String(line_record.get("speaker_id", "")))
		line.text = String(line_record.get("text", ""))
		line.seconds = float(line_record.get("seconds", DEFAULT_LINE_SECONDS))
		line.voice_path = String(line_record.get("voice", ""))
		shot.lines.append(line)
	return shot


static func _line_conditions_met(line_record: Dictionary, state: GameState) -> bool:
	var conditions: Variant = line_record.get("conditions", [])
	if typeof(conditions) != TYPE_ARRAY or (conditions as Array).is_empty():
		return true
	if state == null:
		return false
	return StateRuleEvaluator.new().evaluate_conditions(conditions as Array, state)


func shot_count() -> int:
	return shots.size()


## Every caption in order. A player who skips still gets these facts in the journal,
## which is why ADR 0034 requires the facts to live in the captions.
func captions() -> PackedStringArray:
	var result := PackedStringArray()
	for shot: Shot in shots:
		if not shot.caption.is_empty():
			result.append(shot.caption)
	return result

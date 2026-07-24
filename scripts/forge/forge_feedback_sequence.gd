class_name ForgeFeedbackSequence
extends RefCounted

## Narrative forging beats for P1-022. Advances through fixed phases without
## temperature, strike-accuracy, or timing-score mechanics.

signal feedback_event(phase: StringName)

const PHASE_ORDER: Array[StringName] = [
	&"heat",
	&"hammer_rhythm",
	&"quench",
	&"maker_stamp",
	&"object_reveal",
]

const PHASE_HEADINGS: Dictionary = {
	&"heat": "Heat",
	&"hammer_rhythm": "Hammer rhythm",
	&"quench": "Quench",
	&"maker_stamp": "Maker stamp",
	&"object_reveal": "Object reveal",
}

const PHASE_BODY: Dictionary = {
	&"heat": "The steel takes the forge glow. Kalev reads the colour, not a gauge.",
	&"hammer_rhythm": "Hammer falls in his steady rhythm. Each strike shapes the work.",
	&"quench": "Steam rises as the piece meets the quench. The metal sets its temper.",
	&"maker_stamp": "Kalev presses his maker's mark into the finished work.",
	&"object_reveal": "The commission piece is set aside, ready to leave the forge.",
}

var _phase_index := 0
var _option_id := ""
var _snapshot: Dictionary = {}


static func phase_order() -> Array[StringName]:
	return PHASE_ORDER.duplicate()


static func trace_phases(option_id: String, snapshot: Dictionary = {}) -> Array[StringName]:
	var sequence := ForgeFeedbackSequence.new()
	sequence.reset(option_id, snapshot)
	var trace: Array[StringName] = []
	while true:
		var phase := sequence.advance()
		if phase.is_empty():
			break
		trace.append(phase)
	return trace


func reset(option_id: String, snapshot: Dictionary) -> void:
	_option_id = option_id
	_snapshot = snapshot.duplicate(true)
	_phase_index = 0


func get_option_id() -> String:
	return _option_id


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func has_started() -> bool:
	return _phase_index > 0


func is_finished() -> bool:
	return _phase_index >= PHASE_ORDER.size()


func current_phase() -> StringName:
	if _phase_index <= 0 or _phase_index > PHASE_ORDER.size():
		return &""
	return PHASE_ORDER[_phase_index - 1]


func heading_for(phase: StringName) -> String:
	return String(PHASE_HEADINGS.get(phase, ""))


func body_for(phase: StringName) -> String:
	return String(PHASE_BODY.get(phase, ""))


func advance() -> StringName:
	if is_finished():
		return &""
	var phase := PHASE_ORDER[_phase_index]
	_phase_index += 1
	feedback_event.emit(phase)
	return phase

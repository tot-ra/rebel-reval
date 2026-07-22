class_name ReflectionModel
extends RefCounted

## Builds the Hingepuu reflection snapshot from authored convictions and live GameState.
## WHY: slice reflection stays data-shaped so the overlay can stay dumb UI and tests can
## assert recap/mark/option parity without scene wiring.

const CONVICTION_DUTY := "Duty"
const CONVICTION_FURY := "Fury"
const CONVICTION_MERCY := "Mercy"

const COMMISSION_WATCH_BUCKLE := &"commission.watch_buckle_repair"
const FLAG_COMPLETED := &"flag.reflection.completed"
const FLAG_DUTY := &"flag.reflection.duty"
const FLAG_FURY := &"flag.reflection.fury"
const FLAG_MERCY := &"flag.reflection.mercy"


static func is_available(state: GameState) -> bool:
	return (
		state != null
		and state.get_phase() == GameState.PHASE_REFLECTION_MORNING
		and not state.get_flag(FLAG_COMPLETED)
	)


static func build_snapshot(state: GameState) -> Dictionary:
	var marks := _build_marks(state)
	return {
		"title": "Hingepuu",
		"intro": (
			"Kalev wakes beneath the soul-tree. The night's work still hangs in the branches."
		),
		"recap_lines": _build_recap_lines(state),
		"marks": marks,
		"plain_summary": _build_plain_summary(state, marks),
		"options": _build_options(),
	}


static func apply_conviction(state: GameState, option_id: String, evaluator: StateRuleEvaluator) -> bool:
	if state == null or evaluator == null:
		return false
	for option: Dictionary in _build_options():
		if String(option.get("id", "")) != option_id:
			continue
		var effects: Array = option.get("effects", [])
		if effects.is_empty():
			return false
		if not evaluator.apply_effect(effects[0] as Dictionary, state):
			return false
		state.set_flag(FLAG_COMPLETED, true)
		match String(option.get("conviction", "")):
			CONVICTION_DUTY:
				state.set_flag(FLAG_DUTY, true)
			CONVICTION_FURY:
				state.set_flag(FLAG_FURY, true)
			CONVICTION_MERCY:
				state.set_flag(FLAG_MERCY, true)
		return true
	return false


static func _build_recap_lines(state: GameState) -> Array[String]:
	var lines: Array[String] = []
	lines.append(
		"Suspicion %d, solidarity %d, scarcity %d."
		% [
			state.get_pressure(GameState.PRESSURE_SUSPICION),
			state.get_pressure(GameState.PRESSURE_SOLIDARITY),
			state.get_pressure(GameState.PRESSURE_SCARCITY),
		]
	)
	if state.has_forged_modification(COMMISSION_WATCH_BUCKLE, &"honest_work"):
		lines.append("The watch buckle was repaired cleanly.")
	elif state.has_forged_modification(COMMISSION_WATCH_BUCKLE, &"subtle_defect"):
		lines.append("The buckle hides a weakness only Kalev knows.")
	elif state.has_forged_modification(COMMISSION_WATCH_BUCKLE, &"secret_feature"):
		lines.append("A secret release waits inside the buckle.")
	else:
		lines.append("No forged commission record weighs on the tree yet.")
	if state.get_relationship(&"rel.henning_trust") != 0:
		lines.append(
			"Henning's trust sits at %+d."
			% state.get_relationship(&"rel.henning_trust")
		)
	return lines


static func _build_marks(state: GameState) -> Array[Dictionary]:
	var marks: Array[Dictionary] = []
	if state.has_forged_modification(COMMISSION_WATCH_BUCKLE, &"honest_work"):
		marks.append(_mark("honest_work", "Honest hand", Color(0.45, 0.78, 0.58, 1.0)))
	elif state.has_forged_modification(COMMISSION_WATCH_BUCKLE, &"subtle_defect"):
		marks.append(_mark("subtle_defect", "Hidden flaw", Color(0.86, 0.62, 0.28, 1.0)))
	elif state.has_forged_modification(COMMISSION_WATCH_BUCKLE, &"secret_feature"):
		marks.append(_mark("secret_feature", "Secret catch", Color(0.62, 0.48, 0.86, 1.0)))

	if state.get_pressure(GameState.PRESSURE_SUSPICION) >= 2:
		marks.append(_mark("watchful_doubt", "Watchful doubt", Color(0.86, 0.34, 0.34, 1.0)))
	if state.get_pressure(GameState.PRESSURE_SOLIDARITY) >= 1:
		marks.append(_mark("quiet_bonds", "Quiet bonds", Color(0.42, 0.66, 0.9, 1.0)))
	if state.get_flag(&"flag.watch_buckle_weakened"):
		marks.append(_mark("weakened_buckle", "Strained buckle", Color(0.9, 0.55, 0.2, 1.0)))
	if state.get_flag(&"flag.watch_buckle_hidden_release"):
		marks.append(_mark("hidden_release", "Hidden release", Color(0.72, 0.5, 0.92, 1.0)))
	return marks


static func _build_plain_summary(state: GameState, marks: Array[Dictionary]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for line in _build_recap_lines(state):
		parts.append(line)
	if marks.is_empty():
		parts.append("The branches are bare of consequence marks.")
	else:
		var mark_labels: PackedStringArray = PackedStringArray()
		for mark: Dictionary in marks:
			mark_labels.append(String(mark.get("label", "")))
		parts.append("Marks on the tree: %s." % ", ".join(mark_labels))
	return " ".join(parts)


static func _build_options() -> Array[Dictionary]:
	return [
		{
			"id": "duty",
			"conviction": CONVICTION_DUTY,
			"title": CONVICTION_DUTY,
			"summary": "Answer for the work and keep Henning's trust.",
			"plain_text": "Duty strengthens Henning's trust by one step.",
			"effects": [
				{"op": "adjust_relationship", "key": "rel.henning_trust", "amount": 1},
			],
		},
		{
			"id": "fury",
			"conviction": CONVICTION_FURY,
			"title": CONVICTION_FURY,
			"summary": "Let the anger feed the bonds that keep Reval standing together.",
			"plain_text": "Fury raises solidarity pressure by one step.",
			"effects": [
				{"op": "adjust_pressure", "key": "pressure.solidarity", "amount": 1},
			],
		},
		{
			"id": "mercy",
			"conviction": CONVICTION_MERCY,
			"title": CONVICTION_MERCY,
			"summary": "Ease the watchful doubt that followed the night's work.",
			"plain_text": "Mercy lowers suspicion pressure by one step.",
			"effects": [
				{"op": "adjust_pressure", "key": "pressure.suspicion", "amount": -1},
			],
		},
	]


static func _mark(mark_id: String, label: String, color: Color) -> Dictionary:
	return {
		"id": mark_id,
		"label": label,
		"color": color,
	}

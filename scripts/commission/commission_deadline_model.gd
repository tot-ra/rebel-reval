class_name CommissionDeadlineModel
extends RefCounted

## Resolves commission deadline status from authored content, phase order, and GameState.

const STATUS_ACTIVE := &"active"
const STATUS_MET := &"met"
const STATUS_MISSED := &"missed"


static func phase_sequence_index(phase_id: StringName, content_db: ContentDB) -> int:
	if content_db == null or not content_db.is_loaded() or phase_id.is_empty():
		return -1
	for profile_id in content_db.get_ids_by_type(ContentDB.TYPE_PHASE_PROFILE):
		var profile := content_db.get_phase_profile(profile_id)
		if profile.is_empty():
			continue
		if StringName(String(profile.get("phase_id", ""))) == phase_id:
			return int(profile.get("sequence_index", -1))
	return -1


static func sync_on_phase_change(
	state: GameState,
	content_db: ContentDB,
	_previous: StringName,
	next: StringName,
	evaluator: StateRuleEvaluator = null
) -> void:
	if state == null or content_db == null or not content_db.is_loaded() or next.is_empty():
		return
	var next_index := phase_sequence_index(next, content_db)
	if next_index < 0:
		return
	var rule_evaluator := _evaluator(evaluator)
	for commission_id in content_db.get_ids_by_type(ContentDB.TYPE_COMMISSION):
		_maybe_mark_missed(commission_id, state, content_db, next_index, rule_evaluator)


static func mark_commission_met(
	state: GameState,
	commission_id: StringName,
	content_db: ContentDB
) -> void:
	if state == null or not _has_deadline(commission_id, content_db):
		return
	if state.get_commission_deadline_status(commission_id) == STATUS_MISSED:
		return
	if _is_commission_resolved(state, commission_id):
		state.set_commission_deadline_status(commission_id, STATUS_MET)


static func mark_commission_met_if_timely(
	state: GameState,
	commission_id: StringName,
	content_db: ContentDB
) -> void:
	if state == null or not _has_deadline(commission_id, content_db):
		return
	if state.get_commission_deadline_status(commission_id) == STATUS_MISSED:
		return
	var commission := content_db.get_commission(commission_id)
	var deadline := _deadline_block(commission)
	var due_phase_id := StringName(String(deadline.get("due_phase_id", "")))
	var due_index := phase_sequence_index(due_phase_id, content_db)
	var current_index := phase_sequence_index(state.get_phase(), content_db)
	if due_index < 0 or current_index < 0 or current_index >= due_index:
		return
	state.set_commission_deadline_status(commission_id, STATUS_MET)


static func is_deadline_missed(state: GameState, commission_id: StringName) -> bool:
	return state.get_commission_deadline_status(commission_id) == STATUS_MISSED


static func is_deadline_met(state: GameState, commission_id: StringName) -> bool:
	var status := state.get_commission_deadline_status(commission_id)
	if status == STATUS_MET:
		return true
	if status == STATUS_MISSED:
		return false
	return _is_before_due_phase(state, commission_id, _runtime_content_db())


static func build_journal_deadlines(state: GameState, content_db: ContentDB) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if state == null or content_db == null or not content_db.is_loaded():
		return entries

	for commission_id in content_db.get_ids_by_type(ContentDB.TYPE_COMMISSION):
		var commission := content_db.get_commission(commission_id)
		var deadline := _deadline_block(commission)
		if deadline.is_empty():
			continue
		if _is_commission_resolved(state, commission_id):
			continue
		var status := state.get_commission_deadline_status(commission_id)
		if status == STATUS_MISSED:
			continue
		entries.append({
			"commission_id": commission_id,
			"title": String(commission.get("title", String(commission_id))),
			"label": String(deadline.get("journal_label", "")),
			"due_phase_id": StringName(String(deadline.get("due_phase_id", ""))),
			"status": String(status),
		})

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("commission_id", "")) < String(b.get("commission_id", ""))
	)
	return entries


static func deadline_snapshot(
	commission: Dictionary,
	state: GameState,
	content_db: ContentDB
) -> Dictionary:
	var deadline := _deadline_block(commission)
	if deadline.is_empty() or state == null:
		return {}
	var commission_id := StringName(String(commission.get("id", "")))
	if _is_commission_resolved(state, commission_id):
		return {}
	var status := state.get_commission_deadline_status(commission_id)
	if status == STATUS_MISSED:
		return {
			"label": String(deadline.get("journal_label", "")),
			"status": "missed",
			"display": "Deadline missed - penalties already applied.",
		}
	return {
		"label": String(deadline.get("journal_label", "")),
		"status": String(status),
		"display": String(deadline.get("journal_label", "")),
	}


static func _maybe_mark_missed(
	commission_id: StringName,
	state: GameState,
	content_db: ContentDB,
	next_phase_index: int,
	evaluator: StateRuleEvaluator
) -> void:
	var commission := content_db.get_commission(commission_id)
	var deadline := _deadline_block(commission)
	if deadline.is_empty():
		return

	var due_phase_id := StringName(String(deadline.get("due_phase_id", "")))
	var due_index := phase_sequence_index(due_phase_id, content_db)
	if due_index < 0 or next_phase_index < due_index:
		return

	var status := state.get_commission_deadline_status(commission_id)
	if status == STATUS_MISSED or status == STATUS_MET:
		return
	if _is_commission_resolved(state, commission_id):
		state.set_commission_deadline_status(commission_id, STATUS_MET)
		return

	state.set_commission_deadline_status(commission_id, STATUS_MISSED)
	var missed_effects: Array = deadline.get("missed_effects", [])
	if not missed_effects.is_empty():
		evaluator.apply_effects(_runtime_rules(missed_effects), state)


static func _is_commission_resolved(state: GameState, commission_id: StringName) -> bool:
	if state == null or commission_id.is_empty():
		return false
	for record in state.get_forged_records():
		if record.commission_id == commission_id:
			return true
	return false


static func _has_deadline(commission_id: StringName, content_db: ContentDB) -> bool:
	if content_db == null or not content_db.is_loaded():
		return false
	var commission := content_db.get_commission(commission_id)
	return not _deadline_block(commission).is_empty()


static func _deadline_block(commission: Dictionary) -> Dictionary:
	var value: Variant = commission.get("deadline", {})
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return value as Dictionary


static func _runtime_rules(authored_rules: Variant) -> Array:
	var runtime_rules: Array = []
	if typeof(authored_rules) != TYPE_ARRAY:
		return runtime_rules
	for value in authored_rules as Array:
		if typeof(value) != TYPE_DICTIONARY:
			runtime_rules.append(value)
			continue
		var rule := (value as Dictionary).duplicate(true)
		if typeof(rule.get("amount")) == TYPE_FLOAT:
			var amount := float(rule["amount"])
			if amount == floor(amount):
				rule["amount"] = int(amount)
		runtime_rules.append(rule)
	return runtime_rules


static func _evaluator(evaluator: StateRuleEvaluator = null) -> StateRuleEvaluator:
	if evaluator != null:
		return evaluator
	# WHY: lazy load avoids a compile-time cycle with StateRuleEvaluator.
	return load("res://scripts/state/state_rule_evaluator.gd").new() as StateRuleEvaluator


static func _runtime_content_db() -> ContentDB:
	if SessionState.content_db != null and SessionState.content_db.is_loaded():
		return SessionState.content_db
	return null


static func _is_before_due_phase(
	state: GameState,
	commission_id: StringName,
	content_db: ContentDB
) -> bool:
	if state == null or content_db == null or not content_db.is_loaded():
		return false
	var commission := content_db.get_commission(commission_id)
	var deadline := _deadline_block(commission)
	if deadline.is_empty():
		return false
	var due_index := phase_sequence_index(
		StringName(String(deadline.get("due_phase_id", ""))),
		content_db
	)
	var current_index := phase_sequence_index(state.get_phase(), content_db)
	return due_index >= 0 and current_index >= 0 and current_index < due_index

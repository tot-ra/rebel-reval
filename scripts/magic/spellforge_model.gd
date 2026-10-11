class_name SpellforgeModel
extends RefCounted

## Player-facing state for the closed spell cookbook. The model only selects
## learned elements; MagicResolver remains authoritative for recipes and costs.

const MAX_SEQUENCE_LENGTH := 3
const TYPE_SPELL := "spell"
const TYPE_RITE := "rite"
## Demo HUD slot order. Unlisted learned recipes sort after these by id.
const QUICK_SLOT_ORDER: Array[StringName] = [
	&"spell.pagan.fireball",
	&"spell.pagan.earth_tremor",
	&"spell.pagan.iron_skin",
	&"rite.blessing",
]

const FAILURE_TEXT: Dictionary = {
	MagicResolver.FAILURE_UNKNOWN_SEQUENCE: "No authored spell matches that sequence.",
	MagicResolver.FAILURE_LOCKED: "That recipe has not been learned.",
	MagicResolver.FAILURE_NEEDS_HAMMER: "A forge hammer is required as the conduit.",
	MagicResolver.FAILURE_INSUFFICIENT_WILLPOWER: "Not enough willpower.",
	MagicResolver.FAILURE_INSUFFICIENT_PIETY: "Not enough piety.",
	MagicResolver.FAILURE_INSUFFICIENT_HEALTH: "Not enough health.",
	MagicResolver.FAILURE_WRONG_SCHOOL: "That recipe belongs to another school.",
	MagicResolver.FAILURE_SUPPRESSED: "Magic is suppressed here.",
}

var _state: GameState
var _content_db: ContentDB
var _sequence: Array[StringName] = []
var _armed_rite_id: StringName = &""
var _feedback := "Choose up to three learned elements."


func configure(state: GameState, content_db: ContentDB) -> void:
	_state = state
	_content_db = content_db
	_sequence.clear()
	_armed_rite_id = &""
	_feedback = "Choose up to three learned elements."


func selected_sequence() -> Array[StringName]:
	return _sequence.duplicate()


func feedback_text() -> String:
	return _feedback


func willpower() -> int:
	if _state == null:
		return 0
	return _state.get_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER)


func piety() -> int:
	if _state == null:
		return 0
	return _state.get_magic_resource(GameState.MAGIC_RESOURCE_PIETY)


func learned_spells() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if _state == null or _content_db == null:
		return rows
	for record_type in [TYPE_SPELL, TYPE_RITE]:
		for recipe_id in _content_db.get_ids_by_type(record_type):
			if not _state.has_magic_grant(recipe_id):
				continue
			var record := (
				_content_db.get_spell(recipe_id)
				if record_type == TYPE_SPELL
				else _content_db.get_rite(recipe_id)
			)
			rows.append(_learned_row(recipe_id, record))
	rows.sort_custom(_learned_spell_less)
	return rows


func arm_spell(spell_id: StringName) -> bool:
	for row in learned_spells():
		if row["id"] != spell_id:
			continue
		_sequence.clear()
		_armed_rite_id = &""
		# WHY: rites are fixed liturgy. Arm by authored ID, never by forged chips.
		if String(spell_id).begins_with("rite."):
			_armed_rite_id = spell_id
			_feedback = "Armed %s." % String(row["name"])
			return true
		for element_id in row["sequence"]:
			_sequence.append(element_id)
		_feedback = "Armed %s." % String(row["name"])
		return true
	_feedback = "That recipe has not been learned."
	return false


## Magic answers only in the spirit world (ADR 0033); world casts are refused.
func is_spirit_world() -> bool:
	return _state != null and _state.spirit_encounter_active


func notify_physical_world() -> void:
	_feedback = "Magic answers only in the spirit world."


func notify_empty_slot() -> void:
	_feedback = "No learned spell in that slot."


func learned_elements() -> Array[StringName]:
	var learned: Array[StringName] = []
	if _state == null or _content_db == null:
		return learned
	for spell_id in _content_db.get_ids_by_type(TYPE_SPELL):
		if not _state.has_magic_grant(spell_id):
			continue
		for element_id in _record_sequence(_content_db.get_spell(spell_id)):
			if not learned.has(element_id):
				learned.append(element_id)
	learned.sort_custom(_element_less)
	return learned


func catalog_elements() -> Array[StringName]:
	var elements: Array[StringName] = []
	if _content_db == null:
		return elements
	for spell_id in _content_db.get_ids_by_type(TYPE_SPELL):
		for element_id in _record_sequence(_content_db.get_spell(spell_id)):
			if not elements.has(element_id):
				elements.append(element_id)
	elements.sort_custom(_element_less)
	return elements


func select_element(element_id: StringName) -> bool:
	if not learned_elements().has(element_id):
		_feedback = "%s is not learned." % display_element(element_id)
		return false
	if _sequence.size() >= MAX_SEQUENCE_LENGTH:
		_feedback = "A spell sequence can contain at most three elements."
		return false
	_armed_rite_id = &""
	_sequence.append(element_id)
	_feedback = "Sequence: %s" % sequence_text(_sequence)
	return true


func remove_last() -> bool:
	if _sequence.is_empty():
		_feedback = "The sequence is already empty."
		return false
	_sequence.pop_back()
	_armed_rite_id = &""
	_feedback = (
		"Sequence: %s" % sequence_text(_sequence)
		if not _sequence.is_empty()
		else "Sequence cleared."
	)
	return true


func clear_sequence() -> void:
	_sequence.clear()
	_armed_rite_id = &""
	_feedback = "Sequence cleared."


func cast(caster: Node2D, direction: Vector2, host: Node = null) -> Dictionary:
	var result: Dictionary
	if not _armed_rite_id.is_empty():
		result = MagicResolver.cast(_state, _content_db, _armed_rite_id)
	elif _sequence.is_empty():
		_feedback = "Choose at least one learned element."
		return {"ok": false, "reason": MagicResolver.FAILURE_UNKNOWN_SEQUENCE}
	else:
		result = MagicResolver.cast(
			_state, _content_db, &"", _sequence, MagicResolver.SCHOOL_PAGAN
		)
	if not bool(result.get("ok", false)):
		_feedback = failure_text(StringName(String(result.get("reason", ""))))
		return result
	var delivery := MagicCastExecutor2D.execute(result, caster, direction, host)
	if delivery == null:
		_feedback = "The spell resolved, but its delivery could not enter the world."
		return {
			"ok": false,
			"reason": &"magic.fail.delivery",
			"target_id": result.get("target_id", &""),
		}
	_feedback = "%s cast." % _recipe_name(StringName(String(result.get("target_id", ""))))
	_sequence.clear()
	_armed_rite_id = &""
	return result


func cookbook_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if _content_db == null:
		return rows
	for spell_id in _content_db.get_ids_by_type(TYPE_SPELL):
		var record := _content_db.get_spell(spell_id)
		var learned := _state != null and _state.has_magic_grant(spell_id)
		rows.append(
			{
				"id": spell_id,
				"name": String(record.get("name", spell_id)),
				"sequence": _record_sequence(record),
				"sequence_text": sequence_text(_record_sequence(record)),
				"summary": String(record.get("effect_summary", "")),
				"learned": learned,
			}
		)
	return rows


func _recipe_name(recipe_id: StringName) -> String:
	if _content_db == null:
		return String(recipe_id)
	if String(recipe_id).begins_with("rite."):
		return String(_content_db.get_rite(recipe_id).get("name", recipe_id))
	return String(_content_db.get_spell(recipe_id).get("name", recipe_id))


func _learned_row(recipe_id: StringName, record: Dictionary) -> Dictionary:
	return {
		"id": recipe_id,
		"name": String(record.get("name", recipe_id)),
		"sequence": _record_sequence(record),
		"cost": _spell_cost(record),
		"resource": _spell_resource(record),
		"summary": String(record.get("effect_summary", "")),
	}


static func failure_text(reason: StringName) -> String:
	return String(FAILURE_TEXT.get(reason, "The spell could not be cast."))


static func display_element(element_id: StringName) -> String:
	var text := String(element_id).trim_prefix("element.").replace("_", " ")
	return text.capitalize()


static func sequence_text(sequence: Array[StringName]) -> String:
	var names := PackedStringArray()
	for element_id in sequence:
		names.append(display_element(element_id))
	return " + ".join(names) if not names.is_empty() else "Empty"


static func _element_less(left: StringName, right: StringName) -> bool:
	return String(left) < String(right)


static func _spell_resource(record: Dictionary) -> String:
	var cost: Variant = record.get("cost", {})
	if not cost is Dictionary:
		return "resource.willpower"
	return String((cost as Dictionary).get("resource", "resource.willpower"))


static func _record_sequence(record: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	var raw_sequence: Variant = record.get("sequence", [])
	if not raw_sequence is Array:
		return result
	for raw_element in raw_sequence as Array:
		result.append(StringName(String(raw_element)))
	return result


static func _spell_cost(record: Dictionary) -> int:
	var cost: Variant = record.get("cost", {})
	if not cost is Dictionary:
		return 0
	return int((cost as Dictionary).get("amount", 0))


static func _learned_spell_less(left: Dictionary, right: Dictionary) -> bool:
	var left_rank := _quick_slot_rank(StringName(String(left.get("id", ""))))
	var right_rank := _quick_slot_rank(StringName(String(right.get("id", ""))))
	if left_rank != right_rank:
		return left_rank < right_rank
	return String(left.get("id", "")) < String(right.get("id", ""))


static func _quick_slot_rank(spell_id: StringName) -> int:
	var index := QUICK_SLOT_ORDER.find(spell_id)
	return index if index >= 0 else QUICK_SLOT_ORDER.size() + 1

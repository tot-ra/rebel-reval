class_name MagicResolver
extends RefCounted

## Closed-cookbook casting for P7-010. Content records remain the only source of
## spell/rite identity; this service never synthesizes an effect at runtime.

const FAILURE_UNKNOWN_SEQUENCE := &"magic.fail.unknown_sequence"
const FAILURE_LOCKED := &"magic.fail.locked"
const FAILURE_NEEDS_HAMMER := &"magic.fail.needs_hammer"
const FAILURE_INSUFFICIENT_WILLPOWER := &"magic.fail.insufficient_willpower"
const FAILURE_INSUFFICIENT_PIETY := &"magic.fail.insufficient_piety"
const FAILURE_INSUFFICIENT_HEALTH := &"magic.fail.insufficient_health"
const FAILURE_WRONG_SCHOOL := &"magic.fail.wrong_school"
const FAILURE_SUPPRESSED := &"magic.fail.suppressed"

const SCHOOL_PAGAN := &"school.pagan"
const SCHOOL_DIVINE := &"school.divine"
const TYPE_SPELL := "spell"
const TYPE_RITE := "rite"
const TYPE_MAGIC_GRANT := "magic_grant"

const ELEMENT_ASPECTS: Dictionary = {
	&"element.earth": &"aspect.nature",
	&"element.metal": &"aspect.nature",
	&"element.water": &"aspect.affection",
	&"element.air": &"aspect.affection",
	&"element.fire": &"aspect.tenacity",
	&"element.beast": &"aspect.tenacity",
	&"element.life": &"aspect.unity",
	&"element.hope": &"aspect.unity",
	&"element.deception": &"aspect.resonance",
	&"element.dominion": &"aspect.resonance",
	&"element.mind": &"aspect.awareness",
	&"element.time": &"aspect.awareness",
	&"element.faith": &"aspect.light",
	&"element.spirit": &"aspect.light",
}
const NATURAL_POINT_EFFECTIVENESS := 0.02


## Applies one authored grant/revoke operation. The operation record itself is
## content, so callers cannot grant an arbitrary target without a reviewed row.
static func apply_grant_operation(
	state: GameState, content_db: ContentDB, operation_id: StringName
) -> bool:
	if state == null or content_db == null:
		return false
	var operation := content_db.get_magic_grant(operation_id)
	if operation.is_empty():
		return false
	var target_id := StringName(String(operation.get("target_id", "")))
	var grant_flag := StringName(String(operation.get("grant_flag", "")))
	if operation.get("operation", "") == "grant":
		return state.grant_magic(target_id, grant_flag)
	if operation.get("operation", "") == "revoke":
		return state.revoke_magic(target_id, grant_flag)
	return false


## Resolves a cast request and spends its authored resource on success.
## `sequence` is used for pagan lookup; rites must be requested by authored ID.
static func cast(
	state: GameState,
	content_db: ContentDB,
	target_id: StringName = &"",
	sequence: Array[StringName] = [],
	requested_school: StringName = &"",
	suppressed: bool = false
) -> Dictionary:
	if state == null or content_db == null:
		return _failure(FAILURE_UNKNOWN_SEQUENCE)
	if suppressed:
		return _failure(FAILURE_SUPPRESSED)

	var record: Dictionary = {}
	var resolved_id := target_id
	if not sequence.is_empty():
		resolved_id = _find_spell_for_sequence(content_db, sequence)
		if resolved_id.is_empty():
			return _failure(FAILURE_UNKNOWN_SEQUENCE)
	if resolved_id.begins_with("spell."):
		record = content_db.get_spell(resolved_id)
	elif resolved_id.begins_with("rite."):
		record = content_db.get_rite(resolved_id)
	else:
		return _failure(FAILURE_UNKNOWN_SEQUENCE)
	if record.is_empty():
		return _failure(FAILURE_UNKNOWN_SEQUENCE)

	var school := StringName(String(record.get("school", "")))
	if not requested_school.is_empty() and requested_school != school:
		return _failure(FAILURE_WRONG_SCHOOL)
	if not state.has_magic_grant(resolved_id):
		return _failure(FAILURE_LOCKED, resolved_id)

	var conduit := String(record.get("requires_conduit", "none"))
	if conduit == "hammer" and not state.is_forge_conduit_available():
		return _failure(FAILURE_NEEDS_HAMMER, resolved_id)
	if (
		record.get("requires_conduit", "none") == "none"
		and bool(record.get("allows_hammer_symbol", false))
	):
		# An allowed symbol is metadata, not a mandatory conduit requirement.
		pass

	var cost: Variant = record.get("cost", {})
	if not cost is Dictionary:
		return _failure(FAILURE_UNKNOWN_SEQUENCE, resolved_id)
	var cost_dict := cost as Dictionary
	var resource_id := StringName(String(cost_dict.get("resource", "")))
	var amount := int(cost_dict.get("amount", 0))
	var insufficient := _insufficient_failure(resource_id)
	if amount < 1 or insufficient.is_empty():
		return _failure(FAILURE_UNKNOWN_SEQUENCE, resolved_id)
	if state.get_magic_resource(resource_id) < amount:
		return _failure(insufficient, resolved_id)
	state.spend_magic_resource(resource_id, amount)
	var effect := (record.get("effect", {}) as Dictionary).duplicate(true)
	var elements := _record_elements(record)
	var natural_multiplier := natural_effectiveness_multiplier(state, elements)
	_scale_effect(effect, natural_multiplier)
	return {
		"ok": true,
		"reason": &"",
		"target_id": resolved_id,
		"school": school,
		"effect_summary": String(record.get("effect_summary", "")),
		# Return a scaled deep copy. Authored content remains immutable and the
		# delivery adapter still receives the same declarative module shape.
		"effect": effect,
		"natural_multiplier": natural_multiplier,
		"resource": resource_id,
		"amount": amount,
	}


## Returns the deterministic NATURAL multiplier for all authored cast elements.
## Multi-element recipes average their per-element multipliers so each element
## contributes once without making the number of modules change spell balance.
static func natural_effectiveness_multiplier(
	state: GameState, elements: Array[StringName]
) -> float:
	if state == null or not state.is_natural_system_enabled():
		return 1.0
	if not state.get_flag(&"flag.natural.initial_allocation"):
		return 1.0
	if elements.is_empty():
		return 1.0

	var total := 0.0
	for element_id in elements:
		var aspect_id: StringName = ELEMENT_ASPECTS.get(element_id, &"")
		if aspect_id.is_empty():
			# An element without a NATURAL owner contributes the neutral baseline
			# rather than disappearing from a multi-element average.
			total += 1.0
			continue
		var rank := state.get_natural_effective_aspect_rank(aspect_id)
		total += 1.0 + NATURAL_POINT_EFFECTIVENESS * float(rank)
	return total / float(elements.size())


static func _record_elements(record: Dictionary) -> Array[StringName]:
	var raw_elements: Variant = record.get("sequence", record.get("tags", []))
	var elements: Array[StringName] = []
	if not raw_elements is Array:
		return elements
	for raw_element in raw_elements as Array:
		elements.append(StringName(String(raw_element)))
	return elements


static func _scale_effect(effect: Dictionary, multiplier: float) -> void:
	for key in effect:
		var value: Variant = effect[key]
		if value is Dictionary:
			var module := value as Dictionary
			var kind := String(module.get("kind", ""))
			if kind in ["damage", "heal", "control", "stagger"]:
				for magnitude_key in ["amount", "magnitude", "duration_sec"]:
					if module.has(magnitude_key):
						module[magnitude_key] = float(module[magnitude_key]) * multiplier
			_scale_effect(value as Dictionary, multiplier)


static func _find_spell_for_sequence(
	content_db: ContentDB, sequence: Array[StringName]
) -> StringName:
	if sequence.size() < 1 or sequence.size() > 3:
		return &""
	for spell_id in content_db.get_ids_by_type(TYPE_SPELL):
		var spell := content_db.get_spell(spell_id)
		var authored: Array[StringName] = []
		var raw_sequence: Variant = spell.get("sequence", [])
		if not raw_sequence is Array:
			continue
		for element in raw_sequence as Array:
			authored.append(StringName(String(element)))
		if authored == sequence:
			return spell_id
	return &""


static func _insufficient_failure(resource_id: StringName) -> StringName:
	match resource_id:
		GameState.MAGIC_RESOURCE_WILLPOWER:
			return FAILURE_INSUFFICIENT_WILLPOWER
		GameState.MAGIC_RESOURCE_PIETY:
			return FAILURE_INSUFFICIENT_PIETY
		GameState.MAGIC_RESOURCE_HEALTH:
			return FAILURE_INSUFFICIENT_HEALTH
		_:
			return &""


static func _failure(reason: StringName, target_id: StringName = &"") -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"target_id": target_id,
	}

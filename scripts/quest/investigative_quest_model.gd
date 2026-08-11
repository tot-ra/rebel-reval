class_name InvestigativeQuestModel
extends RefCounted

## Resolves suspect pools, confrontation tiers, and quest outcomes for authored
## multi-step investigations declared on quest records.

const TIER_BLIND := &"blind"
const TIER_PARTIAL := &"partial"
const TIER_NARROW := &"narrow"
const TIER_RESOLVED := &"resolved"

const OUTCOME_CORRECT := &"resolved_correct"
const OUTCOME_UNCERTAIN := &"resolved_uncertain"
const OUTCOME_MISACCUSED := &"resolved_misaccused"


static func investigation_block(quest: Dictionary) -> Dictionary:
	var value: Variant = quest.get("investigation", {})
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return value as Dictionary


static func known_clue_fact_ids(state: GameState, quest: Dictionary) -> Array[StringName]:
	var known: Array[StringName] = []
	if state == null:
		return known
	for clue in _clues(quest):
		var fact_id := StringName(String(clue.get("fact_id", "")))
		if fact_id.is_empty():
			continue
		if state.get_fact(fact_id):
			known.append(fact_id)
	known.sort()
	return known


static func remaining_suspects(state: GameState, quest: Dictionary) -> Array[StringName]:
	var suspects := _suspects(quest)
	var exonerated := _exonerated_suspects(state, quest)
	var remaining: Array[StringName] = []
	for suspect_id in suspects:
		if not exonerated.has(suspect_id):
			remaining.append(suspect_id)
	return remaining


static func culprit_id(quest: Dictionary) -> StringName:
	return StringName(String(investigation_block(quest).get("culprit_id", "")))


static func is_culprit_identifiable(state: GameState, quest: Dictionary) -> bool:
	var culprit := culprit_id(quest)
	if culprit.is_empty():
		return false
	return remaining_suspects(state, quest) == [culprit]


static func confrontation_tier(state: GameState, quest: Dictionary) -> StringName:
	var known_count := known_clue_fact_ids(state, quest).size()
	var min_full := int(investigation_block(quest).get("min_clues_for_full_resolution", 3))
	if is_culprit_identifiable(state, quest) and known_count >= min_full:
		return TIER_RESOLVED
	if known_count >= min_full:
		return TIER_NARROW
	if known_count >= 2:
		return TIER_PARTIAL
	if known_count >= 1:
		return TIER_PARTIAL
	return TIER_BLIND


static func resolve_outcome_id(
	state: GameState, quest: Dictionary, accused_suspect_id: StringName
) -> StringName:
	if accused_suspect_id.is_empty():
		return OUTCOME_MISACCUSED
	if is_culprit_identifiable(state, quest) and accused_suspect_id == culprit_id(quest):
		return OUTCOME_CORRECT
	var known_count := known_clue_fact_ids(state, quest).size()
	if known_count == 0:
		return OUTCOME_MISACCUSED
	if accused_suspect_id == culprit_id(quest):
		return OUTCOME_UNCERTAIN
	return OUTCOME_MISACCUSED


static func transition_id_for_outcome(outcome_id: StringName) -> StringName:
	match outcome_id:
		OUTCOME_CORRECT:
			return &"confront_correct"
		OUTCOME_UNCERTAIN:
			return &"confront_uncertain"
		_:
			return &"confront_misaccused"


static func journal_clue_entries(state: GameState, quest: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry in _journal_evidence(quest):
		var fact_id := StringName(String(entry.get("fact_id", "")))
		if fact_id.is_empty() or not state.get_fact(fact_id):
			continue
		(
			entries
			. append(
				{
					"fact_id": fact_id,
					"text": String(entry.get("text", "")),
					"quest_id": StringName(String(quest.get("id", ""))),
				}
			)
		)
	return entries


static func _clues(quest: Dictionary) -> Array:
	var clues: Variant = investigation_block(quest).get("clues", [])
	if typeof(clues) != TYPE_ARRAY:
		return []
	return clues as Array


static func _suspects(quest: Dictionary) -> Array[StringName]:
	var suspects: Array[StringName] = []
	var raw: Variant = investigation_block(quest).get("suspects", [])
	if typeof(raw) != TYPE_ARRAY:
		return suspects
	for value in raw as Array:
		var suspect_id := StringName(String(value))
		if not suspect_id.is_empty():
			suspects.append(suspect_id)
	return suspects


static func _exonerated_suspects(state: GameState, quest: Dictionary) -> Dictionary:
	var exonerated: Dictionary = {}
	if state == null:
		return exonerated
	for clue in _clues(quest):
		var fact_id := StringName(String(clue.get("fact_id", "")))
		if fact_id.is_empty() or not state.get_fact(fact_id):
			continue
		var cleared: Variant = clue.get("exonerates", [])
		if typeof(cleared) != TYPE_ARRAY:
			continue
		for value in cleared as Array:
			exonerated[StringName(String(value))] = true
	return exonerated


static func _journal_evidence(quest: Dictionary) -> Array:
	var entries: Variant = quest.get("journal_evidence", [])
	if typeof(entries) != TYPE_ARRAY:
		return []
	return entries as Array

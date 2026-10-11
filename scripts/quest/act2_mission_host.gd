class_name Act2MissionHost
extends RefCounted

## Runtime offer/start facade for the authored P5-006 siege packages.
##
## The packages remain ordinary ContentDB quest records. This host supplies the
## Act 2 phase/alignment catalog and delegates progression to QuestManager, so
## flags, faction-ledger events, and quest states keep the existing save format.

const PHASE_INVESTMENT := &"phase.act2.siege.investment"
const PHASE_SORTIE_SUPPLY := &"phase.act2.siege.sortie_supply"
const PHASE_ASSAULT := &"phase.act2.siege.assault"
const SIEGE_INVESTMENT := &"siege.investment"
const SIEGE_SORTIE_SUPPLY := &"siege.sortie_supply"
const SIEGE_ASSAULT := &"siege.assault"
const ALIGNMENT_REBEL := &"rebel"
const ALIGNMENT_RULER := &"ruler"
const MIN_OFFER_STANDING := 2
const FLAG_BOUNDARY_SEAL := &"flag.act_boundary.viru_seal"
const FLAG_BOUNDARY_BREAK := &"flag.act_boundary.viru_break"
const FLAG_BOUNDARY_OPEN := &"flag.act_boundary.viru_open"

const _MISSION_CATALOG: Array[Dictionary] = [
	{
		"quest_id": &"quest.act2.siege.investment.rebel",
		"phase_id": PHASE_INVESTMENT,
		"siege_phase": SIEGE_INVESTMENT,
		"alignment": ALIGNMENT_REBEL,
		"faction_id": FactionLedger.HARJU_KINGS,
	},
	{
		"quest_id": &"quest.act2.siege.investment.ruler",
		"phase_id": PHASE_INVESTMENT,
		"siege_phase": SIEGE_INVESTMENT,
		"alignment": ALIGNMENT_RULER,
		"faction_id": FactionLedger.DANISH_CROWN,
	},
	{
		"quest_id": &"quest.act2.siege.sortie_supply.rebel",
		"phase_id": PHASE_SORTIE_SUPPLY,
		"siege_phase": SIEGE_SORTIE_SUPPLY,
		"alignment": ALIGNMENT_REBEL,
		"faction_id": FactionLedger.HARJU_KINGS,
	},
	{
		"quest_id": &"quest.act2.siege.sortie_supply.ruler",
		"phase_id": PHASE_SORTIE_SUPPLY,
		"siege_phase": SIEGE_SORTIE_SUPPLY,
		"alignment": ALIGNMENT_RULER,
		"faction_id": FactionLedger.LIVONIAN_ORDER,
	},
	{
		"quest_id": &"quest.act2.siege.assault.rebel",
		"phase_id": PHASE_ASSAULT,
		"siege_phase": SIEGE_ASSAULT,
		"alignment": ALIGNMENT_REBEL,
		"faction_id": FactionLedger.HARJU_KINGS,
	},
	{
		"quest_id": &"quest.act2.siege.assault.ruler",
		"phase_id": PHASE_ASSAULT,
		"siege_phase": SIEGE_ASSAULT,
		"alignment": ALIGNMENT_RULER,
		"faction_id": FactionLedger.LIVONIAN_ORDER,
	},
]

var _content_db: ContentDB
var _state: GameState
var _quest_manager: QuestManager


func _init(
	content_db: ContentDB = null, state: GameState = null, evaluator: StateRuleEvaluator = null
) -> void:
	_content_db = content_db
	bind_state(state, evaluator)


## Rebinds the facade after SessionState replaces its canonical save state.
func bind_state(state: GameState, evaluator: StateRuleEvaluator = null) -> void:
	_state = state
	_quest_manager = QuestManager.new(_content_db, _state, evaluator)


func current_phase_id() -> StringName:
	if _state == null:
		return &""
	return _phase_id_for(_state.get_phase())


func current_siege_phase() -> StringName:
	var phase_id := current_phase_id()
	for mission in _MISSION_CATALOG:
		if mission["phase_id"] == phase_id:
			return mission["siege_phase"]
	return &""


## Returns offer snapshots for the current Act 2 phase, or an explicit phase.
## An optional alignment narrows the result to rebel or ruler offers.
func available_offers(
	phase_id: StringName = &"", alignment: StringName = &""
) -> Array[Dictionary]:
	var resolved_phase := _phase_id_for(phase_id)
	if resolved_phase.is_empty():
		resolved_phase = current_phase_id()
	if (
		resolved_phase.is_empty()
		or (
			not alignment.is_empty()
			and not [ALIGNMENT_REBEL, ALIGNMENT_RULER].has(alignment)
		)
	):
		return []
	var offers: Array[Dictionary] = []
	for catalog_entry in _MISSION_CATALOG:
		if catalog_entry["phase_id"] != resolved_phase:
			continue
		if not alignment.is_empty() and catalog_entry["alignment"] != alignment:
			continue
		var quest_id: StringName = catalog_entry["quest_id"]
		if not _alignment_is_available(
			StringName(catalog_entry["alignment"]), StringName(catalog_entry["faction_id"])
		):
			continue
		var quest := _content_db.get_quest(quest_id) if _content_db != null else {}
		if quest.is_empty() or _state == null or not _state.get_quest_state(quest_id).is_empty():
			continue
		var offer := catalog_entry.duplicate(true)
		offer["title"] = String(quest.get("title", ""))
		offer["summary"] = String(quest.get("summary", ""))
		offers.append(offer)
	return offers


func can_start_mission(quest_id: StringName) -> bool:
	return not _matching_offer(quest_id).is_empty()


## Starts only a catalogued mission that belongs to the current phase. Once
## started, QuestManager owns all authored transitions and their side effects.
func start_mission(quest_id: StringName) -> bool:
	var offer := _matching_offer(quest_id)
	if offer.is_empty() or _quest_manager == null:
		return false
	return _quest_manager.start_quest(quest_id)


func transition(quest_id: StringName, transition_id: StringName) -> bool:
	if _quest_manager == null:
		return false
	return _quest_manager.transition(quest_id, transition_id)


func get_last_result() -> QuestManager.Result:
	if _quest_manager == null:
		return QuestManager.Result.INVALID_DEPENDENCIES
	return _quest_manager.get_last_result()


func _alignment_is_available(alignment: StringName, faction_id: StringName) -> bool:
	if _state == null:
		return false
	if alignment == ALIGNMENT_REBEL:
		return (
			_state.get_flag(FLAG_BOUNDARY_BREAK)
			or _state.get_flag(FLAG_BOUNDARY_OPEN)
			or _state.get_faction_standing(faction_id) >= MIN_OFFER_STANDING
		)
	if alignment == ALIGNMENT_RULER:
		return (
			_state.get_flag(FLAG_BOUNDARY_SEAL)
			or _state.get_flag(FLAG_BOUNDARY_OPEN)
			or _state.get_faction_standing(faction_id) >= MIN_OFFER_STANDING
		)
	return false


func get_last_error() -> String:
	if _quest_manager == null:
		return "Act2MissionHost is not bound to a GameState"
	return _quest_manager.get_last_error()


func _matching_offer(quest_id: StringName) -> Dictionary:
	for offer in available_offers():
		if offer["quest_id"] == quest_id:
			return offer
	return {}


func _phase_id_for(value: StringName) -> StringName:
	match value:
		PHASE_INVESTMENT, SIEGE_INVESTMENT:
			return PHASE_INVESTMENT
		PHASE_SORTIE_SUPPLY, SIEGE_SORTIE_SUPPLY:
			return PHASE_SORTIE_SUPPLY
		PHASE_ASSAULT, SIEGE_ASSAULT:
			return PHASE_ASSAULT
	return &""

class_name GameState
extends RefCounted

## Fired after a slot's contents change so the 3D view can mirror the state.
signal equipment_changed(slot: StringName)
## Fired when quest ownership flags change.
signal items_changed
## Fired when a forged commission record is committed.
signal forged_record_added(record_id: StringName)
## Fired when an explicit faction ledger event is recorded.
signal faction_event_recorded(event_id: StringName, faction_id: StringName)
## Fired when an explicit Living City Hope/Fear event is recorded.
signal living_city_event_recorded(event_id: StringName)
## Fired when the campaign phase changes; SessionState autosaves on this boundary.
signal phase_changed(previous: StringName, next: StringName)

const _PersistenceScript := preload("res://scripts/state/game_state_persistence.gd")
const _RelationshipMemoryScript := preload("res://scripts/relationship/relationship_memory.gd")
const COMMISSION_DEADLINE_ACTIVE := &"active"
const CURRENT_VERSION := 2
const PHASE_PROLOGUE_DAY := &"phase.prologue_day"
const PHASE_INVESTIGATION_MORNING := &"phase.investigation_morning"
const PHASE_INVESTIGATION_NIGHT := &"phase.investigation_night"
const PHASE_CONSEQUENCE_NIGHT := &"phase.consequence_night"
const PHASE_REFLECTION_MORNING := &"phase.reflection_morning"
const SLICE_PHASES: Array[StringName] = [
	PHASE_PROLOGUE_DAY,
	PHASE_INVESTIGATION_MORNING,
	PHASE_INVESTIGATION_NIGHT,
	PHASE_CONSEQUENCE_NIGHT,
	PHASE_REFLECTION_MORNING,
]
const PRESSURE_SUSPICION := &"pressure.suspicion"
const PRESSURE_SOLIDARITY := &"pressure.solidarity"
const PRESSURE_SCARCITY := &"pressure.scarcity"
const RELATIONSHIP_MIN := -3
const RELATIONSHIP_MAX := 3
const PRESSURE_MIN := 0
const PRESSURE_MAX := 3
const LIVING_CITY_HOPE := &"living_city.hope"
const LIVING_CITY_FEAR := &"living_city.fear"
const LIVING_CITY_MIN := 0
const LIVING_CITY_MAX := 20
const LIVING_CITY_DEFAULT := 8
const LIVING_CITY_DELTA_MIN := -5
const LIVING_CITY_DELTA_MAX := 5

const NATURAL_VERSION := 1
const NATURAL_ASPECT_BASELINE := 5
const NATURAL_ASPECT_CAP := 50
const NATURAL_INITIAL_POINTS := 10
const NATURAL_ASPECT_IDS: Array[StringName] = [
	&"aspect.nature",
	&"aspect.affection",
	&"aspect.tenacity",
	&"aspect.unity",
	&"aspect.resonance",
	&"aspect.awareness",
	&"aspect.light",
]
const NATURAL_ASPECT_DISPLAY_NAMES: Dictionary = {
	&"aspect.nature": "Nature",
	&"aspect.affection": "Affection",
	&"aspect.tenacity": "Tenacity",
	&"aspect.unity": "Unity",
	&"aspect.resonance": "Resonance",
	&"aspect.awareness": "Awareness",
	&"aspect.light": "Light",
}
const PSYCHE_VERSION := 1
const PSYCHE_STATE_IDS: Array[StringName] = [
	&"psyche.state.ruthless",
	&"psyche.state.exalted",
	&"psyche.state.melancholy",
	&"psyche.state.pride",
	&"psyche.state.apathy",
	&"psyche.state.paranoid",
	&"psyche.state.obsession",
]
const PSYCHE_FACE_IDS: Array[StringName] = [
	&"face.persona",
	&"face.shadow",
	&"face.anima",
	&"face.self",
]
const PSYCHE_STATE_DELTAS: Dictionary = {
	&"psyche.state.ruthless": {&"aspect.tenacity": 2, &"aspect.unity": -2},
	&"psyche.state.exalted": {&"aspect.affection": 1, &"aspect.nature": -1},
	&"psyche.state.melancholy": {&"aspect.awareness": -2},
	&"psyche.state.apathy": {&"aspect.unity": -2, &"aspect.resonance": -1},
}

var version: int = CURRENT_VERSION
var phase: StringName = PHASE_PROLOGUE_DAY
var player: PlayerState = PlayerState.new()
var bag: InventoryBag = InventoryBag.new()
var map_world_state: MapStableStateStore = MapStableStateStore.new()

var _equipped: Dictionary[StringName, StringName] = {}
var _facts: Dictionary[StringName, bool] = {}
var _relationships: Dictionary[StringName, int] = {}
var _faction_events: Dictionary[StringName, Dictionary] = {}
var _pressures: Dictionary[StringName, int] = {}
var _living_city_events: Dictionary[StringName, Dictionary] = {}
var _living_city: Dictionary[StringName, int] = {}
var _forged_records: Dictionary[StringName, ForgedRecord] = {}
var _flags: Dictionary[StringName, bool] = {}
var _quest_states: Dictionary[StringName, StringName] = {}
var _location_states: Dictionary[StringName, StringName] = {}
var _items: Dictionary[StringName, bool] = {}
var _dialogue_nodes_seen: Dictionary[StringName, bool] = {}
var _relationship_memories: Dictionary[StringName, bool] = {}
var _commission_deadlines: Dictionary[StringName, StringName] = {}
var _world_items: Dictionary = {}
var _world_defaults_seeded: Dictionary = {}
## One equipped forge technique (Iron / Ember / Root) or empty when none.
var _equipped_forge_technique: StringName = &""
## Frozen Act 1 transition envelope written at St. George's Night (P4-009).
var _act1_transition: Dictionary = {}
var _natural_aspects: Dictionary[StringName, int] = {}
var _natural_unspent_points := 0
var _psyche_states: Dictionary[StringName, Dictionary] = {}
var _psyche_face_integration: Dictionary[StringName, int] = {}

func _init() -> void:
	_pressures[PRESSURE_SUSPICION] = 0
	_pressures[PRESSURE_SOLIDARITY] = 0
	_pressures[PRESSURE_SCARCITY] = 0
	_living_city[LIVING_CITY_HOPE] = LIVING_CITY_DEFAULT
	_living_city[LIVING_CITY_FEAR] = LIVING_CITY_DEFAULT
	for aspect_id in NATURAL_ASPECT_IDS:
		_natural_aspects[aspect_id] = NATURAL_ASPECT_BASELINE
	for face_id in PSYCHE_FACE_IDS:
		_psyche_face_integration[face_id] = 0


## NATURAL stores authored aspect ranks only; psyche modifiers are composed at read time.
func get_natural_aspect_rank(aspect_id: StringName) -> int:
	if not NATURAL_ASPECT_IDS.has(aspect_id):
		return 0
	return int(_natural_aspects.get(aspect_id, NATURAL_ASPECT_BASELINE))


func get_natural_effective_aspect_rank(aspect_id: StringName) -> int:
	var rank := get_natural_aspect_rank(aspect_id)
	for state_id in _psyche_states:
		var deltas: Dictionary = PSYCHE_STATE_DELTAS.get(state_id, {})
		rank += int(deltas.get(aspect_id, 0)) * int(_psyche_states[state_id].get("intensity", 1))
	return clampi(rank, 1, NATURAL_ASPECT_CAP)


func get_natural_aspects() -> Dictionary[StringName, int]:
	return _natural_aspects.duplicate()


func get_natural_unspent_points() -> int:
	return _natural_unspent_points


func grant_natural_points(amount: int) -> bool:
	if amount <= 0:
		return false
	_natural_unspent_points += amount
	return true


func spend_natural_point(aspect_id: StringName) -> StringName:
	if not NATURAL_ASPECT_IDS.has(aspect_id):
		return &"natural.fail.unknown_aspect"
	if _natural_unspent_points <= 0:
		return &"natural.fail.no_points"
	if get_natural_aspect_rank(aspect_id) >= NATURAL_ASPECT_CAP:
		return &"natural.fail.at_cap"
	_natural_aspects[aspect_id] = get_natural_aspect_rank(aspect_id) + 1
	_natural_unspent_points -= 1
	return &""


func get_psyche_states() -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for state_id in _psyche_states:
		states.append(_psyche_states[state_id].duplicate(true))
	states.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return String(a.get("id", "")) < String(b.get("id", ""))
	)
	return states


func apply_psyche_state(
	state_id: StringName, intensity: int, source_beat: StringName = &""
) -> StringName:
	if not PSYCHE_STATE_IDS.has(state_id):
		return &"psyche.fail.unknown_state"
	if intensity < 1 or intensity > 3:
		return &"psyche.fail.blocked"
	if _psyche_states.has(state_id):
		return &"psyche.fail.already_active"
	_psyche_states[state_id] = {
		"id": String(state_id),
		"intensity": intensity,
		"source_beat": String(source_beat),
	}
	return &""


func clear_psyche_state(state_id: StringName) -> StringName:
	if not _psyche_states.erase(state_id):
		return &"psyche.fail.unknown_state"
	return &""


func get_psyche_face_integration(face_id: StringName) -> int:
	return clampi(int(_psyche_face_integration.get(face_id, 0)), 0, 5)


func set_psyche_face_integration(face_id: StringName, rank: int) -> bool:
	if not PSYCHE_FACE_IDS.has(face_id):
		return false
	_psyche_face_integration[face_id] = clampi(rank, 0, 5)
	return true


func get_psyche_faces() -> Dictionary[StringName, int]:
	return _psyche_face_integration.duplicate()


func set_natural_initial_allocation_complete(value: bool) -> void:
	set_flag(&"flag.natural.initial_allocation", value)


func is_natural_system_enabled() -> bool:
	return get_flag(&"flag.natural.system_enabled")


func get_hingepuu_loci() -> Array[Dictionary]:
	var loci: Array[Dictionary] = [{"id": "hingepuu.locus.reflection", "kind": "rite"}]
	for aspect_id in NATURAL_ASPECT_IDS:
		loci.append(
			{
				"id": "hingepuu.locus.%s" % String(aspect_id).trim_prefix("aspect."),
				"kind": "aspect",
			}
		)
	for face_id in PSYCHE_FACE_IDS:
		loci.append(
			{
				"id": "hingepuu.locus.%s" % String(face_id).trim_prefix("face."),
				"kind": "face",
			}
		)
	return loci


func get_version() -> int:
	return version


func get_phase() -> StringName:
	return phase


func set_phase(value: StringName) -> void:
	if phase == value:
		return
	var previous := phase
	phase = value
	phase_changed.emit(previous, value)


func get_commission_deadline_status(commission_id: StringName) -> StringName:
	if commission_id.is_empty():
		return &""
	if not _commission_deadlines.has(commission_id):
		return COMMISSION_DEADLINE_ACTIVE
	return _commission_deadlines[commission_id]


func set_commission_deadline_status(commission_id: StringName, status: StringName) -> void:
	if commission_id.is_empty() or status.is_empty():
		return
	_commission_deadlines[commission_id] = status


func get_fact(key: StringName) -> bool:
	return _facts.get(key, false)


func set_fact(key: StringName, value: bool) -> void:
	_facts[key] = value


func get_flag(key: StringName) -> bool:
	return _flags.get(key, false)


func set_flag(key: StringName, value: bool) -> void:
	_flags[key] = value


func equipped_forge_technique() -> StringName:
	return _equipped_forge_technique


## Equips an allowlisted forge technique, or clears it when empty. Returns false
## when the id is not one of the three authored techniques.
func set_equipped_forge_technique(technique_id: StringName) -> bool:
	if technique_id.is_empty():
		_equipped_forge_technique = &""
		return true
	if not ForgeTechnique.is_allowed(technique_id):
		return false
	_equipped_forge_technique = technique_id
	return true


func get_act1_transition() -> Dictionary:
	return _act1_transition.duplicate(true)


func set_act1_transition(envelope: Dictionary) -> void:
	_act1_transition = envelope.duplicate(true)


func has_act1_transition() -> bool:
	return not _act1_transition.is_empty()


func get_quest_state(key: StringName) -> StringName:
	return _quest_states.get(key, &"")


func set_quest_state(key: StringName, value: StringName) -> void:
	_quest_states[key] = value


func get_location_state(key: StringName) -> StringName:
	return _location_states.get(key, &"")


func set_location_state(key: StringName, value: StringName) -> void:
	_location_states[key] = value


func load_map_world_state(
	payload: Dictionary,
	known_archetypes: Array[StringName] = [],
	expected_fingerprints: Dictionary = {}
) -> Array[String]:
	return map_world_state.load_payload(payload, known_archetypes, expected_fingerprints)


func save_map_world_state() -> Dictionary:
	return map_world_state.save_payload()


## --- Equipment placement (see docs/INVENTORY_MECHANICS.md) ---------------
## Equipped items leave the bag grid but keep counting toward the weight cap:
## you carry what you wear. Failed swaps mutate nothing.


func equipped_item(slot: StringName) -> StringName:
	return _equipped.get(slot, &"")


func equipped_slots() -> Array[StringName]:
	var slots: Array[StringName] = []
	for slot: StringName in _equipped:
		slots.append(slot)
	slots.sort()
	return slots


func equip_from_bag(slot: StringName, item_id: StringName) -> bool:
	if slot.is_empty() or item_id.is_empty():
		return false
	var placement := bag.find_placement(item_id)
	if placement == null:
		return false

	# Take one unit out of the grid before attempting the swap-back so the
	# previous occupant can use the freed cells.
	if placement.quantity > 1:
		placement.quantity -= 1
	else:
		bag.remove(placement)

	var previous := equipped_item(slot)
	if not previous.is_empty() and bag.try_add(previous) != InventoryBag.AddResult.OK:
		# Rollback: the previous occupant does not fit back into the grid.
		if placement.quantity >= 1 and bag.find_placement(item_id) == placement:
			placement.quantity += 1
		else:
			bag.try_add(item_id)
		return false

	_equipped[slot] = item_id
	_refresh_reserved_weight()
	equipment_changed.emit(slot)
	return true


func unequip_to_bag(slot: StringName) -> bool:
	var item_id := equipped_item(slot)
	if item_id.is_empty():
		return false
	# The item's own weight is already counted as reserved, so release it
	# for the duration of the add-back check.
	bag.reserved_weight_kg -= bag.profile_for(item_id).weight_kg
	if bag.try_add(item_id) != InventoryBag.AddResult.OK:
		_refresh_reserved_weight()
		return false
	_equipped.erase(slot)
	_refresh_reserved_weight()
	equipment_changed.emit(slot)
	return true


## Bag weight plus worn weight; the cap covers everything Kalev carries.
func get_carried_weight() -> float:
	return bag.get_total_weight() + bag.reserved_weight_kg


func _refresh_reserved_weight() -> void:
	var total := 0.0
	for slot: StringName in _equipped:
		total += bag.profile_for(_equipped[slot]).weight_kg
	bag.reserved_weight_kg = total


func has_item(key: StringName) -> bool:
	return _items.has(key)


func get_owned_item_ids_in_order() -> Array[StringName]:
	var keys: Array[StringName] = []
	for key: StringName in _items:
		keys.append(key)
	return keys


func possesses_item(item_id: StringName) -> bool:
	if item_id.is_empty():
		return false
	if has_item(item_id):
		return true
	if bag.find_placement(item_id) != null:
		return true
	for slot: StringName in equipped_slots():
		if equipped_item(slot) == item_id:
			return true
	return false


func add_item(key: StringName) -> bool:
	if key.is_empty() or _items.has(key):
		return false
	_items[key] = true
	items_changed.emit()
	return true


func remove_item(key: StringName) -> bool:
	if not _items.erase(key):
		return false
	items_changed.emit()
	return true


func has_dialogue_node_seen(dialogue_id: StringName, node_id: String) -> bool:
	if dialogue_id.is_empty() or node_id.is_empty():
		return false
	return _dialogue_nodes_seen.has(_dialogue_node_key(dialogue_id, node_id))


func mark_dialogue_node_seen(dialogue_id: StringName, node_id: String) -> void:
	if dialogue_id.is_empty() or node_id.is_empty():
		return
	_dialogue_nodes_seen[_dialogue_node_key(dialogue_id, node_id)] = true


func get_dialogue_nodes_seen() -> Array[StringName]:
	var keys: Array[StringName] = []
	for key: StringName in _dialogue_nodes_seen:
		keys.append(key)
	keys.sort()
	return keys


func has_relationship_memory(key: StringName) -> bool:
	return _relationship_memories.get(key, false)


func record_relationship_memory(key: StringName) -> bool:
	if not _RelationshipMemoryScript.is_valid_key(key):
		return false
	_relationship_memories[key] = true
	return true


func get_relationship_memories() -> Array[StringName]:
	var keys: Array[StringName] = []
	for key: StringName in _relationship_memories:
		if _relationship_memories[key]:
			keys.append(key)
	keys.sort()
	return keys


func get_relationship_memories_for_character(character_id: StringName) -> Array[StringName]:
	var keys: Array[StringName] = []
	for key: StringName in get_relationship_memories():
		if _RelationshipMemoryScript.character_id_for_key(key) == character_id:
			keys.append(key)
	return keys


## --- World item placement (session-scoped, survives map re-entry) ---------
## Items on the ground live outside the bag grid until picked up.


func get_world_items(location_id: StringName) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if location_id.is_empty():
		return records
	var bucket: Variant = _world_items.get(String(location_id), {})
	if not bucket is Dictionary:
		return records
	for object_key in bucket:
		var record: Variant = bucket[object_key]
		if record is Dictionary:
			records.append((record as Dictionary).duplicate(true))
	records.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return String(a.get("object_id", "")) < String(b.get("object_id", ""))
	)
	return records


func is_world_item_placed(location_id: StringName, object_id: StringName) -> bool:
	if location_id.is_empty() or object_id.is_empty():
		return false
	var bucket: Variant = _world_items.get(String(location_id), {})
	return bucket is Dictionary and (bucket as Dictionary).has(String(object_id))


func place_world_item(
	location_id: StringName, object_id: StringName, item_id: StringName, position: Vector2
) -> bool:
	if location_id.is_empty() or object_id.is_empty() or item_id.is_empty():
		return false
	var bucket: Dictionary = _world_items.get(String(location_id), {}) as Dictionary
	if not _world_items.has(String(location_id)):
		_world_items[String(location_id)] = bucket
	bucket[String(object_id)] = {
		"object_id": object_id,
		"item_id": item_id,
		"position": position,
	}
	return true


func are_world_defaults_seeded(location_id: StringName) -> bool:
	if location_id.is_empty():
		return false
	return bool(_world_defaults_seeded.get(String(location_id), false))


func mark_world_defaults_seeded(location_id: StringName) -> void:
	if location_id.is_empty():
		return
	_world_defaults_seeded[String(location_id)] = true


func take_world_item(location_id: StringName, object_id: StringName) -> Dictionary:
	if location_id.is_empty() or object_id.is_empty():
		return {}
	var bucket: Variant = _world_items.get(String(location_id), {})
	if not bucket is Dictionary:
		return {}
	var key := String(object_id)
	var record: Variant = (bucket as Dictionary).get(key, {})
	if not record is Dictionary:
		return {}
	(bucket as Dictionary).erase(key)
	return (record as Dictionary).duplicate(true)


func get_relationship(key: StringName) -> int:
	return _relationships.get(key, 0)


func set_relationship(key: StringName, value: int) -> void:
	_relationships[key] = clampi(value, RELATIONSHIP_MIN, RELATIONSHIP_MAX)


func adjust_relationship(key: StringName, amount: int) -> void:
	set_relationship(key, get_relationship(key) + amount)


func has_faction_event(event_id: StringName) -> bool:
	return _faction_events.has(event_id)


func record_faction_event(
	event_id: StringName, faction_id: StringName, delta: int, summary: String
) -> bool:
	# WHY: candidate seats (P4-045 Blackheads) record events/IDs without joining
	# FactionLedger.ACTIVE_FACTIONS, so the launch-eight journal table stays exact.
	if event_id.is_empty() or not FactionCandidateSeats.is_recordable_faction(faction_id):
		return false
	if _faction_events.has(event_id):
		return false
	_faction_events[event_id] = {
		"event_id": event_id,
		"faction_id": faction_id,
		"delta": clampi(delta, FactionLedger.STANDING_MIN, FactionLedger.STANDING_MAX),
		"summary": summary,
	}
	faction_event_recorded.emit(event_id, faction_id)
	return true


func get_faction_standing(faction_id: StringName) -> int:
	if not FactionCandidateSeats.is_recordable_faction(faction_id):
		return 0
	var total := 0
	for event in _faction_events.values():
		if event.get("faction_id", &"") == faction_id:
			total += int(event.get("delta", 0))
	return clampi(total, FactionLedger.STANDING_MIN, FactionLedger.STANDING_MAX)


func get_faction_events_for(faction_id: StringName) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for event_id in _faction_events.keys():
		var event: Dictionary = _faction_events[event_id]
		if event.get("faction_id", &"") != faction_id:
			continue
		events.append(event.duplicate(true))
	events.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return String(a.get("event_id", "")) < String(b.get("event_id", ""))
	)
	return events


func get_pressure(key: StringName) -> int:
	return _pressures.get(key, 0)


func set_pressure(key: StringName, value: int) -> void:
	_pressures[key] = clampi(value, PRESSURE_MIN, PRESSURE_MAX)


func adjust_pressure(key: StringName, amount: int) -> void:
	set_pressure(key, get_pressure(key) + amount)


func get_living_city_meter(key: StringName) -> int:
	return _living_city.get(key, LIVING_CITY_DEFAULT)


func get_living_city_hope() -> int:
	return get_living_city_meter(LIVING_CITY_HOPE)


func get_living_city_fear() -> int:
	return get_living_city_meter(LIVING_CITY_FEAR)


func has_living_city_event(event_id: StringName) -> bool:
	return _living_city_events.has(event_id)


func record_living_city_event(
	event_id: StringName, hope_delta: int, fear_delta: int, summary: String
) -> bool:
	if event_id.is_empty() or not String(event_id).begins_with("living."):
		return false
	if _living_city_events.has(event_id):
		return false
	if (
		(hope_delta == 0 and fear_delta == 0)
		or hope_delta < LIVING_CITY_DELTA_MIN
		or hope_delta > LIVING_CITY_DELTA_MAX
		or fear_delta < LIVING_CITY_DELTA_MIN
		or fear_delta > LIVING_CITY_DELTA_MAX
	):
		return false
	_living_city_events[event_id] = {
		"event_id": event_id,
		"hope_delta": hope_delta,
		"fear_delta": fear_delta,
		"summary": summary,
	}
	_living_city[LIVING_CITY_HOPE] = clampi(
		get_living_city_hope() + hope_delta, LIVING_CITY_MIN, LIVING_CITY_MAX
	)
	_living_city[LIVING_CITY_FEAR] = clampi(
		get_living_city_fear() + fear_delta, LIVING_CITY_MIN, LIVING_CITY_MAX
	)
	living_city_event_recorded.emit(event_id)
	return true


func get_living_city_events() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for event_id in _living_city_events:
		events.append((_living_city_events[event_id] as Dictionary).duplicate(true))
	events.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return String(a.get("event_id", "")) < String(b.get("event_id", ""))
	)
	return events


func set_living_city_meter(key: StringName, value: int) -> void:
	if key != LIVING_CITY_HOPE and key != LIVING_CITY_FEAR:
		return
	_living_city[key] = clampi(value, LIVING_CITY_MIN, LIVING_CITY_MAX)


func add_forged_record(record: ForgedRecord) -> bool:
	if record == null or record.record_id.is_empty():
		return false
	if _forged_records.has(record.record_id):
		return false
	_forged_records[record.record_id] = record
	forged_record_added.emit(record.record_id)
	return true


func has_forged_record(record_id: StringName) -> bool:
	return _forged_records.has(record_id)


func has_forged_modification(commission_id: StringName, modification_id: StringName) -> bool:
	for record in get_forged_records():
		if record.commission_id == commission_id and record.modification_id == modification_id:
			return true
	return false


func get_forged_record(record_id: StringName) -> ForgedRecord:
	return _forged_records.get(record_id)


func get_forged_records() -> Array[ForgedRecord]:
	var records: Array[ForgedRecord] = []
	for record in _forged_records.values():
		records.append(record)
	records.sort_custom(
		func(a: ForgedRecord, b: ForgedRecord) -> bool:
			return String(a.record_id) < String(b.record_id)
	)
	return records


## Migrates the last released v1 payload without mutating the caller's data.
## V2 introduced persistent loose world items and the stable map-state envelope.
static func _migrate_v1_to_v2(payload: Dictionary) -> Dictionary:
	var migrated := payload.duplicate(true)
	migrated["version"] = 2
	if not migrated.has("world_items"):
		migrated["world_items"] = {}
	if not migrated.has("world_defaults_seeded"):
		migrated["world_defaults_seeded"] = {}
	if not migrated.has("map_world_state"):
		migrated["map_world_state"] = {
			"save_version": MapStableStateStore.CURRENT_SAVE_VERSION,
			"world_state": {},
		}
	return migrated


func save_payload() -> Dictionary:
	return _PersistenceScript.save_payload(self)


func load_payload(payload: Dictionary) -> Array[String]:
	return _PersistenceScript.load_payload(self, payload)


func _dialogue_node_key(dialogue_id: StringName, node_id: String) -> StringName:
	return StringName("%s:%s" % [String(dialogue_id), node_id])

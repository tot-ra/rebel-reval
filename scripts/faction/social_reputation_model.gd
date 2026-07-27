class_name SocialReputationModel
extends RefCounted

## Authored public reputation moments keyed to faction standing thresholds.
## Each event fires once, sets a stable flag, and drives a bark pool reaction.

const REACTION_CHEER := &"cheer"
const REACTION_MURMUR := &"murmur"
const REACTION_SILENCE := &"silence"
const REACTION_QUESTION := &"question"

const EVENTS: Array[Dictionary] = [
	{
		"event_id": &"reputation.harju_kings_trusted",
		"faction_id": FactionLedger.HARJU_KINGS,
		"threshold": 2,
		"reaction": REACTION_CHEER,
		"bark_pool_id": &"bark.reputation.harju_kings_trusted",
		"flag_id": &"flag.reputation.harju_kings_trusted",
		"location_ids": [&"loc.lower_town_slice"],
		"sfx_path": "res://sounds/walk_wood.mp3",
		"sfx_pitch": 0.85,
		"sfx_volume_db": -14.0,
	},
]


static func flag_for_event(event_id: StringName) -> StringName:
	for event in EVENTS:
		if event.get("event_id", &"") == event_id:
			return event.get("flag_id", &"")
	return &""


static func events_to_fire(state: GameState, location_id: StringName) -> Array[Dictionary]:
	var pending: Array[Dictionary] = []
	if state == null:
		return pending
	for event in EVENTS:
		if not _location_matches(event, location_id):
			continue
		var flag_id: StringName = event.get("flag_id", &"")
		if flag_id.is_empty() or state.get_flag(flag_id):
			continue
		if not _threshold_met(state, event):
			continue
		pending.append(event.duplicate(true))
	return pending


static func mark_fired(state: GameState, event: Dictionary) -> void:
	var flag_id: StringName = event.get("flag_id", &"")
	if state == null or flag_id.is_empty():
		return
	state.set_flag(flag_id, true)


static func _threshold_met(state: GameState, event: Dictionary) -> bool:
	var faction_id: StringName = event.get("faction_id", &"")
	var threshold := int(event.get("threshold", 0))
	return state.get_faction_standing(faction_id) >= threshold


static func _location_matches(event: Dictionary, location_id: StringName) -> bool:
	var locations: Array = event.get("location_ids", [])
	if locations.is_empty():
		return true
	return locations.has(location_id)

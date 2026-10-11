class_name EventOverlayModel
extends RefCounted

## Calendar-bound public-life overlays from the R-25 dossier.
##
## `trade_modifier` is a multiplier: 1.0 keeps routine trade, 0.5 restricts it,
## and 0.0 closes it. Routes use stable venue tokens rather than inventing new
## festival-only map geometry. Siege overrides keep the public beat legible
## while shortening exposed processions or tightening supply activity.

const YEAR := 1343
const VENUE_FORUM := &"forum"
const VENUE_CHURCH_THRESHOLD := &"church_threshold"
const VENUE_GATE_APPROACH := &"gate_approach"
const VENUE_TAVERN := &"tavern"
const VENUE_VANATURU_KAEL := &"vanaturu_kael"
const ALLOWED_VENUES: Array[StringName] = [
	VENUE_FORUM,
	VENUE_CHURCH_THRESHOLD,
	VENUE_GATE_APPROACH,
	VENUE_TAVERN,
	VENUE_VANATURU_KAEL,
]

const EVENT_IDS: Array[StringName] = [
	&"easter_feast",
	&"st_georges_feast",
	&"rogation_procession",
	&"ascension_holy_day",
	&"market_pillory",
	&"ration_queue",
	&"watch_muster",
]

const EVENTS: Dictionary = {
	&"easter_feast":
	{
		"event_id": &"easter_feast",
		"date": {"day": 13, "month": 4, "year": YEAR},
		"end_date": {"day": 14, "month": 4, "year": YEAR},
		"venue": VENUE_TAVERN,
		"public_visibility": &"high",
		"trade_modifier": 0.5,
		"procession_route": [],
		"siege_override":
		{
			"public_visibility": &"medium",
			"trade_modifier": 0.25,
			"procession_route": [],
		},
	},
	&"st_georges_feast":
	{
		"event_id": &"st_georges_feast",
		"date": {"day": 23, "month": 4, "year": YEAR},
		"venue": VENUE_CHURCH_THRESHOLD,
		"public_visibility": &"high",
		"trade_modifier": 1.0,
		"procession_route": [VENUE_CHURCH_THRESHOLD, VENUE_FORUM],
		"siege_override":
		{
			"public_visibility": &"medium",
			"trade_modifier": 0.5,
			"procession_route": [VENUE_CHURCH_THRESHOLD],
		},
	},
	&"rogation_procession":
	{
		"event_id": &"rogation_procession",
		"date": {"day": 19, "month": 5, "year": YEAR},
		"end_date": {"day": 21, "month": 5, "year": YEAR},
		"venue": VENUE_CHURCH_THRESHOLD,
		"public_visibility": &"medium",
		"trade_modifier": 0.5,
		"procession_route": [VENUE_CHURCH_THRESHOLD, VENUE_FORUM, VENUE_GATE_APPROACH],
		"siege_override":
		{
			"public_visibility": &"low",
			"trade_modifier": 0.25,
			"procession_route": [VENUE_CHURCH_THRESHOLD, VENUE_GATE_APPROACH],
		},
	},
	&"ascension_holy_day":
	{
		"event_id": &"ascension_holy_day",
		"date": {"day": 22, "month": 5, "year": YEAR},
		"venue": VENUE_CHURCH_THRESHOLD,
		"public_visibility": &"medium",
		"trade_modifier": 0.0,
		"procession_route": [VENUE_CHURCH_THRESHOLD, VENUE_FORUM],
		"siege_override":
		{
			"public_visibility": &"low",
			"trade_modifier": 0.25,
			"procession_route": [VENUE_CHURCH_THRESHOLD],
		},
	},
	&"market_pillory":
	{
		"event_id": &"market_pillory",
		"date": {"day": 21, "month": 4, "year": YEAR},
		"venue": VENUE_FORUM,
		"public_visibility": &"high",
		"trade_modifier": 0.5,
		"procession_route": [],
		"siege_override":
		{
			"public_visibility": &"medium",
			"trade_modifier": 0.25,
			"procession_route": [],
		},
	},
	&"ration_queue":
	{
		"event_id": &"ration_queue",
		"date": {"day": 24, "month": 4, "year": YEAR},
		"venue": VENUE_VANATURU_KAEL,
		"public_visibility": &"high",
		"trade_modifier": 0.25,
		"procession_route": [],
		"siege_only": true,
		"siege_override":
		{
			"public_visibility": &"high",
			"trade_modifier": 0.0,
			"procession_route": [],
		},
	},
	&"watch_muster":
	{
		"event_id": &"watch_muster",
		"date": {"day": 24, "month": 4, "year": YEAR},
		"venue": VENUE_GATE_APPROACH,
		"public_visibility": &"high",
		"trade_modifier": 0.5,
		"procession_route": [VENUE_GATE_APPROACH],
		"siege_only": true,
		"siege_override":
		{
			"public_visibility": &"high",
			"trade_modifier": 0.25,
			"procession_route": [VENUE_GATE_APPROACH],
		},
	},
}


static func event_ids() -> Array[StringName]:
	return EVENT_IDS.duplicate()


static func all_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event_id: StringName in EVENT_IDS:
		result.append(event_for(event_id))
	return result


static func event_for(event_id: StringName) -> Dictionary:
	var event: Dictionary = EVENTS.get(event_id, {})
	return event.duplicate(true)


static func resolve(event_id: StringName, siege_active: bool = false) -> Dictionary:
	var event := event_for(event_id)
	if event.is_empty() or not siege_active:
		return event
	var override: Dictionary = event.get("siege_override", {})
	for field: String in ["public_visibility", "trade_modifier", "procession_route"]:
		if override.has(field):
			event[field] = override[field]
	return event


static func events_on(date: Dictionary, siege_active: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event_id: StringName in EVENT_IDS:
		var event := event_for(event_id)
		if bool(event.get("siege_only", false)) and not siege_active:
			continue
		if _date_in_window(date, event):
			result.append(resolve(event_id, siege_active))
	return result


static func _date_in_window(date: Dictionary, event: Dictionary) -> bool:
	var value := _date_key(date)
	var start := _date_key(event.get("date", {}))
	var end := _date_key(event.get("end_date", event.get("date", {})))
	return value >= start and value <= end


static func _date_key(date: Dictionary) -> int:
	return (
		int(date.get("year", 0)) * 10000 + int(date.get("month", 0)) * 100 + int(date.get("day", 0))
	)

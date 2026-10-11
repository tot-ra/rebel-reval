extends "res://tests/godot/test_case.gd"

const ModelScript := preload("res://scripts/world/event_overlay_model.gd")

const EXPECTED_EVENT_IDS: Array[StringName] = [
	&"easter_feast",
	&"st_georges_feast",
	&"rogation_procession",
	&"ascension_holy_day",
	&"market_pillory",
	&"ration_queue",
	&"watch_muster",
]


func test_public_life_contract_declares_all_seven_event_ids() -> void:
	assert_eq(ModelScript.event_ids(), EXPECTED_EVENT_IDS)
	assert_eq(ModelScript.all_events().size(), EXPECTED_EVENT_IDS.size())
	for event_id: StringName in EXPECTED_EVENT_IDS:
		var event := ModelScript.event_for(event_id)
		assert_eq(event.get("event_id", &""), event_id)
		assert_false(event.is_empty())
		assert_false(event.has("market_weekday"), "%s must not invent a weekly market day" % event_id)


func test_public_life_contract_uses_julian_1343_dates_and_existing_venues() -> void:
	var expected_dates := {
		&"easter_feast": {"day": 13, "month": 4, "year": 1343},
		&"st_georges_feast": {"day": 23, "month": 4, "year": 1343},
		&"rogation_procession": {"day": 19, "month": 5, "year": 1343},
		&"ascension_holy_day": {"day": 22, "month": 5, "year": 1343},
		&"market_pillory": {"day": 21, "month": 4, "year": 1343},
		&"ration_queue": {"day": 24, "month": 4, "year": 1343},
		&"watch_muster": {"day": 24, "month": 4, "year": 1343},
	}
	for event_id: StringName in EXPECTED_EVENT_IDS:
		var event := ModelScript.event_for(event_id)
		assert_eq(event.get("date", {}), expected_dates[event_id])
		assert_array_contains(ModelScript.ALLOWED_VENUES, event.get("venue", &""))
		for route_venue: StringName in event.get("procession_route", []):
			assert_array_contains(ModelScript.ALLOWED_VENUES, route_venue)
		for route_venue: StringName in event.get("siege_override", {}).get("procession_route", []):
			assert_array_contains(ModelScript.ALLOWED_VENUES, route_venue)


func test_siege_override_shortens_public_processions_and_enables_supply_beats() -> void:
	var feast := ModelScript.resolve(&"st_georges_feast", false)
	var siege_feast := ModelScript.resolve(&"st_georges_feast", true)
	assert_eq(feast.get("procession_route", []).size(), 2)
	assert_eq(siege_feast.get("procession_route", []).size(), 1)
	assert_eq(siege_feast.get("public_visibility", &""), &"medium")
	assert_eq(siege_feast.get("trade_modifier", -1.0), 0.5)

	assert_eq(ModelScript.events_on({"day": 24, "month": 4, "year": 1343}, false).size(), 0)
	var siege_events := ModelScript.events_on({"day": 24, "month": 4, "year": 1343}, true)
	var siege_ids: Array[StringName] = []
	for event: Dictionary in siege_events:
		siege_ids.append(event.get("event_id", &""))
	assert_array_contains(siege_ids, &"ration_queue")
	assert_array_contains(siege_ids, &"watch_muster")
	assert_eq(ModelScript.resolve(&"ration_queue", true).get("trade_modifier", -1.0), 0.0)


func test_multi_day_windows_cover_easter_and_rogation_dates() -> void:
	var easter_events := ModelScript.events_on({"day": 14, "month": 4, "year": 1343})
	assert_eq(easter_events.size(), 1)
	assert_eq(easter_events[0].get("event_id", &""), &"easter_feast")

	var rogation_events := ModelScript.events_on({"day": 20, "month": 5, "year": 1343})
	assert_eq(rogation_events.size(), 1)
	assert_eq(rogation_events[0].get("event_id", &""), &"rogation_procession")

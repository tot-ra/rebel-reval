extends "res://tests/godot/test_case.gd"

const HostScript := preload("res://scripts/quest/act2_mission_host.gd")

const CONTENT_DIRS: Array[String] = [
	"res://content/packages/act2_siege_investment_rebel/content",
	"res://content/packages/act2_siege_investment_ruler/content",
	"res://content/packages/act2_siege_sortie_rebel/content",
	"res://content/packages/act2_siege_sortie_ruler/content",
	"res://content/packages/act2_siege_assault_rebel/content",
	"res://content/packages/act2_siege_assault_ruler/content",
]

const MISSIONS: Array[Dictionary] = [
	{
		"quest_id": &"quest.act2.siege.investment.rebel",
		"phase_id": HostScript.PHASE_INVESTMENT,
		"alignment": HostScript.ALIGNMENT_REBEL,
		"event_id": &"ledger.act2.siege.investment.rebel.direct",
		"phase_flag": &"flag.war.siege_phase.investment",
	},
	{
		"quest_id": &"quest.act2.siege.investment.ruler",
		"phase_id": HostScript.PHASE_INVESTMENT,
		"alignment": HostScript.ALIGNMENT_RULER,
		"event_id": &"ledger.act2.siege.investment.ruler.direct",
		"phase_flag": &"flag.war.siege_phase.investment",
	},
	{
		"quest_id": &"quest.act2.siege.sortie_supply.rebel",
		"phase_id": HostScript.PHASE_SORTIE_SUPPLY,
		"alignment": HostScript.ALIGNMENT_REBEL,
		"event_id": &"ledger.act2.siege.sortie_supply.rebel.direct",
		"phase_flag": &"flag.war.siege_phase.sortie_supply",
	},
	{
		"quest_id": &"quest.act2.siege.sortie_supply.ruler",
		"phase_id": HostScript.PHASE_SORTIE_SUPPLY,
		"alignment": HostScript.ALIGNMENT_RULER,
		"event_id": &"ledger.act2.siege.sortie_supply.ruler.direct",
		"phase_flag": &"flag.war.siege_phase.sortie_supply",
	},
	{
		"quest_id": &"quest.act2.siege.assault.rebel",
		"phase_id": HostScript.PHASE_ASSAULT,
		"alignment": HostScript.ALIGNMENT_REBEL,
		"event_id": &"ledger.act2.siege.assault.rebel.direct",
		"phase_flag": &"flag.war.siege_phase.assault",
	},
	{
		"quest_id": &"quest.act2.siege.assault.ruler",
		"phase_id": HostScript.PHASE_ASSAULT,
		"alignment": HostScript.ALIGNMENT_RULER,
		"event_id": &"ledger.act2.siege.assault.ruler.direct",
		"phase_flag": &"flag.war.siege_phase.assault",
	},
]

const BOUNDARY_FAMILIES: Array[Dictionary] = [
	{
		"id": "seal",
		"flag": HostScript.FLAG_BOUNDARY_SEAL,
		"allowed_alignments": [HostScript.ALIGNMENT_RULER],
	},
	{
		"id": "break",
		"flag": HostScript.FLAG_BOUNDARY_BREAK,
		"allowed_alignments": [HostScript.ALIGNMENT_REBEL],
	},
	{
		"id": "open",
		"flag": HostScript.FLAG_BOUNDARY_OPEN,
		"allowed_alignments": [HostScript.ALIGNMENT_REBEL, HostScript.ALIGNMENT_RULER],
	},
]

var db: ContentDB


func before_each() -> void:
	db = ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS), "Act 2 siege content should load")


func test_each_siege_phase_offers_both_authored_alignments() -> void:
	for phase_id in [
		HostScript.PHASE_INVESTMENT,
		HostScript.PHASE_SORTIE_SUPPLY,
		HostScript.PHASE_ASSAULT,
	]:
		var state := _state_for_phase(phase_id)
		var host := HostScript.new(db, state)
		var offers := host.available_offers()
		assert_eq(offers.size(), 2, "phase should expose both authored offers: %s" % phase_id)
		assert_eq(host.available_offers(phase_id, HostScript.ALIGNMENT_REBEL).size(), 1)
		assert_eq(host.available_offers(phase_id, HostScript.ALIGNMENT_RULER).size(), 1)


func test_each_act1_boundary_family_exposes_expected_routes_and_survives_save_load() -> void:
	for boundary: Dictionary in BOUNDARY_FAMILIES:
		var boundary_flag: StringName = boundary["flag"]
		var allowed_alignments: Array = boundary["allowed_alignments"]
		for phase_id in [
			HostScript.PHASE_INVESTMENT,
			HostScript.PHASE_SORTIE_SUPPLY,
			HostScript.PHASE_ASSAULT,
		]:
			var offers_state := _state_for_phase(phase_id, boundary_flag)
			var offers_host := HostScript.new(db, offers_state)
			var offers := offers_host.available_offers()
			assert_eq(
				offers.size(),
				allowed_alignments.size(),
				"boundary family offer count mismatch: %s / %s" % [boundary["id"], phase_id],
			)
			for alignment: StringName in [HostScript.ALIGNMENT_REBEL, HostScript.ALIGNMENT_RULER]:
				var alignment_offers := offers_host.available_offers(phase_id, alignment)
				if not allowed_alignments.has(alignment):
					assert_eq(
						alignment_offers.size(),
						0,
						"boundary family must hide %s: %s" % [alignment, boundary["id"]],
					)
					continue

				assert_eq(alignment_offers.size(), 1)
				var mission := _mission_for(phase_id, alignment)
				var state := _state_for_phase(phase_id, boundary_flag)
				var host := HostScript.new(db, state)
				var quest_id: StringName = alignment_offers[0]["quest_id"]
				assert_eq(quest_id, mission["quest_id"])
				assert_true(host.can_start_mission(quest_id))
				assert_true(host.start_mission(quest_id), "mission should start: %s" % quest_id)
				assert_true(host.transition(quest_id, &"brief"))
				assert_true(host.transition(quest_id, &"resolve_direct"))
				assert_eq(state.get_quest_state(quest_id), &"direct_complete")
				assert_true(state.get_flag(boundary_flag))
				assert_true(state.has_faction_event(mission["event_id"]))
				for other_boundary: StringName in [
					HostScript.FLAG_BOUNDARY_SEAL,
					HostScript.FLAG_BOUNDARY_BREAK,
					HostScript.FLAG_BOUNDARY_OPEN,
				]:
					if other_boundary != boundary_flag:
						assert_false(state.get_flag(other_boundary))

				var restored := GameState.new()
				assert_eq(restored.load_payload(state.save_payload()), [])
				assert_eq(restored.get_phase(), phase_id)
				assert_eq(restored.get_quest_state(quest_id), &"direct_complete")
				assert_true(restored.get_flag(boundary_flag))
				assert_true(restored.has_faction_event(mission["event_id"]))
				for other_boundary: StringName in [
					HostScript.FLAG_BOUNDARY_SEAL,
					HostScript.FLAG_BOUNDARY_BREAK,
					HostScript.FLAG_BOUNDARY_OPEN,
				]:
					if other_boundary != boundary_flag:
						assert_false(restored.get_flag(other_boundary))


func _mission_for(phase_id: StringName, alignment: StringName) -> Dictionary:
	for mission: Dictionary in MISSIONS:
		if mission["phase_id"] == phase_id and mission["alignment"] == alignment:
			return mission
	return {}


func test_wrong_phase_offer_is_hidden_and_cannot_start() -> void:
	var state := _state_for_phase(HostScript.PHASE_INVESTMENT)
	var host := HostScript.new(db, state)
	var sortie_id: StringName = MISSIONS[2]["quest_id"]

	assert_true(host.available_offers(HostScript.PHASE_SORTIE_SUPPLY).size() == 2)
	assert_false(host.can_start_mission(sortie_id))
	assert_false(host.start_mission(sortie_id))
	assert_eq(state.get_quest_state(sortie_id), &"")


func test_production_session_loads_all_siege_quests() -> void:
	for mission in MISSIONS:
		var quest_id: StringName = mission["quest_id"]
		assert_true(
			SessionState.content_db.has_record(quest_id),
			"production ContentDB should load %s" % quest_id,
		)
	assert_true(SessionState.act2_mission_host != null)


func test_all_siege_missions_start_and_direct_outcomes_survive_save_load() -> void:
	for mission in MISSIONS:
		var state := _state_for_phase(mission["phase_id"])
		var host := HostScript.new(db, state)
		var quest_id: StringName = mission["quest_id"]

		assert_true(host.can_start_mission(quest_id), "mission should be offered: %s" % quest_id)
		assert_true(host.start_mission(quest_id), "mission should start: %s" % quest_id)
		assert_true(host.transition(quest_id, &"brief"))
		assert_true(host.transition(quest_id, &"resolve_direct"))
		assert_eq(state.get_quest_state(quest_id), &"direct_complete")
		assert_true(state.get_flag(mission["phase_flag"]))
		assert_true(state.has_faction_event(mission["event_id"]))

		var restored := GameState.new()
		assert_eq(restored.load_payload(state.save_payload()), [])
		assert_eq(restored.get_phase(), mission["phase_id"])
		assert_eq(restored.get_quest_state(quest_id), &"direct_complete")
		assert_true(restored.get_flag(mission["phase_flag"]))
		assert_true(restored.has_faction_event(mission["event_id"]))


func _state_for_phase(
	phase_id: StringName, boundary_flag: StringName = HostScript.FLAG_BOUNDARY_OPEN
) -> GameState:
	var state := GameState.new()
	state.set_phase(phase_id)
	state.set_flag(boundary_flag, true)
	return state

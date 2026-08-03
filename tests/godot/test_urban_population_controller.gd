extends "res://tests/godot/test_case.gd"

const ProfileScript := preload("res://scripts/world/urban_population_profile.gd")

const PHASE_DAY := GameState.PHASE_INVESTIGATION_MORNING
const PHASE_NIGHT := GameState.PHASE_INVESTIGATION_NIGHT
const DATE_OFF_DAY := {"day": 22, "month": 4, "year": 1343}
const DATE_MARKET_DAY := {"day": 24, "month": 4, "year": 1343}


func test_all_four_profiles_are_constructible_from_explicit_inputs() -> void:
	var profiles := [
		ProfileScript.day(PHASE_DAY, DATE_OFF_DAY, 1343),
		ProfileScript.night(PHASE_NIGHT, DATE_OFF_DAY, 1343),
		ProfileScript.market_day(PHASE_DAY, DATE_MARKET_DAY, 1343),
		ProfileScript.crackdown(PHASE_DAY, DATE_OFF_DAY, 1343),
	]
	assert_eq(profiles.size(), 4)
	assert_eq(profiles[0].get("profile_id"), ProfileScript.PROFILE_DAY)
	assert_eq(profiles[1].get("profile_id"), ProfileScript.PROFILE_NIGHT)
	assert_eq(profiles[2].get("profile_id"), ProfileScript.PROFILE_MARKET_DAY)
	assert_eq(profiles[3].get("profile_id"), ProfileScript.PROFILE_CRACKDOWN)
	assert_eq(ProfileScript.PROFILE_TENSE, ProfileScript.PROFILE_CRACKDOWN)
	for profile: Dictionary in profiles:
		assert_false(profile.get("phase_id", &"").is_empty())
		assert_eq(profile.get("date"), DATE_OFF_DAY if profile.get("profile_id") != ProfileScript.PROFILE_MARKET_DAY else DATE_MARKET_DAY)
		assert_true(int(profile.get("total_count", 0)) <= int(profile.get("actor_cap", 0)))


func test_market_day_has_more_civilians_than_off_day() -> void:
	var off_day := ProfileScript.day(PHASE_DAY, DATE_OFF_DAY, 1343)
	var market_day := ProfileScript.market_day(PHASE_DAY, DATE_MARKET_DAY, 1343)
	assert_false(bool(off_day.get("calendar_market_day")))
	assert_true(bool(market_day.get("calendar_market_day")))
	assert_true(
		int(market_day.get("civilian_count", 0)) > int(off_day.get("civilian_count", 0)),
		"Market-day civilian count must exceed the ordinary day count"
	)
	assert_eq(market_day.get("occupation_mix", {}).get(&"merchant"), 10)
	assert_array_contains(market_day.get("zone_ids", []), ProfileScript.ZONE_MARKET)
	assert_eq(market_day.get("movement_mode"), ProfileScript.MOVEMENT_ROUTE_BETWEEN_ZONES)


func test_night_reduces_civilians_and_increases_watch() -> void:
	var day := ProfileScript.day(PHASE_DAY, DATE_OFF_DAY, 1343)
	var night := ProfileScript.night(PHASE_NIGHT, DATE_OFF_DAY, 1343)
	assert_true(int(night.get("civilian_count", 0)) < int(day.get("civilian_count", 0)))
	assert_true(int(night.get("watch_count", 0)) > int(day.get("watch_count", 0)))
	assert_eq(night.get("phase_time_band"), &"night")
	assert_eq(night.get("watch_policy"), &"curfew_watch")
	assert_eq(night.get("anchor_mode"), ProfileScript.ANCHOR_AUTHORED)
	assert_eq(night.get("movement_mode"), ProfileScript.MOVEMENT_RETURN_TO_ANCHOR)


func test_crackdown_reduces_civilians_and_increases_watch_explicitly() -> void:
	var day := ProfileScript.day(PHASE_DAY, DATE_OFF_DAY, 1343)
	var crackdown := ProfileScript.crackdown(PHASE_DAY, DATE_OFF_DAY, 1343)
	assert_true(int(crackdown.get("civilian_count", 0)) < int(day.get("civilian_count", 0)))
	assert_true(int(crackdown.get("watch_count", 0)) > int(day.get("watch_count", 0)))
	assert_eq(crackdown.get("watch_policy"), &"reinforced_crackdown_watch")
	assert_eq(crackdown.get("civilian_policy"), &"reduced_visible_civilians")
	assert_array_contains(crackdown.get("zone_ids", []), ProfileScript.ZONE_CHECKPOINT)
	assert_eq(crackdown.get("movement_mode"), ProfileScript.MOVEMENT_CAUTIOUS)


func test_profiles_expose_occupation_zone_and_authored_cap_rules() -> void:
	var snapshot := ProfileScript.day(PHASE_DAY, DATE_OFF_DAY, 77)
	var occupation_mix: Dictionary = snapshot["occupation_mix"]
	var actor_plan: Array[Dictionary] = snapshot["actor_plan"]
	assert_eq(occupation_mix.get(&"merchant"), 4)
	assert_eq(occupation_mix.get(&"artisan"), 5)
	assert_eq(occupation_mix.get(&"laborer"), 5)
	assert_eq(occupation_mix.get(&"resident"), 4)
	var civilian_occupation_total := 0
	for occupation in occupation_mix.values():
		civilian_occupation_total += int(occupation)
	assert_eq(civilian_occupation_total, snapshot["civilian_count"])
	assert_eq(actor_plan.size(), snapshot["total_count"])
	for actor in actor_plan:
		assert_array_contains(snapshot["zone_ids"], actor["zone_id"])
		assert_eq(actor["movement_mode"], snapshot["movement_mode"])
		assert_eq(actor["anchor_mode"], snapshot["anchor_mode"])
	assert_true(int(snapshot["civilian_count"]) <= int(snapshot["civilian_cap"]))
	assert_true(int(snapshot["watch_count"]) <= int(snapshot["watch_cap"]))
	assert_eq(snapshot["rules"]["watch_vs_civilian"], &"routine_watch")


func test_seed_replays_identical_profile_without_game_state_mutation() -> void:
	var first := ProfileScript.market_day(PHASE_DAY, DATE_MARKET_DAY, 2024)
	var second := ProfileScript.market_day(PHASE_DAY, DATE_MARKET_DAY, 2024)
	assert_eq(first, second)
	assert_eq(first["replay_inputs"]["seed"], 2024)
	assert_eq(first["replay_inputs"]["phase_id"], PHASE_DAY)
	assert_eq(first["replay_inputs"]["date"], DATE_MARKET_DAY)
	assert_false("GameState" in first)
	assert_false("state" in first)

	var changed_seed := ProfileScript.market_day(PHASE_DAY, DATE_MARKET_DAY, 2025)
	assert_ne(first["actor_plan"], changed_seed["actor_plan"], "Seed should change assignment order")
	assert_eq(first["civilian_count"], changed_seed["civilian_count"])
	assert_eq(first["watch_count"], changed_seed["watch_count"])


func test_unknown_profile_falls_back_to_day_without_side_effects() -> void:
	var snapshot := ProfileScript.resolve(&"not_a_profile", PHASE_DAY, DATE_OFF_DAY, 1343)
	assert_eq(snapshot.get("profile_id"), ProfileScript.PROFILE_DAY)
	assert_eq(snapshot.get("civilian_count"), 18)

extends "res://tests/godot/test_case.gd"

const ProfileScript := preload("res://scripts/world/urban_population_profile.gd")
const CrowdRenderer := preload("res://scripts/map/view3d/map_view_crowd_renderer.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")
const UrbanPopulationMapBinding := preload("res://scripts/world/urban_population_map_binding.gd")
const LowerTownSliceDefinition := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")

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


func test_actor_plan_adapter_exposes_stable_renderer_agnostic_records() -> void:
	var profile := ProfileScript.market_day(PHASE_DAY, DATE_MARKET_DAY, 2024)
	var records: Array[Dictionary] = ProfileScript.actor_records(profile)
	assert_eq(records, profile["actor_plan"])
	assert_eq(records.size(), profile["total_count"])
	var expected_ids: Array[StringName] = []
	for index in records.size():
		var record: Dictionary = records[index]
		expected_ids.append(StringName("crowd.market_day.%03d" % index))
		assert_eq(record["actor_id"], expected_ids[index])
		assert_eq(record["actor_index"], index)
		assert_eq(record["replay_seed"], 2024)
		for field: StringName in [
			&"role",
			&"occupation",
			&"zone_id",
			&"movement_mode",
			&"anchor_mode",
		]:
			assert_true(record.has(field), "actor record must expose %s" % String(field))
			assert_false(String(record[field]).is_empty(), "actor record field %s must be non-empty" % String(field))
	assert_eq(records, ProfileScript.actor_records(profile), "same resolved profile must replay identical records")
	var changed_seed := ProfileScript.actor_records(ProfileScript.market_day(PHASE_DAY, DATE_MARKET_DAY, 2025))
	assert_ne(records, changed_seed, "seed must affect deterministic assignment records")
	assert_eq(records[0]["actor_id"], changed_seed[0]["actor_id"], "identity must not depend on replay seed")
	assert_eq(changed_seed[0]["replay_seed"], 2025)


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


func test_context_resolver_selects_four_profiles_from_phase_date_and_overlays() -> void:
	var day := ProfileScript.resolve_for_context(PHASE_DAY, DATE_OFF_DAY, 1343)
	var market_day := ProfileScript.resolve_for_context(PHASE_DAY, DATE_MARKET_DAY, 1343)
	var night := ProfileScript.resolve_for_context(PHASE_NIGHT, DATE_OFF_DAY, 1343)
	var crackdown := ProfileScript.resolve_for_context(
		PHASE_DAY,
		DATE_OFF_DAY,
		1343,
		{"crackdown": true}
	)

	assert_eq(day["profile_id"], ProfileScript.PROFILE_DAY)
	assert_eq(market_day["profile_id"], ProfileScript.PROFILE_MARKET_DAY)
	assert_eq(night["profile_id"], ProfileScript.PROFILE_NIGHT)
	assert_eq(crackdown["profile_id"], ProfileScript.PROFILE_CRACKDOWN)
	assert_eq(day["replay_inputs"]["phase_id"], PHASE_DAY)
	assert_eq(market_day["replay_inputs"]["date"], DATE_MARKET_DAY)
	assert_eq(night["replay_inputs"]["seed"], 1343)
	for profile: Dictionary in [day, market_day, night, crackdown]:
		assert_false(profile.has("GameState"))
		assert_false(profile.has("state"))
		assert_eq(profile["actor_plan"].size(), profile["total_count"])


func test_context_resolver_precedence_keeps_overlays_deterministic() -> void:
	var tense_night := ProfileScript.resolve_for_context(
		PHASE_NIGHT,
		DATE_MARKET_DAY,
		7,
		{"market_day": true, "tense": true}
	)
	var explicit_night := ProfileScript.resolve_for_context(
		PHASE_DAY,
		DATE_MARKET_DAY,
		7,
		{"time_band": "night", "market_day": true}
	)
	var unknown_band := ProfileScript.resolve_for_context(
		PHASE_DAY,
		DATE_OFF_DAY,
		7,
		{"time_band": "twilight"}
	)

	assert_eq(tense_night["profile_id"], ProfileScript.PROFILE_CRACKDOWN)
	assert_eq(explicit_night["profile_id"], ProfileScript.PROFILE_NIGHT)
	assert_eq(unknown_band["profile_id"], ProfileScript.PROFILE_DAY)
	assert_eq(
		unknown_band,
		ProfileScript.resolve_for_context(PHASE_DAY, DATE_OFF_DAY, 7, {"time_band": "twilight"}),
		"unknown context inputs must use a stable safe fallback"
	)


func test_context_resolver_replays_same_inputs_without_game_state_writes() -> void:
	var first := ProfileScript.resolve_for_context(
		PHASE_DAY,
		DATE_MARKET_DAY,
		2024,
		{"market_day": true}
	)
	var second := ProfileScript.resolve_for_context(
		PHASE_DAY,
		DATE_MARKET_DAY,
		2024,
		{"market_day": true}
	)

	assert_eq(first, second)
	assert_eq(first["replay_inputs"]["profile_id"], ProfileScript.PROFILE_MARKET_DAY)
	assert_eq(first["replay_inputs"]["seed"], 2024)
	assert_false(first.has("GameState"))
	assert_false(first.has("state"))


func test_authored_lower_town_clusters_feed_all_four_profiles() -> void:
	var first_map: MapDefinition = LowerTownSliceDefinition.create()
	var second_map: MapDefinition = LowerTownSliceDefinition.create()
	var first_clusters := _lower_town_population_clusters(first_map)
	var second_clusters := _lower_town_population_clusters(second_map)
	var grid := MapBuilder.build(first_map)

	assert_eq(first_clusters, second_clusters, "authored cluster IDs and anchors must be stable across parses")
	assert_eq(first_clusters.size(), 3, "Lower Town must expose worker, merchant, and watch clusters")
	for cluster: Dictionary in first_clusters:
		assert_false(String(cluster["cluster_id"]).is_empty())
		assert_false((cluster["zone_ids"] as Array).is_empty())
		assert_false((cluster["anchor_ids"] as Array).is_empty())
		for anchor_id: StringName in cluster["anchor_ids"]:
			assert_true(MapVerification.has_anchor(first_map, anchor_id), "missing authored cluster anchor %s" % String(anchor_id))
			var anchor_position := MapVerification.anchor_position(first_map, anchor_id)
			assert_true(MapVerification.is_walkable_point(first_map, grid, anchor_position),
				"cluster anchor %s must remain walkable" % String(anchor_id))

	var profiles: Array[Dictionary] = [
		ProfileScript.day(PHASE_DAY, DATE_OFF_DAY, 434),
		ProfileScript.market_day(PHASE_DAY, DATE_MARKET_DAY, 434),
		ProfileScript.night(PHASE_NIGHT, DATE_OFF_DAY, 434),
		ProfileScript.crackdown(PHASE_DAY, DATE_OFF_DAY, 434),
	]
	for profile: Dictionary in profiles:
		var consumed_clusters := _clusters_consumed_by_profile(profile, first_clusters)
		assert_true(consumed_clusters.size() >= 1,
			"profile %s must consume an authored readable cluster" % String(profile["profile_id"]))
		for zone_id: StringName in profile["zone_ids"]:
			assert_true(_cluster_has_zone(first_clusters, zone_id),
				"profile %s zone %s must be backed by an authored cluster" % [String(profile["profile_id"]), String(zone_id)])
		assert_true(_profile_has_occupation(profile, &"laborer") or _profile_has_occupation(profile, &"artisan"),
			"profile %s must feed worker/carrier activity" % String(profile["profile_id"]))
		assert_true(_profile_has_occupation(profile, &"merchant") or profile["profile_id"] == ProfileScript.PROFILE_NIGHT,
			"profile %s must feed merchant/customer activity or explicitly shelter at night" % String(profile["profile_id"]))
		assert_true(_profile_has_role(profile, &"watch"),
			"profile %s must feed watch/checkpoint activity" % String(profile["profile_id"]))
		var actor_cluster_ids := _actor_plan_cluster_ids(profile, first_clusters)
		assert_eq(actor_cluster_ids.size(), (profile["actor_plan"] as Array).size(),
			"profile %s must map every actor plan record to an authored cluster" % String(profile["profile_id"]))
		assert_eq(_actor_plan_cluster_ids(profile, first_clusters), _actor_plan_cluster_ids(profile, second_clusters),
			"profile %s cluster assignment must be stable across map parses" % String(profile["profile_id"]))
		var replay_profile := ProfileScript.resolve(
			profile["profile_id"],
			profile["phase_id"],
			profile["date"],
			profile["seed"],
		)
		assert_eq(profile["actor_plan"], replay_profile["actor_plan"],
			"profile %s actor plan must replay from equal inputs" % String(profile["profile_id"]))
		assert_eq(actor_cluster_ids, _actor_plan_cluster_ids(replay_profile, second_clusters),
			"profile %s actor cluster assignment must replay from equal inputs" % String(profile["profile_id"]))

	var all_consumed_clusters: Array[StringName] = []
	for profile: Dictionary in profiles:
		for cluster_id: StringName in _clusters_consumed_by_profile(profile, first_clusters):
			if not all_consumed_clusters.has(cluster_id):
				all_consumed_clusters.append(cluster_id)
	assert_eq(all_consumed_clusters.size(), 3, "the four profiles must collectively consume all readable clusters")


func test_lower_town_cluster_roles_cover_workers_merchants_and_watch() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var clusters := _lower_town_population_clusters(definition)
	var cluster_by_id := {}
	for cluster: Dictionary in clusters:
		cluster_by_id[cluster["cluster_id"]] = cluster

	assert_true(cluster_by_id.has(&"workers_carriers"))
	assert_true(cluster_by_id.has(&"merchants_customers"))
	assert_true(cluster_by_id.has(&"watch_checkpoint"))
	assert_array_contains(cluster_by_id[&"workers_carriers"]["anchor_ids"], &"workers_yard")
	assert_array_contains(cluster_by_id[&"workers_carriers"]["anchor_ids"], &"carriers_lane")
	assert_array_contains(cluster_by_id[&"merchants_customers"]["anchor_ids"], &"merchants_market")
	assert_array_contains(cluster_by_id[&"watch_checkpoint"]["anchor_ids"], &"watch_west_checkpoint")
	assert_array_contains(cluster_by_id[&"watch_checkpoint"]["anchor_ids"], &"watch_east_checkpoint")
	assert_array_contains(cluster_by_id[&"workers_carriers"]["zone_ids"], ProfileScript.ZONE_WORK_YARD)
	assert_array_contains(cluster_by_id[&"merchants_customers"]["zone_ids"], ProfileScript.ZONE_MARKET)
	assert_array_contains(cluster_by_id[&"watch_checkpoint"]["zone_ids"], ProfileScript.ZONE_CHECKPOINT)


func test_lower_town_binding_snapshot_and_profile_records_are_complete() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var grid := MapBuilder.build(definition)
	var lookup := UrbanPopulationMapBinding.build_lookup(definition, grid)

	assert_eq(lookup["map_id"], &"lower_town_slice")
	assert_eq(lookup["clusters"], UrbanPopulationMapBinding.lookup(definition, grid))
	assert_eq((lookup["clusters_by_id"] as Dictionary).keys().size(), 3)
	for cluster_id: StringName in [
		UrbanPopulationMapBinding.CLUSTER_WORKERS,
		UrbanPopulationMapBinding.CLUSTER_MERCHANTS,
		UrbanPopulationMapBinding.CLUSTER_WATCH,
	]:
		assert_true((lookup["clusters_by_id"] as Dictionary).has(cluster_id))
	var expected_zone_bindings := {
		ProfileScript.ZONE_WORK_YARD: {
			"cluster_ids": [UrbanPopulationMapBinding.CLUSTER_WORKERS],
			"anchor_ids":
			[&"workers_yard", &"carriers_lane", &"smithy_door", &"brewery_door", &"street_start"],
		},
		ProfileScript.ZONE_RESIDENTIAL: {
			"cluster_ids": [UrbanPopulationMapBinding.CLUSTER_WORKERS],
			"anchor_ids":
			[&"workers_yard", &"carriers_lane", &"smithy_door", &"brewery_door", &"street_start"],
		},
		ProfileScript.ZONE_MARKET: {
			"cluster_ids": [UrbanPopulationMapBinding.CLUSTER_MERCHANTS],
			"anchor_ids": [&"merchants_market", &"customers_street", &"mart_street", &"street_start"],
		},
		ProfileScript.ZONE_STREET: {
			"cluster_ids": [
				UrbanPopulationMapBinding.CLUSTER_MERCHANTS,
				UrbanPopulationMapBinding.CLUSTER_WATCH,
			],
			"anchor_ids": [
				&"merchants_market", &"customers_street", &"mart_street", &"street_start",
				&"watch_west_checkpoint", &"watch_east_checkpoint", &"checkpoint_west", &"checkpoint_east",
			],
		},
		ProfileScript.ZONE_CHECKPOINT: {
			"cluster_ids": [UrbanPopulationMapBinding.CLUSTER_WATCH],
			"anchor_ids": [
				&"watch_west_checkpoint", &"watch_east_checkpoint", &"checkpoint_west", &"checkpoint_east",
			],
		},
		ProfileScript.ZONE_SAFE_INTERIOR: {
			"cluster_ids": [UrbanPopulationMapBinding.CLUSTER_WATCH],
			"anchor_ids": [
				&"watch_west_checkpoint", &"watch_east_checkpoint", &"checkpoint_west", &"checkpoint_east",
			],
		},
	}
	var zones_by_id: Dictionary = lookup["zones_by_id"]
	assert_eq(zones_by_id.keys().size(), expected_zone_bindings.keys().size())
	for zone_id: StringName in expected_zone_bindings:
		assert_true(zones_by_id.has(zone_id), "missing runtime population zone %s" % String(zone_id))
		var zone_record: Dictionary = zones_by_id[zone_id]
		assert_eq(zone_record["zone_id"], zone_id)
		assert_eq(zone_record["cluster_ids"], expected_zone_bindings[zone_id]["cluster_ids"])
		assert_eq(zone_record["anchor_ids"], expected_zone_bindings[zone_id]["anchor_ids"])
		for anchor_id: StringName in zone_record["anchor_ids"]:
			assert_true((lookup["anchors_by_id"] as Dictionary).has(anchor_id))
	var mutated_zone: Dictionary = (lookup["zones_by_id"] as Dictionary)[ProfileScript.ZONE_WORK_YARD]
	(mutated_zone["anchor_ids"] as Array).clear()
	var fresh_lookup := UrbanPopulationMapBinding.build_lookup(definition, grid)
	assert_eq(
		(fresh_lookup["zones_by_id"] as Dictionary)[ProfileScript.ZONE_WORK_YARD]["anchor_ids"],
		expected_zone_bindings[ProfileScript.ZONE_WORK_YARD]["anchor_ids"],
		"mutating a returned lookup must not change the next runtime snapshot"
	)
	var expected_activity_anchors := {
		&"workers_yard": &"workers_yard",
		&"carriers_lane": &"carriers_lane",
		&"merchants_market": &"merchants_market",
		&"customers_street": &"customers_street",
		&"watch_west_checkpoint": &"watch_checkpoint",
		&"watch_east_checkpoint": &"watch_checkpoint",
	}
	for anchor_id: StringName in expected_activity_anchors:
		assert_true((lookup["anchors_by_id"] as Dictionary).has(anchor_id))
		var authored_anchor: Dictionary = definition.interaction_anchors.filter(
			func(candidate: Dictionary) -> bool: return candidate.get("id", &"") == anchor_id
		)[0]
		var anchor_record: Dictionary = lookup["anchors_by_id"][anchor_id]
		assert_eq(authored_anchor.get("kind", &""), expected_activity_anchors[anchor_id])
		assert_eq(anchor_record["anchor_id"], anchor_id)
		assert_eq(anchor_record["anchor_kind"], expected_activity_anchors[anchor_id])
		assert_eq(anchor_record["anchor_position"], MapVerification.anchor_position(definition, anchor_id))
		assert_true(MapVerification.is_walkable_point(definition, grid, anchor_record["anchor_position"]))

	var profile := ProfileScript.market_day(PHASE_DAY, DATE_MARKET_DAY, 434)
	var records := UrbanPopulationMapBinding.bind_profile(profile, definition, grid)
	assert_eq(records.size(), (profile["actor_plan"] as Array).size())
	for record: Dictionary in records:
		assert_false(String(record["cluster_id"]).is_empty())
		assert_false(String(record["anchor_id"]).is_empty())
		assert_eq(record["anchor_position"], MapVerification.anchor_position(definition, record["anchor_id"]))


func test_binding_maps_every_actor_in_each_profile_to_an_authored_zone_and_anchor() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var grid := MapBuilder.build(definition)
	var lookup := UrbanPopulationMapBinding.build_lookup(definition, grid)
	var zones_by_id: Dictionary = lookup["zones_by_id"]
	var profiles: Array[Dictionary] = [
		ProfileScript.day(PHASE_DAY, DATE_OFF_DAY, 434),
		ProfileScript.market_day(PHASE_DAY, DATE_MARKET_DAY, 434),
		ProfileScript.night(PHASE_NIGHT, DATE_OFF_DAY, 434),
		ProfileScript.crackdown(PHASE_DAY, DATE_OFF_DAY, 434),
	]

	for profile: Dictionary in profiles:
		var profile_id := String(profile["profile_id"])
		var records := UrbanPopulationMapBinding.bind_profile(profile, definition, grid)
		assert_eq(records.size(), (profile["actor_plan"] as Array).size(),
			"profile %s must bind every actor" % profile_id)
		for record: Dictionary in records:
			var zone_id: StringName = record["zone_id"]
			var cluster_id: StringName = record["cluster_id"]
			var anchor_id: StringName = record["anchor_id"]
			assert_true(zones_by_id.has(zone_id),
				"profile %s actor zone must be authored: %s" % [profile_id, String(zone_id)])
			var zone_record: Dictionary = zones_by_id[zone_id]
			assert_array_contains(zone_record["cluster_ids"], cluster_id)
			assert_array_contains(zone_record["anchor_ids"], anchor_id)
			assert_eq(record["anchor_position"], MapVerification.anchor_position(definition, anchor_id))


func test_population_binding_fails_closed_for_unknown_map_and_ids() -> void:
	var definition := MapDefinition.new()
	definition.map_id = &"not_lower_town"
	var unknown_lookup := UrbanPopulationMapBinding.build_lookup(definition)
	assert_true((unknown_lookup["clusters"] as Array).is_empty())
	assert_true((unknown_lookup["zones_by_id"] as Dictionary).is_empty())
	assert_true((unknown_lookup["anchors_by_id"] as Dictionary).is_empty())
	assert_true(UrbanPopulationMapBinding.clusters_for_map(definition).is_empty())
	assert_true(UrbanPopulationMapBinding.anchor_ids_for_cluster(&"missing_cluster", []).is_empty())
	assert_eq(UrbanPopulationMapBinding.cluster_id_for_actor({"zone_id": &"missing_zone"}, []), &"")
	assert_true(UrbanPopulationMapBinding.bind_profile({"actor_plan": [{"actor_index": 0, "zone_id": &"missing_zone"}]}, definition).is_empty())


func _lower_town_population_clusters(definition: MapDefinition) -> Array[Dictionary]:
	return UrbanPopulationMapBinding.clusters_for_map(definition)


func _clusters_consumed_by_profile(profile: Dictionary, clusters: Array[Dictionary]) -> Array[StringName]:
	var consumed: Array[StringName] = []
	var profile_zones: Array = profile["zone_ids"]
	for cluster: Dictionary in clusters:
		for zone_id: StringName in cluster["zone_ids"]:
			if profile_zones.has(zone_id):
				consumed.append(cluster["cluster_id"])
				break
	return consumed


func _cluster_has_zone(clusters: Array[Dictionary], zone_id: StringName) -> bool:
	for cluster: Dictionary in clusters:
		if (cluster["zone_ids"] as Array).has(zone_id):
			return true
	return false


func _profile_has_occupation(profile: Dictionary, occupation: StringName) -> bool:
	return int((profile["occupation_mix"] as Dictionary).get(occupation, 0)) > 0


func _profile_has_role(profile: Dictionary, role: StringName) -> bool:
	for actor: Dictionary in profile["actor_plan"]:
		if actor["role"] == role:
			return true
	return false


func _actor_plan_cluster_ids(profile: Dictionary, clusters: Array[Dictionary]) -> Array[StringName]:
	var result: Array[StringName] = []
	for actor: Dictionary in profile["actor_plan"]:
		for cluster: Dictionary in clusters:
			if cluster["zone_ids"].has(actor["zone_id"]):
				result.append(cluster["cluster_id"])
				break
	return result


func test_seeded_placement_fixture_replays_identical_actor_ids_and_positions() -> void:
	var profile := ProfileScript.market_day(PHASE_DAY, DATE_MARKET_DAY, 2024)
	var first := _build_placement_fixture(profile, 10)
	var second := _build_placement_fixture(profile, 10)
	assert_eq(first, second, "equal profile inputs must reproduce crowd IDs and positions")
	assert_eq(first.size(), 10)
	for placement: Dictionary in first:
		assert_true(placement.has("actor_id"))
		assert_true(placement.has("position"))
		assert_false(String(placement["actor_id"]).is_empty())


func test_placement_fixture_is_authored_walkable_and_clear_of_buildings_props() -> void:
	var profile := ProfileScript.day(PHASE_DAY, DATE_OFF_DAY, 2024)
	var placements := _build_placement_fixture(profile, 8)
	var map_fixture := _build_map_fixture()
	var definition: MapDefinition = map_fixture["definition"]
	var grid: MapTerrainGrid = map_fixture["grid"]
	var allowed_zones := {
		&"street_frontage": Rect2(32.0, 32.0, 160.0, 96.0),
		&"work_yard": Rect2(256.0, 32.0, 192.0, 96.0),
		&"residential_yard": Rect2(480.0, 32.0, 160.0, 96.0),
	}
	var prop_position := MapVerification.prop_position(definition, &"yard_barrel")
	assert_false(
		MapVerification.is_walkable_point(definition, grid, Vector2(336.0, 80.0)),
		"building footprint must reject crowd placement cells"
	)

	for placement: Dictionary in placements:
		var position: Vector2 = placement["position"]
		var zone_id: StringName = placement["zone_id"]
		assert_true(allowed_zones.has(zone_id), "placement must use an authored active zone")
		assert_true((allowed_zones[zone_id] as Rect2).has_point(position), "placement must stay inside its authored zone")
		assert_true(MapVerification.is_walkable_point(definition, grid, position), "placement must stay on a walkable cell")
		assert_false(position.distance_to(prop_position) < 24.0, "placement must keep clearance from authored prop collision")


func test_invalid_points_are_rejected_and_valid_points_are_capped_by_renderer_capacity() -> void:
	var profile := ProfileScript.day(PHASE_DAY, DATE_OFF_DAY, 2024)
	var placements := _build_placement_fixture(profile, 64)
	var renderer := CrowdRenderer.new()
	renderer.configure(3, 2024)

	var accepted := 0
	for placement: Dictionary in placements:
		if not _is_valid_placement(placement):
			continue
		accepted += 1
		renderer.set_actor_position(accepted, Vector3(placement["position"].x, 0.0, placement["position"].y))

	assert_true(accepted > renderer.capacity(), "fixture must exercise renderer overflow")
	assert_eq(renderer.capacity(), 3, "renderer capacity must remain the authored cap")
	assert_true(renderer.active_count() >= accepted, "logical placement registration must not silently drop valid actors")
	assert_false(_is_valid_placement({"actor_id": "crowd.invalid", "zone_id": &"not_authored", "position": Vector2(-1.0, -1.0)}),
		"invalid zone and out-of-bounds point must be rejected")
	renderer.queue_free()


func test_named_and_interactable_npcs_are_excluded_from_generated_crowd_set() -> void:
	var profile := ProfileScript.day(PHASE_DAY, DATE_OFF_DAY, 2024)
	var named_ids := {&"crowd.day.005": true, &"char.mart": true, &"interact.cistern": true}
	var generated := _build_placement_fixture(profile, 32, named_ids)

	assert_eq(generated.size(), 31, "reserved named actor must reduce generated crowd count")
	for placement: Dictionary in generated:
		assert_false(named_ids.has(StringName(placement["actor_id"])),
			"named/interactable actors must not be generated crowd members")


func test_all_profiles_keep_crowd_clear_of_gameplay_reserved_spaces() -> void:
	var profiles: Array[Dictionary] = [
		ProfileScript.day(PHASE_DAY, DATE_OFF_DAY, 2024),
		ProfileScript.market_day(PHASE_DAY, DATE_MARKET_DAY, 2024),
		ProfileScript.night(PHASE_NIGHT, DATE_OFF_DAY, 2024),
		ProfileScript.crackdown(PHASE_DAY, DATE_OFF_DAY, 2024),
	]
	for profile: Dictionary in profiles:
		var profile_id := StringName(profile["profile_id"])
		var requested_count := int(profile["total_count"])
		var first := _build_placement_fixture(profile, requested_count)
		var second := _build_placement_fixture(profile, requested_count)
		assert_eq(first, second, "profile %s placement must be deterministic" % String(profile_id))
		assert_eq(first.size(), requested_count, "profile %s must produce its complete plan" % String(profile_id))
		for placement: Dictionary in first:
			var violation := _gameplay_reserved_space_violation(placement)
			assert_eq(
				violation,
				&"",
				"profile %s actor %s violates %s reserve" % [
					String(profile_id),
					String(placement["actor_id"]),
					String(violation),
				]
			)
			assert_true(
				_is_valid_placement(placement),
				"profile %s actor %s must pass the complete placement safety gate" % [
					String(profile_id),
					String(placement["actor_id"]),
				]
			)


func test_reserved_space_diagnostics_identify_each_gameplay_category() -> void:
	for reserved: Dictionary in _fixture_gameplay_reserved_spaces():
		var bounds: Rect2 = reserved["bounds"]
		var placement := {
			"actor_id": "crowd.reserve.%s" % String(reserved["category"]),
			"zone_id": reserved["zone_id"],
			"position": bounds.get_center(),
		}
		assert_eq(
			_gameplay_reserved_space_violation(placement),
			reserved["category"],
			"diagnostic must identify %s" % String(reserved["category"]),
		)
		assert_false(
			_is_valid_placement(placement),
			"placement validation must reject %s" % String(reserved["category"]),
		)


func _fixture_gameplay_reserved_spaces() -> Array[Dictionary]:
	return [
		{
			"category": &"player_spawn",
			"zone_id": &"street_frontage",
			"bounds": Rect2(128.0, 80.0, 32.0, 32.0),
		},
		{
			"category": &"transition",
			"zone_id": &"market_lane",
			"bounds": Rect2(160.0, 192.0, 32.0, 32.0),
		},
		{
			"category": &"building_entrance",
			"zone_id": &"work_yard",
			"bounds": Rect2(400.0, 80.0, 32.0, 32.0),
		},
		{
			"category": &"interaction_prompt",
			"zone_id": &"residential_yard",
			"bounds": Rect2(592.0, 80.0, 32.0, 32.0),
		},
		{
			"category": &"patrol_route",
			"zone_id": &"checkpoint",
			"bounds": Rect2(816.0, 80.0, 32.0, 32.0),
		},
	]


func _gameplay_reserved_space_violation(placement: Dictionary) -> StringName:
	var position: Vector2 = placement.get("position", Vector2(-1.0, -1.0))
	for reserved: Dictionary in _fixture_gameplay_reserved_spaces():
		var bounds: Rect2 = reserved["bounds"]
		if bounds.grow(24.0).has_point(position):
			return StringName(reserved["category"])
	return &""


func _build_placement_fixture(profile: Dictionary, requested_count: int, excluded_ids: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var zones: Array[StringName] = profile["zone_ids"]
	var seed := int(profile["seed"])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for index in requested_count:
		var actor_id := StringName("crowd.%s.%03d" % [String(profile["profile_id"]), index])
		if excluded_ids.has(actor_id):
			continue
		var zone_id: StringName = zones[index % zones.size()]
		var zone := _fixture_zone_rect(zone_id)
		var placed := false
		for _attempt in 64:
			var position := Vector2(
				rng.randi_range(int(zone.position.x) + 4, int(zone.end.x) - 4),
				rng.randi_range(int(zone.position.y) + 4, int(zone.end.y) - 4),
			)
			var placement := {
				"actor_id": actor_id,
				"zone_id": zone_id,
				"position": position,
			}
			if not _is_valid_placement(placement):
				continue
			result.append(placement)
			placed = true
			break
		assert_true(placed, "fixture could not find a safe point in %s" % String(zone_id))
	return result


func _build_map_fixture() -> Dictionary:
	var definition := MapDefinition.new()
	definition.map_id = &"test_urban_population"
	definition.cell_size = 32
	definition.size_cells = Vector2i(32, 16)
	definition.base_terrain = MapTypes.TERRAIN_GRASS
	definition.player_spawn = Vector2(16.0, 16.0)
	definition.location = &"test"
	definition.scope = &"prototype"
	definition.palette = &"test"
	definition.fingerprint = "urban-population-test"
	definition.buildings.append({
		"id": &"test_building",
		"kind": MapTypes.BUILDING_KIND_HOUSE,
		"footprint": Rect2(10.0 * 32.0, 2.0 * 32.0, 2.0 * 32.0, 2.0 * 32.0),
	})
	definition.props.append({
		"id": &"yard_barrel",
		"kind": MapTypes.PROP_KIND_BARRELS,
		"position": Vector2(17.0 * 32.0, 3.0 * 32.0),
	})
	return {"definition": definition, "grid": MapBuilder.build(definition)}


func _fixture_zone_origin(zone_id: StringName) -> Vector2:
	match zone_id:
		&"street_frontage":
			return Vector2(32.0, 32.0)
		&"work_yard":
			return Vector2(256.0, 32.0)
		&"residential_yard":
			return Vector2(480.0, 32.0)
		&"market_lane":
			return Vector2(32.0, 160.0)
		&"checkpoint":
			return Vector2(704.0, 32.0)
		&"safe_interior":
			return Vector2(800.0, 32.0)
	return Vector2(-1000.0, -1000.0)


func _is_valid_placement(placement: Dictionary) -> bool:
	var actor_id := StringName(placement.get("actor_id", &""))
	var zone_id := StringName(placement.get("zone_id", &""))
	var position: Vector2 = placement.get("position", Vector2(-1.0, -1.0))
	if actor_id.is_empty() or not String(actor_id).begins_with("crowd."):
		return false
	var zone := _fixture_zone_rect(zone_id)
	if zone == Rect2() or not zone.has_point(position):
		return false
	var map_fixture := _build_map_fixture()
	var definition: MapDefinition = map_fixture["definition"]
	var grid: MapTerrainGrid = map_fixture["grid"]
	if not MapVerification.is_walkable_point(definition, grid, position):
		return false
	var prop_position := MapVerification.prop_position(definition, &"yard_barrel")
	if position.distance_to(prop_position) < 24.0:
		return false
	return _gameplay_reserved_space_violation({"position": position}) == &""


func _fixture_zone_rect(zone_id: StringName) -> Rect2:
	match zone_id:
		&"street_frontage":
			return Rect2(32.0, 32.0, 160.0, 96.0)
		&"work_yard":
			return Rect2(256.0, 32.0, 192.0, 96.0)
		&"residential_yard":
			return Rect2(480.0, 32.0, 160.0, 96.0)
		&"market_lane":
			return Rect2(32.0, 160.0, 192.0, 96.0)
		&"checkpoint":
			return Rect2(704.0, 32.0, 160.0, 96.0)
		&"safe_interior":
			return Rect2(800.0, 32.0, 160.0, 96.0)
	return Rect2()

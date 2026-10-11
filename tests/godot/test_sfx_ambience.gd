extends "res://tests/godot/test_case.gd"

## AmbienceController layer selection, crossfade, hour gating and the spot
## budget (ADR 0035 phase 2). Fixture entries keep the assertions independent of
## the shipped placeholder beds.

const AmbienceControllerScript := preload("res://scripts/audio/ambience_controller.gd")
const BED_ID := &"amb.test.bed"
const NIGHT_ID := &"amb.test.night"
const RAIN_ID := &"amb.test.rain"
const SPOT_ID := &"amb.test.spot"
const NOON := 0.5
const MIDNIGHT := 0.0


func _catalog() -> SfxCatalog:
	var entries: Array = []
	for id: StringName in [BED_ID, NIGHT_ID, RAIN_ID]:
		entries.append(
			{
				"id": String(id),
				"bus": "Ambience",
				"streams": ["res://sounds/weather/rain_roof.mp3"],
				"spatial": "none",
			}
		)
	entries.append(
		{
			"id": String(SPOT_ID),
			"bus": "Ambience",
			"streams": ["res://sounds/door.mp3"],
			"spatial": "3d",
			"max_voices": 8,
		}
	)
	var catalog := SfxCatalog.new()
	catalog.load_dictionary({"entries": entries})
	return catalog


func _install(profile: Dictionary) -> AmbienceController:
	var ambience: AmbienceController = AmbienceControllerScript.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(ambience)
	ambience.set_catalog(_catalog())
	ambience.configure(profile, 4242)
	return ambience


func test_bed_fades_in_and_reports_its_layer() -> void:
	var ambience := _install({"bed": [{"id": BED_ID}]})
	assert_eq(ambience.active_layer_ids().size(), 0, "nothing plays before the first sync")
	ambience.sync(0.1, Vector3.ZERO, NOON)
	assert_array_contains(ambience.active_layer_ids(), BED_ID)
	# One 0.1 s tick must not jump to full level: the bed crossfades in.
	var after_one_tick := ambience.layer_linear_volume(BED_ID)
	for i in 40:
		ambience.sync(0.1, Vector3.ZERO, NOON)
	assert_true(
		ambience.layer_linear_volume(BED_ID) > after_one_tick,
		"the bed must keep rising toward its target, not snap to it"
	)
	ambience.queue_free()


func test_hour_window_gates_a_layer() -> void:
	var ambience := _install({"mid": [{"id": NIGHT_ID, "hours": [21.0, 5.0]}]})
	ambience.sync(1.0, Vector3.ZERO, NOON)
	assert_eq(ambience.active_layer_ids().size(), 0, "a night layer stays silent at noon")
	ambience.sync(1.0, Vector3.ZERO, MIDNIGHT)
	assert_array_contains(
		ambience.active_layer_ids(), NIGHT_ID, "the wrapping 21-05 window must include midnight"
	)
	ambience.queue_free()


func test_entry_without_hours_plays_around_the_clock() -> void:
	assert_true(AmbienceControllerScript.entry_audible_at_hour({"id": BED_ID}, 3.0))
	assert_true(AmbienceControllerScript.entry_audible_at_hour({"hours": [6.0, 20.0]}, 6.0))
	assert_false(AmbienceControllerScript.entry_audible_at_hour({"hours": [6.0, 20.0]}, 20.0))
	assert_true(AmbienceControllerScript.entry_audible_at_hour({"hours": [22.0, 2.0]}, 23.0))
	assert_false(AmbienceControllerScript.entry_audible_at_hour({"hours": [22.0, 2.0]}, 12.0))


func test_weather_layer_follows_rain_and_roof_suppression() -> void:
	var ambience := _install({"weather": {"rain_exterior": RAIN_ID}})
	ambience.sync(1.0, Vector3.ZERO, NOON, 0.0, false)
	assert_eq(ambience.active_layer_ids().size(), 0, "dry weather stays silent")
	ambience.sync(1.0, Vector3.ZERO, NOON, 0.8, false)
	assert_array_contains(ambience.active_layer_ids(), RAIN_ID)
	var open_air := ambience.layer_linear_volume(RAIN_ID)
	assert_true(open_air > 0.0, "open-air rain must be audible")
	# Indoors the roof bed owns the sound, so the exterior overlay must retire.
	for i in 40:
		ambience.sync(0.5, Vector3.ZERO, NOON, 0.8, true)
	assert_eq(
		ambience.layer_linear_volume(RAIN_ID),
		0.0,
		"a roofed listener must not hear the exterior rain loop"
	)
	ambience.queue_free()


func test_spot_layer_respects_interval_and_budget() -> void:
	var ambience := _install(
		{
			"spot":
			[
				{"id": SPOT_ID, "min_interval": 1.0, "max_interval": 1.0},
				{"id": SPOT_ID, "min_interval": 1.0, "max_interval": 1.0},
				{"id": SPOT_ID, "min_interval": 1.0, "max_interval": 1.0},
			]
		}
	)
	ambience.sync(0.5, Vector3.ZERO, NOON)
	assert_eq(ambience.spot_play_count(), 0, "spots must wait out their first interval")
	ambience.sync(0.6, Vector3.ZERO, NOON)
	assert_eq(
		ambience.spot_play_count(),
		AmbienceControllerScript.MAX_CONCURRENT_SPOTS,
		"the soundscape budget caps simultaneous spot voices"
	)
	assert_eq(ambience.last_spot_id(), SPOT_ID)
	ambience.queue_free()


func test_disabled_and_empty_profiles_stay_silent() -> void:
	var ambience := _install({"bed": [{"id": BED_ID}]})
	ambience.sync(1.0, Vector3.ZERO, NOON)
	ambience.set_audio_enabled(false)
	ambience.sync(1.0, Vector3.ZERO, NOON)
	assert_eq(ambience.layer_linear_volume(BED_ID), 0.0, "muting stops the bed")
	ambience.queue_free()

	var parked := _install({})
	parked.sync(1.0, Vector3.ZERO, NOON, 1.0, false)
	assert_eq(parked.active_layer_ids().size(), 0, "a map without a profile plays nothing")
	parked.queue_free()


func test_unknown_ids_are_skipped_without_crashing() -> void:
	var ambience := _install({"bed": [{"id": &"amb.nope.missing"}], "spot": [{"id": &"amb.nope"}]})
	for i in 5:
		ambience.sync(1.0, Vector3.ZERO, NOON)
	assert_eq(ambience.active_layer_ids().size(), 0)
	assert_eq(ambience.spot_play_count(), 0)
	ambience.queue_free()

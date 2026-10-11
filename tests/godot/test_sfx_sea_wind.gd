extends "res://tests/godot/test_case.gd"

## R-1550: sea surf and wind layers of AmbienceController. The tier mix follows
## wind strength, surf follows distance to the sea, interiors mute both. Fixture
## catalog entries keep the assertions independent of the shipped recordings.

const AmbienceControllerScript := preload("res://scripts/audio/ambience_controller.gd")
const AmbienceProfilesScript := preload("res://scripts/audio/ambience_profiles.gd")
const SEA := {
	"calm": &"amb.test.sea_calm", "moderate": &"amb.test.sea_mid", "storm": &"amb.test.sea_storm"
}
const WIND := {
	"light": &"amb.test.wind_light",
	"strong": &"amb.test.wind_strong",
	"storm": &"amb.test.wind_storm",
}
const NOON := 0.5


func _catalog() -> SfxCatalog:
	var entries: Array = []
	for id: Variant in SEA.values() + WIND.values():
		entries.append(
			{
				"id": String(id),
				"bus": "Ambience",
				"streams": ["res://sounds/weather/rain_roof.mp3"],
				"spatial": "none",
			}
		)
	var catalog := SfxCatalog.new()
	catalog.load_dictionary({"entries": entries})
	return catalog


func _install() -> AmbienceController:
	var ambience: AmbienceController = AmbienceControllerScript.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(ambience)
	ambience.set_catalog(_catalog())
	ambience.configure({"sea": SEA, "wind": WIND}, 4242)
	return ambience


func _settle(ambience: AmbienceController) -> void:
	for i in 30:
		ambience.sync(0.5, Vector3.ZERO, NOON)


func test_tier_weights_keep_equal_power() -> void:
	for strength: float in [0.0, 0.2, 0.5, 0.71, 1.0]:
		var w := AmbienceControllerScript.tier_weights(strength)
		assert_almost_eq(w[0] * w[0] + w[1] * w[1] + w[2] * w[2], 1.0, 0.001, "power at %s" % strength)
	var calm := AmbienceControllerScript.tier_weights(0.0)
	assert_almost_eq(calm[0], 1.0, 0.001, "still air is pure calm tier")
	var gale := AmbienceControllerScript.tier_weights(1.0)
	assert_almost_eq(gale[2], 1.0, 0.001, "full wind is pure storm tier")
	assert_almost_eq(gale[0], 0.0, 0.001, "calm never mixes into a gale")


func test_shore_gain_falls_off_inland() -> void:
	assert_almost_eq(AmbienceControllerScript.shore_gain(0.0), 1.0, 0.001)
	var near := AmbienceControllerScript.shore_gain(20.0)
	var mid := AmbienceControllerScript.shore_gain(90.0)
	assert_true(near > mid and mid > 0.0, "surf fades with distance")
	assert_eq(AmbienceControllerScript.shore_gain(AmbienceControllerScript.SEA_AUDIBLE_DISTANCE), 0.0)
	assert_eq(AmbienceControllerScript.shore_gain(INF), 0.0, "no sea nearby is silence")


func test_nearest_sea_distance_probes_rings() -> void:
	# Sea is everything with x >= 40.
	var is_sea := func(xz: Vector2) -> bool: return xz.x >= 40.0
	var at_shore := AmbienceControllerScript.nearest_sea_distance(Vector2(40.0, 0.0), is_sea)
	assert_eq(at_shore, 0.0, "standing in the sea")
	var inland := AmbienceControllerScript.nearest_sea_distance(Vector2.ZERO, is_sea)
	assert_true(inland >= 40.0 and inland <= 45.0, "first ring past 40 m, got %s" % inland)
	var far := AmbienceControllerScript.nearest_sea_distance(Vector2(-500.0, 0.0), is_sea)
	assert_true(is_inf(far), "beyond the probe the sea is out of earshot")


func test_calm_and_storm_pick_different_surf() -> void:
	var ambience := _install()
	ambience.set_exterior_weather(0.0, 0.0, 5.0, false)
	_settle(ambience)
	var ids := ambience.active_layer_ids()
	assert_array_contains(ids, SEA["calm"], "calm sea in still air")
	assert_false(ids.has(SEA["storm"]), "no storm breakers in still air")
	ambience.set_exterior_weather(1.0, 0.0, 5.0, false)
	_settle(ambience)
	ids = ambience.active_layer_ids()
	assert_array_contains(ids, SEA["storm"], "storm breakers in a gale")
	assert_array_contains(ids, WIND["storm"], "storm wind in a gale")
	assert_false(ids.has(SEA["calm"]), "calm surf fades out in a gale")
	ambience.queue_free()


func test_surf_is_silent_far_inland_but_wind_still_blows() -> void:
	var ambience := _install()
	ambience.set_exterior_weather(0.5, 0.0, INF, false)
	_settle(ambience)
	var ids := ambience.active_layer_ids()
	for id: Variant in SEA.values():
		assert_false(ids.has(id), "no surf inland: %s" % id)
	assert_array_contains(ids, WIND["strong"], "wind is not tied to the shore")
	ambience.queue_free()


func test_interior_mutes_sea_and_wind() -> void:
	var ambience := _install()
	ambience.set_exterior_weather(0.8, 0.5, 0.0, true)
	_settle(ambience)
	assert_eq(ambience.active_layer_ids().size(), 0, "interiors hear neither sea nor wind")
	ambience.queue_free()


func test_gusts_lift_the_wind() -> void:
	assert_true(
		AmbienceControllerScript.wind_level(0.3, 1.0) > AmbienceControllerScript.wind_level(0.3, 0.0)
	)
	assert_true(AmbienceControllerScript.wind_level(0.0, 0.0) > 0.0, "still air keeps a faint breath")


func test_coastal_profiles_declare_all_tiers() -> void:
	for map_id: StringName in [&"reval_city", &"world_saaremaa"]:
		var profile := AmbienceProfilesScript.profile_for_map(map_id)
		for tier: StringName in AmbienceControllerScript.SEA_TIERS:
			assert_true(profile.get("sea", {}).has(String(tier)), "%s sea %s" % [map_id, tier])
		for tier: StringName in AmbienceControllerScript.WIND_TIERS:
			assert_true(profile.get("wind", {}).has(String(tier)), "%s wind %s" % [map_id, tier])

extends "res://tests/godot/test_case.gd"

const MusicDirectorScript := preload("res://scripts/global/music_director.gd")

const CITY_SCENE := "res://scenes/world/reval_city/reval_city.tscn"


func test_every_zone_theme_is_a_real_theme_with_tracks() -> void:
	for zone: Dictionary in CityMusicZones.ZONES:
		var theme: StringName = zone["theme"]
		assert_true(MusicDirectorScript.has_theme(theme), "%s: unknown theme %s" % [zone["id"], theme])
		assert_false(
			MusicDirectorScript.day_track_paths_for_theme(theme).is_empty(),
			"%s: theme %s has no tracks" % [zone["id"], theme]
		)


func test_zone_centres_are_inside_the_plan() -> void:
	var plan := CityPlan.load_default()
	for zone: Dictionary in CityMusicZones.ZONES:
		var at: Vector2 = zone["at"]
		assert_true(plan.bounds.has_point(at), "%s centre is outside the plan bounds" % zone["id"])


func test_music_follows_position() -> void:
	assert_eq(CityMusicZones.theme_at(Vector2(5, -10), "district.lower_town"), &"center")
	assert_eq(CityMusicZones.theme_at(Vector2(-13, 15), "district.lower_town"), &"raekoda")
	assert_eq(CityMusicZones.theme_at(Vector2(111, -445), "district.lower_town"), &"oleviste")
	assert_eq(CityMusicZones.theme_at(Vector2(230, -640)), &"harbor")
	assert_eq(CityMusicZones.theme_at(Vector2(-400, 100), "district.toompea"), &"toompea")
	assert_eq(CityMusicZones.theme_at(Vector2(-342, 24), "district.toompea"), &"st_mary")
	assert_eq(CityMusicZones.theme_at(Vector2(-332, -26), "district.toompea"), &"dome_school")
	assert_eq(CityMusicZones.theme_at(Vector2(170, -180), "district.lower_town"), &"tavern")
	assert_eq(CityMusicZones.theme_at(Vector2(200, 40), "district.viru"), &"viru")


func test_district_is_the_fallback_and_fields_are_silent() -> void:
	# Far from every zone: the district decides, and open country has no theme.
	assert_eq(CityMusicZones.theme_at(Vector2(2000, 2000), "district.lower_town"), &"center")
	assert_eq(CityMusicZones.theme_at(Vector2(2000, 2000), ""), &"")


func test_hysteresis_holds_theme_just_outside_its_radius() -> void:
	var zone: Dictionary = CityMusicZones.ZONES[0]
	var at: Vector2 = zone["at"]
	var radius: float = zone["radius"]
	var just_out := at + Vector2(radius * 1.1, 0.0)
	assert_ne(CityMusicZones.theme_at(just_out, ""), zone["theme"], "fresh visit leaves at the radius")
	assert_eq(
		CityMusicZones.theme_at(just_out, "", zone["theme"]), zone["theme"], "held while leaving"
	)
	var far := at + Vector2(radius * 1.5, 0.0)
	assert_ne(
		CityMusicZones.theme_at(far, "", zone["theme"]), zone["theme"], "released once clearly out"
	)


func test_city_scene_has_no_scene_theme() -> void:
	assert_true(MusicDirectorScript.SCENE_THEME_ROUTES.has(CITY_SCENE))
	assert_true(MusicDirectorScript.theme_for_scene(CITY_SCENE).is_empty())

extends "res://tests/godot/test_case.gd"

const MusicDirectorScript = preload("res://scripts/global/music_director.gd")
const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")

const DISTRICT_SCENE_THEMES: Dictionary = {
	"res://scenes/reval_east/reval_east.tscn": &"town",
	"res://scenes/reval_east/viru_gate_foreland/viru_gate_foreland.tscn": &"town",
	"res://scenes/reval_center/reval_center.tscn": &"center",
	"res://scenes/reval_center/market_civic_quarter/olaf_guild_hall.tscn": &"center",
	"res://scenes/reval_center/town_hall/town_hall.tscn": &"center",
	"res://scenes/reval_north/reval_north.tscn": &"north",
	"res://scenes/reval_monastery/reval_monastery.tscn": &"monastery",
	"res://scenes/harbor/harbor_north.tscn": &"harbor",
	"res://scenes/harbor/harbor_east.tscn": &"harbor",
	"res://scenes/reval_toompea/reval_toompea.tscn": &"toompea",
	"res://scenes/reval_south/reval_south.tscn": &"south",
}


func test_all_traversable_districts_route_to_restored_themes() -> void:
	for scene_path: String in DISTRICT_SCENE_THEMES:
		assert_eq(
			MusicDirectorScript.theme_for_scene(scene_path),
			DISTRICT_SCENE_THEMES[scene_path],
			"traversable district should use its location-specific theme"
		)


func test_all_district_themes_have_loadable_day_tracks() -> void:
	for theme_id: StringName in DISTRICT_SCENE_THEMES.values():
		var track_paths := MusicDirectorScript.day_track_paths_for_theme(theme_id)
		assert_false(track_paths.is_empty(), "district theme %s should have restored tracks" % theme_id)
		for track_path: String in track_paths:
			assert_true(ResourceLoader.exists(track_path), "restored track should load: %s" % track_path)


func test_volume_fades_to_half_at_midnight() -> void:
	var noon_linear := MusicDirectorScript.volume_linear_for_day_blend(DayNightCycle.day_blend(0.5))
	var midnight_linear := MusicDirectorScript.volume_linear_for_day_blend(DayNightCycle.day_blend(0.0))
	assert_true(is_equal_approx(noon_linear, 1.0), "noon should keep full linear volume")
	assert_true(is_equal_approx(midnight_linear, 0.5), "midnight should duck to 50 percent linear volume")


func test_volume_db_follows_cycle_progress() -> void:
	var day_db := MusicDirectorScript.volume_db_for_cycle_progress(0.5)
	var night_db := MusicDirectorScript.volume_db_for_cycle_progress(0.0)
	assert_true(day_db > night_db, "night volume must be quieter than day volume")
	assert_true(
		is_equal_approx(day_db, MusicDirectorScript.DEFAULT_VOLUME_DB),
		"noon should use the default theme volume"
	)



func test_cycle_progress_is_exposed_for_hud_animation() -> void:
	assert_true(is_equal_approx(MusicDirector.get_cycle_progress(), DayNightCycle.DEFAULT_PROGRESS))


func test_is_cycle_active_tracks_set_and_clear() -> void:
	MusicDirector.clear_cycle_progress()
	assert_false(MusicDirector.is_cycle_active())
	MusicDirector.set_cycle_progress(0.4)
	assert_true(MusicDirector.is_cycle_active())
	assert_true(is_equal_approx(MusicDirector.get_cycle_progress(), 0.4))
	MusicDirector.clear_cycle_progress()
	assert_false(MusicDirector.is_cycle_active())



func test_elapsed_solar_days_advance_calendar_and_reset_with_cycle() -> void:
	MusicDirector.clear_cycle_progress()
	var initial_phase := SkyWeather3D.lunar_phase(MusicDirector.current_calendar_date())
	MusicDirector.set_cycle_progress(0.0)
	MusicDirector.set_cycle_elapsed_days(1)
	assert_eq(MusicDirector.current_calendar_date(), {"day": 22, "month": 4, "year": 1343})
	assert_eq(MusicDirector.get_cycle_elapsed_days(), 1)
	var phase_step := fposmod(
		SkyWeather3D.lunar_phase(MusicDirector.current_calendar_date()) - initial_phase,
		1.0
	)
	assert_true(
		phase_step > 0.03 and phase_step < 0.04,
		"one completed solar day must advance the lunar phase by one synodic day"
	)
	MusicDirector.clear_cycle_progress()
	assert_eq(MusicDirector.get_cycle_elapsed_days(), 0)
	assert_eq(MusicDirector.current_calendar_date(), {"day": 21, "month": 4, "year": 1343})

func test_active_slice_themes_have_no_night_tracks_yet() -> void:
	for theme_id: StringName in [&"forge", &"town"]:
		assert_true(
			MusicDirectorScript.night_track_paths_for_theme(theme_id).is_empty(),
			"active slice themes have no approved night folders yet"
		)


func test_toompea_has_distinct_day_and_night_playlists() -> void:
	var day_paths := MusicDirectorScript.day_track_paths_for_theme(&"toompea")
	var night_paths := MusicDirectorScript.night_track_paths_for_theme(&"toompea")
	assert_false(day_paths.is_empty(), "Toompea should have restored daytime music")
	assert_false(night_paths.is_empty(), "Toompea should have restored nighttime music")
	assert_ne(day_paths, night_paths, "Toompea day and night playlists should stay distinct")


func test_night_track_paths_fallback_to_day_when_missing() -> void:
	var day_paths := MusicDirectorScript.day_track_paths_for_theme(&"town")
	var resolved := MusicDirectorScript.theme_track_paths(&"town", true)
	assert_eq(resolved, day_paths, "missing night tracks must fall back to day playlist")


func test_is_night_period_matches_visual_bucket() -> void:
	assert_true(MusicDirectorScript.is_night_period(0.0), "midnight must count as night")
	assert_false(MusicDirectorScript.is_night_period(0.5), "noon must count as day")

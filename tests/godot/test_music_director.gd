extends "res://tests/godot/test_case.gd"

const MusicDirectorScript = preload("res://scripts/global/music_director.gd")
const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")


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


func test_active_themes_have_no_night_tracks_yet() -> void:
	for theme_id: StringName in [&"forge", &"town"]:
		assert_true(
			MusicDirectorScript.night_track_paths_for_theme(theme_id).is_empty(),
			"active slice themes have no approved night folders yet"
		)


func test_night_track_paths_fallback_to_day_when_missing() -> void:
	var day_paths := MusicDirectorScript.day_track_paths_for_theme(&"town")
	var resolved := MusicDirectorScript.theme_track_paths(&"town", true)
	assert_eq(resolved, day_paths, "missing night tracks must fall back to day playlist")


func test_is_night_period_matches_visual_bucket() -> void:
	assert_true(MusicDirectorScript.is_night_period(0.0), "midnight must count as night")
	assert_false(MusicDirectorScript.is_night_period(0.5), "noon must count as day")

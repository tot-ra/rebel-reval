extends "res://tests/godot/test_case.gd"

const MusicDirectorScript = preload("res://scripts/global/music_director.gd")
const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")

## Scenes that still pick their own theme; the seamless city picks per zone instead
## (CityMusicZones), so these are the themes it can ask for.
const DISTRICT_SCENE_THEMES: Dictionary = {
	"res://scenes/reval_east/forge/forge.tscn": &"forge",
}
const CITY_ZONE_THEMES: Array[StringName] = [
	&"center", &"raekoda", &"holy_spirit", &"north", &"oleviste", &"monastery", &"south",
	&"town", &"forge", &"garden", &"harbor", &"toompea",
	&"viru", &"tavern", &"st_mary", &"dome_school",
]


func test_all_traversable_districts_route_to_restored_themes() -> void:
	for scene_path: String in DISTRICT_SCENE_THEMES:
		assert_eq(
			MusicDirectorScript.theme_for_scene(scene_path),
			DISTRICT_SCENE_THEMES[scene_path],
			"traversable district should use its location-specific theme"
		)


func test_all_district_themes_have_loadable_day_tracks() -> void:
	for theme_id: StringName in CITY_ZONE_THEMES:
		var track_paths := MusicDirectorScript.day_track_paths_for_theme(theme_id)
		assert_false(track_paths.is_empty(), "district theme %s should have restored tracks" % theme_id)
		for track_path: String in track_paths:
			assert_true(ResourceLoader.exists(track_path), "restored track should load: %s" % track_path)


func test_volume_fades_to_half_at_midnight() -> void:
	var noon_blend := DayNightCycle.day_blend(0.5)
	var midnight_blend := DayNightCycle.day_blend(0.0)
	var noon_linear := MusicDirectorScript.volume_linear_for_day_blend(noon_blend)
	var midnight_linear := MusicDirectorScript.volume_linear_for_day_blend(midnight_blend)
	assert_true(is_equal_approx(noon_linear, 1.0), "noon should keep full linear volume")
	assert_true(
		is_equal_approx(midnight_linear, 0.5),
		"midnight should duck to 50 percent linear volume"
	)


func test_volume_db_follows_cycle_progress() -> void:
	var day_db := MusicDirectorScript.volume_db_for_cycle_progress(0.5)
	var night_db := MusicDirectorScript.volume_db_for_cycle_progress(0.0)
	assert_true(day_db > night_db, "night volume must be quieter than day volume")
	assert_true(
		is_equal_approx(day_db, MusicDirectorScript.DEFAULT_VOLUME_DB),
		"noon should use the default theme volume"
	)



func test_cycle_progress_is_exposed_for_hud_animation() -> void:
	MusicDirector.clear_cycle_progress()
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

func test_active_slice_themes_use_manifest_track_lists() -> void:
	var forge_paths := MusicDirectorScript.day_track_paths_for_theme(&"forge")
	var town_paths := MusicDirectorScript.day_track_paths_for_theme(&"town")
	assert_eq(forge_paths.size(), 1, "slice forge theme should ship one approved track")
	assert_eq(town_paths.size(), 2, "slice town theme should ship two approved tracks")
	assert_true(
		forge_paths[0].ends_with("Fireside Tale.mp3"),
		"slice forge theme should keep Fireside Tale"
	)


func test_holy_spirit_church_uses_dedicated_hymn_playlist() -> void:
	var track_paths := MusicDirectorScript.day_track_paths_for_theme(&"holy_spirit")
	assert_true(
		track_paths.has("res://music/revel_center/holy spirit church/Hymn of the Holy Spirit.mp3"),
		"Holy Spirit chapel should play the hymn"
	)
	for track_path: String in track_paths:
		assert_true(track_path.contains("Hymn of the Holy Spirit"), "chapel plays only hymn takes")
		assert_true(ResourceLoader.exists(track_path), "hymn track should load: %s" % track_path)


func test_town_slice_theme_has_no_night_tracks() -> void:
	assert_true(
		MusicDirectorScript.night_track_paths_for_theme(&"town").is_empty(),
		"the slice town theme has no approved night folder"
	)


## R-1576: the smithy adds The Smith's Song at night; the day list stays the slice track.
func test_forge_night_adds_smiths_song() -> void:
	var night_paths := MusicDirectorScript.night_track_paths_for_theme(&"forge")
	assert_true(night_paths.has("res://music/forge/Fireside Tale.mp3"), "night keeps Fireside Tale")
	assert_true(
		night_paths.has("res://music/forge/The Smith's Song.mp3"), "night adds The Smith's Song"
	)
	for track_path: String in night_paths:
		assert_true(ResourceLoader.exists(track_path), "forge night track should load: %s" % track_path)


## R-1576: the seamless Viru quarter plays every revel_east track, not just the two slice tracks.
func test_viru_theme_scans_the_restored_east_folder() -> void:
	var viru_paths := MusicDirectorScript.day_track_paths_for_theme(&"viru")
	var town_paths := MusicDirectorScript.day_track_paths_for_theme(&"town")
	for track_path: String in town_paths:
		assert_true(viru_paths.has(track_path), "viru should include slice track %s" % track_path)
	assert_true(viru_paths.size() > town_paths.size(), "viru should add the restored east tracks")


func test_day_night_themes_have_distinct_playlists() -> void:
	for theme_id: StringName in [&"toompea", &"st_mary", &"dome_school"]:
		var day_paths := MusicDirectorScript.day_track_paths_for_theme(theme_id)
		var night_paths := MusicDirectorScript.night_track_paths_for_theme(theme_id)
		assert_false(day_paths.is_empty(), "%s should have daytime music" % theme_id)
		assert_false(night_paths.is_empty(), "%s should have nighttime music" % theme_id)
		assert_ne(day_paths, night_paths, "%s day and night playlists should stay distinct" % theme_id)
		for track_path: String in night_paths:
			assert_true(ResourceLoader.exists(track_path), "night track should load: %s" % track_path)


func test_apothecary_theme_is_registered_for_interiors() -> void:
	assert_true(MusicDirectorScript.has_theme(&"apothecary"))
	assert_false(MusicDirectorScript.day_track_paths_for_theme(&"apothecary").is_empty())


func test_night_track_paths_fallback_to_day_when_missing() -> void:
	var day_paths := MusicDirectorScript.day_track_paths_for_theme(&"town")
	var resolved := MusicDirectorScript.theme_track_paths(&"town", true)
	assert_eq(resolved, day_paths, "missing night tracks must fall back to day playlist")


func test_is_night_period_matches_visual_bucket() -> void:
	assert_true(MusicDirectorScript.is_night_period(0.0), "midnight must count as night")
	assert_false(MusicDirectorScript.is_night_period(0.5), "noon must count as day")

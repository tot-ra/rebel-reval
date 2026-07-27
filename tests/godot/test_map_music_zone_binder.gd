extends "res://tests/godot/test_case.gd"

const MusicDirectorScript := preload("res://scripts/global/music_director.gd")
const MapMusicZoneBinder := preload("res://scripts/map/map_music_zone_binder.gd")
const ToompeaQuarterDefinition := preload("res://scripts/map/definitions/prototypes/toompea_quarter_definition.gd")


func test_garden_theme_has_loadable_day_and_night_tracks() -> void:
	var day_paths := MusicDirectorScript.day_track_paths_for_theme(&"garden")
	var night_paths := MusicDirectorScript.night_track_paths_for_theme(&"garden")
	assert_false(day_paths.is_empty(), "garden theme should ship daytime tracks")
	assert_false(night_paths.is_empty(), "garden theme should ship nighttime tracks")
	for track_path: String in day_paths:
		assert_true(ResourceLoader.exists(track_path), "garden day track should load: %s" % track_path)
	for track_path: String in night_paths:
		assert_true(ResourceLoader.exists(track_path), "garden night track should load: %s" % track_path)


func test_toompea_compiles_danish_kings_garden_music_zone() -> void:
	var definition := ToompeaQuarterDefinition.create()
	var garden_volume: Dictionary = {}
	for volume in definition.fade_volumes:
		if volume.get("id", &"") == &"fade.danish_kings_garden":
			garden_volume = volume
			break
	assert_false(garden_volume.is_empty(), "Toompea should author a Danish King's Garden fade volume")
	assert_eq(garden_volume.get("music_theme", &""), &"garden")


func test_music_zone_binder_selects_garden_on_eastern_slope() -> void:
	var definition := ToompeaQuarterDefinition.create()
	var garden_volume: Dictionary = {}
	for volume in definition.fade_volumes:
		if volume.get("id", &"") == &"fade.danish_kings_garden":
			garden_volume = volume
			break
	var rect := garden_volume["rect"] as Rect2
	var player := CharacterBody2D.new()
	player.global_position = rect.get_center()

	var binder := MapMusicZoneBinder.new()
	binder.configure(definition, player)
	assert_eq(binder._theme_at_player_position(), &"garden")

	player.global_position = rect.position - Vector2(8, 8)
	assert_true(binder._theme_at_player_position().is_empty())

	player.free()
	binder.free()

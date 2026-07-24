extends "res://tests/godot/test_case.gd"

const SkyWeatherRoofAudio := preload("res://scripts/map/view3d/sky_weather_roof_audio.gd")
const ROOF_LOOP_PATH := "res://sounds/weather/rain_roof.mp3"


func test_rain_roof_clip_imports_as_loopable_audio() -> void:
	assert_true(ResourceLoader.exists(ROOF_LOOP_PATH), "roof rain clip must exist")
	var stream := load(ROOF_LOOP_PATH) as AudioStream
	assert_true(stream is AudioStream, "roof rain clip must import as AudioStream")
	assert_true(stream.get_length() >= 30.0, "roof loop must be long enough to avoid obvious seams")
	assert_true(stream.get_length() <= 60.0, "roof loop must stay within the authored cap")


func test_roof_audio_target_volume_follows_suppression_and_intensity() -> void:
	assert_false(
		SkyWeatherRoofAudio.should_play_roof_audio(false, 1.0),
		"outdoor rain must not trigger the roof bed"
	)
	assert_false(
		SkyWeatherRoofAudio.should_play_roof_audio(true, 0.0),
		"dry interiors stay silent"
	)
	assert_true(
		SkyWeatherRoofAudio.should_play_roof_audio(true, 1.0),
		"a roofed interior during rain must request the bed"
	)
	var half := SkyWeatherRoofAudio.target_linear_volume(true, 0.5)
	var full := SkyWeatherRoofAudio.target_linear_volume(true, 1.0)
	assert_true(half > 0.0 and full > half, "roof volume must crossfade with rain intensity")
	assert_eq(
		SkyWeatherRoofAudio.target_linear_volume(true, 1.0, false),
		0.0,
		"disabling audio must not change the weather field, only mute playback"
	)


func test_roof_audio_player_respects_suppression() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var roof := SkyWeatherRoofAudio.new()
	tree.root.add_child(roof)
	roof.sync(false, 1.0)
	assert_false(roof.roof_audio_active(), "outdoor suppression keeps the roof player silent")
	roof.sync(true, 1.0)
	assert_true(roof.roof_audio_active(), "roofed rain must audibly arm the player")
	var weather_before := 1.0
	roof.set_audio_enabled(false)
	roof.sync(true, weather_before)
	assert_false(roof.roof_audio_active(), "muting audio must not require a weather change")
	roof.queue_free()

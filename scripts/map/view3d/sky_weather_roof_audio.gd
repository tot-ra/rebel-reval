class_name SkyWeatherRoofAudio
extends Node

## Muffled rain-on-roof bed for enclosed interiors (P0-124). Plays only while
## the weather controller reports suppressed falling rain and a non-zero profile.

const AudioBusService := preload("res://scripts/settings/audio_bus_service.gd")
const ROOF_LOOP_PATH := "res://sounds/weather/rain_roof.mp3"
const RAIN_AUDIBLE_THRESHOLD := 0.02
const MAX_LINEAR_VOLUME := 0.42
const FADE_DB_PER_SECOND := 12.0
const SILENCE_DB := -80.0

var _player: AudioStreamPlayer
var _audio_enabled := true


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "RoofRainPlayer"
	var stream := load(ROOF_LOOP_PATH) as AudioStream
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	_player.stream = stream
	_player.volume_db = SILENCE_DB
	AudioBusService.assign_bus(_player, AudioBusService.BUS_SFX)
	add_child(_player)


func set_audio_enabled(enabled: bool) -> void:
	_audio_enabled = enabled
	if not enabled:
		_stop_immediately()


func sync(rain_suppressed: bool, rain_intensity: float, delta: float = 0.0) -> void:
	if _player == null:
		return
	var target_linear := target_linear_volume(rain_suppressed, rain_intensity, _audio_enabled)
	var target_db := SILENCE_DB
	if target_linear > 0.0:
		target_db = linear_to_db(target_linear)
	if delta > 0.0:
		var step_db := FADE_DB_PER_SECOND * delta
		if target_db > _player.volume_db:
			_player.volume_db = minf(target_db, _player.volume_db + step_db)
		else:
			_player.volume_db = maxf(target_db, _player.volume_db - step_db)
	else:
		_player.volume_db = target_db
	if target_linear > 0.0:
		if not _player.playing:
			_player.play()
	elif _player.volume_db <= SILENCE_DB + 1.0:
		_stop_immediately()


static func should_play_roof_audio(
	rain_suppressed: bool,
	rain_intensity: float,
	audio_enabled: bool = true
) -> bool:
	return audio_enabled and rain_suppressed and rain_intensity > RAIN_AUDIBLE_THRESHOLD


static func target_linear_volume(
	rain_suppressed: bool,
	rain_intensity: float,
	audio_enabled: bool = true
) -> float:
	if not should_play_roof_audio(rain_suppressed, rain_intensity, audio_enabled):
		return 0.0
	return clampf(rain_intensity, 0.0, 1.0) * MAX_LINEAR_VOLUME


func roof_audio_active() -> bool:
	return (
		_player != null
		and _player.playing
		and _player.volume_db > SILENCE_DB + 1.0
	)


func roof_audio_linear_volume() -> float:
	if _player == null or not _player.playing or _player.volume_db <= SILENCE_DB + 1.0:
		return 0.0
	return db_to_linear(_player.volume_db)


func _stop_immediately() -> void:
	if _player == null:
		return
	_player.stop()
	_player.volume_db = SILENCE_DB

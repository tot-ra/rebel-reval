class_name NunnatornAudioController
extends Node

## R-628: restrained roof-and-wind bed for the enclosed Nunnatorn tower.
## Presentation only: this node never reads or mutates encounter, save, or map state.

const AudioBusService := preload("res://scripts/settings/audio_bus_service.gd")

## Catalog ID (ADR 0035); the clip and bus live in content/audio/sfx_catalog.json.
## The catalog trim is deliberately not applied: this bed is driven by its own
## MAX_LINEAR_VOLUME and migrating must not change how it sounds.
const ROOF_SOUND_ID := &"amb.weather.rain_roof"
## Used only when the catalog entry is missing.
const ROOF_LOOP_FALLBACK_PATH := "res://sounds/weather/rain_roof.mp3"
const RAIN_AUDIBLE_THRESHOLD := 0.02
const MAX_LINEAR_VOLUME := 0.30
const FADE_DB_PER_SECOND := 12.0
const SILENCE_DB := -80.0

var _player: AudioStreamPlayer
var _audio_enabled := true


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "NunnatornRoofBed"
	var entry := SfxCatalog.load_default().get_entry(ROOF_SOUND_ID)
	var stream_path := ROOF_LOOP_FALLBACK_PATH
	var bus := AudioBusService.BUS_SFX
	if entry.has("streams"):
		stream_path = String(entry["streams"][0])
		bus = StringName(entry.get("bus", bus))
	var stream := load(stream_path) as AudioStream
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	_player.stream = stream
	_player.volume_db = SILENCE_DB
	AudioBusService.assign_bus(_player, bus)
	add_child(_player)


func set_audio_enabled(enabled: bool) -> void:
	_audio_enabled = enabled
	if not enabled:
		_stop_immediately()


func sync(rain_intensity: float, delta: float = 0.0) -> void:
	if _player == null:
		return
	var target_linear := target_linear_volume(rain_intensity, _audio_enabled)
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


static func target_linear_volume(rain_intensity: float, audio_enabled: bool = true) -> float:
	if not audio_enabled or rain_intensity <= RAIN_AUDIBLE_THRESHOLD:
		return 0.0
	return clampf(rain_intensity, 0.0, 1.0) * MAX_LINEAR_VOLUME


func audio_active() -> bool:
	return _player != null and _player.playing and _player.volume_db > SILENCE_DB + 1.0


func linear_volume() -> float:
	if not audio_active():
		return 0.0
	return db_to_linear(_player.volume_db)


func _stop_immediately() -> void:
	if _player == null:
		return
	_player.stop()
	_player.volume_db = SILENCE_DB

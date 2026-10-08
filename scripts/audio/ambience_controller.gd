class_name AmbienceController
extends Node

## Layered ambience for one map (ADR 0035 phase 2): a quiet looping bed, a
## mid-ground loop, sporadic positional spot one-shots, and a weather overlay.
## Layers are declared per map in AmbienceProfiles and addressed by catalog ID.
##
## Why layers instead of one long loop: a fixed-interval distinctive event near
## a loop point exposes the loop, so distinctive material lives in the spot
## layer with randomised intervals and positions.
##
## The weather layer covers *exterior* rain only. Muffled rain on a roof stays
## with SkyWeatherRoofAudio, which is already mounted in SkyWeather3D; running
## both would double the indoor rain.
##
## Crossfades follow music_director.gd: a per-second dB ramp toward a target,
## never an instant cut. Selection uses a private seeded RNG and never touches
## game state; nothing here is saved.

const SfxPlayerScript := preload("res://scripts/audio/sfx_player.gd")
const AudioBusServiceScript := preload("res://scripts/settings/audio_bus_service.gd")

const SILENCE_DB := -80.0
const FADE_DB_PER_SECOND := 9.0
## Soundscape budget: more simultaneous spot voices than this would bury the
## cues the player must hear (Pires/Alves/Roque "healthy soundscape").
const MAX_CONCURRENT_SPOTS := 2
const SPOT_RADIUS_MIN := 8.0
const SPOT_RADIUS_MAX := 26.0
const SPOT_HEIGHT := 1.6
## Rain is audible from this intensity up; below it the overlay stays silent.
const RAIN_AUDIBLE_THRESHOLD := 0.02

var _catalog: SfxCatalog
var _sfx: SfxPlayer
var _rng := RandomNumberGenerator.new()
var _profile: Dictionary = {}
var _audio_enabled := true
var _listener := Vector3.ZERO
var _cycle_progress := DayNightCycle.DEFAULT_PROGRESS
## sound_id -> {"player": AudioStreamPlayer, "target_db": float}
var _loops: Dictionary = {}
## spot index -> seconds until the next attempt
var _spot_countdown: PackedFloat32Array = PackedFloat32Array()
var _active_spots: Array[Node] = []
var _spot_play_count := 0
var _last_spot_id := &""


func _ready() -> void:
	_catalog = SfxCatalog.load_default()
	_sfx = SfxPlayerScript.new()
	_sfx.name = "AmbienceSpotPlayer"
	add_child(_sfx)
	_sfx.setup(_catalog, hash("ambience"))


## `profile` is an AmbienceProfiles entry. Passing an empty dictionary parks the
## controller silently, which is what unsupported maps get.
func configure(profile: Dictionary, rng_seed: int = 0) -> void:
	_profile = profile
	if rng_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = rng_seed
	_stop_all_loops()
	var spots: Array = _profile.get("spot", [])
	_spot_countdown.resize(spots.size())
	for index in spots.size():
		_spot_countdown[index] = _next_spot_delay(spots[index])


## Override seam for tests, which assert layer behaviour against fixture
## entries rather than the shipped catalog.
func set_catalog(catalog: SfxCatalog) -> void:
	_catalog = catalog
	if _sfx != null:
		_sfx.setup(catalog, hash("ambience"))


func set_audio_enabled(enabled: bool) -> void:
	_audio_enabled = enabled
	if not enabled:
		_stop_all_loops()
		_stop_all_spots()


func sync(
	delta: float,
	listener: Vector3,
	cycle_progress: float,
	rain_intensity: float = 0.0,
	rain_suppressed: bool = false
) -> void:
	_listener = listener
	_cycle_progress = wrapf(cycle_progress, 0.0, 1.0)
	_prune_spots()
	if not _audio_enabled or _profile.is_empty():
		_fade_loops(delta)
		return
	for layer: StringName in [&"bed", &"mid"]:
		for entry: Dictionary in _profile.get(layer, []):
			_sync_loop_entry(entry, 1.0)
	_sync_weather_layer(rain_intensity, rain_suppressed)
	_retire_unwanted_loops()
	_fade_loops(delta)
	_sync_spots(delta)


## Catalog IDs currently fading in or playing. Tests and the debug overlay read
## this instead of walking the player nodes.
func active_layer_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for sound_id: StringName in _loops.keys():
		if float(_loops[sound_id]["target_db"]) > SILENCE_DB:
			ids.append(sound_id)
	ids.sort()
	return ids


func layer_linear_volume(sound_id: StringName) -> float:
	if not _loops.has(sound_id):
		return 0.0
	var player := _loops[sound_id]["player"] as AudioStreamPlayer
	if player == null or not player.playing or player.volume_db <= SILENCE_DB + 1.0:
		return 0.0
	return db_to_linear(player.volume_db)


func active_spot_count() -> int:
	return _active_spots.size()


func spot_play_count() -> int:
	return _spot_play_count


func last_spot_id() -> StringName:
	return _last_spot_id


## True while the clip's hour window contains the current time. An entry without
## an `hours` pair plays around the clock.
static func entry_audible_at_hour(entry: Dictionary, hour: float) -> bool:
	var hours: Array = entry.get("hours", [])
	if hours.size() != 2:
		return true
	var from := float(hours[0])
	var to := float(hours[1])
	if is_equal_approx(from, to):
		return true
	if from < to:
		return hour >= from and hour < to
	# Wrapping window, for example 21:00 to 05:00.
	return hour >= from or hour < to


func _sync_loop_entry(entry: Dictionary, gain: float) -> void:
	var sound_id := StringName(entry.get("id", &""))
	if String(sound_id).is_empty() or not _catalog.has_entry(sound_id):
		return
	var hour := DayNightCycle.progress_to_hour(_cycle_progress)
	if not entry_audible_at_hour(entry, hour):
		_set_loop_target(sound_id, SILENCE_DB)
		return
	var catalog_entry := _catalog.get_entry(sound_id)
	var base_db := float(catalog_entry.get("volume_db", 0.0)) + float(entry.get("volume_db", 0.0))
	var clamped_gain := clampf(gain, 0.0, 1.0)
	if clamped_gain <= 0.0:
		_set_loop_target(sound_id, SILENCE_DB)
		return
	_ensure_loop_player(sound_id, catalog_entry)
	_set_loop_target(sound_id, base_db + linear_to_db(clamped_gain))


func _sync_weather_layer(rain_intensity: float, rain_suppressed: bool) -> void:
	var weather: Dictionary = _profile.get("weather", {})
	var sound_id := StringName(weather.get("rain_exterior", &""))
	if String(sound_id).is_empty():
		return
	var gain := 0.0
	if not rain_suppressed and rain_intensity > RAIN_AUDIBLE_THRESHOLD:
		gain = clampf(rain_intensity, 0.0, 1.0)
	_sync_loop_entry({"id": sound_id}, gain)


## Silences loops the current profile/time no longer asks for, so a rebind or a
## dusk transition does not leave a stale bed running.
func _retire_unwanted_loops() -> void:
	var wanted: Dictionary = {}
	for layer: StringName in [&"bed", &"mid"]:
		for entry: Dictionary in _profile.get(layer, []):
			wanted[StringName(entry.get("id", &""))] = true
	var weather: Dictionary = _profile.get("weather", {})
	if not String(weather.get("rain_exterior", &"")).is_empty():
		wanted[StringName(weather["rain_exterior"])] = true
	for sound_id: StringName in _loops.keys():
		if not wanted.has(sound_id):
			_set_loop_target(sound_id, SILENCE_DB)


func _ensure_loop_player(sound_id: StringName, catalog_entry: Dictionary) -> void:
	if _loops.has(sound_id):
		return
	var stream := load(String(catalog_entry["streams"][0])) as AudioStream
	if stream == null:
		return
	# Beds must loop seamlessly; the catalog stores the clip, not the loop flag.
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var player := AudioStreamPlayer.new()
	player.name = "AmbienceLoop_%s" % String(sound_id).replace(".", "_")
	player.stream = stream
	player.volume_db = SILENCE_DB
	AudioBusServiceScript.assign_bus(player, StringName(catalog_entry.get("bus", &"Ambience")))
	add_child(player)
	_loops[sound_id] = {"player": player, "target_db": SILENCE_DB}


func _set_loop_target(sound_id: StringName, target_db: float) -> void:
	if _loops.has(sound_id):
		_loops[sound_id]["target_db"] = target_db


func _fade_loops(delta: float) -> void:
	var step := FADE_DB_PER_SECOND * maxf(delta, 0.0)
	for sound_id: StringName in _loops.keys():
		var record: Dictionary = _loops[sound_id]
		var player := record["player"] as AudioStreamPlayer
		if player == null:
			continue
		var target := float(record["target_db"])
		if step <= 0.0:
			player.volume_db = target
		elif target > player.volume_db:
			player.volume_db = minf(target, player.volume_db + step)
		else:
			player.volume_db = maxf(target, player.volume_db - step)
		if player.volume_db > SILENCE_DB + 1.0:
			if not player.playing:
				player.play()
		elif player.playing:
			player.stop()


func _sync_spots(delta: float) -> void:
	var spots: Array = _profile.get("spot", [])
	if spots.is_empty():
		return
	var hour := DayNightCycle.progress_to_hour(_cycle_progress)
	for index in spots.size():
		if index >= _spot_countdown.size():
			break
		_spot_countdown[index] = _spot_countdown[index] - maxf(delta, 0.0)
		if _spot_countdown[index] > 0.0:
			continue
		var entry: Dictionary = spots[index]
		_spot_countdown[index] = _next_spot_delay(entry)
		if not entry_audible_at_hour(entry, hour):
			continue
		if _active_spots.size() >= MAX_CONCURRENT_SPOTS:
			continue
		_play_spot(entry)


func _play_spot(entry: Dictionary) -> void:
	var sound_id := StringName(entry.get("id", &""))
	if String(sound_id).is_empty() or not _catalog.has_entry(sound_id):
		return
	var player := _sfx.play(sound_id, _random_spot_position(entry))
	if player == null:
		return
	_active_spots.append(player)
	_spot_play_count += 1
	_last_spot_id = sound_id


func _random_spot_position(entry: Dictionary) -> Vector3:
	var radius_min := float(entry.get("radius_min", SPOT_RADIUS_MIN))
	var radius_max := float(entry.get("radius_max", SPOT_RADIUS_MAX))
	var angle := _rng.randf_range(0.0, TAU)
	var radius := _rng.randf_range(radius_min, maxf(radius_max, radius_min))
	return _listener + Vector3(cos(angle) * radius, SPOT_HEIGHT, sin(angle) * radius)


func _next_spot_delay(entry: Dictionary) -> float:
	var minimum := float(entry.get("min_interval", 10.0))
	var maximum := maxf(float(entry.get("max_interval", 30.0)), minimum)
	return _rng.randf_range(minimum, maximum)


func _prune_spots() -> void:
	var alive: Array[Node] = []
	for node in _active_spots:
		if is_instance_valid(node) and node.get("playing"):
			alive.append(node)
	_active_spots = alive


func _stop_all_spots() -> void:
	for node in _active_spots:
		if is_instance_valid(node):
			node.call("stop")
	_active_spots.clear()


func _stop_all_loops() -> void:
	for sound_id: StringName in _loops.keys():
		var player := _loops[sound_id]["player"] as AudioStreamPlayer
		if player != null:
			player.stop()
			player.volume_db = SILENCE_DB
			player.queue_free()
	_loops.clear()

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
## Sea and wind (R-1550). Each layer holds three loops of the same place at
## rising weather (calm/moderate/storm surf, light/strong/storm wind) and
## crossfades between them by wind strength, so the weather changes the
## *character* of the sound, not only its level.
const SEA_TIERS: Array[StringName] = [&"calm", &"moderate", &"storm"]
const WIND_TIERS: Array[StringName] = [&"light", &"strong", &"storm"]
## Surf is full at the waterline and silent this far inland (world units, metres).
const SEA_AUDIBLE_DISTANCE := 180.0
## Wind is a faint breath in calm air and full in a gale; gusts lift it briefly.
## The tier clips are already mastered louder per tier (generate_sea_wind_beds.py),
## so surf needs no extra strength curve; wind gets one because still air should
## be near silent while a still sea still laps.
const WIND_CALM_LEVEL := 0.35
const WIND_GUST_BOOST := 0.35
## Ring probe for the nearest sea: radii (world units) and directions per ring.
const SEA_PROBE_RADII: Array[float] = [
	0.0, 6.0, 12.0, 20.0, 30.0, 45.0, 65.0, 90.0, 120.0, 150.0, 180.0
]
const SEA_PROBE_DIRECTIONS := 16

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
## Exterior weather fed by the runtime before sync (set_exterior_weather).
var _wind_strength := 0.0
var _wind_gust := 0.0
var _sea_distance := INF
var _exterior_suppressed := false


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
	_sync_sea_layer()
	_sync_wind_layer()
	_retire_unwanted_loops()
	_fade_loops(delta)
	_sync_spots(delta)


## Exterior state for the sea and wind layers, set by the runtime each frame
## before sync(). `sea_distance` is the distance in world units from the
## listener to the nearest sea (INF when none is near; see nearest_sea_distance).
## `exterior_suppressed` mutes both, for interiors.
func set_exterior_weather(
	wind_strength: float, wind_gust: float, sea_distance: float, exterior_suppressed: bool
) -> void:
	_wind_strength = clampf(wind_strength, 0.0, 1.0)
	_wind_gust = clampf(wind_gust, 0.0, 1.0)
	_sea_distance = sea_distance
	_exterior_suppressed = exterior_suppressed


## Amplitude weights for three tiers centred on strength 0, 0.5 and 1. Adjacent
## tiers crossfade at equal power (sqrt), so the sum of squares stays 1 and two
## uncorrelated noisy loops do not dip in loudness mid-fade.
static func tier_weights(strength: float) -> PackedFloat32Array:
	var s := clampf(strength, 0.0, 1.0)
	var weights := PackedFloat32Array([0.0, 0.0, 0.0])
	if s <= 0.5:
		var t := s / 0.5
		weights[0] = sqrt(1.0 - t)
		weights[1] = sqrt(t)
	else:
		var t := (s - 0.5) / 0.5
		weights[1] = sqrt(1.0 - t)
		weights[2] = sqrt(t)
	return weights


## Surf level by distance from the waterline: full at the water, quadratic
## falloff to silence at `audible_distance`.
static func shore_gain(distance: float, audible_distance: float = SEA_AUDIBLE_DISTANCE) -> float:
	if is_inf(distance) or is_nan(distance) or audible_distance <= 0.0:
		return 0.0
	var t := clampf(1.0 - maxf(distance, 0.0) / audible_distance, 0.0, 1.0)
	return t * t


static func wind_level(strength: float, gust: float) -> float:
	var s := clampf(strength, 0.0, 1.0)
	var level := lerpf(WIND_CALM_LEVEL, 1.0, s) * (1.0 + WIND_GUST_BOOST * clampf(gust, 0.0, 1.0))
	return clampf(level, 0.0, 1.0)


## Distance (world units) from `origin` to the nearest point where `is_sea`
## returns true, probed on rings of SEA_PROBE_RADII. Coarse by design: the
## result only drives a falloff curve. INF when no ring touches the sea.
static func nearest_sea_distance(origin: Vector2, is_sea: Callable) -> float:
	for radius: float in SEA_PROBE_RADII:
		if radius <= 0.0:
			if bool(is_sea.call(origin)):
				return 0.0
			continue
		for index in SEA_PROBE_DIRECTIONS:
			var angle := TAU * float(index) / float(SEA_PROBE_DIRECTIONS)
			if bool(is_sea.call(origin + Vector2(cos(angle), sin(angle)) * radius)):
				return radius
	return INF


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


## Profile "sea": {"calm": id, "moderate": id, "storm": id, optional
## "audible_distance"}. Tier mix by wind strength, level by shore distance.
func _sync_sea_layer() -> void:
	var sea: Dictionary = _profile.get("sea", {})
	if sea.is_empty():
		return
	var level := 0.0
	if not _exterior_suppressed:
		var audible := float(sea.get("audible_distance", SEA_AUDIBLE_DISTANCE))
		level = shore_gain(_sea_distance, audible)
	_sync_tier_loops(sea, SEA_TIERS, level)


## Profile "wind": {"light": id, "strong": id, "storm": id}.
func _sync_wind_layer() -> void:
	var wind: Dictionary = _profile.get("wind", {})
	if wind.is_empty():
		return
	var level := 0.0 if _exterior_suppressed else wind_level(_wind_strength, _wind_gust)
	_sync_tier_loops(wind, WIND_TIERS, level)


func _sync_tier_loops(layer: Dictionary, tiers: Array[StringName], level: float) -> void:
	var weights := tier_weights(_wind_strength)
	for index in tiers.size():
		# Profile keys are Strings; a StringName key would miss them.
		var sound_id := StringName(layer.get(String(tiers[index]), &""))
		if not String(sound_id).is_empty():
			_sync_loop_entry({"id": sound_id}, level * weights[index])


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
	for layer_name: String in ["sea", "wind"]:
		for tier_id: Variant in _profile.get(layer_name, {}).values():
			if tier_id is StringName:
				wanted[tier_id] = true
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
